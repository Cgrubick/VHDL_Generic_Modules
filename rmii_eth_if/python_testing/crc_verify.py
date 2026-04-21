#!/usr/bin/env python3
"""
crc_verify.py - Compute Ethernet CRC-32 (FCS) for a given frame.
Matches crc_gen.vhd: poly=0xEDB88320, init=0xFFFFFFFF, no final XOR.

Usage:
    Edit the PACKETS list below and run: python crc_verify.py
"""

import zlib

# ── Packet definitions ────────────────────────────────────────────────────────
# Ethernet header (14) + IP header (20) + UDP header (8) + payload.

PACKETS = [
    ("TEST1: DEADBEEF payload", bytes([
        # Ethernet header (14 bytes)
        0xA5, 0xA5, 0xA5, 0xA5, 0xA5, 0xA5,  # dst MAC
        0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3,  # src MAC
        0x08, 0x00,                            # EtherType: IPv4
        # IPv4 header (20 bytes)
        0x45, 0x00,        # version/IHL, DSCP/ECN
        0x00, 0x5C,        # total length: 92
        0x00, 0x00,        # identification
        0x40, 0x00,        # flags/fragment offset
        0x40, 0x11,        # TTL=64, protocol=UDP
        0x00, 0x00,        # header checksum (disabled)
        0xC0, 0xA8, 0x01, 0x64,  # src IP: 192.168.1.100
        0xC0, 0xA8, 0x01, 0x65,  # dst IP: 192.168.1.101
        # UDP header (8 bytes)
        0x45, 0x67,        # src port
        0x45, 0x67,        # dst port
        0x00, 0x48,        # length: 72
        0x00, 0x00,        # checksum (disabled)
        # Payload
        0xDE, 0xAD, 0xBE, 0xEF,
    ])),

    ("TEST3: 64x A5 payload", bytes([
        # Ethernet header (14 bytes)
        0xA5, 0xA5, 0xA5, 0xA5, 0xA5, 0xA5,
        0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3,
        0x08, 0x00,
        # IPv4 header (20 bytes)
        0x45, 0x00,
        0x00, 0x5C,
        0x00, 0x00,
        0x40, 0x00,
        0x40, 0x11,
        0x00, 0x00,
        0xC0, 0xA8, 0x01, 0x64,
        0xC0, 0xA8, 0x01, 0x65,
        # UDP header (8 bytes)
        0x45, 0x67,
        0x45, 0x67,
        0x00, 0x48,
        0x00, 0x00,
        # Payload: 64 x 0xA5
        *([0xA5] * 64),
    ])),
]

# ── CRC functions ─────────────────────────────────────────────────────────────

def crc32_vhdl(data: bytes) -> int:
    """poly=0xEDB88320, init=0xFFFFFFFF, NO final XOR  (matches crc_gen.vhd)."""
    return zlib.crc32(data, 0xFFFFFFFF) & 0xFFFFFFFF

def crc32_ethernet(data: bytes) -> int:
    """Standard IEEE 802.3 FCS: same but with final XOR 0xFFFFFFFF."""
    return (zlib.crc32(data, 0xFFFFFFFF) ^ 0xFFFFFFFF) & 0xFFFFFFFF

def fcs_wire_bytes(crc: int) -> str:
    """CRC as 4 LSB-first wire bytes (matching VHDL shift_right output)."""
    return " ".join(f"{(crc >> (8*i)) & 0xFF:02X}" for i in range(4))

# ── Main ──────────────────────────────────────────────────────────────────────

for name, data in PACKETS:
    vhdl_crc = crc32_vhdl(data)
    eth_crc  = crc32_ethernet(data)
    print(f"{name}")
    print(f"  VHDL crc_out (no final XOR) : 0x{vhdl_crc:08X}  wire: {fcs_wire_bytes(vhdl_crc)}")
    print(f"  Standard Ethernet FCS       : 0x{eth_crc:08X}  wire: {fcs_wire_bytes(eth_crc)}")
    print()
