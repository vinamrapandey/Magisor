"""
Magisor Main Application Entry Point
Orchestrates system startup, config verification, onboarding validation,
hook listeners, UI components, and the Qt execution loop.
"""
import sys
import os
import logging
from typing import Optional

from PyQt5.QtWidgets import QApplication
from PyQt5.QtCore import QObject, pyqtSignal, QThread

# Initialize environmental managers and configurations first
import env_manager
import config

from onboarding import OnboardingWizard
from mouse_hook import MouseHookEngine
from capture import ScreenCaptureManager
from overlay import OverlayWindow
from tray import SystemTrayIcon
import ai_client

# Configure logger
logger = logging.getLogger("magisor.main")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class GeminiAnalysisWorker(QThread):
    """Background execution thread querying the Gemini API without freezing the UI."""
    finished = pyqtSignal(dict)
    error = pyqtSignal(str)
    
    def __init__(self, image_base64: str, user_prompt: Optional[str] = None, context: Optional[str] = None):
        super().__init__()
        self.image_base64 = image_base64
        self.user_prompt = user_prompt
        self.context = context
        
    def run(self):
        try:
            # Query Gemini Vision model
            result = ai_client.analyze_screen(
                self.image_base64, 
                user_prompt=self.user_prompt, 
                context=self.context
            )
            self.finished.emit(result)
        except Exception as e:
            self.error.emit(str(e))

class MagisorAppController(QObject):
    """Thread-safe core app controller connecting input hooks, capturing, and visual displays."""
    shake_signal = pyqtSignal(int, int)
    
    def __init__(self, qt_app: QApplication):
        super().__init__()
        self.app = qt_app
        
        self.capture_mgr = ScreenCaptureManager()
        self.overlay = OverlayWindow()
        self.analysis_worker: Optional[GeminiAnalysisWorker] = None
        self.current_image_base64 = ""
        
        # Connect follow-up prompts from overlay to controller query logic
        self.overlay.followup_submitted.connect(self.on_followup_submitted)
        
        # Route background mouse gestures safely across thread boundaries to GUI thread
        self.shake_signal.connect(self._handle_shake_on_gui_thread)
        
        # Initialize System Tray
        project_root = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(project_root, "assets", "tray_icon.png")
        
        self.tray_icon = SystemTrayIcon(
            icon_path=icon_path,
            on_settings_clicked=self.show_settings,
            on_exit_clicked=self.exit_app
        )
        self.tray_icon.show()
        
        # 1. Onboarding check on first launch
        if not config.get_setting("onboarding_complete", False):
            logger.info("Magisor first run: presenting onboarding wizard.")
            wizard = OnboardingWizard()
            wizard.exec_()
            
        # 2. Key check warning bubble post onboarding
        if not config.is_api_key_set():
            logger.warning("Gemini API key missing on startup. Triggering system warning.")
            self.tray_icon.show_notification(
                "Magisor Status",
                "No API key set. Open Settings to add one."
            )
            
        # 3. Start global mouse hook thread
        self.mouse_engine = MouseHookEngine(on_shake_callback=self.on_shake_detected)
        self.mouse_engine.start()
        
        logger.info("Magisor successfully initialized. Waiting for gesture triggers...")

    def on_shake_detected(self, x: int, y: int) -> None:
        """Triggered from background pynput thread. Marshall coordinates safely to main GUI thread."""
        logger.info("Cursor shake intercepted globally at: (%d, %d)", x, y)
        self.shake_signal.emit(x, y)
        
    def _handle_shake_on_gui_thread(self, x: int, y: int) -> None:
        """Executes actual screenshot crop, spinner displays, and background API queries on GUI thread."""
        logger.info("Executing shake handle pipeline on GUI thread at: (%d, %d)", x, y)
        
        # Show transparent overlay instantly with spinner placeholder
        self.overlay.show_near_cursor(x, y, "Consulting Magisor...")
        
        # Capture crop box centered around cursor with bounds checks
        try:
            pil_img, b64_jpeg = self.capture_mgr.capture_around_cursor(
                x, y, width=600, height=400, draw_highlight=False
            )
            self.current_image_base64 = b64_jpeg
        except Exception as e:
            logger.error("Screen capture failed: %s", str(e))
            self.overlay.show_error(f"Capture failed: {str(e)}")
            return
            
        # Spawn async worker thread
        self._trigger_analysis()

    def _trigger_analysis(self, user_prompt: Optional[str] = None) -> None:
        """Utility to safely run or reset worker execution thread."""
        if self.analysis_worker and self.analysis_worker.isRunning():
            self.analysis_worker.terminate()
            self.analysis_worker.wait()
            
        self.analysis_worker = GeminiAnalysisWorker(
            self.current_image_base64,
            user_prompt=user_prompt
        )
        self.analysis_worker.finished.connect(self._on_analysis_success)
        self.analysis_worker.error.connect(self._on_analysis_error)
        self.analysis_worker.start()

    def _on_analysis_success(self, result: dict) -> None:
        logger.info("Gemini analysis completed successfully.")
        self.overlay.update_content(result)
        
    def _on_analysis_error(self, err_msg: str) -> None:
        logger.error("Gemini query thread failed: %s", err_msg)
        is_key_missing = "API key not configured" in err_msg or "MissingAPIKeyError" in err_msg
        self.overlay.show_error(err_msg, show_settings_btn=is_key_missing)

    def on_followup_submitted(self, text: str) -> None:
        """Consults Gemini with follow-up prompts."""
        logger.info("Submitting follow-up prompt: '%s'", text)
        self._trigger_analysis(user_prompt=text)

    def show_settings(self) -> None:
        """Pops open settings dialogue."""
        logger.info("Launching Settings Dialog from Tray context...")
        wizard = OnboardingWizard()
        wizard.exec_()
        
    def exit_app(self) -> None:
        """Enforces clean teardown stopping background loops, listeners, and widgets."""
        logger.info("Shutting down Magisor globally...")
        if hasattr(self, 'mouse_engine') and self.mouse_engine:
            self.mouse_engine.stop()
        if hasattr(self, 'tray_icon') and self.tray_icon:
            self.tray_icon.hide()
        if hasattr(self, 'overlay') and self.overlay:
            self.overlay.close()
        self.app.quit()
        sys.exit(0)

def main():
    """Initializes the core modules and kicks off the PyQt5 event loop."""
    logger.info("Initializing Magisor Core...")
    app = QApplication(sys.argv)
    
    # Enable exit triggers on keyboard interruption inside console
    import signal
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    # Prevent GUI app exiting instantly if all dialog windows close
    app.setQuitOnLastWindowClosed(False)
    
    # Initialize Core Application Controller
    controller = MagisorAppController(app)
    
    logger.info("Magisor is running silently in the system tray.")
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
