"""
send_udp.py  –  Send UDP packets to the FPGA.

Addresses match ip_defs_pkg.vhd:
  FPGA IP   : 192.168.1.100
  FPGA port : 0x4567 (17767)

Usage:
  python send_udp.py                        # sends one default message
  python send_udp.py "hello fpga"           # custom message string
  python send_udp.py --count 5              # send 5 packets
  python send_udp.py --hex DEADBEEF         # send raw hex bytes
"""

import socket
import argparse
import time

FPGA_IP   = "10.0.0.81"
FPGA_PORT = 0x4567   # 17767


def send(data: bytes, host: str = FPGA_IP, port: int = FPGA_PORT):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.sendto(data, (host, port))
        print(f"  -> {host}:{port}  [{len(data)} bytes]  {data.hex()}")


def main():
    parser = argparse.ArgumentParser(description="Send UDP packets to the FPGA")
    parser.add_argument("message", nargs="?", default="hello fpga",
                        help="ASCII message to send (default: 'hello fpga')")
    parser.add_argument("--hex", metavar="HEX",
                        help="Send raw hex bytes instead of ASCII (e.g. DEADBEEF)")
    parser.add_argument("--count", type=int, default=1,
                        help="Number of packets to send (default: 1)")
    parser.add_argument("--delay", type=float, default=0.0,
                        help="Seconds between packets (default: 0)")
    parser.add_argument("--ip", default=FPGA_IP,
                        help=f"FPGA IP address (default: {FPGA_IP})")
    parser.add_argument("--port", type=int, default=FPGA_PORT,
                        help=f"FPGA UDP port (default: {FPGA_PORT})")
    args = parser.parse_args()

    if args.hex:
        data = bytes.fromhex(args.hex)
    else:
        data = args.message.encode()

    print(f"Sending {args.count} packet(s) to {args.ip}:{args.port}")
    for i in range(args.count):
        send(data, args.ip, args.port)
        if args.delay and i < args.count - 1:
            time.sleep(args.delay)


if __name__ == "__main__":
    main()
