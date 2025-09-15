import evdev
import asyncio
import signal
import os
import subprocess
import time

DEVICES = {}  # path -> device
PRESS_TASKS = {}

async def monitor_gamepad(dev):
    pressed_state = {
        evdev.ecodes.BTN_MODE: False,
        'dpad_up': False  # track separately
    }
    try:
        combo_active = False
        combo_start_time = None
        hold_duration = 1.0  # seconds
        async for event in dev.async_read_loop():
            if event.type == evdev.ecodes.EV_KEY and event.code == evdev.ecodes.BTN_MODE:
                pressed_state[evdev.ecodes.BTN_MODE] = bool(event.value)
            elif event.type == evdev.ecodes.EV_ABS and event.code == evdev.ecodes.ABS_HAT0Y:
                pressed_state['dpad_up'] = (event.value == -1)
            
            # check if combo is active
            if pressed_state[evdev.ecodes.BTN_MODE] and pressed_state['dpad_up']:
                if combo_start_time is None:
                    combo_start_time = time.monotonic()  # start timer
                elif not combo_active and (time.monotonic() - combo_start_time) >= hold_duration:
                    combo_active = True
                    print("Home + D-Pad Up held for 1s!")
                    subprocess.run([ "pkill", "-SIGUSR1", "-f", "gpu-screen-recorder" ])
            else:
                # Reset timer and combo state when released
                combo_start_time = None
                combo_active = False
    except OSError:
        print(f"Device disconnected: {dev.name} at {dev.path}")

def find_gamepads():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    gamepads = []
    for dev in devices:
        if 'Wireless Controller' in dev.name or 'Gamepad' in dev.name:
            gamepads.append(dev)
    return gamepads

async def main_loop():
    global DEVICES
    while True:
        current_paths = {dev.path for dev in find_gamepads()}

        # Handle new devices
        for path in current_paths - DEVICES.keys():
            dev = evdev.InputDevice(path)
            DEVICES[path] = dev
            print(f"Added {dev.name} at {dev.path}")
            asyncio.create_task(monitor_gamepad(dev))

        # Handle disconnected devices (don't kill the monitor task)
        for path in list(DEVICES.keys()):
            if path not in current_paths:
                dev = DEVICES.pop(path)
                print(f"Removed {dev.name} at {dev.path}")
                try:
                    dev.close()
                except Exception:
                    pass

        await asyncio.sleep(1)  # scan frequency

def exit_now(signum, frame):
    print("Exiting…")
    os._exit(0)  # immediate exit, avoids InputDevice.__del__ spam

signal.signal(signal.SIGINT, exit_now)
signal.signal(signal.SIGTERM, exit_now)

asyncio.run(main_loop())
