import cocotb

from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly

class GPMC(object):

	def __init__(self, dut, config):
		self.dut = dut
		self.config = config
		self.dut.gpmc_clk <= 0
		self.dut.gpmc_cs_n <= 1
		self.dut.gpmc_ad <= cocotb.binary.BinaryValue('ZZZZZZZZZZZZZZZZ')
		self.dut.gpmc_adv_n <= 0
		self.dut.gpmc_oe_n <= 1
		self.dut.gpmc_we_n <= 1
		self.dut.gpmc_be_n <= 3
	
	def dump_regs(self):
		""" Dump Register Settings in HEX """
		# we don't do any bounds checking on the parameters at the moment
		reg = 0
		reg |= (self.config["WRAPBURST"]                << 31)
		reg |= (self.config["READMULTIPLE"]             << 30)
		reg |= (self.config["READTYPE"]                 << 29)
		reg |= (self.config["WRITEMULTIPLE"]            << 28)
		reg |= (self.config["WRITETYPE"]                << 27)
		reg |= (self.config["CLKACTIVATIONTIME"]        << 25)
		reg |= (self.config["ATTACHEDDEVICEPAGELENGTH"] << 23)
		reg |= (self.config["WAITREADMONITORING"]       << 22)
		reg |= (self.config["WAITWRITEMONITORING"]      << 21)
		reg |= (self.config["WAITMONITORINGTIME"]       << 18)
		reg |= (self.config["WAITPINSELECT"]            << 16)
		reg |= (self.config["DEVICESIZE"]               << 12)
		reg |= (self.config["DEVICETYPE"]               << 10)
		reg |= (self.config["MUXADDDATA"]               << 8)
		reg |= (self.config["TIMEPARAGRANUALRITY"]      << 4)
		reg |= (self.config["GPMCFCLKDIVIDER"]          << 0)
		print("GPMC_CONFIG1 = 0x{:08x}".format(reg))
		reg = 0
		reg |= (self.config["CSWROFFTIME"]    << 16)
		reg |= (self.config["CSRDOFFTIME"]    << 8)
		reg |= (self.config["CSEXTRADELAY"]   << 7)
		reg |= (self.config["CSONTIME"]       << 0)
		print("GPMC_CONFIG2 = 0x{:08x}".format(reg))
		reg = 0
		reg |= (self.config["ADVAADMUXWROFFTIME"]  << 28)
		reg |= (self.config["ADVAADMUXRDOFFTIME"]  << 24)
		reg |= (self.config["ADVWROFFTIME"]        << 16)
		reg |= (self.config["ADVRDOFFTIME"]        << 8)
		reg |= (self.config["ADVEXTRADELAY"]       << 7)
		reg |= (self.config["ADVAADMUXONTIME"]     << 4)
		reg |= (self.config["ADVONTIME"]           << 0)
		print("GPMC_CONFIG3 = 0x{:08x}".format(reg))
		reg = 0
		reg |= (self.config["WEOFFTIME"]       << 24)
		reg |= (self.config["WEEXTRADELAY"]    << 23)
		reg |= (self.config["WEONTIME"]        << 16)
		reg |= (self.config["OEAADMUXOFFTIME"] << 13)
		reg |= (self.config["OEOFFTIME"]       << 8)
		reg |= (self.config["OEEXTRADELAY"]    << 7)
		reg |= (self.config["OEAADMUXONTIME"]  << 4)
		reg |= (self.config["OEONTIME"]        << 0)
		print("GPMC_CONFIG4 = 0x{:08x}".format(reg))
		reg = 0
		reg |= (self.config["PAGEBURSTACCESSTIME"] << 24)
		reg |= (self.config["RDACCESSTIME"]        << 16)
		reg |= (self.config["WRCYCLETIME"]         << 8)
		reg |= (self.config["RDCYCLETIME"]         << 0)
		print("GPMC_CONFIG5 = 0x{:08x}".format(reg))
		reg = 0x80000000
		reg |= (self.config["WRACCESSTIME"]         << 24)
		reg |= (self.config["WRDATAONADMUXBUS"]     << 16)
		reg |= (self.config["CYCLE2CYCLEDELAY"]     << 8)
		reg |= (self.config["CYCLE2CYCLESAMECSEN"]  << 7)
		reg |= (self.config["CYCLE2CYCLEDIFFCSEN"]  << 6)
		reg |= (self.config["BUSTURNAROUND"]        << 0)
		print("GPMC_CONFIG6 = 0x{:08x}".format(reg))
		reg = 0
		reg |= (self.config["MASKADDRESS"]          << 8)
		reg |= (self.config["CSVALID"]              << 6)
		reg |= (self.config["BASEADDRESS"]          << 0)
		print("GPMC_CONFIG7 = 0x{:08x}".format(reg))

	async def do_read_cs(self):
		await RisingEdge(self.dut.gpmc_fclk)
		clocks = 0
		# FA9 (CSONTIME * (TimeParaGranularity + 1) + 0.5 * CSExtraDelay) * GPMF_FCLK
		onclock = self.config["CSONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		# FA1 + FA9
		offclock = self.config["CSRDOFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < onclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_cs_n <= 0
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_cs_n <= 1

	async def do_read_ad(self, addr):
		await RisingEdge(self.dut.gpmc_fclk)
		clocks = 0
		# assert Address
		self.dut.gpmc_ad <= ((addr >> 1) & 0xFFFF)
		# FA29 + FA13 + FA37
		offclock = self.config["OEONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_ad <= cocotb.binary.BinaryValue('ZZZZZZZZZZZZZZZZ')
		readclock = self.config["RDACCESSTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < readclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		return self.dut.gpmc_ad.value

	async def do_read_be(self, be_n):
		await RisingEdge(self.dut.gpmc_fclk)
		self.dut.gpmc_be_n <= 0
		clocks = 0
		offclock = self.config["RDCYCLETIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_be_n <= 3

	async def do_read_nadv(self):
		await RisingEdge(self.dut.gpmc_fclk)
		self.dut.gpmc_adv_n <= 1
		clocks = 0
		offclock = self.config["ADVONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_adv_n <= 0
		offclock = self.config["ADVRDOFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_adv_n <= 1
		offclock = self.config["RDCYCLETIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_adv_n <= 0

	async def do_read_noe(self):
		await RisingEdge(self.dut.gpmc_fclk)
		clocks = 0
		onclock = self.config["OEONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < onclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_oe_n <= 0
		offclock = self.config["OEOFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_oe_n <= 1

	async def do_read(self, addr, be_n=0):
		# emulate the ASYNC states given our current config
		read_cs = cocotb.fork(self.do_read_cs())
		read_ad = cocotb.fork(self.do_read_ad(addr))
		read_be = cocotb.fork(self.do_read_be(be_n))
		read_nadv = cocotb.fork(self.do_read_nadv())
		read_noe = cocotb.fork(self.do_read_noe())
		await read_cs
		await read_be
		await read_noe
		await read_nadv
		value = await read_ad
		cycle_delay = self.config["OEOFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		if self.config["CYCLE2CYCLESAMECSEN"] > cycle_delay:
			cycle_delay = self.config["CYCLE2CYCLESAMECSEN"]*(1+self.config["TIMEPARAGRANUALRITY"])
		if self.config["CYCLE2CYCLEDIFFCSEN"] > cycle_delay:
			cycle_delay = self.config["CYCLE2CYCLEDIFFCSEN"]*(1+self.config["TIMEPARAGRANUALRITY"])
		clocks = 0
		while clocks < cycle_delay:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		return value

	async def do_write_cs(self):
		await RisingEdge(self.dut.gpmc_fclk)
		clocks = 0
		# FA9 (CSONTIME * (TimeParaGranularity + 1) + 0.5 * CSExtraDelay) * GPMF_FCLK
		onclock = self.config["CSONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		# FA1 + FA9
		offclock = self.config["CSWROFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < onclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_cs_n <= 0
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_cs_n <= 1

	async def do_write_ad(self, addr, data):
		await RisingEdge(self.dut.gpmc_fclk)
		clocks = 0
		# assert Address
		self.dut.gpmc_ad <= ((addr >> 1) & 0xFFFF)
		# FA29 + FA13 + FA37
		offclock = self.config["WRDATAONADMUXBUS"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			self.dut.gpmc_ad <= ((addr >> 1) & 0xFFFF)
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_ad <= data
		offclock = self.config["WRCYCLETIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_ad <= cocotb.binary.BinaryValue('ZZZZZZZZZZZZZZZZ')

	async def do_write_be(self, be_n):
		await RisingEdge(self.dut.gpmc_fclk)
		self.dut.gpmc_be_n <= be_n
		clocks = 0
		offclock = self.config["WRCYCLETIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_be_n <= 3

	async def do_write_nadv(self):
		await RisingEdge(self.dut.gpmc_fclk)
		self.dut.gpmc_adv_n <= 1
		clocks = 0
		offclock = self.config["ADVONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_adv_n <= 0
		offclock = self.config["ADVWROFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_adv_n <= 1
		offclock = self.config["WRCYCLETIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_adv_n <= 0

	async def do_write_nwe(self):
		await RisingEdge(self.dut.gpmc_fclk)
		clocks = 0
		offclock = self.config["WEONTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_we_n <= 0
		offclock = self.config["WEOFFTIME"]*(1+self.config["TIMEPARAGRANUALRITY"])
		while clocks < offclock:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
		self.dut.gpmc_we_n <= 1

	async def do_write(self, addr, data, be_n=0):
		# emulate the ASYNC states given our current config
		write_cs = cocotb.fork(self.do_write_cs())
		write_ad = cocotb.fork(self.do_write_ad(addr, data))
		write_be = cocotb.fork(self.do_write_be(be_n))
		write_nadv = cocotb.fork(self.do_write_nadv())
		write_nwe = cocotb.fork(self.do_write_nwe())
		await write_be
		await write_nadv
		await write_nwe
		await write_cs
		await write_ad
		cycle_delay = self.config["CYCLE2CYCLEDELAY"]*(1+self.config["TIMEPARAGRANUALRITY"])
		if self.config["CYCLE2CYCLESAMECSEN"]*(1+self.config["TIMEPARAGRANUALRITY"]) > cycle_delay:
			cycle_delay = self.config["CYCLE2CYCLESAMECSEN"]*(1+self.config["TIMEPARAGRANUALRITY"])
		if self.config["CYCLE2CYCLEDIFFCSEN"]*(1+self.config["TIMEPARAGRANUALRITY"]) > cycle_delay:
			cycle_delay = self.config["CYCLE2CYCLEDIFFCSEN"]*(1+self.config["TIMEPARAGRANUALRITY"])
		clocks = 0
		while clocks < cycle_delay:
			await RisingEdge(self.dut.gpmc_fclk)
			clocks = clocks + 1
