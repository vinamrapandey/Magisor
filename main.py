"""
Magisor Main Application Entry Point
Orchestrates system startup, config verification, onboarding validation,
hook listeners, UI components, and the Qt execution loop.
"""
import sys
from PyQt5.QtWidgets import QApplication

def main():
    """Initializes the core modules and kicks off the PyQt5 event loop."""
    print("Initializing Magisor Core...")
    app = QApplication(sys.argv)
    
    # 1. Load settings (config.py)
    # 2. Check for API key. If missing, show OnboardingWizard (onboarding.py)
    # 3. Initialize mouse hooks (mouse_hook.py)
    # 4. Initialize system tray (tray.py)
    # 5. Initialize background voice activation if enabled (voice.py)
    
    print("Magisor is running silently in the system tray.")
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
