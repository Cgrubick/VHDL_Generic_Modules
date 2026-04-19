"""
test_packet_tx.py  –  cocotb testbench for packet_tx.vhd

DUT interface
-------------
  clk             : in  std_logic
  reset_n         : in  std_logic
  S_AXI_S_TVALID  : in  std_logic
  S_AXI_S_TDATA   : in  std_logic_vector(7 downto 0)
  S_AXI_S_TLAST   : in  std_logic
  S_AXI_S_TREADY  : out std_logic
  ETH_TXD         : out std_logic_vector(1 downto 0)   -- RMII 2-bit dibit
  ETH_TXEN        : out std_logic

Operation
---------
Payload bytes are pushed over AXI-Stream into an internal FIFO.  Asserting
TLAST on the last byte triggers a full Ethernet/IP/UDP frame:
  [ 7×0x55 preamble ][ 0xD5 SFD ][ 42-byte header ][ payload ][ 4-byte FCS ]

The RMII output is 2-bit (dibit) per clock, transmitted LSB-first within each byte.

Tests
-----
  test_single_small_packet            –  4-byte payload  DE AD BE EF
  test_back_to_back_packets           –  two 4-byte packets, separated by a short gap
  test_64_byte_payload                –  64-byte payload of 0xA5
  test_tready_backpressure            –  FIFO depth=32; flooding >32 bytes must deassert TREADY
"""

import zlib
import struct
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# ---------------------------------------------------------------------------
# Constants matching ip_defs_pkg.vhd
# ---------------------------------------------------------------------------
HOST_MAC  = bytes([0x10, 0xFF, 0xE0, 0xB4, 0x93, 0xAF])  # 10:ff:e0:b4:93:af
FPGA_MAC  = bytes([0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3])
FPGA_IP   = bytes([0x0A, 0x00, 0x00, 0x51])   # 10.0.0.81
HOST_IP   = bytes([0x0A, 0x00, 0x00, 0x50])   # 10.0.0.80
FPGA_PORT = 0x4567
HOST_PORT = 0x4567

CLK_PERIOD_NS = 20   # 50 MHz

# CRC-32 magic residue: feeding (header + payload + FCS) through CRC with
# init=0xFFFFFFFF, no final XOR, poly=0xEDB88320 always yields this value.
CRC_RESIDUE = 0x2144DF1C

# ---------------------------------------------------------------------------
# CRC helper  (matches crc_gen.vhd: poly=0xEDB88320, init=0xFFFFFFFF, no XOR)
# ---------------------------------------------------------------------------
def crc32_no_xor(data: bytes) -> int:
    return zlib.crc32(data, 0xFFFFFFFF) & 0xFFFFFFFF


# ---------------------------------------------------------------------------
# Expected fixed header (42 bytes)
# ---------------------------------------------------------------------------
def _build_header() -> bytes:
    eth = HOST_MAC + FPGA_MAC + b'\x08\x00'                   # 14 bytes
    ip  = bytes([
        0x45, 0x00,        # version/IHL, DSCP/ECN
        0x00, 0x5C,        # total length = 92
        0x00, 0x00,        # identification
        0x40, 0x00,        # flags: don't fragment
        0x40, 0x11,        # TTL=64, protocol=UDP
        0x00, 0x00,        # header checksum (disabled)
    ]) + FPGA_IP + HOST_IP                                     # 20 bytes
    udp = struct.pack('>HHHH',
        FPGA_PORT, HOST_PORT,
        0x0048,            # UDP length = 8 + 64
        0x0000)            # checksum disabled                 # 8 bytes
    return eth + ip + udp  # 42 bytes

EXPECTED_HEADER = _build_header()


# ---------------------------------------------------------------------------
# Reset helper
# ---------------------------------------------------------------------------
async def reset_dut(dut, cycles: int = 5):
    dut.reset_n.value        = 0
    dut.S_AXI_S_TVALID.value = 0
    dut.S_AXI_S_TDATA.value  = 0
    dut.S_AXI_S_TLAST.value  = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)


# ---------------------------------------------------------------------------
# AXI-Stream driver
# ---------------------------------------------------------------------------
async def axi_send_byte(dut, byte: int, last: bool = False):
    """Drive one byte onto the AXI-Stream slave port; waits for TREADY."""
    dut.S_AXI_S_TDATA.value  = byte
    dut.S_AXI_S_TVALID.value = 1
    dut.S_AXI_S_TLAST.value  = 1 if last else 0
    while True:
        await RisingEdge(dut.clk)
        if int(dut.S_AXI_S_TREADY.value) == 1:
            break
    dut.S_AXI_S_TVALID.value = 0
    dut.S_AXI_S_TLAST.value  = 0


async def axi_send_packet(dut, payload: bytes):
    """Stream all payload bytes over AXI-S; TLAST asserted on the last byte."""
    for i, b in enumerate(payload):
        await axi_send_byte(dut, b, last=(i == len(payload) - 1))


# ---------------------------------------------------------------------------
# RMII frame collector
# ---------------------------------------------------------------------------
async def collect_frame(dut, timeout_clocks: int = 1500):
    """
    Waits for ETH_TXEN to assert, samples dibits until it deasserts,
    reassembles bytes (LSB-first, 4 dibits/byte), strips preamble/SFD.

    Returns:
        preamble_ok  (bool)  – at least 7 × 0x55 bytes seen before SFD
        sfd_ok       (bool)  – 0xD5 SFD byte found
        frame_bytes  (bytes) – everything after SFD (header + payload + FCS)
    """
    # Wait for TXEN to go high
    for _ in range(timeout_clocks):
        await RisingEdge(dut.clk)
        if int(dut.ETH_TXEN.value) == 1:
            break
    else:
        raise AssertionError("Timed out waiting for ETH_TXEN to assert")

    # Sample dibits while TXEN is high
    dibits = []
    while int(dut.ETH_TXEN.value) == 1:
        dibits.append(int(dut.ETH_TXD.value) & 0x3)
        await RisingEdge(dut.clk)

    if len(dibits) % 4 != 0:
        raise AssertionError(
            f"Non-byte-aligned dibit count ({len(dibits)}); "
            f"last few dibits: {dibits[-8:]}")

    # Reassemble bytes LSB-first
    raw = []
    for i in range(0, len(dibits), 4):
        b  =  dibits[i]
        b |=  dibits[i+1] << 2
        b |=  dibits[i+2] << 4
        b |=  dibits[i+3] << 6
        raw.append(b)

    # Parse preamble (7 × 0x55) and SFD (0xD5)
    preamble_cnt = 0
    sfd_idx      = None
    for idx, b in enumerate(raw):
        if b == 0x55:
            preamble_cnt += 1
        elif b == 0xD5:
            sfd_idx = idx
            break
        else:
            break  # unexpected byte in preamble region

    preamble_ok = preamble_cnt >= 7
    sfd_ok      = sfd_idx is not None

    frame_bytes = bytes(raw[sfd_idx + 1:]) if sfd_ok else b''
    return preamble_ok, sfd_ok, frame_bytes


# ---------------------------------------------------------------------------
# Frame verifier
# ---------------------------------------------------------------------------
def verify_frame(frame_bytes: bytes, payload: bytes, label: str):
    """
    Check a captured post-SFD frame (header + payload + FCS).
    Returns a list of error strings; empty == all checks passed.
    """
    errors = []
    expected_len = len(EXPECTED_HEADER) + len(payload) + 4
    if len(frame_bytes) != expected_len:
        errors.append(
            f"{label}: byte count {len(frame_bytes)}, expected {expected_len}")
        return errors  # length wrong – skip further checks

    rx_header  = frame_bytes[:42]
    rx_payload = frame_bytes[42 : 42 + len(payload)]

    # Header field checks
    if rx_header != EXPECTED_HEADER:
        for i, (exp, got) in enumerate(zip(EXPECTED_HEADER, rx_header)):
            if exp != got:
                errors.append(
                    f"{label}: header byte[{i}] = 0x{got:02X}, expected 0x{exp:02X}")

    # Payload check
    if bytes(rx_payload) != bytes(payload):
        errors.append(
            f"{label}: payload mismatch\n"
            f"  expected: {bytes(payload).hex()}\n"
            f"  received: {bytes(rx_payload).hex()}")

    # FCS residue check
    residue = crc32_no_xor(frame_bytes)
    if residue != CRC_RESIDUE:
        errors.append(
            f"{label}: FCS residue 0x{residue:08X}, expected 0x{CRC_RESIDUE:08X}")

    return errors


# ---------------------------------------------------------------------------
# Test 1 – single small packet
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_single_small_packet(dut):
    """4-byte payload DE AD BE EF: verify preamble, SFD, header, payload, FCS."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    PAYLOAD = bytes([0xDE, 0xAD, 0xBE, 0xEF])

    # Start collector before driving AXI-S (frame won't appear for hundreds of clocks)
    frame_task = cocotb.start_soon(collect_frame(dut, timeout_clocks=1500))
    await axi_send_packet(dut, PAYLOAD)
    preamble_ok, sfd_ok, frame_bytes = await frame_task

    assert preamble_ok, "Preamble (≥7 × 0x55) not detected"
    assert sfd_ok,      "SFD byte 0xD5 not detected"

    errors = verify_frame(frame_bytes, PAYLOAD, "test_single_small_packet")
    assert not errors, "\n".join(errors)

    dut._log.info("PASS — %d bytes after SFD", len(frame_bytes))


# ---------------------------------------------------------------------------
# Test 2 – back-to-back packets
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_back_to_back_packets(dut):
    """Two consecutive 4-byte packets: both frames must be valid."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    PAYLOAD = bytes([0xDE, 0xAD, 0xBE, 0xEF])

    async def send_two():
        await axi_send_packet(dut, PAYLOAD)
        for _ in range(4):
            await RisingEdge(dut.clk)
        await axi_send_packet(dut, PAYLOAD)

    async def collect_two():
        results = []
        for _ in range(2):
            r = await collect_frame(dut, timeout_clocks=2000)
            results.append(r)
        return results

    send_task    = cocotb.start_soon(send_two())
    collect_task = cocotb.start_soon(collect_two())

    await send_task
    results = await collect_task

    for idx, (preamble_ok, sfd_ok, frame_bytes) in enumerate(results):
        label = f"test_back_to_back_packets[frame {idx}]"
        assert preamble_ok, f"{label}: preamble not detected"
        assert sfd_ok,      f"{label}: SFD not detected"
        errors = verify_frame(frame_bytes, PAYLOAD, label)
        assert not errors, "\n".join(errors)
        dut._log.info("%s PASS — %d bytes", label, len(frame_bytes))


# ---------------------------------------------------------------------------
# Test 3 – 64-byte payload
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_64_byte_payload(dut):
    """64-byte payload of 0xA5: verify frame structure and FCS."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    PAYLOAD = bytes([0xA5] * 64)

    frame_task = cocotb.start_soon(collect_frame(dut, timeout_clocks=1500))
    await axi_send_packet(dut, PAYLOAD)
    preamble_ok, sfd_ok, frame_bytes = await frame_task

    assert preamble_ok, "Preamble not detected"
    assert sfd_ok,      "SFD not detected"

    errors = verify_frame(frame_bytes, PAYLOAD, "test_64_byte_payload")
    assert not errors, "\n".join(errors)

    dut._log.info("PASS — %d bytes after SFD", len(frame_bytes))


# ---------------------------------------------------------------------------
# Test 4 – TREADY backpressure when FIFO fills
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_tready_backpressure(dut):
    """
    Drive more than 32 bytes (FIFO depth) without TLAST so the FIFO cannot
    drain.  TREADY must deassert before 40 bytes are offered.
    """
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    saw_not_ready = False
    for i in range(40):
        dut.S_AXI_S_TDATA.value  = i & 0xFF
        dut.S_AXI_S_TVALID.value = 1
        dut.S_AXI_S_TLAST.value  = 0
        await RisingEdge(dut.clk)
        if int(dut.S_AXI_S_TREADY.value) == 0:
            saw_not_ready = True
            dut._log.info("TREADY deasserted after %d bytes", i + 1)
            break

    dut.S_AXI_S_TVALID.value = 0

    assert saw_not_ready, \
        "TREADY never deasserted after 40 bytes — FIFO backpressure not working"
    dut._log.info("PASS — FIFO backpressure verified")
