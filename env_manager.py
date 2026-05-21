"""
Environment Variable Manager
Loads and validates runtime configurations from the .env file.
"""
import os
import logging
from typing import Dict, Any
import dotenv
from dotenv import load_dotenv

# Configure logger
logger = logging.getLogger("magisor.env_manager")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class EnvManager:
    """Manages system environment variables for the Magisor application."""
    
    def __init__(self):
        self.env_data: Dict[str, str] = {}
        
    def load_environment(self) -> bool:
        """
        Loads environment variables from the .env file.
        
        Returns:
            bool: True if loaded successfully, False otherwise.
        """
        # Load the .env file from the project root (where this file resides)
        project_root = os.path.dirname(os.path.abspath(__file__))
        env_path = os.path.join(project_root, ".env")
        
        if not os.path.exists(env_path):
            logger.warning("The .env file was not found at '%s'. Make sure to create it.", env_path)
            self.env_data = {}
            return False
            
        try:
            # Use python-dotenv to load into os.environ
            load_dotenv(dotenv_path=env_path)
            
            # Read all key-value pairs from .env to populate self.env_data dictionary
            try:
                self.env_data = {k: v for k, v in dotenv.dotenv_values(env_path).items() if v is not None}
            except Exception:
                # Fallback manual parser if dotenv_values fails
                self.env_data = {}
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            parts = line.split("=", 1)
                            key = parts[0].strip()
                            val = parts[1].strip()
                            if len(val) >= 2 and ((val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'"))):
                                val = val[1:-1]
                            self.env_data[key] = val
            return True
        except Exception as e:
            logger.error("Error loading .env file: %s", str(e))
            self.env_data = {}
            return False

    def get(self, key: str, default: Any = None) -> Any:
        """
        Retrieves the value of an environment variable.
        
        Args:
            key (str): The environment variable name.
            default (Any): The default value to return if key doesn't exist.
            
        Returns:
            Any: The value of the environment variable.
        """
        # Check os.environ first to support runtime override, then fall back to loaded self.env_data
        return os.environ.get(key, self.env_data.get(key, default))

    def validate_env(self) -> bool:
        """
        Validates that all required system variables are present.
        
        Returns:
            bool: True if valid, False otherwise.
        """
        project_root = os.path.dirname(os.path.abspath(__file__))
        env_example_path = os.path.join(project_root, ".env.example")
        
        if not os.path.exists(env_example_path):
            logger.warning("The .env.example template file was not found at '%s'. Skipping validation.", env_example_path)
            return True
            
        # Parse all required keys from .env.example
        example_keys = []
        try:
            example_keys = list(dotenv.dotenv_values(env_example_path).keys())
        except Exception:
            # Fallback manual parser for .env.example
            with open(env_example_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key = line.split("=", 1)[0].strip()
                        if key:
                            example_keys.append(key)
                            
        # Validate that each key in .env.example is present in actual .env file
        # Note: We must never log the actual values of any keys - only their names.
        missing_keys = []
        for key in example_keys:
            if key not in self.env_data:
                missing_keys.append(key)
                logger.warning(
                    "Required environment key '%s' is missing from the actual .env file. "
                    "Please add '%s' to your .env file.", 
                    key, key
                )
                
        return len(missing_keys) == 0

# Initialize global instance
_global_instance = EnvManager()

# On startup, load environment variables and validate
_global_instance.load_environment()
_global_instance.validate_env()

def get_env(key: str, fallback: Any = None) -> Any:
    """
    Exposes the value of any environment variable.
    
    Args:
        key (str): The environment variable name.
        fallback (Any): The default value if not found.
        
    Returns:
        Any: The value of the environment variable.
    """
    return _global_instance.get(key, fallback)
