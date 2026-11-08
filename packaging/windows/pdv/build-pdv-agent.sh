#!/usr/bin/env bash
# Gera geban-periferico.exe (agente PDV Windows) com PyInstaller.
# DEVE rodar no Windows (PyInstaller não cross-compila).
#
#   ./build-pdv-agent.sh
#
# Pré-requisitos: Python 3.10+ e pip.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(cd ../../.. && pwd)

python -m venv .venv-build
# shellcheck disable=SC1091
. .venv-build/Scripts/activate   # Windows
pip install --upgrade pip
pip install -r "$ROOT/periferico/requirements.txt" pyinstaller

pyinstaller --noconfirm --clean \
    --name geban-periferico \
    --add-data "$ROOT/periferico:periferico" \
    --hidden-import serial --hidden-import serial.tools.list_ports \
    --hidden-import usb.core --hidden-import usb.util \
    --hidden-import websockets \
    --exclude-module tkinter --exclude-module pytest \
    "$ROOT/periferico/periferico_service.py"

echo "PRONTO: dist/geban-periferico.exe"
ls -lh dist/geban-periferico.exe
