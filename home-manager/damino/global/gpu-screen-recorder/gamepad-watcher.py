#!/usr/bin/env python3
import ctypes
import time
import subprocess
import sdl2
import sdl2.ext
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Only track Guide + D-Pad Up
WATCH_BUTTONS = [sdl2.SDL_CONTROLLER_BUTTON_GUIDE, sdl2.SDL_CONTROLLER_BUTTON_DPAD_UP]

controller_state = {}

def open_controllers():
    sdl2.SDL_Init(sdl2.SDL_INIT_GAMECONTROLLER)
    controllers = {}
    for i in range(sdl2.SDL_NumJoysticks()):
        if sdl2.SDL_IsGameController(i):
            ctrl = sdl2.SDL_GameControllerOpen(i)
            instance_id = sdl2.SDL_JoystickInstanceID(sdl2.SDL_GameControllerGetJoystick(ctrl))
            name = sdl2.SDL_GameControllerName(ctrl)
            logging.info(f"Controller plugged in: {name.decode()}")
            controllers[instance_id] = {
                "controller": ctrl,
                "pressed": {b: False for b in WATCH_BUTTONS},
                "hold_start": {b: None for b in WATCH_BUTTONS},
                "combo_active": False,   # <-- new flag
            }
    return controllers

def process_events():
    event = sdl2.SDL_Event()
    while sdl2.SDL_PollEvent(ctypes.byref(event)) != 0:
        if event.type == sdl2.SDL_CONTROLLERBUTTONDOWN:
            instance_id = event.cbutton.which
            button = event.cbutton.button
            if instance_id in controller_state and button in WATCH_BUTTONS:
                state = controller_state[instance_id]
                state["pressed"][button] = True
                if state["hold_start"][button] is None:
                    state["hold_start"][button] = time.time()
        elif event.type == sdl2.SDL_CONTROLLERBUTTONUP:
            instance_id = event.cbutton.which
            button = event.cbutton.button
            if instance_id in controller_state and button in WATCH_BUTTONS:
                state = controller_state[instance_id]
                state["pressed"][button] = False
                state["hold_start"][button] = None
                state["combo_active"] = False
        elif event.type == sdl2.SDL_CONTROLLERDEVICEADDED:
            idx = event.cdevice.which
            if sdl2.SDL_IsGameController(idx):
                ctrl = sdl2.SDL_GameControllerOpen(idx)
                instance_id = sdl2.SDL_JoystickInstanceID(sdl2.SDL_GameControllerGetJoystick(ctrl))
                name_ptr = sdl2.SDL_GameControllerName(ctrl)
                name = name_ptr.decode() if name_ptr else f"Controller_{idx}"
                logging.info(f"Controller plugged in: {name}")
                controller_state[instance_id] = {
                    "controller": ctrl,
                    "pressed": {b: False for b in WATCH_BUTTONS},
                    "hold_start": {b: None for b in WATCH_BUTTONS},
                    "combo_active": False,
                }
        elif event.type == sdl2.SDL_CONTROLLERDEVICEREMOVED:
            instance_id = event.cdevice.which
            if instance_id in controller_state:
                ctrl = controller_state[instance_id]["controller"]
                sdl2.SDL_GameControllerClose(ctrl)
                del controller_state[instance_id]
                logging.info(f"Controller unplugged: {instance_id}")


def check_combo():
    now = time.time()
    for state in controller_state.values():
        if all(state["pressed"][b] for b in WATCH_BUTTONS):
            if not state["combo_active"]:
                hold_times = [state["hold_start"][b] for b in WATCH_BUTTONS]
                if all(start and now - start >= 1.0 for start in hold_times):
                    logging.info("Guide + D-Pad Up held for 1s! Triggering pkill...")
                    subprocess.run(["pkill", "-SIGUSR1", "-f", "gpu-screen-recorder"])
                    state["combo_active"] = True
        else:
            state["combo_active"] = False  # reset when any button is released

def main_loop():
    global controller_state
    controller_state = open_controllers()
    try:
        while True:
            process_events()
            check_combo()
            time.sleep(0.01)  # 100 Hz polling
    except KeyboardInterrupt:
        logging.info("Exiting...")
    finally:
        for state in controller_state.values():
            sdl2.SDL_GameControllerClose(state["controller"])
        sdl2.SDL_Quit()

if __name__ == "__main__":
    main_loop()
