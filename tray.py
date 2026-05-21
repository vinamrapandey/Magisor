"""
System Tray Icon
Integrates Magisor into the Windows system tray with right-click menu controls.
"""
import os
import logging
from PyQt5.QtWidgets import QSystemTrayIcon, QMenu, QAction
from PyQt5.QtGui import QIcon
from typing import Callable

# Configure logger
logger = logging.getLogger("magisor.tray")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class SystemTrayIcon(QSystemTrayIcon):
    """System tray component representing Magisor status and quick settings."""
    
    def __init__(self, icon_path: str, on_settings_clicked: Callable[[], None], on_exit_clicked: Callable[[], None]):
        """
        Initializes the tray icon with custom menu actions.
        
        Args:
            icon_path (str): Path to tray icon image asset.
            on_settings_clicked (Callable[[], None]): Callback for clicking Settings.
            on_exit_clicked (Callable[[], None]): Callback for clicking Exit.
        """
        super().__init__()
        self.icon_path = icon_path
        
        # Set Tray Icon image
        if os.path.exists(self.icon_path):
            self.setIcon(QIcon(self.icon_path))
        else:
            logger.warning("Tray icon file not found at: '%s'. Initializing empty icon.", self.icon_path)
            self.setIcon(QIcon())
            
        self.init_menu(on_settings_clicked, on_exit_clicked)
        self.setToolTip("Magisor - AI Cursor Assistant")

    def init_menu(self, on_settings_clicked: Callable[[], None], on_exit_clicked: Callable[[], None]) -> None:
        """Builds context menu actions and icons."""
        self.menu = QMenu()
        
        # Premium dark mode styled context menu
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
        
        # Open Settings Action
        settings_action = QAction("Open Settings...", self)
        settings_action.triggered.connect(on_settings_clicked)
        self.menu.addAction(settings_action)
        
        self.menu.addSeparator()
        
        # Exit Action
        exit_action = QAction("Exit Magisor", self)
        exit_action.triggered.connect(on_exit_clicked)
        self.menu.addAction(exit_action)
        
        self.setContextMenu(self.menu)

    def show_notification(self, title: str, message: str) -> None:
        """
        Displays a native Windows toast notification from the system tray.
        
        Args:
            title (str): Toast title.
            message (str): Toast body message.
        """
        # Triggers a native system tray notification message bubble
        self.showMessage(title, message, QSystemTrayIcon.Information, 3000)
