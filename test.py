# import cocotb libraries
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

# variables
CLK_PERIOD = 10

# test function
@cocotb.test()
async def test(dut):
    # init the signals
    dut.clk.value       = 0
    dut.rst.value       = 1
    dut.start.value     = 0
    dut.plaintext.value = 0
    dut.userkey.value   = 0

    # start clock
    clk = Clock(dut.clk, 10, 'ns')   # 10 ns = 100MHz
    await cocotb.start(clk.start())

    # wait for 2 clock periods before putting reset down
    await Timer(2*CLK_PERIOD, 'ns')
    dut.rst.value = 0

    # wait again for 2 clockcycles before starting
    await Timer(2*CLK_PERIOD, 'ns')
    dut.start.value     = 1
    dut.plaintext.value = 0xe28336f5_9e6623df_d2c97f5f_7630f5a2
    dut.userkey.value   = 0x6a84d95d_1bc483f1_d5cccca1_e12d2951_e5c7bcda_2ca8c9c6_01ecef2b_1cc7c433

    # wait until dut is busy to put start signal down
    await RisingEdge(dut.busy)
    await RisingEdge(dut.clk)
    dut.start.value     = 0
    dut.plaintext.value = 0
    dut.userkey.value   = 0

    # wait until ancryption is finished
    await FallingEdge(dut.busy)
    await Timer(4*CLK_PERIOD, 'ns')

    """NO assertion is tested. This testbench is purely visually used to verify the functions."""