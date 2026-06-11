; Nullsoft Scriptable Install System (NSIS) Script for Magisor AI Assistant
; Generates a professional Windows Modern UI Installer.

!include "MUI2.nsh"

Name "Magisor"
OutFile "Magisor Setup 1.0.exe"
InstallDir "C:\Program Files\Magisor"

RequestExecutionLevel admin

; Modern UI styling options
!define MUI_ABORTWARNING
!define MUI_ICON "assets\tray_icon.ico"
!define MUI_UNICON "assets\tray_icon.ico"

; Welcome Screen
!insertmacro MUI_PAGE_WELCOME

; Directory Selection
!insertmacro MUI_PAGE_DIRECTORY

; Installs Files
!insertmacro MUI_PAGE_INSTFILES

; Custom Modern UI Finish Page with exact post-install instructions
!define MUI_FINISHPAGE_TITLE "Magisor Setup Completed"
!define MUI_FINISHPAGE_TEXT "Magisor is installed.\r\n\r\nLaunch it and follow the setup wizard to connect your Gemini API key."
!define MUI_FINISHPAGE_RUN "$INSTDIR\Magisor.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Magisor"
!insertmacro MUI_PAGE_FINISH

; Uninstaller confirm panels
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Install"
  ; Forcefully kill any running instance of the app before trying to overwrite files
  nsExec::ExecToLog 'taskkill /F /IM Magisor.exe'
  Sleep 1000

  SetOutPath "$INSTDIR"
  
  ; Copy all compiled binaries from Flutter build folder recursively
  File /r "magisor_flutter\build\windows\x64\runner\Release\*.*"
  Rename "$INSTDIR\magisor_flutter.exe" "$INSTDIR\Magisor.exe"
  
  ; Write uninstaller binary
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ; Register "Launch on Windows Startup" under Current User registry Run key
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Magisor" '"$INSTDIR\Magisor.exe"'
  
  ; Register in Add/Remove programs (Windows App Uninstall Control Panel)
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Magisor" "DisplayName" "Magisor AI Assistant"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Magisor" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Magisor" "DisplayIcon" '"$INSTDIR\Magisor.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Magisor" "DisplayVersion" "1.0"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Magisor" "Publisher" "Vinamra Pandey"
  
  ; Create Start Menu shortcuts
  CreateDirectory "$SMPROGRAMS\Magisor"
  CreateShortcut "$SMPROGRAMS\Magisor\Magisor.lnk" "$INSTDIR\Magisor.exe" "" "$INSTDIR\Magisor.exe" 0
  CreateShortcut "$SMPROGRAMS\Magisor\Uninstall Magisor.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
SectionEnd

Section "Uninstall"
  ; Remove startup registration
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Magisor"
  
  ; Remove registry elements
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Magisor"
  DeleteRegKey HKLM "Software\Magisor"
  
  ; Remove shortcuts and menu directories
  Delete "$SMPROGRAMS\Magisor\Magisor.lnk"
  Delete "$SMPROGRAMS\Magisor\Uninstall Magisor.lnk"
  RMDir "$SMPROGRAMS\Magisor"
  
  ; Teardown installed directory files completely
  RMDir /r "$INSTDIR"
SectionEnd
