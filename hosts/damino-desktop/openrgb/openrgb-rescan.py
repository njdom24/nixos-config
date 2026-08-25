# Work around RAM not being detected until rescan
import socket
import sys
import time

try:
    from openrgb.network import NetworkClient
except ImportError:
    sys.exit("openrgb-python is required: pip install openrgb-python")

NET_PACKET_ID_REQUEST_RESCAN_DEVICES = 140


def connect_with_retry(host, port, name, timeout=15.0, delay=0.5):
    deadline = time.monotonic() + timeout
    last_err = None
    while time.monotonic() < deadline:
        try:
            return NetworkClient(lambda *_: None, host, port, name)
        except (ConnectionRefusedError, OSError, socket.error) as e:
            last_err = e
            time.sleep(delay)
    msg = f"Could not connect to {host}:{port} after {timeout}s"
    sys.exit(f"{msg}: {last_err}")


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 6742

    client = connect_with_retry(host, port, "openrgb-rescan")
    try:
        client.send_header(0, NET_PACKET_ID_REQUEST_RESCAN_DEVICES, 0)
    finally:
        client.stop_connection()

    print(f"Rescan request sent to {host}:{port}")


if __name__ == "__main__":
    main()
