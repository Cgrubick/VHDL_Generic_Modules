import cocotb
from cocotb.triggers import FallingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def async_fifo_tb(dut):

    cocotb.start_soon(Clock(dut.wr_clk, 10, units="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 5, units="ns").start())
    await Timer(50, units="ns")
    cocotb.log.info("full is %s", dut.full.value)
    cocotb.log.info("empty is %s", dut.empty.value)
    cocotb.log.info("wr_clk is %s", dut.wr_clk.value)
    await Timer(50, units="ns")
    cocotb.log.info("wr_clk is %s", dut.wr_clk.value)
    await Timer(5, units="ns")
    assert dut.wr_clk.value == 1
    await Timer(5, units="ns")
    assert dut.rd_clk.value == 1
    await Timer(5, units="ns")
    assert dut.rd_clk.value == 1