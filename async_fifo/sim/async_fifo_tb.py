import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer, ReadOnly, First

async def full_reset(dut):
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_rst_n.value = 0
    dut.rd_rst_n.value = 0
    await Timer(50, unit="ns")
    dut.wr_rst_n.value = 1
    dut.rd_rst_n.value = 1
    await Timer(50, unit="ns")
    dut._log.info("RSTs: wr=%s, rd=%s", dut.wr_rst_n.value, dut.rd_rst_n.value)

async def empty_check(dut):
    assert dut.empty.value == 1, f"empty = {dut.empty.value}"

async def ptr_dump(dut):
   dut._log.info("ptrs: wr=%s wr_gray=%s rd=%s rd_gray=%s", dut.wr_ptr.value, dut.wr_ptr_gray.value, dut.rd_ptr.value, dut.rd_ptr_gray.value)
@cocotb.test()
async def async_fifo_tb(dut):
    
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 5, unit="ns").start())
    await full_reset(dut)
    await Timer(50, unit="ns")
    await ptr_dump(dut)
    await Timer(50, unit="ns")
    await empty_check(dut)
