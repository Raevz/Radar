# ========================================
# File:        radar_display.py
# Description: Receive angle and distance values from FPGA module through UART.
#              Use these values to show a basic radar sweep with the 
#              angle variable controlling an arm that moves across the pitch 
#              and red dots appearing to indicate the distance from the sensor 
#              that is detected.
# Authors:     Yizuo Chen && Ryan McKay && ChatGPT for UART parsing and reading functions
# Date:        April 15, 2025
# ========================================
import serial
import matplotlib.pyplot as plt
import numpy as np
import threading
import time

# === CONFIGURATION ===
SERIAL_PORT = "COM13"
BAUD_RATE = 115200
UPDATE_INTERVAL = 0.05  # 50 ms
MAX_RANGE_CM = 100
FADE_TIME = 2.0  # seconds

# === Detection history ===
history = []
history_lock = threading.Lock()
latest_angle = 0

def parse_uart_line(line):
    try:
        line = line.strip()
        if line.startswith("A") and ",D" in line:
            a_str, d_str = line[1:].split(",D")
            return int(a_str), int(d_str)
    except Exception as e:
        print("Parse error:", e)
    return None, None

def uart_reader_thread():
    global history, latest_angle
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"[INFO] Connected to {SERIAL_PORT} at {BAUD_RATE} baud")
    except serial.SerialException as e:
        print(f"[ERROR] Could not open {SERIAL_PORT}: {e}")
        return

    while True:
        line = ser.readline().decode(errors='ignore')
        angle, dist = parse_uart_line(line)
        if angle is not None and dist is not None:
            timestamp = time.time()
            with history_lock:
                history.append((angle, dist, timestamp))
                latest_angle = angle

def radar_plot():
    global latest_angle
    plt.ion()
    fig, ax = plt.subplots(figsize=(8, 4), subplot_kw={'projection': 'polar'})

    ax.set_theta_zero_location('W')   # 0° on the left
    ax.set_theta_direction(1)         # Counter-clockwise sweep
    ax.set_rlim(0, MAX_RANGE_CM)
    ax.set_title("Heartbeat Radar (1m, L→R)", fontsize=14)

    scatter = ax.scatter([], [], c='red', s=40, alpha=1.0)
    sweep_line, = ax.plot([], [], 'g-', linewidth=2)

    while True:
        now = time.time()
        points = []
        alphas = []

        with history_lock:
            # Prune old detections
            history[:] = [(a, d, t) for (a, d, t) in history if now - t <= FADE_TIME]
            for angle, dist, t in history:
                age = now - t
                fade = max(0.0, 1.0 - age / FADE_TIME)
                points.append((np.radians(angle), dist))
                alphas.append(fade)

        # Update points
        if points:
            angles_rad, radii = zip(*points)
            scatter.set_offsets(np.c_[angles_rad, radii])
            scatter.set_alpha(alphas)
        else:
            scatter.set_offsets([])

        # Sweep line
        sweep_theta = np.radians(latest_angle)
        sweep_line.set_data([sweep_theta, sweep_theta], [0, MAX_RANGE_CM])

        plt.pause(UPDATE_INTERVAL)

if __name__ == "__main__":
    print("[INFO] Launching radar display...")
    reader = threading.Thread(target=uart_reader_thread, daemon=True)
    reader.start()
    radar_plot()
