"""
Global Mouse Hook and Shake Detection Engine
Monitors cursor movement globally to trigger screenshot/AI overlay when shaken.
"""
import time
import logging
from typing import Callable, Optional, List
from pynput import mouse

import config

# Configure logger
logger = logging.getLogger("magisor.mouse_hook")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

class MouseHookEngine:
    """
    Globally hooks the mouse system and calculates cursor movement speed
    to detect a rapid horizontal "shake" gesture.
    """
    
    def __init__(self, on_shake_callback: Callable[[int, int], None]):
        """
        Initializes the shake detector.
        
        Args:
            on_shake_callback (Callable[[int, int], None]): Function to trigger when a shake is detected.
        """
        self.on_shake_callback = on_shake_callback
        self.listener: Optional[mouse.Listener] = None
        self.is_running = False
        
        # State tracking parameters
        self.reversals: List[float] = []
        self.current_direction: Optional[int] = None # 1 = Right, -1 = Left
        self.last_peak_x: Optional[int] = None
        self.last_trigger_time: float = 0.0

    def start(self) -> None:
        """Starts the global mouse hooking listener asynchronously."""
        if self.is_running:
            return
            
        self.is_running = True
        self.reversals = []
        self.current_direction = None
        self.last_peak_x = None
        self.last_trigger_time = 0.0
        
        logger.info("Starting global mouse hook engine...")
        self.listener = mouse.Listener(on_move=self._on_move)
        self.listener.start()

    def stop(self) -> None:
        """Stops the global mouse hooking listener."""
        if not self.is_running:
            return
            
        self.is_running = False
        if self.listener:
            self.listener.stop()
            self.listener = None
        logger.info("Stopped global mouse hook engine.")

    def _on_move(self, x: int, y: int) -> None:
        """
        Internal callback for mouse moves. Tracks velocity, direction shifts,
        and temporal frequency to identify a global left-right shake gesture.
        
        Args:
            x (int): Cursor X position.
            y (int): Cursor Y position.
        """
        if not self.is_running:
            return
            
        now = time.time()
        
        # Cooldown enforcement (1.5 seconds)
        if now - self.last_trigger_time < 1.5:
            # Reset tracking states during cooldown to prevent buffer accumulation
            self.reversals = []
            self.current_direction = None
            self.last_peak_x = x
            return

        # Fetch sensitivity dynamically from config.py to respect runtime adjustments
        try:
            sensitivity = config.get_setting("shake_sensitivity", "medium")
            if isinstance(sensitivity, str):
                sensitivity = sensitivity.lower()
            else:
                sensitivity = "medium"
        except Exception:
            sensitivity = "medium"
            
        if sensitivity == "low":
            required_reversals = 5
            min_dist = 30
        elif sensitivity == "high":
            required_reversals = 2
            min_dist = 15
        else: # medium / default fallback
            required_reversals = 3
            min_dist = 20

        # Initialize peak reference on very first movement
        if self.last_peak_x is None:
            self.last_peak_x = x
            self.current_direction = None
            return

        # Set initial direction if not yet established
        if self.current_direction is None:
            diff = x - self.last_peak_x
            if abs(diff) >= min_dist:
                self.current_direction = 1 if diff > 0 else -1
                self.last_peak_x = x
            return

        # Peak detection logic to find robust reversals
        if self.current_direction == 1: # Moving Right
            if x > self.last_peak_x:
                self.last_peak_x = x
            elif self.last_peak_x - x >= min_dist:
                # Reversal to Left detected!
                self.current_direction = -1
                self.last_peak_x = x
                self.reversals.append(now)
                self._check_shake(now, required_reversals, x, y)
        else: # Moving Left (self.current_direction == -1)
            if x < self.last_peak_x:
                self.last_peak_x = x
            elif x - self.last_peak_x >= min_dist:
                # Reversal to Right detected!
                self.current_direction = 1
                self.last_peak_x = x
                self.reversals.append(now)
                self._check_shake(now, required_reversals, x, y)

    def _check_shake(self, now: float, required_reversals: int, x: int, y: int) -> None:
        """Helper to trim reversals window and verify if thresholds are crossed."""
        # Retain reversals within the 400ms time window
        self.reversals = [t for t in self.reversals if now - t <= 0.400]
        
        if len(self.reversals) >= required_reversals:
            # Shake event detected!
            self.last_trigger_time = now
            
            # Reset tracking variables immediately to clear buffer
            self.reversals = []
            self.current_direction = None
            self.last_peak_x = x
            
            # Call callback, catching exceptions to keep the background listener alive
            if self.on_shake_callback:
                try:
                    self.on_shake_callback(x, y)
                except TypeError:
                    try:
                        # Fallback for callbacks expecting no arguments
                        self.on_shake_callback() # type: ignore
                    except Exception as e:
                        logger.error("Error executing shake callback: %s", str(e))
                except Exception as e:
                    logger.error("Error executing shake callback: %s", str(e))

if __name__ == "__main__":
    print("Testing MouseHookEngine... Shake your mouse rapidly to trigger shake events.")
    
    def on_shake_detected(x: int, y: int) -> None:
        print(f"SHAKE DETECTED at {x},{y}")
        
    engine = MouseHookEngine(on_shake_callback=on_shake_detected)
    engine.start()
    
    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopping listener...")
        engine.stop()
