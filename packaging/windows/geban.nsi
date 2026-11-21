; GEBAN ERP — instalador Windows all-in-one (NSIS)
; Instala por usuário em %LOCALAPPDATA%\GEBAN (não exige administrador).
; O geban-launcher.exe sobe o PostgreSQL embarcado, a interface web
; (advplc serve :8081), a API (:8090) e o agendador, e abre o navegador.
;
; Compilar: makensis geban.nsi   (payload/ deve estar montado — ver build-package.sh)

!include "MUI2.nsh"
!include "FileFunc.nsh"

Name "GEBAN ERP"
OutFile "geban-setup.exe"
InstallDir "$LOCALAPPDATA\GEBAN"
InstallDirRegKey HKCU "Software\GEBAN" "InstallDir"
RequestExecutionLevel user
Unicode true
SetCompressor /SOLID lzma

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "English"

Section "GEBAN ERP" SecMain
    SetOutPath "$INSTDIR"
    File /r "payload\*.*"

    ; Atalho na área de trabalho e no menu iniciar
    CreateShortcut "$DESKTOP\GEBAN ERP.lnk" "$INSTDIR\geban-launcher.exe" \
        "" "$INSTDIR\geban-launcher.exe" 0
    CreateDirectory "$SMPROGRAMS\GEBAN"
    CreateShortcut "$SMPROGRAMS\GEBAN\GEBAN ERP.lnk" "$INSTDIR\geban-launcher.exe"
    CreateShortcut "$SMPROGRAMS\GEBAN\Desinstalar GEBAN.lnk" "$INSTDIR\uninstall.exe"

    ; Inicialização automática no logon do usuário (launcher é leve:
    ; verifica se já está no ar e sai se sim — ver nota no launcher)
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" \
        "GEBAN" '"$INSTDIR\geban-launcher.exe" --autostart'

    WriteRegStr HKCU "Software\GEBAN" "InstallDir" "$INSTDIR"

    ; O desinstalador precisa ser gravado durante a instalação —
    ; WriteUninstaller dentro da seção "Uninstall" só rodaria na hora
    ; de desinstalar (tarde demais).
    WriteUninstaller "$INSTDIR\uninstall.exe"

    ; Pergunta se quer iniciar agora
    MessageBox MB_YESNO|MB_ICONQUESTION \
        "GEBAN instalado em $INSTDIR.$\n$\nDeseja iniciar agora?" IDYES StartNow IDNO Done
    StartNow:
        Exec '"$INSTDIR\geban-launcher.exe"'
    Done:
SectionEnd

; ATENÇÃO: o nome desta seção precisa ser "Uninstall" — o makensis só
; reconhece a seção de desinstalação por esse nome exato. Qualquer outro
; nome (ex.: "Desinstalar") vira uma segunda seção de INSTALAÇÃO e o
; código de limpeza roda no fim do setup, apagando o que acabou de
; instalar.
Section "Uninstall"
    ; ATENÇÃO: a desinstalação apaga $INSTDIR\data (banco local) — o
    ; MUI_UNPAGE_CONFIRM acima é o aviso; não há como desfazer.
    ; Encerra o agendador antes de remover
    nsExec::Exec 'schtasks /Delete /TN "GEBAN Scheduler" /F'
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "GEBAN"
    DeleteRegKey HKCU "Software\GEBAN"
    RMDir /r "$INSTDIR"
    Delete "$DESKTOP\GEBAN ERP.lnk"
    RMDir /r "$SMPROGRAMS\GEBAN"
SectionEnd
