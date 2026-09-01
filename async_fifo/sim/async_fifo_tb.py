import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer, ReadOnly, First

WR_CLK = 10
RD_CLK = 5

async def full_reset(dut):
    dut.wr_en.value    = 0
    dut.rd_en.value    = 0
    dut.wr_rst_n.value = 0
    dut.rd_rst_n.value = 0
    await Timer(20, unit="ns")
    dut.wr_rst_n.value = 1
    dut.rd_rst_n.value = 1
    await RisingEdge(dut.wr_clk)
    await empty_check(dut)
    await not_full_check(dut)

async def empty_check(dut):
    assert dut.empty.value == 1, f"empty = {dut.empty.value}"

async def full_check(dut):
    assert dut.full.value == 1, f"full = {dut.full.value}"

async def not_empty_check(dut):
    assert dut.empty.value == 0, f"empty = {dut.empty.value}"

async def not_full_check(dut):
    assert dut.full.value == 0, f"full = {dut.full.value}"

async def ptr_dump(dut):
   cocotb.log.info("ptrs: wr=%s wr_gray=%s rd=%s rd_gray=%s", dut.wr_ptr.value, dut.wr_ptr_gray.value, dut.rd_ptr.value, dut.rd_ptr_gray.value)

async def init(dut):
    cocotb.start_soon(Clock(dut.wr_clk, WR_CLK, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, RD_CLK, unit="ns").start())
    await full_reset(dut)

async def write_word(dut, word): 
    dut.wr_en.value = 1
    dut.wr_data.value = word
    await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0

async def read_word(dut): 
    dut.rd_en.value = 1
    await RisingEdge(dut.rd_clk)
    rd_data = dut.rd_data.value
    dut.rd_en.value = 0
    return rd_data

@cocotb.test()
async def init_test(dut):
    await init(dut)
    await Timer(50, unit="ns")

@cocotb.test()
async def full_test(dut):
    await init(dut)
    await Timer(50, unit="ns")
    assert dut.ae.value == 0, f"almost empty is = {dut.ae.value}"
    for _ in range(32):
        await write_word(dut, 0xA5A5A5A5)
    await RisingEdge(dut.wr_clk)
    await full_check(dut)

@cocotb.test()
async def empty_test(dut):
    await init(dut)
    await Timer(50, unit="ns")
    assert dut.ae.value == 0, f"almost empty is = {dut.ae.value}"
    for _ in range(32):
        await write_word(dut, 0xA5A5A5A5)
    for _ in range(32):
        await read_word(dut)
    await RisingEdge(dut.rd_clk)
    await empty_check(dut)

@cocotb.test()
async def almost_full_test(dut):
    await init(dut)
    await Timer(50, unit="ns")
    assert dut.ae.value == 0, f"almost empty is = {dut.ae.value}"
    for i in range(32):
        await write_word(dut, 0xA5A5A5A5)
        # cocotb.log.info("ae %d: af=%d", dut.ae.value, dut.af.value)
    await RisingEdge(dut.wr_clk)
    # cocotb.log.info("ae %d: af=%d", dut.ae.value, dut.af.value)
    assert dut.af.value == 1, f"almost full is = {dut.af.value}"

@cocotb.test()
async def almost_empty_test(dut):
    await init(dut)
    await Timer(50, unit="ns")
    assert dut.ae.value == 0, f"almost empty is = {dut.ae.value}"
    for _ in range(32):
        await write_word(dut, 0xA5A5A5A5)
    for _ in range(31):
        await read_word(dut)
    await RisingEdge(dut.wr_clk)
    await not_full_check(dut)
    assert dut.ae.value == 1, f"almost empty is = {dut.ae.value}"