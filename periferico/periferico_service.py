"""
GEBAN Periférico Service — Serviço genérico de controle de periféricos PDV.

Arquitetura plug-and-play:
- Drivers são módulos Python na pasta drivers/
- Cada driver implementa a interface PerifericoDriver
- Configuração por cliente em config/perifericos.json
- Auto-detecção de dispositivos USB/serial na inicialização

Uso:
    python periferico_service.py [--config config/perifericos.json] [--port 9100]

WebSocket server na porta 9100 para comunicação com frontend PDV.
"""

import asyncio
import json
import logging
import os
import sys
import tempfile
from abc import ABC, abstractmethod
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    serial = None
try:
    import usb.core
    import usb.util
    HAS_PYUSB = True
except ImportError:
    HAS_PYUSB = False

# Configuração do logger
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('geban-periferico')


# =============================================================================
# Interface Base para Drivers
# =============================================================================

class PerifericoDriver(ABC):
    """Interface base para todos os drivers de periféricos."""
    
    name: str = "base"
    tipo: str = "UNKNOWN"
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.connected = False
        self.device = None
        self.last_error = None
    
    @abstractmethod
    async def connect(self) -> bool:
        """Conecta ao dispositivo. Retorna True se sucesso."""
        pass
    
    @abstractmethod
    async def disconnect(self) -> None:
        """Desconecta do dispositivo."""
        pass
    
    async def health_check(self) -> Dict[str, Any]:
        """Testa conectividade. Retorna dict com status."""
        return {
            "connected": self.connected,
            "driver": self.name,
            "tipo": self.tipo,
            "last_error": self.last_error
        }
    
    # Métodos específicos por tipo de periférico
    async def print_receipt(self, data: bytes) -> bool:
        """Imprime cupom (subclass deve implementar)."""
        raise NotImplementedError
    
    async def read_barcode(self, timeout_ms: int = 5000) -> Optional[str]:
        """Lê código de barras (subclass deve implementar)."""
        raise NotImplementedError
    
    async def authorize_transaction(
        self, 
        amount: float, 
        type: str = "CREDIT"
    ) -> Dict[str, Any]:
        """Autoriza transação de cartão (subclass deve implementar)."""
        raise NotImplementedError
    
    async def read_weight(self) -> Optional[float]:
        """Lê peso da balança (subclass deve implementar)."""
        raise NotImplementedError
    
    async def open_cash_drawer(self):
        """Abre gaveta de dinheiro (subclass deve implementar)."""
        raise NotImplementedError
    
    def __repr__(self):
        return f"<{self.name} connected={self.connected}>"


# =============================================================================
# Driver: Impressora Térmica ESC/POS (USB e Rede)
# =============================================================================

class EscPosUSB(PerifericoDriver):
    """Driver ESC/POS para impressoras térmicas via USB."""
    
    name = "escpos_usb"
    tipo = "IMPRESSORA"
    
    # VID/PID comuns de impressoras térmicas
    KNOWN_VENDORS = {
        0x04B8: "Epson",
        0x1A86: "HPRT",
        0x04F3: "Bematech",
        0x04E8: "Samsung",
    }
    
    async def connect(self) -> bool:
        if not HAS_PYUSB:
            self.last_error = "pyusb nao instalado"
            return False
        
        try:
            vid = int(self.config.get("vendor_id", "0"), 16)
            pid = int(self.config.get("product_id", "0"), 16)
            
            self.device = usb.core.find(idVendor=vid, idProduct=pid)
            
            if self.device is None:
                # Tentar auto-detectar impressora ESC/POS
                self.device = self._auto_detect()
            
            if self.device is not None:
                # Detach kernel driver se necessario
                if self.device.is_kernel_driver_active(0):
                    try:
                        self.device.detach_kernel_driver(0)
                    except:
                        pass
                self.device.set_configuration()
                self.connected = True
                logger.info(f"Impressora USB conectada: VID={vid:04x} PID={pid:04x}")
                return True
            else:
                self.last_error = "impressora USB nao encontrada"
                return False
                
        except Exception as e:
            self.last_error = str(e)
            return False
    
    def _auto_detect(self):
        """Tenta auto-detectar impressora térmica na lista de USB."""
        if not HAS_PYUSB:
            return None
        
        for dev in usb.core.find(find_all=True):
            # Verificar se é provavel ser uma impressora térmica
            if dev.idVendor in self.KNOWN_VENDORS:
                return dev
        
        # Se apenas uma impressora USB estiver conectada, usar ela
        printers = []
        for dev in usb.core.find(find_all=True):
            if dev.device_class == 7 or dev.device_class == 0xFF:  # Printer or Vendor specific
                printers.append(dev)
        
        return printers[0] if printers else None
    
    async def disconnect(self) -> None:
        if self.device:
            try:
                usb.util.dispose_resources(self.device)
            except:
                pass
        self.connected = False
    
    async def print_receipt(self, data: bytes) -> bool:
        if not self.connected or self.device is None:
            return False
        
        try:
            # Encontrar endpoint de output
            endpoint = None
            for cfg in self.device:
                for iface in cfg:
                    for ep in iface:
                        if ep.bEndpointAddress & 0x80 == 0:  # Output
                            endpoint = ep
                            break
                if endpoint:
                    break
            
            if endpoint is None:
                # Fallback: usar endpoint 1
                endpoint = 1
            
            self.device.write(endpoint, data)
            return True
        except Exception as e:
            self.last_error = str(e)
            return False


class EscPosNetwork(PerifericoDriver):
    """Driver ESC/POS para impressoras térmicas via rede TCP."""
    
    name = "escpos_network"
    tipo = "IMPRESSORA"
    
    async def connect(self) -> bool:
        try:
            import socket
            self.host = self.config.get("host", "192.0.2.10")
            self.port = int(self.config.get("port", "9100"))
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(5.0)
            self.socket.connect((self.host, self.port))
            self.connected = True
            logger.info(f"Impressora rede conectada: {self.host}:{self.port}")
            return True
        except Exception as e:
            self.last_error = str(e)
            return False
    
    async def disconnect(self) -> None:
        if hasattr(self, 'socket'):
            try:
                self.socket.close()
            except:
                pass
        self.connected = False
    
    async def print_receipt(self, data: bytes) -> bool:
        if not self.connected:
            return False
        try:
            self.socket.sendall(data)
            return True
        except Exception as e:
            self.last_error = str(e)
            return False


class EscPosVirtual(PerifericoDriver):
    """Impressora térmica emulada, sem hardware.

    Configuração: {"out_dir": "saidas", "colunas": 48}.
    Caminhos relativos de saída partem da pasta deste serviço.
    """

    name = "escpos_virtual"
    tipo = "IMPRESSORA"

    async def connect(self) -> bool:
        self.out_dir = Path(self.config.get("out_dir", "saidas"))
        if not self.out_dir.is_absolute():
            self.out_dir = Path(__file__).resolve().parent / self.out_dir
        try:
            self.out_dir.mkdir(parents=True, exist_ok=True)
        except OSError as error:
            self.out_dir = Path(tempfile.mkdtemp(prefix="geban-cupons-"))
            logger.warning(f"Saída de cupons indisponível ({error}); usando {self.out_dir}")
        self.connected = True
        return True

    async def disconnect(self) -> None:
        self.connected = False

    async def open_cash_drawer(self) -> bool:
        return True

    @staticmethod
    def _decode(data: bytes) -> str:
        # O PDV envia UTF-8 (TextEncoder); cp850 cobre impressoras legadas.
        for encoding in ("utf-8", "cp850"):
            try:
                return data.decode(encoding)
            except UnicodeDecodeError:
                pass
        return data.decode("latin-1")

    async def print_receipt(self, data: bytes) -> bool:
        if not self.connected:
            await self.connect()
        # ponytail: parser simplificado ignora bitmap download/codepage;
        # evolução: biblioteca dedicada de emulação ESC/POS.
        coupons = []
        chars = []
        alignment, bold = 0, False
        text = bytearray()

        def flush_text():
            # Decodifica a sequência inteira para preservar caracteres UTF-8 multibyte.
            if text:
                chars.extend((c, alignment, bold) for c in self._decode(bytes(text)))
                text.clear()

        i = 0
        while i < len(data):
            if data[i] not in (10, 13, 0x1b, 0x1d):
                text.append(data[i])
                i += 1
                continue
            flush_text()
            if data[i] in (10, 13):
                chars.append(("\n", alignment, bold))
                i += 2 if data[i:i + 2] == b"\r\n" else 1
            elif data[i:i + 2] == b"\x1b@":
                alignment, bold = 0, False
                i += 2
            elif data[i:i + 2] in (b"\x1ba", b"\x1bE"):
                if i + 2 >= len(data):
                    break
                value = data[i + 2]
                if data[i + 1] == ord("a"):
                    alignment = value - 48 if value in (48, 49, 50) else value
                else:
                    bold = bool(value & 1)
                i += 3
            elif data[i:i + 2] in (b"\x1dV", b"\x1bi"):
                if chars:
                    coupons.append(chars)
                    chars = []
                if data[i + 1] == ord("V"):
                    mode = data[i + 2] if i + 2 < len(data) else 0
                    i += 4 if mode in (65, 66, 97, 98) else 3
                else:
                    i += 2
            elif data[i:i + 3] == b"\x1d(k":
                if i + 5 > len(data):
                    break
                size = int.from_bytes(data[i + 3:i + 5], "little")
                command = data[i + 5:i + 5 + size]
                # cn=49, fn=80, m=48: armazenamento do conteúdo QR.
                if command[:3] == b"1P0":
                    marker = "[QR: " + self._decode(command[3:]) + "]"
                    chars.extend((c, alignment, bold) for c in marker)
                i += 5 + size
            else:
                i += 1  # Comando ESC/GS não suportado: descarta só o prefixo.
        flush_text()
        if chars:
            coupons.append(chars)
        try:
            for coupon in coupons:
                self._save_coupon(coupon)
        except Exception as error:
            self.last_error = str(error)
            logger.warning(f"Falha ao salvar cupom virtual: {error}")
            return False
        return True

    def _save_coupon(self, chars) -> None:
        stem = self.out_dir / ("cupom-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        stem.with_suffix(".txt").write_text("".join(c[0] for c in chars), encoding="utf-8")
        try:
            from PIL import Image, ImageDraw, ImageFont
        except ImportError:
            return  # Texto sempre disponível, mesmo sem Pillow.

        try:
            columns = max(1, int(self.config.get("colunas", 48)))
        except (TypeError, ValueError):
            columns = 48
        rows, row = [], []
        for char in chars:
            if char[0] == "\n":
                rows.append(row)
                row = []
            else:
                if len(row) == columns:
                    rows.append(row)
                    row = []
                row.append(char)
        if row or not rows:
            rows.append(row)
        try:
            font = ImageFont.truetype("DejaVuSansMono.ttf", 14)
        except OSError:
            font = ImageFont.load_default()
        cell_width = max(1, int(font.getlength("M")) + 1)
        line_height = font.getbbox("Ag")[3] + 5
        margin = 12
        image = Image.new("RGB", (columns * cell_width + 2 * margin,
                                  len(rows) * line_height + 2 * margin), "white")
        draw = ImageDraw.Draw(image)
        for line_no, row in enumerate(rows):
            alignment = row[0][1] if row else 0
            spare = (columns - len(row)) * cell_width
            x = margin + (spare // 2 if alignment == 1 else spare if alignment == 2 else 0)
            y = margin + line_no * line_height
            for char, _, bold in row:
                draw.text((x, y), char, font=font, fill="black")
                if bold:
                    draw.text((x + 1, y), char, font=font, fill="black")
                x += cell_width
        image.save(stem.with_suffix(".png"))


# =============================================================================
# Driver: TEF (Terminal de Cartão)
# =============================================================================

class TEFBase(PerifericoDriver):
    """Base para drivers TEF."""
    
    tipo = "TEF"
    
    async def authorize_transaction(self, amount: float, type: str = "CREDIT") -> Dict[str, Any]:
        raise NotImplementedError


class TEFGenericTCP(TEFBase):
    """Driver TEF genérico via TCP/IP (protocolo customizado)."""
    
    name = "tef_generic_tcp"
    
    async def connect(self) -> bool:
        try:
            import socket
            self.host = self.config.get("host", "127.0.0.1")
            self.port = int(self.config.get("port", "8082"))
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(10.0)
            self.socket.connect((self.host, self.port))
            self.connected = True
            logger.info(f"TEF TCP conectado: {self.host}:{self.port}")
            return True
        except Exception as e:
            self.last_error = str(e)
            return False
    
    async def disconnect(self) -> None:
        if hasattr(self, 'socket'):
            try:
                self.socket.close()
            except:
                pass
        self.connected = False
    
    async def authorize_transaction(self, amount: float, type: str = "CREDIT") -> Dict[str, Any]:
        """Autoriza transação via TCP. Protocolo genérico."""
        if not self.connected:
            return {"success": False, "error": "nao conectado"}
        
        try:
            cmd = json.dumps({
                "type": type.upper(),
                "amount": round(amount, 2),
                "merchant_id": self.config.get("merchant_id", ""),
                "device_id": self.config.get("device_id", "")
            }).encode() + b'\n'
            
            self.socket.sendall(cmd)
            
            response = b""
            while True:
                chunk = self.socket.recv(4096)
                if not chunk:
                    break
                response += chunk
                if b'\n' in response:
                    break
            
            result = json.loads(response.decode())
            return {
                "success": result.get("approval_code") is not None,
                "approval_code": result.get("approval_code"),
                "transaction_id": result.get("transaction_id"),
                "response_code": result.get("response_code"),
                "raw": result
            }
        except Exception as e:
            return {"success": False, "error": str(e)}


class TEFHTTPREST(TEFBase):
    """Driver TEF via HTTP REST API (ex: PagSeguro, GetNet)."""
    
    name = "tef_http_rest"
    
    async def connect(self) -> bool:
        self.connected = True
        return True
    
    async def disconnect(self) -> None:
        self.connected = False
    
    async def authorize_transaction(self, amount: float, type: str = "CREDIT") -> Dict[str, Any]:
        """Autoriza transação via HTTP REST."""
        try:
            import urllib.request
            import urllib.error
            
            url = self.config.get("endpoint", "https://api.exemplo.com/autenticar")
            api_key = self.config.get("api_key", "")
            
            data = json.dumps({
                "amount": round(amount, 2),
                "type": type.upper(),
                "merchant_id": self.config.get("merchant_id", "")
            }).encode()
            
            req = urllib.request.Request(
                url,
                data=data,
                headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode())
                return {
                    "success": result.get("status") == "approved",
                    "approval_code": result.get("approval_code"),
                    "transaction_id": result.get("transaction_id"),
                    "raw": result
                }
        except Exception as e:
            return {"success": False, "error": str(e)}


# =============================================================================
# Driver: Leitor de Código de Barras
# =============================================================================

class BarcodeReaderKBWedge(PerifericoDriver):
    """Leitor de código de barras via Keyboard Wedge (USB HID)."""
    
    name = "kb_wedge"
    tipo = "LEITOR"
    
    async def connect(self) -> bool:
        self.connected = True
        logger.info("Leitor KB wedge: pronto (configurar no navegador)")
        return True
    
    async def disconnect(self) -> None:
        self.connected = False
    
    async def read_barcode(self, timeout_ms: int = 5000) -> Optional[str]:
        """Keyboard wedge é capturado pelo navegador via input field."""
        return None  # Frontend captura via JavaScript


class BarcodeReaderSerial(PerifericoDriver):
    """Leitor de código de barras via porta serial."""
    
    name = "leitor_serial"
    tipo = "LEITOR"
    
    async def connect(self) -> bool:
        try:
            port = self.config.get("port", "/dev/ttyUSB0")
            baudrate = int(self.config.get("baudrate", "9600"))
            if serial is None:
                raise RuntimeError("pyserial nao instalado")
            self.serial_port = serial.Serial(port, baudrate, timeout=1)
            self.connected = True
            logger.info(f"Leitor serial conectado: {port}")
            return True
        except Exception as e:
            self.last_error = str(e)
            return False
    
    async def disconnect(self) -> None:
        if hasattr(self, 'serial_port'):
            try:
                self.serial_port.close()
            except:
                pass
        self.connected = False
    
    async def read_barcode(self, timeout_ms: int = 5000) -> Optional[str]:
        if not self.connected:
            return None
        
        try:
            self.serial_port.timeout = timeout_ms / 1000.0
            data = self.serial_port.readline().decode().strip()
            return data if data else None
        except Exception as e:
            self.last_error = str(e)
            return None


# =============================================================================
# Driver: Balança Digital
# =============================================================================

class ScaleSerial(PerifericoDriver):
    """Balança digital via porta serial."""
    
    name = "peso_serial"
    tipo = "PESADORA"
    
    async def connect(self) -> bool:
        try:
            port = self.config.get("port", "/dev/ttyS0")
            baudrate = int(self.config.get("baudrate", "2400"))
            if serial is None:
                raise RuntimeError("pyserial nao instalado")
            self.serial_port = serial.Serial(port, baudrate, timeout=1)
            self.connected = True
            logger.info(f"Balança serial conectada: {port}")
            return True
        except Exception as e:
            self.last_error = str(e)
            return False
    
    async def disconnect(self) -> None:
        if hasattr(self, 'serial_port'):
            try:
                self.serial_port.close()
            except:
                pass
        self.connected = False
    
    async def read_weight(self) -> Optional[float]:
        if not self.connected:
            return None
        
        try:
            line = self.serial_port.readline().decode().strip()
            for part in line.split():
                try:
                    return float(part)
                except ValueError:
                    continue
            return None
        except Exception as e:
            self.last_error = str(e)
            return None


# =============================================================================
# Driver: Gaveta de Dinheiro
# =============================================================================

class CashDrawerUSB(PerifericoDriver):
    """Gaveta de dinheiro via USB (RJ11)."""
    
    name = "gaveta_usb"
    tipo = "GAVETA"
    
    async def connect(self) -> bool:
        if not HAS_PYUSB:
            self.last_error = "pyusb nao instalado"
            return False
        
        try:
            self.device = usb.core.find(idVendor=0x04B8, idProduct=0x0101)
            if self.device is None:
                for dev in usb.core.find(find_all=True):
                    if dev.device_class == 0xFF:
                        self.device = dev
                        break
            
            if self.device:
                self.connected = True
                return True
            else:
                self.last_error = "gaveta USB nao encontrada"
                return False
        except Exception as e:
            self.last_error = str(e)
            return False
    
    async def disconnect(self) -> None:
        self.connected = False
    
    async def open_cash_drawer(self) -> bool:
        if not self.connected or self.device is None:
            return False
        
        try:
            self.device.write(0x01, b'\x00\x04\x00\x00\x00\x00\x00\x00')
            return True
        except Exception as e:
            self.last_error = str(e)
            return False


# =============================================================================
# Plugin System e Registry
# =============================================================================

class DriverRegistry:
    """Registra e gerencia drivers de periféricos."""
    
    def __init__(self):
        self.drivers: Dict[str, PerifericoDriver] = {}
        self._register_builtins()
    
    def _register_builtins(self):
        """Registra drivers nativos."""
        builtins = [
            EscPosUSB,
            EscPosNetwork,
            EscPosVirtual,
            TEFGenericTCP,
            TEFHTTPREST,
            BarcodeReaderKBWedge,
            BarcodeReaderSerial,
            ScaleSerial,
            CashDrawerUSB,
        ]
        for driver_class in builtins:
            self.register(driver_class)
    
    def register(self, driver_class: type):
        """Registra uma classe de driver."""
        if isinstance(driver_class, type):
            self.drivers[driver_class.name] = driver_class
        else:
            cls = driver_class.__class__
            self.drivers[cls.name] = cls
        logger.info(f"Driver registrado: {driver_class.name} ({driver_class.tipo})")
    
    def get(self, name: str) -> Optional[PerifericoDriver]:
        """Retorna instância de driver pelo nome."""
        return self.drivers.get(name)
    
    def create(self, name: str, config: Dict[str, Any]) -> Optional[PerifericoDriver]:
        """Cria instância de driver com configuração."""
        driver_class = self.drivers.get(name)
        if driver_class and isinstance(driver_class, type):
            return driver_class(config)
        return None
    
    def list_drivers(self) -> List[Dict[str, str]]:
        """Lista drivers disponíveis."""
        return [
            {"name": d.name, "tipo": d.tipo}
            for d in self.drivers.values()
        ]
    
    def auto_detect(self) -> List[Dict[str, Any]]:
        """Tenta auto-detectar dispositivos conectados."""
        detected = []
        
        # Escanear USB
        if HAS_PYUSB:
            for dev in usb.core.find(find_all=True):
                info = {
                    "tipo": "usb",
                    "vendor_id": f"0x{dev.idVendor:04x}",
                    "product_id": f"0x{dev.idProduct:04x}",
                    "description": getattr(dev, 'iProduct', None) or "Dispositivo USB",
                    "drivers_sugeridos": []
                }
                
                if dev.idVendor in EscPosUSB.KNOWN_VENDORS:
                    info["drivers_sugeridos"].append("escpos_usb")
                if dev.device_class == 5 or dev.device_class == 7:
                    info["drivers_sugeridos"].append("escpos_usb")
                
                detected.append(info)
        
        # Escanear seriais
        for port in (serial.tools.list_ports.comports() if serial is not None else []):
            info = {
                "tipo": "serial",
                "path": port.device,
                "description": port.description,
                "drivers_sugeridos": []
            }
            
            if "USB-SERIAL" in port.description.upper() or "FTDI" in port.description.upper():
                info["drivers_sugeridos"].extend(["leitor_serial", "peso_serial"])
            
            detected.append(info)
        
        return detected


# =============================================================================
# Gerenciador de Periféricos
# =============================================================================

class PerifericoManager:
    """Gerencia instâncias de periféricos por cliente."""
    
    def __init__(self, registry: DriverRegistry):
        self.registry = registry
        self.instances: Dict[int, PerifericoDriver] = {}
        self.next_id = 1
    
    def register_periferico(
        self, 
        tipo: str, 
        driver_name: str, 
        config: Dict[str, Any],
        nome: str = ""
    ) -> Optional[int]:
        """Registra um periférico e retorna seu ID."""
        driver = self.registry.create(driver_name, config)
        if driver is None:
            return None
        
        pid = self.next_id
        self.next_id += 1
        self.instances[pid] = driver
        driver._pid = pid
        
        logger.info(f"Periferico registrado: ID={pid}, tipo={tipo}, driver={driver_name}")
        return pid
    
    def get_instance(self, pid: int) -> Optional[PerifericoDriver]:
        """Retorna instância por ID."""
        return self.instances.get(pid)
    
    def list_instances(self) -> List[Dict[str, Any]]:
        """Lista todos os periféricos registrados."""
        result = []
        for pid, driver in self.instances.items():
            result.append({
                "id": pid,
                "driver": driver.name,
                "tipo": driver.tipo,
                "connected": driver.connected,
                "config": driver.config
            })
        return result
    
    async def connect_all(self) -> int:
        """Tenta conectar todos os periféricos registrados."""
        connected = 0
        for pid, driver in self.instances.items():
            if await driver.connect():
                connected += 1
        return connected


# =============================================================================
# WebSocket Server
# =============================================================================

class PerifericoWebSocketHandler:
    """Handler para conexões WebSocket do frontend PDV."""
    
    def __init__(self, manager: PerifericoManager):
        self.manager = manager
        self.clients: List = []
    
    async def connect(self, websocket):
        self.clients.append(websocket)
        logger.info(f"Cliente WebSocket conectado. Total: {len(self.clients)}")
        
        await websocket.send(json.dumps({
            "type": "drivers_list",
            "drivers": self.manager.registry.list_drivers()
        }))
    
    def disconnect(self, websocket):
        if websocket in self.clients:
            self.clients.remove(websocket)
        logger.info(f"Cliente WebSocket desconectado. Total: {len(self.clients)}")
    
    async def handle_message(self, websocket, message: str):
        """Processa mensagem do cliente."""
        try:
            data = json.loads(message)
            msg_type = data.get("type")
            
            if msg_type == "list_drivers":
                await websocket.send(json.dumps({
                    "type": "drivers_list",
                    "drivers": self.manager.registry.list_drivers()
                }))
            
            elif msg_type == "auto_detect":
                detected = self.manager.registry.auto_detect()
                await websocket.send(json.dumps({
                    "type": "detected_devices",
                    "devices": detected
                }))
            
            elif msg_type == "register_periferico":
                pid = self.manager.register_periferico(
                    tipo=data.get("tipo"),
                    driver_name=data.get("driver"),
                    config=data.get("config", {}),
                    nome=data.get("nome", "")
                )
                await websocket.send(json.dumps({"type": "registered", "id": pid}))
            
            elif msg_type == "connect_periferico":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver:
                    ok = await driver.connect()
                    await websocket.send(json.dumps({"type": "connected", "id": pid, "ok": ok}))
            
            elif msg_type == "disconnect_periferico":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver:
                    await driver.disconnect()
                    await websocket.send(json.dumps({"type": "disconnected", "id": pid}))
            
            elif msg_type == "print_receipt":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver and hasattr(driver, 'print_receipt'):
                    ok = await driver.print_receipt(bytes(data.get("data", "")))
                    await websocket.send(json.dumps({"type": "printed", "id": pid, "ok": ok}))
            
            elif msg_type == "read_barcode":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver and hasattr(driver, 'read_barcode'):
                    code = await driver.read_barcode(data.get("timeout_ms", 5000))
                    await websocket.send(json.dumps({"type": "barcode", "id": pid, "code": code}))
            
            elif msg_type == "authorize_transaction":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver and hasattr(driver, 'authorize_transaction'):
                    result = await driver.authorize_transaction(
                        data.get("amount", 0),
                        data.get("type", "CREDIT")
                    )
                    await websocket.send(json.dumps({"type": "transaction_result", "id": pid, **result}))
            
            elif msg_type == "read_weight":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver and hasattr(driver, 'read_weight'):
                    weight = await driver.read_weight()
                    await websocket.send(json.dumps({"type": "weight", "id": pid, "weight": weight}))
            
            elif msg_type == "open_cash_drawer":
                pid = data.get("id")
                driver = self.manager.get_instance(pid)
                if driver and hasattr(driver, 'open_cash_drawer'):
                    ok = await driver.open_cash_drawer()
                    await websocket.send(json.dumps({"type": "drawer_opened", "id": pid, "ok": ok}))
            
            elif msg_type == "list_perifericos":
                await websocket.send(json.dumps({
                    "type": "perifericos_list",
                    "perifericos": self.manager.list_instances()
                }))
            
            else:
                await websocket.send(json.dumps({"type": "error", "message": f"Unknown message type: {msg_type}"}))
        
        except json.JSONDecodeError:
            await websocket.send(json.dumps({"type": "error", "message": "Invalid JSON"}))
        except Exception as e:
            await websocket.send(json.dumps({"type": "error", "message": str(e)}))


# =============================================================================
# Main
# =============================================================================

async def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='GEBAN Periférico Service')
    parser.add_argument('--config', default=str(Path(__file__).resolve().parent / 'config/perifericos.json'),
                        help='Arquivo de configuração')
    parser.add_argument('--port', type=int, default=9100, help='Porta do WebSocket')
    args = parser.parse_args()
    
    # Carregar configuração
    config = {}
    if os.path.exists(args.config):
        with open(args.config, 'r') as f:
            config = json.load(f)
    
    logger.info(f"GEBAN Periférico Service iniciando...")
    logger.info(f"Porta: {args.port}")
    logger.info(f"Config: {args.config}")
    
    # Criar gerenciador
    registry = DriverRegistry()
    manager = PerifericoManager(registry)
    handler = PerifericoWebSocketHandler(manager)
    
    # Carregar periféricos da configuração
    for periph_config in config.get("perifericos", []):
        pid = manager.register_periferico(
            tipo=periph_config.get("tipo"),
            driver_name=periph_config.get("driver"),
            config=periph_config.get("config", {}),
            nome=periph_config.get("nome", "")
        )
        if pid:
            logger.info(f"Periférico carregado: ID={pid}, nome={periph_config.get('nome')}")
    
    connected = await manager.connect_all()
    logger.info(f"Periféricos conectados: {connected}/{len(manager.instances)}")

    # Iniciar servidor WebSocket
    import websockets
    async def _ws_handler(websocket, path=None):
        await handler.connect(websocket)
        try:
            async for message in websocket:
                await handler.handle_message(websocket, message)
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            handler.disconnect(websocket)

    async with websockets.serve(_ws_handler, "0.0.0.0", args.port) as server:
        logger.info(f"WebSocket server rodando em ws://0.0.0.0:{args.port}")
        await asyncio.Future()  # Rodar forever


if __name__ == "__main__":
    asyncio.run(main())
