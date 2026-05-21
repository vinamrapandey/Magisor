"""
Screen Capture Manager
Handles rapid captures of screen regions centered around the cursor.
"""
import os
import io
import base64
import logging
from typing import Tuple
from PIL import Image, ImageDraw
import mss

# Configure logger
logger = logging.getLogger("magisor.capture")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class ScreenCaptureManager:
    """Captures specific regions of the screen using the fast mss library."""
    
    def __init__(self):
        pass

    def capture_around_cursor(
        self, 
        cursor_x: int, 
        cursor_y: int, 
        width: int = 600, 
        height: int = 400,
        draw_highlight: bool = False
    ) -> Tuple[Image.Image, str]:
        """
        Captures a rectangular region of the screen centered around (cursor_x, cursor_y).
        Handles screen boundary clamping when near the edges.
        
        Args:
            cursor_x (int): Center X coordinate (cursor horizontal coordinate).
            cursor_y (int): Center Y coordinate (cursor vertical coordinate).
            width (int): Bounding box width.
            height (int): Bounding box height.
            draw_highlight (bool): If True, overlays a debug crosshair and highlight box.
            
        Returns:
            Tuple[PIL.Image.Image, str]: A tuple containing:
                a) The captured PIL Image object.
                b) A base64-encoded JPEG string.
        """
        with mss.MSS() as sct:
            # Retrieve global virtual monitor (spanning all screens)
            monitor_info = sct.monitors[0]
            screen_left = monitor_info["left"]
            screen_top = monitor_info["top"]
            screen_width = monitor_info["width"]
            screen_height = monitor_info["height"]
            screen_right = screen_left + screen_width
            screen_bottom = screen_top + screen_height
            
            # Constrain capture box dimensions within full screen limits
            width = min(width, screen_width)
            height = min(height, screen_height)
            
            # Calculate top-left bounds
            left = cursor_x - width // 2
            top = cursor_y - height // 2
            
            # Clamp bounds to remain completely within screen dimensions
            if left < screen_left:
                left = screen_left
            if top < screen_top:
                top = screen_top
            if left + width > screen_right:
                left = screen_right - width
            if top + height > screen_bottom:
                top = screen_bottom - height
                
            monitor = {"left": int(left), "top": int(top), "width": int(width), "height": int(height)}
            
            # Perform high-speed screen grab
            logger.info("Grabbing screen region: %s", monitor)
            sct_img = sct.grab(monitor)
            
            # Convert mss RawImage to PIL Image
            img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
            
            # Optionally draw debug cursor highlight
            if draw_highlight:
                rel_x = cursor_x - left
                rel_y = cursor_y - top
                img = self.draw_debug_highlight(img, rel_x, rel_y)
                
            # Convert PIL image to base64 JPEG string
            buffered = io.BytesIO()
            img.save(buffered, format="JPEG", quality=85)
            img_bytes = buffered.getvalue()
            b64_str = base64.b64encode(img_bytes).decode("utf-8")
            
            return img, b64_str

    def draw_debug_highlight(self, img: Image.Image, rel_x: int, rel_y: int) -> Image.Image:
        """
        Draws a neon highlight border around the region and places a target crosshair
        at the exact relative cursor coordinate to help with debugging.
        
        Args:
            img (PIL.Image.Image): Captured region image.
            rel_x (int): Relative X coordinate of the cursor inside the image.
            rel_y (int): Relative Y coordinate of the cursor inside the image.
            
        Returns:
            PIL.Image.Image: Highlighted copy of the image.
        """
        debug_img = img.copy()
        draw = ImageDraw.Draw(debug_img)
        w, h = debug_img.size
        
        # 1. Neon violet outer border highlight
        draw.rectangle([0, 0, w - 1, h - 1], outline="#8b5cf6", width=4)
        
        # 2. Red glowing target crosshair at relative cursor pos
        draw.line([rel_x - 15, rel_y, rel_x + 15, rel_y], fill="#ef4444", width=2)
        draw.line([rel_x, rel_y - 15, rel_x, rel_y + 15], fill="#ef4444", width=2)
        
        # 3. Inner target circle
        draw.ellipse([rel_x - 6, rel_y - 6, rel_x + 6, rel_y + 6], outline="#ffffff", width=1)
        
        return debug_img

if __name__ == "__main__":
    import sys
    print("Testing ScreenCaptureManager...")
    
    # Initialize and perform a test grab centered in typical coordinates
    manager = ScreenCaptureManager()
    
    # Draw at center of monitor 1 or 500,500
    test_x, test_y = 500, 500
    print(f"Performing test capture of 600x400 region around ({test_x}, {test_y})...")
    
    pil_img, b64_jpeg = manager.capture_around_cursor(
        test_x, test_y, width=600, height=400, draw_highlight=True
    )
    
    # Resolve assets output path
    project_root = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(project_root, "assets")
    os.makedirs(assets_dir, exist_ok=True)
    
    output_path = os.path.join(assets_dir, "test_capture.jpg")
    pil_img.save(output_path, "JPEG")
    
    print(f"Successfully saved test capture image with debug highlights to: {output_path}")
    print(f"Base64 JPEG string prefix (first 100 chars): {b64_jpeg[:100]}...")
