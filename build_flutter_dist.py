import os
import subprocess
import shutil

cwd = r"c:\Users\Lenovo\.gemini\antigravity\scratch\magisor\magisor_flutter"
desktop = r"C:\Users\Lenovo\Desktop"

def run_cmd(cmd, step_name):
    print(f"Executing: {step_name}")
    res = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[ERROR] {step_name} failed: {res.stderr}\n{res.stdout}")
        return False
    print(f"[SUCCESS] {step_name}")
    return True

def main():
    print("Building Windows executable...")
    if not run_cmd("flutter build windows", "Flutter Build Windows"):
        print("Skipping Windows installer due to build failure.")

    print("Building Android APK...")
    # Attempt to build APK. If no Android SDK is present, this will naturally fail.
    if run_cmd("flutter build apk", "Flutter Build APK"):
        apk_path = os.path.join(cwd, "build", "app", "outputs", "flutter-apk", "app-release.apk")
        if os.path.exists(apk_path):
            dest_apk = os.path.join(desktop, "Magisor_Flutter.apk")
            shutil.copy(apk_path, dest_apk)
            print(f"Copied APK to Desktop: {dest_apk}")

    # Generate NSIS script for Flutter output
    nsis_script = f"""
Name "Magisor"
Outfile "Magisor Flutter Setup.exe"
InstallDir "$PROGRAMFILES\\Magisor"
RequestExecutionLevel admin

Section "Main"
  SetOutPath "$INSTDIR"
  File /r "build\\windows\\x64\\runner\\Release\\*.*"
  CreateShortcut "$DESKTOP\\Magisor.lnk" "$INSTDIR\\magisor_flutter.exe"
SectionEnd
"""
    nsi_path = os.path.join(cwd, "flutter_installer.nsi")
    with open(nsi_path, "w") as f:
        f.write(nsis_script)

    makensis_path = r"C:\Program Files (x86)\NSIS\makensis.exe"
    if os.path.exists(makensis_path):
        if run_cmd(f'"{makensis_path}" flutter_installer.nsi', "Compile NSIS"):
            installer_path = os.path.join(cwd, "Magisor Flutter Setup.exe")
            if os.path.exists(installer_path):
                dest_installer = os.path.join(desktop, "Magisor Flutter Setup.exe")
                shutil.copy(installer_path, dest_installer)
                print(f"Copied Windows Installer to Desktop: {dest_installer}")
    else:
        print(f"NSIS not found at {makensis_path}. Skipping installer creation.")

if __name__ == "__main__":
    main()
