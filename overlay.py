"""
UI Overlay Window (PyQt5)
Transparent, always-on-top, borderless overlay that appears near the cursor.
"""
import json
import logging
from typing import Optional, Dict, Any, List
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
    QLineEdit, QPushButton, QGraphicsDropShadowEffect, QFrame
)
from PyQt5.QtCore import pyqtSignal, Qt, QPropertyAnimation, QTimer, QPoint, QRectF
from PyQt5.QtGui import QPainter, QColor, QPen, QBrush, QFont

# Configure logger
logger = logging.getLogger("magisor.overlay")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class LoadingSpinner(QWidget):
    """Custom-painted rotating circular violet spinner for async API calls."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(28, 28)
        self.angle = 0
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.rotate)
        
    def rotate(self):
        self.angle = (self.angle + 12) % 360
        self.update()
        
    def start(self):
        self.timer.start(30)
        self.show()
        
    def stop(self):
        self.timer.stop()
        self.hide()
        
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        cx = self.width() / 2
        cy = self.height() / 2
        radius = 8
        
        pen = QPen(QColor(139, 92, 246), 2.5) # Sleek violet line
        pen.setCapStyle(Qt.RoundCap)
        painter.setPen(pen)
        
        # Draw rotating arc (270 degrees)
        painter.drawArc(
            int(cx - radius), int(cy - radius), 
            int(radius * 2), int(radius * 2), 
            self.angle * 16, 270 * 16
        )

class OverlayWindow(QWidget):
    """
    Borderless, semi-transparent window containing AI context,
    follow-up text input, and quick-action suggestions.
    """
    
    # Signal emitted when a follow-up is submitted
    followup_submitted = pyqtSignal(str)
    # Signal emitted when closed
    dismissed = pyqtSignal()
    
    def __init__(self):
        super().__init__()
        self.is_verified = False
        self.init_ui()

    def init_ui(self) -> None:
        """Configures Qt Window flags, styling, background transparency, and layout."""
        # Frameless, transparent, always-on-top, clean utility task window
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setFixedWidth(380)
        
        # Configure fade-in transition
        self.fade_anim = QPropertyAnimation(self, b"windowOpacity")
        self.fade_anim.setDuration(150)
        self.fade_anim.setStartValue(0.0)
        self.fade_anim.setEndValue(1.0)
        
        # Outer base frame styling
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 10, 10, 10)
        
        self.card = QFrame(self)
        self.card.setObjectName("outerFrame")
        self.card.setStyleSheet("""
            QFrame#outerFrame {
                background-color: rgba(20, 20, 20, 230);
                border: 1px solid rgba(255, 255, 255, 20);
                border-radius: 12px;
            }
        """)
        
        card_layout = QVBoxLayout(self.card)
        card_layout.setContentsMargins(16, 16, 16, 16)
        card_layout.setSpacing(12)
        
        # 1. Header (Branding & Close)
        header_layout = QHBoxLayout()
        branding = QLabel("MAGISOR", self)
        branding.setStyleSheet("color: #71717a; font-size: 10px; font-weight: bold; letter-spacing: 1px;")
        header_layout.addWidget(branding)
        
        header_layout.addStretch()
        
        close_btn = QPushButton("✕", self)
        close_btn.setObjectName("closeBtn")
        close_btn.setFixedSize(16, 16)
        close_btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                color: #71717a;
                border: none;
                font-size: 12px;
                font-weight: bold;
            }
            QPushButton:hover {
                color: #ef4444;
            }
        """)
        close_btn.clicked.connect(self.dismiss)
        header_layout.addWidget(close_btn)
        card_layout.addLayout(header_layout)
        
        # 2. Main content display text
        self.summary_label = QLabel("Analyzing...", self)
        self.summary_label.setWordWrap(True)
        self.summary_label.setStyleSheet("color: #ffffff; font-size: 14px; font-weight: 500; line-height: 1.5;")
        card_layout.addWidget(self.summary_label)
        
        # 3. Quick Action Pills Container
        self.pills_widget = QWidget(self)
        self.pills_layout = QHBoxLayout(self.pills_widget)
        self.pills_layout.setContentsMargins(0, 0, 0, 0)
        self.pills_layout.setSpacing(8)
        card_layout.addWidget(self.pills_widget)
        
        # 4. Loading Spinner and Input Box Layout
        bottom_layout = QHBoxLayout()
        bottom_layout.setSpacing(8)
        
        self.spinner = LoadingSpinner(self)
        bottom_layout.addWidget(self.spinner)
        
        self.prompt_input = QLineEdit(self)
        self.prompt_input.setPlaceholderText("Ask follow-up...")
        self.prompt_input.setStyleSheet("""
            QLineEdit {
                background-color: #161622;
                border: 1px solid #2d2d3d;
                border-radius: 6px;
                padding: 6px 10px;
                color: #ffffff;
                font-size: 12px;
            }
            QLineEdit:focus {
                border: 1px solid #8b5cf6;
            }
        """)
        self.prompt_input.returnPressed.connect(self.submit_followup)
        bottom_layout.addWidget(self.prompt_input)
        
        self.send_btn = QPushButton("Send", self)
        self.send_btn.setStyleSheet("""
            QPushButton {
                background-color: #1e1b4b;
                border: 1px solid #4338ca;
                border-radius: 6px;
                padding: 6px 12px;
                color: #ffffff;
                font-weight: bold;
                font-size: 11px;
            }
            QPushButton:hover {
                background-color: #312e81;
            }
        """)
        self.send_btn.clicked.connect(self.submit_followup)
        bottom_layout.addWidget(self.send_btn)
        card_layout.addLayout(bottom_layout)
        
        layout.addWidget(self.card)
        self.setLayout(layout)
        
        # Drop shadow effect
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(15)
        shadow.setXOffset(0)
        shadow.setYOffset(4)
        shadow.setColor(QColor(0, 0, 0, 150))
        self.card.setGraphicsEffect(shadow)

    # --- Events ---

    def keyPressEvent(self, event) -> None:
        """Dismisses the overlay instantly on Escape."""
        if event.key() == Qt.Key_Escape:
            self.dismiss()
        else:
            super().keyPressEvent(event)
            
    def changeEvent(self, event) -> None:
        """Captures window focus loss (outside clicks) and dismisses gracefully."""
        from PyQt5.QtCore import QEvent
        if event.type() == QEvent.WindowDeactivate:
            self.dismiss()
        super().changeEvent(event)

    # --- Core Controls ---

    def show_near_cursor(self, x: int, y: int, initial_content: str = "Analyzing...") -> None:
        """
        Animates a fade-in and displays the overlay adjacent to the cursor coordinates.
        Clamps coordinates to ensure it stays completely inside screen limits.
        """
        self.summary_label.setText(initial_content)
        self.summary_label.setStyleSheet("color: #a1a1aa; font-size: 13px; font-style: italic;")
        
        # Clear action pills
        for i in reversed(range(self.pills_layout.count())):
            widget = self.pills_layout.itemAt(i).widget()
            if widget:
                widget.deleteLater()
                
        self.spinner.start()
        self.show()
        
        # Calculate cursor bounds clamping
        from PyQt5.QtWidgets import QApplication
        screen = QApplication.primaryScreen().geometry()
        
        target_x = x + 20
        target_y = y + 20
        
        # Recalculate dimensions dynamically
        self.adjustSize()
        width = self.width()
        height = self.height()
        
        if target_x + width > screen.right():
            target_x = screen.right() - width - 10
        if target_x < screen.left():
            target_x = screen.left() + 10
            
        if target_y + height > screen.bottom():
            target_y = screen.bottom() - height - 10
        if target_y < screen.top():
            target_y = screen.top() + 10
            
        self.move(target_x, target_y)
        
        # Trigger fade-in
        self.fade_anim.setDirection(QPropertyAnimation.Forward)
        self.fade_anim.start()

    def update_content(self, rich_content: str) -> None:
        """
        Renders Gemini's structured response inside the overlay window.
        """
        self.spinner.stop()
        
        try:
            # Parse response JSON
            if isinstance(rich_content, str):
                data = json.loads(rich_content)
            else:
                data = rich_content
        except Exception:
            data = {
                "summary": rich_content,
                "actions": [],
                "text": ""
            }
            
        summary = data.get("summary", "")
        actions = data.get("actions", [])
        
        self.summary_label.setText(summary)
        self.summary_label.setStyleSheet("color: #ffffff; font-size: 14px; font-weight: 500; line-height: 1.5;")
        
        # Clear previous action pills
        for i in reversed(range(self.pills_layout.count())):
            widget = self.pills_layout.itemAt(i).widget()
            if widget:
                widget.deleteLater()
                
        # Generate new action pills (up to 3)
        for action_text in actions[:3]:
            pill = QPushButton(action_text, self)
            pill.setStyleSheet("""
                QPushButton {
                    background-color: #1e1b4b;
                    border: 1px solid #4338ca;
                    border-radius: 12px;
                    padding: 5px 12px;
                    color: #cbd5e1;
                    font-size: 11px;
                    font-weight: 600;
                }
                QPushButton:hover {
                    background-color: #312e81;
                    border: 1px solid #6366f1;
                    color: #ffffff;
                }
            """)
            pill.clicked.connect(lambda checked, t=action_text: self.on_pill_clicked(t))
            self.pills_layout.addWidget(pill)
            
        self.adjustSize()

    def show_error(self, message: str, show_settings_btn: bool = False) -> None:
        """Displays error layout state inside the card, supporting settings redirections."""
        self.spinner.stop()
        self.summary_label.setText(message)
        self.summary_label.setStyleSheet("color: #f87171; font-size: 13px; font-weight: bold; line-height: 1.4;")
        
        # Clear previous pills
        for i in reversed(range(self.pills_layout.count())):
            widget = self.pills_layout.itemAt(i).widget()
            if widget:
                widget.deleteLater()
                
        if show_settings_btn:
            settings_btn = QPushButton("Open Settings", self)
            settings_btn.setStyleSheet("""
                QPushButton {
                    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #8b5cf6, stop:1 #3b82f6);
                    border: none;
                    border-radius: 6px;
                    padding: 8px 16px;
                    color: #ffffff;
                    font-weight: bold;
                    font-size: 12px;
                }
                QPushButton:hover {
                    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #a78bfa, stop:1 #60a5fa);
                }
            """)
            settings_btn.clicked.connect(self.open_settings_dialog)
            self.pills_layout.addWidget(settings_btn)
            
        self.adjustSize()

    def open_settings_dialog(self) -> None:
        """Redirects user to the Onboarding/Settings Wizard Dialog."""
        self.dismiss()
        try:
            from onboarding import OnboardingWizard
            wizard = OnboardingWizard()
            wizard.exec_()
        except Exception as e:
            logger.error("Failed to load settings wizard: %s", str(e))

    def on_pill_clicked(self, action_text: str) -> None:
        """Callback for suggested action pill clicks."""
        logger.info("Action pill clicked: %s", action_text)
        # Dismiss on action click as requested
        self.dismiss()

    def submit_followup(self) -> None:
        """Handles follow-up submissions, updating content layout and emitting submit signals."""
        text = self.prompt_input.text().strip()
        if not text:
            return
            
        self.prompt_input.clear()
        self.spinner.start()
        self.summary_label.setText("Consulting Magisor...")
        self.summary_label.setStyleSheet("color: #a1a1aa; font-size: 13px; font-style: italic;")
        
        # Clear action pills
        for i in reversed(range(self.pills_layout.count())):
            widget = self.pills_layout.itemAt(i).widget()
            if widget:
                widget.deleteLater()
                
        self.followup_submitted.emit(text)
        self.adjustSize()

    def dismiss(self) -> None:
        """Animates fade-out and hides/closes the overlay window."""
        self.fade_anim.setDirection(QPropertyAnimation.Backward)
        self.fade_anim.finished.connect(self._on_fade_out_finished)
        self.fade_anim.start()
        
    def _on_fade_out_finished(self) -> None:
        # Prevent double-firing hook issues
        try:
            self.fade_anim.finished.disconnect(self._on_fade_out_finished)
        except TypeError:
            pass
        self.hide()
        self.dismissed.emit()
