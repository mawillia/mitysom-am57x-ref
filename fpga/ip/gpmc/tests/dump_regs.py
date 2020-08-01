#!/usr/bin/env python3

from gpmc import GPMC

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
				"TIMEPARAGRANUALRITY"      : 0, # x1 latencies
				"GPMCFCLKDIVIDER"          : 0, # 266 MHz
				# GPMC_CONFIG_2
				"CSWROFFTIME"              : 14,
				"CSRDOFFTIME"              : 16,
				"CSEXTRADELAY"             : 0,
				"CSONTIME"                 : 0,
				# GPMC_CONFIG_3
				"ADVAADMUXWROFFTIME"       : 2, # don't care
				"ADVAADMUXRDOFFTIME"       : 2, # don't care
				"ADVWROFFTIME"             : 6, # nADV deassertion time from start cycle time for write
				"ADVRDOFFTIME"             : 6, # nADV deassertion time from start cycle time for read
				"ADVEXTRADELAY"            : 0, # don't add half cycles
				"ADVAADMUXONTIME"          : 1, # don't care
				"ADVONTIME"                : 0, # nADV assertion time from start cycle
				# GPMC_CONFIG_4
				"WEOFFTIME"                : 14, # nWE deassertion time from start cycle time
				"WEEXTRADELAY"             : 0,  # no half cycles
				"WEONTIME"                 : 6,  # nWE assertion time
				"OEAADMUXOFFTIME"          : 3,  # don't care
				"OEOFFTIME"                : 16, # nOE deassertion time from start cycle time
				"OEEXTRADELAY"             : 0,  # no half cycles
				"OEAADMUXONTIME"           : 1,  # don't care
				"OEONTIME"                 : 6,  # nOE assertion time from start cycle time
				# GPMC_CONFIG_5
				"PAGEBURSTACCESSTIME"      : 1,  # don't care
				"RDACCESSTIME"             : 15, # delay between start cycle time and first data valid
				"WRCYCLETIME"              : 15, # Total write cycle time
				"RDCYCLETIME"              : 17, # Total read cycle time
				# GPMC_CONFIG_6
				"WRACCESSTIME"             : 15, # don't care (sync mode)
				"WRDATAONADMUXBUS"         : 7,  # don't care (sync mode)
				"CYCLE2CYCLEDELAY"         : 3,  # chip select high pulse delay between successive accesses
				"CYCLE2CYCLESAMECSEN"      : 1,  # chip select high pulse delay between successive accesses
				"CYCLE2CYCLEDIFFCSEN"      : 1,  # chip select high pulse delay between successive accesses
				"BUSTURNAROUND"            : 1,
				# GPMC_CONFIG_7
				"MASKADDRESS"              : 15, # 16 MiB mask
				"CSVALID"                  : 1,  # enable CS
				"BASEADDRESS"              : 0   # use relateive address range -> 0x00000000 ->0x00FFFFFF
				}

def dump_regs(config):
	""" Dump Register Settings in HEX """
	# we don't do any bounds checking on the parameters at the moment
	reg = 0
	reg |= (config["WRAPBURST"]                << 31)
	reg |= (config["READMULTIPLE"]             << 30)
	reg |= (config["READTYPE"]                 << 29)
	reg |= (config["WRITEMULTIPLE"]            << 28)
	reg |= (config["WRITETYPE"]                << 27)
	reg |= (config["CLKACTIVATIONTIME"]        << 25)
	reg |= (config["ATTACHEDDEVICEPAGELENGTH"] << 23)
	reg |= (config["WAITREADMONITORING"]       << 22)
	reg |= (config["WAITWRITEMONITORING"]      << 21)
	reg |= (config["WAITMONITORINGTIME"]       << 18)
	reg |= (config["WAITPINSELECT"]            << 16)
	reg |= (config["DEVICESIZE"]               << 12)
	reg |= (config["DEVICETYPE"]               << 10)
	reg |= (config["MUXADDDATA"]               << 8)
	reg |= (config["TIMEPARAGRANUALRITY"]      << 4)
	reg |= (config["GPMCFCLKDIVIDER"]          << 0)
	print("GPMC_CONFIG1 = 0x{:08x}".format(reg))
	reg = 0
	reg |= (config["CSWROFFTIME"]    << 16)
	reg |= (config["CSRDOFFTIME"]    << 8)
	reg |= (config["CSEXTRADELAY"]   << 7)
	reg |= (config["CSONTIME"]       << 0)
	print("GPMC_CONFIG2 = 0x{:08x}".format(reg))
	reg = 0
	reg |= (config["ADVAADMUXWROFFTIME"]  << 28)
	reg |= (config["ADVAADMUXRDOFFTIME"]  << 24)
	reg |= (config["ADVWROFFTIME"]        << 16)
	reg |= (config["ADVRDOFFTIME"]        << 8)
	reg |= (config["ADVEXTRADELAY"]       << 7)
	reg |= (config["ADVAADMUXONTIME"]     << 4)
	reg |= (config["ADVONTIME"]           << 0)
	print("GPMC_CONFIG3 = 0x{:08x}".format(reg))
	reg = 0
	reg |= (config["WEOFFTIME"]       << 24)
	reg |= (config["WEEXTRADELAY"]    << 23)
	reg |= (config["WEONTIME"]        << 16)
	reg |= (config["OEAADMUXOFFTIME"] << 13)
	reg |= (config["OEOFFTIME"]       << 8)
	reg |= (config["OEEXTRADELAY"]    << 7)
	reg |= (config["OEAADMUXONTIME"]  << 4)
	reg |= (config["OEONTIME"]        << 0)
	print("GPMC_CONFIG4 = 0x{:08x}".format(reg))
	reg = 0
	reg |= (config["PAGEBURSTACCESSTIME"] << 24)
	reg |= (config["RDACCESSTIME"]        << 16)
	reg |= (config["WRCYCLETIME"]         << 8)
	reg |= (config["RDCYCLETIME"]         << 0)
	print("GPMC_CONFIG5 = 0x{:08x}".format(reg))
	reg = 0x80000000
	reg |= (config["WRACCESSTIME"]         << 24)
	reg |= (config["WRDATAONADMUXBUS"]     << 16)
	reg |= (config["CYCLE2CYCLEDELAY"]     << 8)
	reg |= (config["CYCLE2CYCLESAMECSEN"]  << 7)
	reg |= (config["CYCLE2CYCLEDIFFCSEN"]  << 6)
	reg |= (config["BUSTURNAROUND"]        << 0)
	print("GPMC_CONFIG6 = 0x{:08x}".format(reg))
	reg = 0
	reg |= (config["MASKADDRESS"]          << 8)
	reg |= (config["CSVALID"]              << 6)
	reg |= (config["BASEADDRESS"]          << 0)
	print("GPMC_CONFIG7 = 0x{:08x}".format(reg))

def dump_uboot_regs(config):
	""" Dump Register Settings for u-boot """
	# we don't do any bounds checking on the parameters at the moment

	def print_reg(reg, shift, comment):
		print("\t({} << {})\t| /* {} {} */".format(config[reg], shift, reg, comment))
	def print_reg2(reg, shift, comment):
		print("\t({} << {})\t  /* {} {} */".format(config[reg], shift, reg, comment))

	print("const u32 gpmc_regs_fpga[GPMC_MAX_REG] = {")

	print("\t// config1")
	print_reg("WRAPBURST", 31, "")
	print_reg("READMULTIPLE", 30, "")
	print_reg("READTYPE", 29, "Async")
	print_reg("WRITEMULTIPLE", 28, "")
	print_reg("WRITETYPE", 27, "Async")
	print_reg("CLKACTIVATIONTIME", 25, "Don't care")
	print_reg("ATTACHEDDEVICEPAGELENGTH", 23, "Don't care")
	print_reg("WAITREADMONITORING", 22, "No wait")
	print_reg("WAITWRITEMONITORING", 21, "No wait")
	print_reg("WAITMONITORINGTIME", 18, "No wait")
	print_reg("WAITPINSELECT", 16, "Don't care")
	print_reg("DEVICESIZE", 12, "16 bit")
	print_reg("DEVICETYPE", 10, "NOR type")
	print_reg("MUXADDDATA", 8, "addr and data multiplexed")
	print_reg("TIMEPARAGRANUALRITY", 4, "x1 latencies")
	print_reg2("GPMCFCLKDIVIDER", 0, "266 MHz")

	print("\t, // config2")
	print_reg("CSWROFFTIME", 16, "")
	print_reg("CSRDOFFTIME", 8, "")
	print_reg("CSEXTRADELAY", 7, "")
	print_reg2("CSONTIME", 0, "")

	print("\t, // config3")
	print_reg("ADVAADMUXWROFFTIME", 28, "Don't care")
	print_reg("ADVAADMUXRDOFFTIME", 24, "Don't care")
	print_reg("ADVWROFFTIME", 16, "nADV deassertion time from start cycle time for write")
	print_reg("ADVRDOFFTIME", 8, "nADV deassertion time from start cycle time for read")
	print_reg("ADVEXTRADELAY", 7, "Don't add half cycles")
	print_reg("ADVAADMUXONTIME", 4, "Don't care")
	print_reg2("ADVONTIME", 0, "nADV assertion time from start cycle")

	print("\t, // config4")
	print_reg("WEOFFTIME", 24, "nWE deassertion time from start cycle time")
	print_reg("WEEXTRADELAY", 23, "No half cycles")
	print_reg("WEONTIME", 16, "nWE assertion time")
	print_reg("OEAADMUXOFFTIME", 13, "Don't care")
	print_reg("OEOFFTIME", 8, "nOE deassertion time from start cycle time")
	print_reg("OEEXTRADELAY", 7, "no half cycles")
	print_reg("OEAADMUXONTIME", 4, "Don't care")
	print_reg2("OEONTIME", 0, "nOE assertion time from start cycle time")

	print("\t, // config5")
	print_reg("PAGEBURSTACCESSTIME", 24, "Don't care")
	print_reg("RDACCESSTIME", 16, "Delay between start cycle time and first data valid")
	print_reg("WRCYCLETIME", 8, "Total write cycle time")
	print_reg2("RDCYCLETIME", 0, "Total read cycle time")

	print("\t, // config6")
	print("\t(1 << 31)\t| /* RESERVED */")
	print_reg("WRACCESSTIME", 24, "Don't care (sync mode)")
	print_reg("WRDATAONADMUXBUS", 16, "Don't care (sync mode)")
	print_reg("CYCLE2CYCLEDELAY", 8, "Chip select high pulse delay between successive accesses")
	print_reg("CYCLE2CYCLESAMECSEN", 7, "Chip select high pulse delay between successive accesses")
	print_reg("CYCLE2CYCLEDIFFCSEN", 6, "Chip select high pulse delay between successive accesses")
	print_reg2("BUSTURNAROUND", 0, "")

	print("\t, // config7")
	print_reg("MASKADDRESS", 8, "16 MiB mask")
	print_reg("CSVALID", 6, "Enable CS")
	print_reg2("BASEADDRESS", 0, "Use relative address range -> 0x00000000 ->0x00FFFFFF")

	print("};")

dump_regs(gpmc_config)
dump_uboot_regs(gpmc_config)
