"""
System Tray Icon and Settings Panel
Integrates Magisor into the Windows system tray and provides a premium configuration panel.
"""
import os
import logging
from typing import Callable, Optional
from PyQt5.QtWidgets import (
    QSystemTrayIcon, QMenu, QAction, QDialog, QVBoxLayout, QHBoxLayout, 
    QLabel, QLineEdit, QComboBox, QCheckBox, QPushButton, QMessageBox
)
from PyQt5.QtGui import QIcon
from PyQt5.QtCore import Qt, QThread, pyqtSignal

import config

# Configure logger
logger = logging.getLogger("magisor.tray")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class KeyVerificationWorker(QThread):
    """Asynchronous background verifier for the Gemini API Key."""
    finished = pyqtSignal(bool, str)

    def __init__(self, api_key: str):
        super().__init__()
        self.api_key = api_key

    def run(self):
        try:
            import google.generativeai as genai
            genai.configure(api_key=self.api_key.strip())
            model = genai.GenerativeModel("gemini-1.5-flash")
            response = model.generate_content("Ping")
            if response.text:
                self.finished.emit(True, "API Key verified successfully!")
            else:
                self.finished.emit(False, "Empty response from API validation request.")
        except Exception as e:
            self.finished.emit(False, str(e))

class SettingsDialog(QDialog):
    """Premium visual settings dialog supporting custom key verification and local configurations."""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.verify_worker: Optional[KeyVerificationWorker] = None
        self.init_ui()

    def init_ui(self) -> None:
        self.setWindowTitle("Magisor Configuration")
        self.setFixedSize(420, 440)
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowContextHelpButtonHint)
        
        # Style sheet to apply premium dark theme matching Magisor designs
        self.setStyleSheet("""
            QDialog {
                background-color: #12121a;
                font-family: 'Segoe UI', sans-serif;
                color: #e2e8f0;
            }
            QLabel {
                color: #cbd5e1;
                font-size: 12px;
                font-weight: 500;
            }
            QLineEdit {
                background-color: #1a1a26;
                border: 1px solid #33334d;
                border-radius: 6px;
                padding: 8px 12px;
                color: #ffffff;
                font-size: 13px;
            }
            QLineEdit:focus {
                border: 1px solid #8b5cf6;
            }
            QComboBox {
                background-color: #1a1a26;
                border: 1px solid #33334d;
                border-radius: 6px;
                padding: 6px 12px;
                color: #ffffff;
                font-size: 12px;
            }
            QComboBox:focus {
                border: 1px solid #8b5cf6;
            }
            QCheckBox {
                color: #cbd5e1;
                font-size: 12px;
                spacing: 8px;
            }
            QPushButton {
                border-radius: 6px;
                padding: 8px 16px;
                font-weight: bold;
                font-size: 12px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(16)

        # 1. Dialog title
        title_label = QLabel("Magisor Settings", self)
        title_label.setStyleSheet("font-size: 18px; font-weight: bold; color: #ffffff; margin-bottom: 8px;")
        layout.addWidget(title_label)

        # 2. API Key setup inputs
        key_layout = QVBoxLayout()
        key_layout.setSpacing(6)
        key_label = QLabel("Gemini API Key", self)
        key_layout.addWidget(key_label)

        # Retrieve saved key and mask it cleanly
        self.saved_key = config.get_setting("gemini_api_key", "")
        masked_key = self.mask_key(self.saved_key)

        self.key_input = QLineEdit(self)
        self.key_input.setEchoMode(QLineEdit.Password)
        self.key_input.setText(masked_key)
        self.key_input.setPlaceholderText("Paste your AIza... Gemini key")
        key_layout.addWidget(self.key_input)
        layout.addLayout(key_layout)

        # 3. Asynchronous Verification Row
        btn_layout = QHBoxLayout()
        self.verify_btn = QPushButton("Verify Key", self)
        self.verify_btn.setStyleSheet("""
            QPushButton {
                background-color: #1e1b4b;
                border: 1px solid #4338ca;
                color: #e2e8f0;
            }
            QPushButton:hover {
                background-color: #312e81;
            }
        """)
        self.verify_btn.clicked.connect(self.verify_key)
        btn_layout.addWidget(self.verify_btn)

        self.verify_status = QLabel("", self)
        self.verify_status.setStyleSheet("font-size: 11px; font-weight: bold; margin-left: 8px;")
        btn_layout.addWidget(self.verify_status)
        btn_layout.addStretch()
        layout.addLayout(btn_layout)

        # 4. Settings Dropdowns
        settings_row = QHBoxLayout()
        settings_row.setSpacing(20)

        # Sensitivity Select
        sens_layout = QVBoxLayout()
        sens_layout.setSpacing(6)
        sens_label = QLabel("Shake Sensitivity", self)
        sens_layout.addWidget(sens_label)

        self.sens_box = QComboBox(self)
        self.sens_box.addItems(["Low", "Medium", "High"])
        saved_sens = config.get_setting("shake_sensitivity", "Medium")
        # Ensure proper case matching
        index = self.sens_box.findText(saved_sens, Qt.MatchFixedString)
        if index >= 0:
            self.sens_box.setCurrentIndex(index)
        sens_layout.addWidget(self.sens_box)
        settings_row.addLayout(sens_layout)

        # Voice Activation Toggle
        voice_layout = QVBoxLayout()
        voice_layout.setSpacing(6)
        voice_label = QLabel("Voice Commands", self)
        voice_layout.addWidget(voice_label)

        self.voice_toggle = QCheckBox("Voice Activation", self)
        self.voice_toggle.setChecked(config.get_setting("voice_activation", False))
        voice_layout.addWidget(self.voice_toggle)
        settings_row.addLayout(voice_layout)
        layout.addLayout(settings_row)

        # 5. Local storage compliance notice note
        note_layout = QVBoxLayout()
        note_text = QLabel("Your API key is stored locally on your device only", self)
        note_text.setStyleSheet("color: #64748b; font-size: 11px; font-style: italic; margin-top: 8px;")
        note_text.setAlignment(Qt.AlignCenter)
        note_layout.addWidget(note_text)
        layout.addLayout(note_layout)

        layout.addSpacing(10)

        # 6. Save and Cancel Buttons
        actions_layout = QHBoxLayout()
        actions_layout.addStretch()

        cancel_btn = QPushButton("Cancel", self)
        cancel_btn.setStyleSheet("""
            QPushButton {
                background-color: #27272a;
                border: 1px solid #3f3f46;
                color: #e2e8f0;
            }
            QPushButton:hover {
                background-color: #3f3f46;
            }
        """)
        cancel_btn.clicked.connect(self.reject)
        actions_layout.addWidget(cancel_btn)

        save_btn = QPushButton("Save Settings", self)
        save_btn.setStyleSheet("""
            QPushButton {
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #8b5cf6, stop:1 #3b82f6);
                border: none;
                color: #ffffff;
            }
            QPushButton:hover {
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #a78bfa, stop:1 #60a5fa);
            }
        """)
        save_btn.clicked.connect(self.save_settings)
        actions_layout.addWidget(save_btn)

        layout.addLayout(actions_layout)

    def mask_key(self, key: str) -> str:
        """Returns the masked user API key to prevent exposing active configurations."""
        if not key:
            return ""
        if len(key) <= 8:
            return "••••••••"
        return key[:4] + "••••••••••••••" + key[-3:]

    def verify_key(self) -> None:
        """Validates the input credentials asynchronously in the background thread."""
        new_key = self.key_input.text().strip()
        
        # Resolve masked vs raw inputs
        if new_key == self.mask_key(self.saved_key):
            new_key = self.saved_key

        if not new_key:
            self.verify_status.setText("Missing key value")
            self.verify_status.setStyleSheet("color: #ef4444; font-size: 11px; font-weight: bold;")
            return

        self.verify_status.setText("Verifying...")
        self.verify_status.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold;")
        self.verify_btn.setEnabled(False)

        # Trigger verifications thread
        self.verify_worker = KeyVerificationWorker(new_key)
        self.verify_worker.finished.connect(self.on_verification_completed)
        self.verify_worker.start()

    def on_verification_completed(self, success: bool, msg: str) -> None:
        """Invoked when the verifications background thread completes."""
        self.verify_btn.setEnabled(True)
        if success:
            self.verify_status.setText("Verified!")
            self.verify_status.setStyleSheet("color: #22c55e; font-size: 11px; font-weight: bold;")
        else:
            self.verify_status.setText("Failed!")
            self.verify_status.setStyleSheet("color: #ef4444; font-size: 11px; font-weight: bold;")
            QMessageBox.warning(self, "Verification Failed", f"Validation check failed:\n{msg}")

    def save_settings(self) -> None:
        """Saves current state options securely to the config module."""
        new_key = self.key_input.text().strip()
        
        # Override masked representations back to local stored secrets
        if new_key == self.mask_key(self.saved_key):
            new_key = self.saved_key

        # Persist values safely via config
        config.set_setting("gemini_api_key", new_key)
        config.set_setting("shake_sensitivity", self.sens_box.currentText().lower())
        config.set_setting("voice_activation", self.voice_toggle.isChecked())
        
        # Update settings complete flag if keys are now configured
        if config.is_api_key_set():
            config.set_setting("onboarding_complete", True)
            
        logger.info("Saved new configuration parameters inside settings dialog.")
        self.accept()


class SystemTrayIcon(QSystemTrayIcon):
    """System tray component representing Magisor status and quick settings."""
    
    def __init__(
        self, 
        icon_path: str, 
        on_settings_clicked: Callable[[], None], 
        on_exit_clicked: Callable[[], None],
        on_test_capture_clicked: Optional[Callable[[], None]] = None
    ):
        """
        Initializes the tray icon with right-click menu and settings.
        """
        super().__init__()
        self.icon_path = icon_path
        self.on_settings_clicked = on_settings_clicked
        self.on_exit_clicked = on_exit_clicked
        self.on_test_capture_clicked = on_test_capture_clicked
        
        # Load tray icon
        if os.path.exists(self.icon_path):
            self.setIcon(QIcon(self.icon_path))
        else:
            logger.warning("Tray icon file not found at: '%s'. Using empty fallback.", self.icon_path)
            self.setIcon(QIcon())

        self.init_menu()
        self.setToolTip("Magisor - AI Cursor Assistant")
        
        # Bind double clicks directly to opening settings panel
        self.activated.connect(self.on_tray_activated)

    def init_menu(self) -> None:
        """Builds context menu actions according to user right-click requirements."""
        self.menu = QMenu()
        
        self.menu.setStyleSheet("""
            QMenu {
                background-color: #12121a;
                border: 1px solid #2a2a38;
                border-radius: 8px;
                color: #e2e8f0;
                padding: 6px;
                font-family: 'Segoe UI', sans-serif;
                font-size: 12px;
            }
            QMenu::item {
                padding: 6px 20px;
                border-radius: 4px;
            }
            QMenu::item:disabled {
                color: #4b5563;
                font-style: italic;
            }
            QMenu::item:selected {
                background-color: #8b5cf6;
                color: #ffffff;
            }
            QMenu::separator {
                height: 1px;
                background-color: #2a2a38;
                margin: 4px 0;
            }
        """)

        # 1. "Magisor is running" (greyed out header title)
        title_action = QAction("Magisor is running", self)
        title_action.setEnabled(False)
        self.menu.addAction(title_action)
        
        self.menu.addSeparator()

        # 2. Settings dialog hook
        settings_action = QAction("Settings", self)
        settings_action.triggered.connect(self.show_dialog)
        self.menu.addAction(settings_action)

        # 3. Test Capture triggers
        test_action = QAction("Test Capture", self)
        if self.on_test_capture_clicked:
            test_action.triggered.connect(self.on_test_capture_clicked)
        self.menu.addAction(test_action)

        self.menu.addSeparator()

        # 4. Quit Action
        exit_action = QAction("Quit", self)
        exit_action.triggered.connect(self.on_exit_clicked)
        self.menu.addAction(exit_action)

        self.setContextMenu(self.menu)

    def show(self) -> None:
        """Overrides show to display the first launch notification toast balloon."""
        super().show()
        # First launch balloon as requested
        self.show_notification(
            "Magisor Active", 
            "Magisor is active — shake your mouse to activate"
        )

    def show_dialog(self) -> None:
        """Pops open the visual Settings Configuration Dialog."""
        dialog = SettingsDialog()
        result = dialog.exec_()
        if result == QDialog.Accepted:
            # Trigger reload/re-hook notifications if settings updated
            self.on_settings_clicked()

    def on_tray_activated(self, reason) -> None:
        """Handles single/double click tray icon activation."""
        if reason == QSystemTrayIcon.DoubleClick:
            self.show_dialog()

    def show_notification(self, title: str, message: str) -> None:
        """Displays a native system tray toast notification."""
        self.showMessage(title, message, QSystemTrayIcon.Information, 3000)
