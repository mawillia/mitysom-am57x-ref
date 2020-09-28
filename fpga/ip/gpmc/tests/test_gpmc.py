import random
import logging

import cocotb
from gpmc import GPMC

from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.drivers import BitDriver
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.result import TestFailure

class GPMC_TB(object):

	def __init__(self, dut, gpmc_config, debug=False):
		self.dut = dut
		self.gpmc = GPMC(dut, gpmc_config)
		self.scoreboard = Scoreboard(dut)

		# Set verbosity on our various interfaces
		# level = logging.DEBUG if debug else logging.WARNING

	async def reset(self, duration=20):
		self.dut._log.debug("Resetting DUT")


async def run_test(dut):

	cocotb.fork(Clock(dut.gpmc_fclk, 3.759, units='ns').start())
	gpmc_config = { "name"              : "ASYNC, Single Read, A/D mode",
					"TIMOUTENABLE"      : 0,
					"TIMEOUTSTARTVALUE" : 511,
					# GPMC_CONFIG1_
					"WRAPBURST"         : 0,
					"READMULTIPLE"      : 0,
					"READTYPE"          : 0, #async
					"WRITEMULTIPLE"     : 0,
					"WRITETYPE"         : 0, #async
					"CLKACTIVATIONTIME" : 0, # don't care
					"ATTACHEDDEVICEPAGELENGTH" : 0, #don't care
					"WAITREADMONITORING"       : 0, # no wait functionality
					"WAITWRITEMONITORING"      : 0, # no wait functionality
					"WAITMONITORINGTIME"       : 0, # no wait
					"WAITPINSELECT"            : 0, # don't care
					"DEVICESIZE"               : 1, # 16 bit
					"DEVICETYPE"               : 0, # NOR type
					"MUXADDDATA"               : 2, # address and data multiplexed
					"TIMEPARAGRANUALRITY"      : 1, # x2 latencies
					"GPMCFCLKDIVIDER"          : 0, # 266 MHz
					# GPMC_CONFIG_2
					"CSWROFFTIME"              : 16,
					"CSRDOFFTIME"              : 14,
					"CSEXTRADELAY"             : 0,
					"CSONTIME"                 : 0,
					# GPMC_CONFIG_3
					"ADVAADMUXWROFFTIME"       : 0, # don't care
					"ADVAADMUXRDOFFTIME"       : 0, # don't care
					"ADVWROFFTIME"             : 6, # nADV deassertion time from start cycle time for write
					"ADVRDOFFTIME"             : 6, # nADV deassertion time from start cycle time for read
					"ADVEXTRADELAY"            : 0, # don't add half cycles
					"ADVAADMUXONTIME"          : 0, # don't care
					"ADVONTIME"                : 0, # nADV assertion time from start cycle
					# GPMC_CONFIG_4
					"WEOFFTIME"                : 14, # nWE deassertion time from start cycle time
					"WEEXTRADELAY"             : 0,  # no half cycles
					"WEONTIME"                 : 6,  # nWE assertion time
					"OEAADMUXOFFTIME"          : 0,  # don't care
					"OEOFFTIME"                : 14, # nOE deassertion time from start cycle time
					"OEEXTRADELAY"             : 0,  # no half cycles
					"OEAADMUXONTIME"           : 0,  # don't care
					"OEONTIME"                 : 6,  # nOE assertion time from start cycle time
					# GPMC_CONFIG_5
					"PAGEBURSTACCESSTIME"      : 0,  # don't care
					"RDACCESSTIME"             : 11, # delay between start cycle time and first data valid
					"WRCYCLETIME"              : 15, # Total write cycle time
					"RDCYCLETIME"              : 16, # Total read cycle time
					# GPMC_CONFIG_6
					"WRACCESSTIME"             : 0, # don't care (sync mode)
					"WRDATAONADMUXBUS"         : 6,  # don't care (sync mode)
					"CYCLE2CYCLEDELAY"         : 3,  # chip select high pulse delay between successive accesses
					"CYCLE2CYCLESAMECSEN"      : 1,  # chip select high pulse delay between successive accesses
					"CYCLE2CYCLEDIFFCSEN"      : 1,  # chip select high pulse delay between successive accesses
					"BUSTURNAROUND"            : 1,
					# GPMC_CONFIG_7
					"MASKADDRESS"              : 15, # 16 MiB mask
					"CSVALID"                  : 1,  # enable CS
					"BASEADDRESS"              : 1   # use relateive address range -> 0x00000000 ->0x00FFFFFF
					}
	tb = GPMC_TB(dut, gpmc_config)
	tb.gpmc.dump_regs()

	await tb.reset()

	await Timer(2, units='us')

	# Start off any optional coroutines

	# Run the transactions
	FPGA_VERSION_ADDR  = 0x0000000C
	BM_VERSION_ADDR    = 0x00000000
	GPIO_VERSION_ADDR  = 0x00000080

	SCRATCH_RAM_ADDR  = 0x00000040
	SCRATCH_RAM_WORDS = int(0x40 / 2)

	# read fpga version data
	fpga_version_data = []
	for i in range(4):
		fpga_version_data.append(await tb.gpmc.do_read(FPGA_VERSION_ADDR))
	
	# check fpga version number
	if fpga_version_data[0] != 0x00BC:
		raise TestFailure("FPGA Version Data Readback failure at offset {}".format(0))
	if fpga_version_data[1] != 0x5410:
		raise TestFailure("FPGA Version Data Readback failure at offset {}".format(1))
	if fpga_version_data[2] != 0x870C:
		raise TestFailure("FPGA Version Data Readback failure at offset {}".format(2))
	if fpga_version_data[3] != 0xC000:
		raise TestFailure("FPGA Version Data Readback failure at offset {}".format(3))

	# read base module version number of base module at address 0
	bm_version_data = []
	for i in range(4):
		bm_version_data.append(await tb.gpmc.do_read(BM_VERSION_ADDR))
	
	# check base module version number
	if bm_version_data[0] != 0x0000:
		raise TestFailure("BM Version Data Readback failure at offset {}".format(0))
	if bm_version_data[1] != 0x5410:
		raise TestFailure("BM Version Data Readback failure at offset {}".format(1))
	if bm_version_data[2] != 0x8103:
		raise TestFailure("BM Version Data Readback failure at offset {}".format(2))
	if bm_version_data[3] != 0xC000:
		raise TestFailure("BM Version Data Readback failure at offset {}".format(3))

	gpio_version_data = []
	for i in range(4):
		gpio_version_data.append(await tb.gpmc.do_read(GPIO_VERSION_ADDR))
	
	# check GPIO module version number
	if gpio_version_data[0] != 0x0004:
		raise TestFailure("GPIO Version Data Readback failure at offset {}".format(0))
	if gpio_version_data[1] != 0x4B13:
		raise TestFailure("GPIO Version Data Readback failure at offset {}".format(1))
	if gpio_version_data[2] != 0x8608:
		raise TestFailure("GPIO Version Data Readback failure at offset {}".format(2))
	if gpio_version_data[3] != 0xC000:
		raise TestFailure("GPIO Version Data Readback failure at offset {}".format(3))

	# test base module scratch pad (read/write)
	scratch_pat = []
	scratch_read = []

	for i in range(SCRATCH_RAM_WORDS):
		val = i + (i ^ 0x00FF)*256
		scratch_pat.append(val)

	# write the ram
	addr = SCRATCH_RAM_ADDR
	for i in range(SCRATCH_RAM_WORDS):
		await tb.gpmc.do_write(addr, scratch_pat[i])
		# await Timer(100, units='ns')
		addr = addr + 2
	addr = SCRATCH_RAM_ADDR

	# read it back
	for i in range(SCRATCH_RAM_WORDS):
		scratch_read.append(await tb.gpmc.do_read(addr))
		addr = addr + 2

	# check it
	for i in range(SCRATCH_RAM_WORDS):
		if scratch_read[i] != scratch_pat[i]:
			raise TestFailure("Scratch pad data readback failure at offset {}".format(i))

	# Wait at least 2 cycles
	for i in range(100):
		await RisingEdge(dut.gpmc_fclk)

	if False:
		pass
		#raise TestFailure("DUT recorded %d packets but tb counted %d" % (
		#                  pkt_count.integer, tb.pkts_sent))
	else:
		dut._log.info("DUT passed")

	raise tb.scoreboard.result

factory = TestFactory(run_test)
factory.generate_tests()

import cocotb.wavedrom
