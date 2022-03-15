# TOP LEVEL CONFIGURATION
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]

#########################################################
# RESET INTERFACE (NOTE This is on Bank 34, you may need to adjust it)
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
#This net is actively driven on the SOM
#set_property PULLUP true [get_ports sys_rst_n]

#########################################################
# GPMC interface

# standards
set_property IOSTANDARD LVCMOS18 [get_ports i_gpmc_cs_n]
#set_property IOSTANDARD LVCMOS18 [get_ports i_gpmc_adv_n]
set_property IOSTANDARD LVCMOS18 [get_ports i_gpmc_oe_n]
set_property IOSTANDARD LVCMOS18 [get_ports i_gpmc_we_n]
set_property IOSTANDARD LVCMOS18 [get_ports {i_gpmc_be_n[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {i_gpmc_be_n[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {io_gpmc_ad[15]}]
set_property IOSTANDARD LVCMOS18 [get_ports {o_sys_nirq[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {o_sys_nirq[1]}]
#set_property IOSTANDARD LVCMOS18 [get_ports {i_gpmc_clk}]
# bank 34
set_property IOSTANDARD LVCMOS18 [get_ports o_cpu_nmi_n]
# bank 15
set_property IOSTANDARD LVCMOS18 [get_ports {i_id[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {i_id[1]}]






