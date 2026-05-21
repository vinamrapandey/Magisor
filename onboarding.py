"""
Onboarding Wizard
Step-by-step setup wizard displayed on first launch to capture and test the Gemini API Key.
"""
import os
import logging
from PyQt5.QtWidgets import (
    QDialog, QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
    QLineEdit, QPushButton, QStackedWidget, QSpacerItem, QSizePolicy
)
from PyQt5.QtCore import pyqtSignal, Qt, QTimer, QThread, QPoint, QRectF
from PyQt5.QtGui import QPainter, QPolygon, QColor, QPen, QBrush, QFont, QDesktopServices
from PyQt5.QtCore import QUrl

import config

# Configure logger
logger = logging.getLogger("magisor.onboarding")

class KeyVerificationWorker(QThread):
    """Asynchronous worker to verify Gemini API Key in the background without blocking the UI thread."""
    result_ready = pyqtSignal(bool, str)
    
    def __init__(self, api_key: str):
        super().__init__()
        self.api_key = api_key
        
    def run(self):
        try:
            import google.generativeai as genai
            genai.configure(api_key=self.api_key)
            # Lightweight verification: list models
            models = list(genai.list_models())
            if models:
                self.result_ready.emit(True, "")
            else:
                self.result_ready.emit(False, "No models were returned by the API.")
        except Exception as e:
            err_msg = str(e)
            # Make common errors user-friendly
            if "API_KEY_INVALID" in err_msg or "400" in err_msg or "invalid" in err_msg.lower():
                err_msg = "The API key you entered is invalid. Please check for typos or extra spaces."
            elif "403" in err_msg:
                err_msg = "Access Forbidden. Ensure the Gemini API is enabled in your Google Cloud Project."
            self.result_ready.emit(False, err_msg)

class StepIndicatorWidget(QWidget):
    """Custom-painted progress bar displaying active, completed, and pending setup steps."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.current_step = 0
        self.setMinimumHeight(60)
        
    def set_step(self, step: int):
        self.current_step = step
        self.update()
        
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        width = self.width()
        height = self.height()
        
        num_steps = 3
        circle_radius = 12
        line_y = height // 2 - 5
        
        # Calculate horizontal spacing
        padding = 70
        step_width = (width - 2 * padding) / (num_steps - 1)
        positions = [padding + i * step_width for i in range(num_steps)]
        
        # Draw full inactive connector line
        painter.setPen(QPen(QColor(45, 45, 68), 3))
        painter.drawLine(int(positions[0]), line_y, int(positions[2]), line_y)
        
        # Draw active completed line portion
        if self.current_step > 0:
            painter.setPen(QPen(QColor(139, 92, 246), 3)) # Vibrant violet line
            painter.drawLine(int(positions[0]), line_y, int(positions[self.current_step]), line_y)
            
        labels = ["Welcome", "API Key", "Tutorial"]
        for i in range(num_steps):
            cx = int(positions[i])
            cy = line_y
            
            # Determine color states
            if i < self.current_step:
                # Completed
                circle_color = QColor(139, 92, 246)
                border_color = QColor(139, 92, 246)
                num_color = QColor(255, 255, 255)
                lbl_color = QColor(226, 232, 240)
            elif i == self.current_step:
                # Active
                circle_color = QColor(30, 27, 75)
                border_color = QColor(139, 92, 246)
                num_color = QColor(167, 139, 250)
                lbl_color = QColor(167, 139, 250)
            else:
                # Inactive
                circle_color = QColor(22, 22, 34)
                border_color = QColor(55, 65, 81)
                num_color = QColor(100, 116, 139)
                lbl_color = QColor(100, 116, 139)
                
            # Draw circle shadow/glow if active
            if i == self.current_step:
                painter.setPen(Qt.NoPen)
                painter.setBrush(QBrush(QColor(139, 92, 246, 50)))
                painter.drawEllipse(QPoint(cx, cy), circle_radius + 4, circle_radius + 4)
                
            # Draw indicator circle
            painter.setPen(QPen(border_color, 2))
            painter.setBrush(QBrush(circle_color))
            painter.drawEllipse(QPoint(cx, cy), circle_radius, circle_radius)
            
            # Draw step number
            painter.setPen(QPen(num_color))
            font = QFont("Segoe UI", 9, QFont.Bold)
            painter.setFont(font)
            painter.drawText(QRectF(cx - circle_radius, cy - circle_radius, circle_radius * 2, circle_radius * 2), Qt.AlignCenter, str(i + 1))
            
            # Draw label
            font_lbl = QFont("Segoe UI", 8, QFont.Bold if i == self.current_step else QFont.Normal)
            painter.setFont(font_lbl)
            painter.setPen(QPen(lbl_color))
            painter.drawText(cx - 50, cy + circle_radius + 5, 100, 20, Qt.AlignCenter, labels[i])

class AnimatedShakeCursorWidget(QWidget):
    """Custom widget rendering an elegant mouse cursor shaking to illustrate the activation gesture."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(220, 160)
        self.angle = 0.0
        self.offset = 0
        
        # Timer to run animation at 60 FPS
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.animate)
        self.timer.start(16)
        
    def animate(self):
        self.angle += 0.15
        import math
        # Quick lateral oscillation to mimic mouse shake
        self.offset = int(math.sin(self.angle) * 35)
        self.update()
        
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        w, h = self.width(), self.height()
        
        # Outer Card container
        painter.setPen(QPen(QColor(45, 45, 68), 1))
        painter.setBrush(QBrush(QColor(18, 18, 29)))
        painter.drawRoundedRect(self.rect().adjusted(10, 10, -10, -10), 12, 12)
        
        # Center reference point
        cx = w // 2 + self.offset
        cy = h // 2
        
        # Dotted vibration boundaries
        painter.setPen(QPen(QColor(139, 92, 246, 60), 2, Qt.DashLine))
        painter.drawLine(w // 2 - 35, cy + 12, w // 2 + 35, cy + 12)
        
        # Glowing shadow pulse underneath the active cursor
        painter.setPen(Qt.NoPen)
        painter.setBrush(QBrush(QColor(139, 92, 246, 40)))
        painter.drawEllipse(QPoint(cx, cy), 18, 18)
        
        # Modern geometric mouse cursor polygon
        cursor = QPolygon([
            QPoint(cx, cy),
            QPoint(cx + 14, cy + 14),
            QPoint(cx + 6, cy + 16),
            QPoint(cx + 10, cy + 25),
            QPoint(cx + 7, cy + 26),
            QPoint(cx + 3, cy + 17),
            QPoint(cx, cy + 20)
        ])
        
        painter.setPen(QPen(QColor(255, 255, 255), 2))
        painter.setBrush(QBrush(QColor(139, 92, 246)))
        painter.drawPolygon(cursor)

class OnboardingWizard(QDialog):
    """User wizard designed to welcome the user, ask for a Gemini API key,
    verify the key validity, and guide them through basic cursor shake controls.
    """
    
    # Signal emitted when setup is completed successfully, emitting the validated API key
    setup_completed = pyqtSignal(str)
    
    def __init__(self):
        super().__init__()
        self.is_verified = False
        self.verified_key = ""
        self.worker = None
        self.init_ui()

    def init_ui(self) -> None:
        """Sets up pages, styling, input forms, and navigation buttons."""
        self.setWindowTitle("Welcome to Magisor")
        self.setFixedSize(520, 520)
        
        # Global style sheet for high-end dark premium aesthetic
        self.setStyleSheet("""
            QDialog {
                background-color: #0c0c14;
            }
            QLabel {
                font-family: 'Segoe UI', Arial, sans-serif;
                color: #e2e8f0;
            }
            QLineEdit {
                background-color: #161624;
                border: 2px solid #28283e;
                border-radius: 8px;
                padding: 10px;
                color: #ffffff;
                font-size: 13px;
                font-family: 'Segoe UI', sans-serif;
            }
            QLineEdit:focus {
                border: 2px solid #8b5cf6;
            }
            QPushButton {
                font-family: 'Segoe UI', sans-serif;
                font-weight: bold;
                border-radius: 8px;
                padding: 10px 20px;
            }
        """)
        
        # Top-level layout
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(24, 20, 24, 20)
        main_layout.setSpacing(10)
        
        # 1. Step Indicator
        self.indicator = StepIndicatorWidget(self)
        main_layout.addWidget(self.indicator)
        
        # Separator line
        sep = QFrame(self)
        sep.setFrameShape(QFrame.HLine)
        sep.setFrameShadow(QFrame.Sunken)
        sep.setStyleSheet("background-color: #1e1e2f; max-height: 1px; border: none;")
        main_layout.addWidget(sep)
        
        # 2. Central stacked pages
        self.pages = QStackedWidget(self)
        self.pages.addWidget(self.create_welcome_page())
        self.pages.addWidget(self.create_api_key_page())
        self.pages.addWidget(self.create_tutorial_page())
        main_layout.addWidget(self.pages)
        
        # Separator line
        sep2 = QFrame(self)
        sep2.setFrameShape(QFrame.HLine)
        sep2.setFrameShadow(QFrame.Sunken)
        sep2.setStyleSheet("background-color: #1e1e2f; max-height: 1px; border: none;")
        main_layout.addWidget(sep2)
        
        # 3. Bottom Navigation Bar
        nav_layout = QHBoxLayout()
        self.back_btn = QPushButton("Back", self)
        self.back_btn.setStyleSheet("""
            QPushButton {
                background-color: #1c1917;
                border: 1px solid #44403c;
                color: #d6d3d1;
            }
            QPushButton:hover {
                background-color: #292524;
            }
        """)
        self.back_btn.clicked.connect(self.go_back)
        nav_layout.addWidget(self.back_btn)
        
        nav_layout.addStretch()
        
        self.next_btn = QPushButton("Get Started", self)
        self.next_btn.setObjectName("actionBtn")
        self.next_btn.setStyleSheet("""
            QPushButton {
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #8b5cf6, stop:1 #3b82f6);
                border: none;
                color: #ffffff;
            }
            QPushButton:hover {
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #a78bfa, stop:1 #60a5fa);
            }
            QPushButton:disabled {
                background-color: #1e293b;
                color: #64748b;
            }
        """)
        self.next_btn.clicked.connect(self.go_next)
        nav_layout.addWidget(self.next_btn)
        
        main_layout.addLayout(nav_layout)
        self.setLayout(main_layout)
        
        # Update navigation initial state
        self.update_nav_buttons()

    # --- Page Creators ---
    
    def create_welcome_page(self) -> QWidget:
        page = QWidget(self)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(10, 20, 10, 10)
        
        # Spacing
        layout.addSpacing(20)
        
        # Title/Logo name centered
        logo_label = QLabel(self)
        logo_label.setAlignment(Qt.AlignCenter)
        logo_label.setText(
            "<span style='font-size: 38px; font-weight: bold; font-family: \"Outfit\", \"Segoe UI\", sans-serif;'>"
            "<span style='color: #c084fc;'>Magi</span>"
            "<span style='color: #60a5fa;'>sor</span></span>"
        )
        layout.addWidget(logo_label)
        
        # Tagline
        tagline_label = QLabel("Your AI-powered cursor assistant for Windows", self)
        tagline_label.setAlignment(Qt.AlignCenter)
        tagline_label.setStyleSheet("color: #a7f3d0; font-size: 14px; font-weight: 600; margin-top: 5px;")
        layout.addWidget(tagline_label)
        
        layout.addSpacing(25)
        
        # Explanation
        explanation_label = QLabel(self)
        explanation_label.setAlignment(Qt.AlignCenter)
        explanation_label.setWordWrap(True)
        explanation_label.setText(
            "Unlock contextual intelligence instantly anywhere on your system.\n\n"
            "Magisor runs silently in the background. Simply shake your mouse "
            "over any text, code, or visual element to invoke an interactive Gemini Vision "
            "overlay instantly."
        )
        explanation_label.setStyleSheet("font-size: 13px; color: #9ca3af; line-height: 1.6;")
        layout.addWidget(explanation_label)
        
        layout.addStretch()
        return page

    def create_api_key_page(self) -> QWidget:
        page = QWidget(self)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(10, 20, 10, 10)
        
        # Heading
        header = QLabel("Connect your Gemini API Key", self)
        header.setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff;")
        layout.addWidget(header)
        
        # Instruction text
        instructions = QLabel(
            "Magisor uses Google's Gemini Vision AI. "
            "You'll need a free API key to get started.", self
        )
        instructions.setWordWrap(True)
        instructions.setStyleSheet("font-size: 13px; color: #9ca3af; line-height: 1.4;")
        layout.addWidget(instructions)
        
        # Clickable Link
        link_label = QLabel(self)
        link_label.setOpenExternalLinks(True)
        link_label.setText(
            "<a href='https://aistudio.google.com' style='color: #a855f7; text-decoration: underline; font-weight: bold;'>"
            "Get your free Gemini API key at aistudio.google.com</a>"
        )
        link_label.setStyleSheet("font-size: 13px;")
        layout.addWidget(link_label)
        
        layout.addSpacing(15)
        
        # Password entry field
        pwd_layout = QHBoxLayout()
        self.api_key_input = QLineEdit(self)
        self.api_key_input.setPlaceholderText("Paste your AIzaSy... API key here")
        self.api_key_input.setEchoMode(QLineEdit.Password)
        self.api_key_input.textChanged.connect(self.on_key_text_changed)
        pwd_layout.addWidget(self.api_key_input)
        
        # Toggle hide/show button
        self.toggle_btn = QPushButton("Show", self)
        self.toggle_btn.setFixedWidth(70)
        self.toggle_btn.setStyleSheet("""
            QPushButton {
                background-color: #161624;
                border: 2px solid #28283e;
                color: #cbd5e1;
                font-size: 11px;
                padding: 10px;
            }
            QPushButton:hover {
                background-color: #2e2a47;
                border: 2px solid #8b5cf6;
            }
        """)
        self.toggle_btn.clicked.connect(self.toggle_password_visibility)
        pwd_layout.addWidget(self.toggle_btn)
        layout.addLayout(pwd_layout)
        
        layout.addSpacing(10)
        
        # Verify and Status layout
        verify_layout = QHBoxLayout()
        self.verify_btn = QPushButton("Verify Key", self)
        self.verify_btn.setFixedWidth(120)
        self.verify_btn.setStyleSheet("""
            QPushButton {
                background-color: #1e1b4b;
                border: 1px solid #4338ca;
                color: #ffffff;
            }
            QPushButton:hover {
                background-color: #312e81;
                border: 1px solid #6366f1;
            }
            QPushButton:disabled {
                background-color: #0f172a;
                border: 1px solid #1e293b;
                color: #475569;
            }
        """)
        self.verify_btn.clicked.connect(lambda: self.validate_api_key(self.api_key_input.text()))
        verify_layout.addWidget(self.verify_btn)
        
        self.status_label = QLabel(self)
        self.status_label.setWordWrap(True)
        self.status_label.setStyleSheet("font-size: 12px;")
        verify_layout.addWidget(self.status_label)
        
        layout.addLayout(verify_layout)
        layout.addStretch()
        return page

    def create_tutorial_page(self) -> QWidget:
        page = QWidget(self)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(10, 20, 10, 10)
        
        # Title
        title = QLabel("Ready to go!", self)
        title.setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff;")
        layout.addWidget(title)
        
        layout.addSpacing(10)
        
        # Animation Widget
        self.shake_anim = AnimatedShakeCursorWidget(self)
        layout.addWidget(self.shake_anim)
        
        layout.addSpacing(15)
        
        # Tutorial description
        tut_desc = QLabel("Shake your mouse to activate Magisor anywhere on screen", self)
        tut_desc.setAlignment(Qt.AlignCenter)
        tut_desc.setStyleSheet("font-size: 14px; font-weight: bold; color: #f8fafc;")
        layout.addWidget(tut_desc)
        
        tut_detail = QLabel(
            "A rapid lateral shake gesture captures the surrounding window context "
            "and opens the conversation workspace instantly.", self
        )
        tut_detail.setAlignment(Qt.AlignCenter)
        tut_detail.setWordWrap(True)
        tut_detail.setStyleSheet("font-size: 12px; color: #94a3b8; line-height: 1.4;")
        layout.addWidget(tut_detail)
        
        layout.addStretch()
        return page

    # --- Event Handlers & Core Methods ---
    
    def toggle_password_visibility(self) -> None:
        if self.api_key_input.echoMode() == QLineEdit.Password:
            self.api_key_input.setEchoMode(QLineEdit.Normal)
            self.toggle_btn.setText("Hide")
        else:
            self.api_key_input.setEchoMode(QLineEdit.Password)
            self.toggle_btn.setText("Show")
            
    def on_key_text_changed(self) -> None:
        self.is_verified = False
        self.next_btn.setEnabled(False)
        self.status_label.clear()
        
    def validate_api_key(self, api_key: str) -> bool:
        """
        Sends a test ping to Gemini API to verify the key.
        """
        api_key = api_key.strip()
        if not api_key:
            self.status_label.setStyleSheet("color: #ef4444;")
            self.status_label.setText("Please enter a valid API key.")
            return False
            
        self.verify_btn.setEnabled(False)
        self.status_label.setStyleSheet("color: #3b82f6;")
        self.status_label.setText("🔄 Verifying key... Please wait.")
        
        # Spawn async QThread worker
        self.worker = KeyVerificationWorker(api_key)
        self.worker.result_ready.connect(self.on_verification_finished)
        self.worker.start()
        return True
        
    def on_verification_finished(self, success: bool, error_msg: str) -> None:
        self.verify_btn.setEnabled(True)
        if success:
            self.is_verified = True
            self.verified_key = self.api_key_input.text().strip()
            self.status_label.setStyleSheet("color: #10b981; font-weight: bold;")
            self.status_label.setText("✅ Key verified!")
            self.next_btn.setEnabled(True)
        else:
            self.is_verified = False
            self.next_btn.setEnabled(False)
            self.status_label.setStyleSheet("color: #ef4444;")
            advice = "\nAdvice: Check your spelling or internet connection."
            self.status_label.setText(f"❌ Verification failed: {error_msg}{advice}")

    def go_next(self) -> None:
        current = self.pages.currentIndex()
        if current == 0:
            self.pages.setCurrentIndex(1)
            self.indicator.set_step(1)
            self.update_nav_buttons()
        elif current == 1:
            self.pages.setCurrentIndex(2)
            self.indicator.set_step(2)
            self.update_nav_buttons()
        elif current == 2:
            self.finish_setup()
            
    def go_back(self) -> None:
        current = self.pages.currentIndex()
        if current > 0:
            self.pages.setCurrentIndex(current - 1)
            self.indicator.set_step(current - 1)
            self.update_nav_buttons()
            
    def update_nav_buttons(self) -> None:
        current = self.pages.currentIndex()
        if current == 0:
            self.back_btn.hide()
            self.next_btn.setText("Get Started")
            self.next_btn.setEnabled(True)
        elif current == 1:
            self.back_btn.show()
            self.next_btn.setText("Next")
            self.next_btn.setEnabled(self.is_verified)
        elif current == 2:
            self.back_btn.show()
            self.next_btn.setText("Finish Setup")
            self.next_btn.setEnabled(True)
            
    def finish_setup(self) -> None:
        """Saves setup completion parameters and notifies the app."""
        key = self.verified_key if self.verified_key else self.api_key_input.text().strip()
        
        # Save key & complete onboarding config
        config.set_setting("gemini_api_key", key)
        config.set_setting("onboarding_complete", True)
        
        # Emit setup completion signal
        self.setup_completed.emit(key)
        
        # Accept dialog
        self.accept()

# Support frame widget for separators
from PyQt5.QtWidgets import QFrame
