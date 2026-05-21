"""
Configuration Manager
Handles loading, saving, and managing user settings (stored in settings.json).
"""
import os
import json
import logging
from typing import Dict, Any

# Configure logger
logger = logging.getLogger("magisor.config")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

# Default configuration schema
DEFAULT_SETTINGS: Dict[str, Any] = {
    "gemini_api_key": "",
    "shake_sensitivity": "medium",
    "voice_activation": False,
    "onboarding_complete": False
}

def sanitize_settings(settings: Dict[str, Any]) -> Dict[str, Any]:
    """
    Creates a copy of settings with sensitive fields (gemini_api_key) redacted.
    """
    sanitized = settings.copy()
    if "gemini_api_key" in sanitized:
        key_val = sanitized["gemini_api_key"]
        if key_val and isinstance(key_val, str):
            sanitized["gemini_api_key"] = f"******** (len={len(key_val)})"
        else:
            sanitized["gemini_api_key"] = ""
    return sanitized

class SettingsManager:
    """Manages application settings stored locally in settings.json."""
    
    def __init__(self, config_filename: str = "settings.json"):
        # Resolve the %APPDATA%/Magisor directory on Windows, falling back to ~/.config on other platforms
        appdata_dir = os.environ.get("APPDATA")
        if not appdata_dir:
            appdata_dir = os.path.join(os.path.expanduser("~"), ".config")
        self.magisor_dir = os.path.join(appdata_dir, "Magisor")
        self.config_filepath = os.path.join(self.magisor_dir, config_filename)
        self.settings: Dict[str, Any] = {}
        
    def load_settings(self) -> Dict[str, Any]:
        """
        Loads user settings from settings.json. If it does not exist, 
        creates it with default configurations.
        
        Returns:
            Dict[str, Any]: Loaded configurations.
        """
        os.makedirs(self.magisor_dir, exist_ok=True)
        
        if not os.path.exists(self.config_filepath):
            logger.info("settings.json does not exist. Initializing with defaults at '%s'.", self.config_filepath)
            self.settings = DEFAULT_SETTINGS.copy()
            self.save_settings()
            return self.settings
            
        try:
            with open(self.config_filepath, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                
            # Merge with defaults to ensure all required fields are present
            self.settings = DEFAULT_SETTINGS.copy()
            for key, val in loaded.items():
                self.settings[key] = val
                
            # Save settings back to ensure any missing schema defaults are persisted
            self.save_settings()
            return self.settings
        except Exception as e:
            logger.error("Failed to load settings.json: %s. Using default settings.", str(e))
            self.settings = DEFAULT_SETTINGS.copy()
            return self.settings

    def save_settings(self) -> bool:
        """
        Saves current configuration state back to settings.json.
        
        Returns:
            bool: True if successful, False otherwise.
        """
        os.makedirs(self.magisor_dir, exist_ok=True)
        
        try:
            # Clean sensitive values before printing or logging
            sanitized = sanitize_settings(self.settings)
            logger.info("Saving settings state: %s", json.dumps(sanitized))
            
            with open(self.config_filepath, "w", encoding="utf-8") as f:
                json.dump(self.settings, f, indent=4)
            return True
        except Exception as e:
            logger.error("Failed to save settings.json: %s", str(e))
            return False

    def get_api_key(self) -> str:
        """
        Retrieves the Gemini Vision API key.
        
        Returns:
            str: The user-supplied Gemini API key or empty string.
        """
        # Ensure we don't log or print the return value
        return self.settings.get("gemini_api_key", "")

    def set_api_key(self, api_key: str) -> None:
        """
        Sets the Gemini Vision API key and triggers a save.
        
        Args:
            api_key (str): The Gemini API key.
        """
        # Ensure we don't log or print the api_key value
        self.settings["gemini_api_key"] = api_key
        self.save_settings()

    def get(self, key: str, default: Any = None) -> Any:
        """
        Retrieves a general configuration value.
        
        Args:
            key (str): Configuration key.
            default (Any): Default value if not found.
            
        Returns:
            Any: Configured value.
        """
        if default is None:
            default = DEFAULT_SETTINGS.get(key)
        return self.settings.get(key, default)

    def set(self, key: str, value: Any) -> None:
        """
        Sets a general configuration key-value pair and triggers save.
        
        Args:
            key (str): Configuration key.
            value (Any): Value to save.
        """
        self.settings[key] = value
        self.save_settings()

# Initialize global instance
_global_settings_manager = SettingsManager()
_global_settings_manager.load_settings()

# Expose required functions at the module level
def get_setting(key: str, default: Any = None) -> Any:
    """
    Retrieves a setting value.
    
    Args:
        key (str): Configuration key.
        default (Any): Default value if not found.
        
    Returns:
        Any: The setting value.
    """
    return _global_settings_manager.get(key, default)

def set_setting(key: str, value: Any) -> None:
    """
    Sets a setting value and saves the configuration.
    
    Args:
        key (str): Configuration key.
        value (Any): Value to save.
    """
    _global_settings_manager.set(key, value)

def load_settings() -> Dict[str, Any]:
    """
    Loads all settings and returns the dictionary.
    
    Returns:
        Dict[str, Any]: The loaded settings dictionary.
    """
    return _global_settings_manager.load_settings()

def save_settings() -> bool:
    """
    Saves the current settings state.
    
    Returns:
        bool: True if successful, False otherwise.
    """
    return _global_settings_manager.save_settings()

def is_api_key_set() -> bool:
    """
    Checks if the gemini_api_key is set as a non-empty string.
    
    Returns:
        bool: True if gemini_api_key is a non-empty string.
    """
    api_key = _global_settings_manager.get_api_key()
    return isinstance(api_key, str) and len(api_key.strip()) > 0
