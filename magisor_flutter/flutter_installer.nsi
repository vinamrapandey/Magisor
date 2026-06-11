
Name "Magisor"
Outfile "Magisor Flutter Setup.exe"
InstallDir "$PROGRAMFILES\Magisor"
RequestExecutionLevel admin

Section "Main"
  SetOutPath "$INSTDIR"
  File /r "build\windows\x64\runner\Release\*.*"
  CreateShortcut "$DESKTOP\Magisor.lnk" "$INSTDIR\magisor_flutter.exe"
SectionEnd
