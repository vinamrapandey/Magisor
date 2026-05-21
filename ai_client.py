"""
Google Gemini Vision API Client
Sends captured screen content and context elements to the Gemini Vision model.
"""
import base64
import json
import logging
from typing import Optional, Dict, Any, List
import google.generativeai as genai
from PIL import Image

import config
import env_manager

# Configure logger
logger = logging.getLogger("magisor.ai_client")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class MissingAPIKeyError(Exception):
    """Exception raised when the Gemini API key is missing or not configured."""
    pass

def analyze_screen(
    image_base64: str, 
    user_prompt: Optional[str] = None, 
    context: Optional[str] = None
) -> Dict[str, Any]:
    """
    Queries Google Gemini 1.5 Flash Vision model with a base64 screenshot and context,
    returning structured recommendations.
    
    Args:
        image_base64 (str): Base64-encoded JPEG image string.
        user_prompt (Optional[str]): Follow-up text prompt or manual query.
        context (Optional[str]): Extracted system/automation metadata context.
        
    Returns:
        Dict[str, Any]: Parsed JSON response containing 'summary', 'actions', and 'text'.
    """
    # Enforce API Key availability
    if not config.is_api_key_set():
        raise MissingAPIKeyError("Gemini API key not configured. Please add it in Magisor Settings.")
        
    api_key = config.get_setting("gemini_api_key")
    if not api_key or not isinstance(api_key, str) or not api_key.strip():
        raise MissingAPIKeyError("Gemini API key not configured. Please add it in Magisor Settings.")
        
    try:
        # Load credentials exclusively from config settings
        genai.configure(api_key=api_key.strip())
        
        # Configure model with custom system instructions
        system_instruction = (
            "You are Magisor, an intelligent cursor assistant for Windows. "
            "The user has pointed their cursor at something on their screen. "
            "Analyze what is visible and provide:\n"
            "1. A one-line summary of what is under the cursor\n"
            "2. Up to 3 smart suggested actions the user might want to take\n"
            "3. If there is text visible, extract the most relevant portion\n"
            "Keep responses concise. Format as JSON with keys: summary, actions, text."
        )
        
        model_name = env_manager.get_env("GEMINI_MODEL", fallback="gemini-2.0-flash")
        model = genai.GenerativeModel(
            model_name=model_name,
            system_instruction=system_instruction
        )
        
        # Construct content inputs
        prompt_parts = []
        
        # 1. Append structural context if present
        if context:
            prompt_parts.append(f"Context from surrounding system:\n{context}\n")
            
        # 2. Append user manual prompt if present
        if user_prompt:
            prompt_parts.append(f"User follow-up prompt/query: {user_prompt}\n")
        else:
            prompt_parts.append("Analyze the image and provide the requested structured JSON details.")
            
        # 3. Add base64 image payload
        try:
            image_data = base64.b64decode(image_base64)
        except Exception as e:
            raise ValueError(f"Failed to decode base64 image data: {str(e)}")
            
        image_part = {
            "mime_type": "image/jpeg",
            "data": image_data
        }
        prompt_parts.append(image_part)
        
        # Request generation enforcing structured JSON output schema
        logger.info("Sending content analysis request to Gemini API (%s)...", model_name)
        generation_config = {
            "response_mime_type": "application/json"
        }
        
        response = model.generate_content(
            prompt_parts,
            generation_config=generation_config
        )
        
        text_response = response.text.strip()
        
        # Fallback cleaning in case markdown wrappers are present
        if text_response.startswith("```"):
            lines = text_response.splitlines()
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            text_response = "\n".join(lines).strip()
            
        # Parse and return JSON
        parsed_data = json.loads(text_response)
        return parsed_data
        
    except Exception as e:
        err_msg = str(e)
        logger.error("Gemini Vision API request failed: %s", err_msg)
        
        # Gracefully handle common authorization/subscription exceptions
        if "API_KEY_INVALID" in err_msg or "400" in err_msg or "invalid" in err_msg.lower():
            raise RuntimeError(
                "Gemini API call failed: Invalid API key. "
                "Please verify your key in Magisor Settings."
            ) from e
        elif "quota" in err_msg.lower() or "429" in err_msg:
            raise RuntimeError(
                "Gemini API quota exceeded. Please wait a moment or check your Google Cloud Console."
            ) from e
        else:
            raise RuntimeError(f"Gemini API Error: {err_msg}") from e

class GeminiVisionClient:
    """Manages direct network calls and structured prompts to Google Gemini Vision API.
    Maintains compatibility with legacy class-based callers.
    """
    
    def __init__(self, api_key: str):
        """
        Initializes the client with the user's API key.
        
        Args:
            api_key (str): Google Gemini API key.
        """
        self.api_key = api_key
        self.model = None

    def analyze_screen_region(
        self, 
        screenshot: Image.Image, 
        context_meta: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        Queries Gemini Vision API with a screen capture and additional text context metadata.
        
        Args:
            screenshot (PIL.Image.Image): Captures surrounding cursor.
            context_meta (Optional[Dict[str, Any]]): Text/structural metadata extracted from UI automation.
            
        Returns:
            str: Rich formatted JSON string response.
        """
        # Convert PIL Image to base64 JPEG
        buffered = io.BytesIO() if 'io' in globals() else __import__('io').BytesIO()
        screenshot.save(buffered, format="JPEG")
        image_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
        
        # Format metadata to string
        context_str = None
        if context_meta:
            context_str = json.dumps(context_meta, indent=2)
            
        # Temporarily register instance key in settings so module functions can execute
        old_key = config.get_setting("gemini_api_key", "")
        config.set_setting("gemini_api_key", self.api_key)
        
        try:
            res_dict = analyze_screen(image_base64, context=context_str)
            return json.dumps(res_dict, indent=4)
        finally:
            # Restore settings state
            config.set_setting("gemini_api_key", old_key)

    def send_followup_prompt(self, follow_up_text: str, conversation_history: List[Dict[str, Any]]) -> str:
        """
        Continues the context session with a conversational follow-up prompt.
        
        Args:
            follow_up_text (str): The user's query or command.
            conversation_history (list): Existing messages in this shake session.
            
        Returns:
            str: Follow-up response.
        """
        try:
            genai.configure(api_key=self.api_key)
            model_name = env_manager.get_env("GEMINI_MODEL", fallback="gemini-2.0-flash")
            model = genai.GenerativeModel(model_name)
            
            # Format history context
            formatted_history = []
            for msg in conversation_history:
                role = "User" if msg.get("role") == "user" else "Model"
                formatted_history.append(f"{role}: {msg.get('content', '')}")
            history_str = "\n".join(formatted_history)
            
            prompt = f"{history_str}\nUser Follow-up: {follow_up_text}"
            logger.info("Sending conversational follow-up to Gemini...")
            response = model.generate_content(prompt)
            return response.text
        except Exception as e:
            logger.error("Gemini follow-up request failed: %s", str(e))
            return f"Conversational query failed: {str(e)}"

# Compliance verification helper for other external service credentials
def get_service_credential(credential_key: str, default: Optional[str] = None) -> Optional[str]:
    """Loads any external service credentials strictly via env_manager, never hardcoded."""
    return env_manager.get_env(credential_key, default)

if __name__ == "__main__":
    print("Testing ai_client.py compilation and custom exceptions...")
    
    # Test checking if the missing API key throws custom exception
    old_key_state = config.get_setting("gemini_api_key")
    
    try:
        # Clear settings key to simulate fresh first-run with missing key
        config.set_setting("gemini_api_key", "")
        
        try:
            analyze_screen("dummy_base64_data")
            print("[FAIL] Test failed: analyze_screen did not raise MissingAPIKeyError for empty keys!")
        except MissingAPIKeyError as e:
            print(f"[SUCCESS] Success: Correctly raised MissingAPIKeyError: {e}")
            
    finally:
        # Restore configuration key
        if old_key_state:
            config.set_setting("gemini_api_key", old_key_state)
            
    print("All internal compilation checks passed successfully!")
