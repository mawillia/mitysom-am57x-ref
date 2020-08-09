#
# NOTE:  typical usage would be "vivado -mode tcl -source ./script/build_devkit_bitstream_batch.tcl"
# make sure you have your license file configuration setup.
#
# Define output directory area
set outputDir ./devkit_output
file mkdir $outputDir
#
set_part xc7a15tcsg325-2
#
# setup design sources and constraints
read_vhdl [ glob ./src/hdl/*.vhd ]
read_verilog [ glob ./src/hdl/*.v ]
read_vhdl [ glob ../ip/common/*.vhd ]
read_vhdl [ glob ../ip/gpio/*.vhd ]
read_vhdl [ glob ../ip/gpmc/*.vhd ]
read_xdc [ glob ./src/constraints/*.xdc ]
#
#
read_ip ./ip/clk_wiz_0/clk_wiz_0.xci
generate_target all [get_ips clk_wiz_0]
synth_ip [get_ips clk_wiz_0]
get_files -all -of_objects [get_files ./ip/clk_wiz_0/clk_wiz_0.xci]
#
#
#
read_ip ./ip/pcie_7x_0/pcie_7x_0.xci
generate_target all [get_ips pcie_7x_0]
synth_ip [get_ips pcie_7x_0]
get_files -all -of_objects [get_files /ip/pcie_7x_0/pcie_7x_0.xci]
#
#

#
#
# run synthesis
synth_design -top devkit_top
write_checkpoint -force $outputDir/post_synth
report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_power -file $outputDir/post_synth_power.rpt
#
#
# run placement and logic optimization
opt_design
place_design
phys_opt_design
write_checkpoint -force $outputDir/post_place
report_timing_summary -file $outputDir/post_place_timing_summary.rpt
#
#
# run router
route_design
write_checkpoint -force $outputDir/post_route
report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/post_route_timing.rpt
report_clock_utilization -file $outputDir/clock_util.rpt
report_utilization -file $outputDir/post_route_util.rpt
report_power -file $outputDir/post_route_power.rpt
report_drc -file $outputDir/post_imp_drc.rpt
#write_verilog -force $outputDir/bft_impl_netlist.v
#write_xdc -no_fixed_only -force $outputDir/bft_impl.xdc
#
#
# Generate bitstream and binary file
write_bitstream -force -bin_file $outputDir/devkit.bit
# Generate file for use with uBoot
# TODO unclear if -disablebitswap is required
write_cfgmem -format BIN -size 4 -interface SMAPx16 -loadbit "up 0 $outputDir/devkit.bit" -verbose $outputDir/devkit_fpga_uboot.bin

