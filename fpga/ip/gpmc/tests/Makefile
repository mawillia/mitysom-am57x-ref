###############################################################################
# Copyright (c) 2013, 2018 Potential Ventures Ltd
# Copyright (c) 2013 SolarFlare Communications Inc
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Potential Ventures Ltd,
#       SolarFlare Communications Inc nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL POTENTIAL VENTURES LTD BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###############################################################################

PWD=$(shell pwd)

export PYTHONPATH := $(PWD)/../cosim:$(PYTHONPATH)

VHDL_SOURCES = $(PWD)/../../common/MitySOM_AM57_pkg.vhd
VHDL_SOURCES += $(PWD)/../GPMC_iface.vhd
VHDL_SOURCES += $(PWD)/../../common/core_version.vhd
VHDL_SOURCES += $(PWD)/../base_module.vhd
VHDL_SOURCES += $(PWD)/../../gpio/gpio.vhd
VHDL_SOURCES += $(PWD)/tb_gpmc_cocotb.vhd
TOPLEVEL = tb_gpmc_cocotb

MODULE := test_gpmc

SIM = ghdl
SIM_ARGS ?= --wave=waveform.ghw

#ifeq ($(OS),Linux)
#    # TODO: work out how to build the extension module on windows
#    MODULE := $(MODULE),test_gpmc
#    CUSTOM_COMPILE_DEPS = hal
#    LD_LIBRARY_PATH := $(PWD)/../cosim:$(LD_LIBRARY_PATH)
#    export LD_LIBRARY_PATH
#endif

include $(shell cocotb-config --makefiles)/Makefile.sim

#ifeq ($(OS),Linux)
#.PHONY: hal
#hal:
#	cd ../cosim && make
#
#clean::
#	-cd ../cosim && make clean
#endif
