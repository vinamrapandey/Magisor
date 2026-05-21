"""
System Tray Icon
Integrates Magisor into the Windows system tray with right-click menu controls.
"""
from PyQt5.QtWidgets import QSystemTrayIcon, QMenu
from typing import Callable

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
        self.init_menu(on_settings_clicked, on_exit_clicked)

    def init_menu(self, on_settings_clicked: Callable[[], None], on_exit_clicked: Callable[[], None]) -> None:
        """Builds context menu actions and icons."""
        pass

    def show_notification(self, title: str, message: str) -> None:
        """
        Displays a native Windows toast notification from the system tray.
        
        Args:
            title (str): Toast title.
            message (str): Toast body message.
        """
        pass
