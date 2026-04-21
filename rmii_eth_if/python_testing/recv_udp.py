"""
recv_udp.py  –  Listen for UDP packets from the FPGA and print them.

Binds to 0.0.0.0:17767 (HOST_PORT = 0x4567).
The FPGA sends "hello clay" every 10 seconds.

Usage:
  python recv_udp.py
  python recv_udp.py --port 17767
"""

import socket
import argparse
from datetime import datetime

HOST_PORT = 0x4567   # 17767


def main():
    parser = argparse.ArgumentParser(description="UDP listener for FPGA packets")
    parser.add_argument("--port", type=int, default=HOST_PORT,
                        help=f"UDP port to listen on (default: {HOST_PORT})")
    args = parser.parse_args()

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.bind(("0.0.0.0", args.port))
        print(f"Listening on UDP port {args.port} — waiting for FPGA packets...\n")
        while True:
            data, addr = s.recvfrom(4096)
            ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            print(f"[{ts}]  from {addr[0]}:{addr[1]}")
            print(f"  hex : {data.hex()}")
            print(f"  text: {data.decode(errors='replace')}\n")


if __name__ == "__main__":
    main()
