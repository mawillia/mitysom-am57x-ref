
###################################################
# PCI EXPRESS INTERFACE (see also xilinx_pcie_7x_ep_x2g2.xdc)
# PCIe on clock 0 and data pairs 0/1
set_property LOC GTPE2_CHANNEL_X0Y0 [get_cells {PCIE_DMA_INST/pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property PACKAGE_PIN E3 [get_ports {pci_exp_rxn[1]}]
set_property PACKAGE_PIN E4 [get_ports {pci_exp_rxp[1]}]
set_property PACKAGE_PIN H1 [get_ports {pci_exp_txn[1]}]
set_property PACKAGE_PIN H2 [get_ports {pci_exp_txp[1]}]
set_property LOC GTPE2_CHANNEL_X0Y1 [get_cells {PCIE_DMA_INST/pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property PACKAGE_PIN A3 [get_ports {pci_exp_rxn[0]}]
set_property PACKAGE_PIN A4 [get_ports {pci_exp_rxp[0]}]
set_property PACKAGE_PIN F1 [get_ports {pci_exp_txn[0]}]
set_property PACKAGE_PIN F2 [get_ports {pci_exp_txp[0]}]

set_property PACKAGE_PIN B6 [get_ports sys_clk_p]
set_property PACKAGE_PIN B5 [get_ports sys_clk_n]
set_property PACKAGE_PIN R6 [get_ports sys_rst_n]

# PCIe on clock 1 and data pairs 2/3
#set_property PACKAGE_PIN G3 [get_ports {pci_exp_rxn[0]}]
#set_property PACKAGE_PIN G4 [get_ports {pci_exp_rxp[0]}]
#set_property PACKAGE_PIN B1 [get_ports {pci_exp_txn[0]}]
#set_property PACKAGE_PIN B2 [get_ports {pci_exp_txp[0]}]
#set_property PACKAGE_PIN C3 [get_ports {pci_exp_rxn[1]}]
#set_property PACKAGE_PIN C4 [get_ports {pci_exp_rxp[1]}]
#set_property PACKAGE_PIN D1 [get_ports {pci_exp_txn[1]}]
#set_property PACKAGE_PIN D2 [get_ports {pci_exp_txp[1]}]
#set_property PACKAGE_PIN D5 [get_ports sys_clk_n]
#set_property PACKAGE_PIN D6 [get_ports sys_clk_p]

#########################################################
# GPMC interface
# locations
# CONFIG -> CSI_B
set_property PACKAGE_PIN T17 [get_ports i_gpmc_cs_n]
# CONFIG -> RDWR
set_property PACKAGE_PIN R18 [get_ports i_gpmc_oe_n]
# CONFIG -> CCLK Must be doubled externally
# CONFIG -> EMCCLK
#set_property PACKAGE_PIN P15 [get_ports i_gpmc_clk]
set_property PACKAGE_PIN K18 [get_ports i_gpmc_we_n]
# D0->D16
set_property PACKAGE_PIN K16 [get_ports {io_gpmc_ad[0]}]
set_property PACKAGE_PIN L17 [get_ports {io_gpmc_ad[1]}]
set_property PACKAGE_PIN J15 [get_ports {io_gpmc_ad[2]}]
set_property PACKAGE_PIN J16 [get_ports {io_gpmc_ad[3]}]
set_property PACKAGE_PIN K17 [get_ports {io_gpmc_ad[4]}]
set_property PACKAGE_PIN L18 [get_ports {io_gpmc_ad[5]}]
set_property PACKAGE_PIN J14 [get_ports {io_gpmc_ad[6]}]
set_property PACKAGE_PIN K15 [get_ports {io_gpmc_ad[7]}]
set_property PACKAGE_PIN M15 [get_ports {io_gpmc_ad[8]}]
set_property PACKAGE_PIN M16 [get_ports {io_gpmc_ad[9]}]
set_property PACKAGE_PIN M17 [get_ports {io_gpmc_ad[10]}]
set_property PACKAGE_PIN M14 [get_ports {io_gpmc_ad[11]}]
set_property PACKAGE_PIN N14 [get_ports {io_gpmc_ad[12]}]
set_property PACKAGE_PIN N17 [get_ports {io_gpmc_ad[13]}]
set_property PACKAGE_PIN N18 [get_ports {io_gpmc_ad[14]}]
set_property PACKAGE_PIN P18 [get_ports {io_gpmc_ad[15]}]
#set_property PACKAGE_PIN L15 [get_ports i_gpmc_adv_n]
set_property PACKAGE_PIN N16 [get_ports {i_gpmc_be_n[0]}]
set_property PACKAGE_PIN L14 [get_ports {i_gpmc_be_n[1]}]

# Interrupt interface
set_property PACKAGE_PIN J18 [get_ports {o_sys_nirq[0]}]
set_property PACKAGE_PIN U10 [get_ports {o_sys_nirq[1]}]
set_property PACKAGE_PIN J6 [get_ports o_cpu_nmi_n]

set_property PACKAGE_PIN D10 [get_ports {i_id[0]}]
set_property PACKAGE_PIN H14 [get_ports {i_id[1]}]

# need to migrate these to generic constraints at IP / core level
# register clock crossing, safe, assumed stable before enabling core
set_false_path -from [get_pins {TP_STREAM/s_frame_cnt_reg[*]/C}] -to [get_pins {TP_STREAM/s_frame_cnt_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_num_cols_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_num_cols_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_num_rows_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_num_rows_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_porch_max_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_porch_max_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_static_val_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_static_val_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_data_div_max_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_data_div_max_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_line_porch_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_line_porch_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_passthru_reg/C}] -to [get_pins {TP_STREAM/s_passthru_m_reg/D}]
set_false_path -from [get_pins {TP_STREAM/s_srst_csr_reg/C}] -to [get_pins {TP_STREAM/s_srst_m_reg/D}]
set_false_path -from [get_pins {TP_STREAM/s_tp_type_csr_reg[*]/C}] -to [get_pins {TP_STREAM/s_tp_type_m_reg[*]/D}]
set_false_path -from [get_pins {TP_STREAM/s_en_tp_csr_reg/C}] -to [get_pins {TP_STREAM/s_en_tp_m_reg/D}]

# register clock crossing, safe, assumed stable before reading
set_false_path -from [get_pins {PCIE_STREAMER/s_num_cap_frames_reg_reg[*]/C}] -to [get_pins {PCIE_STREAMER/s_num_cap_frames_reg[*]/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_FIFO_overflow_sticky_data_reg*/C}] -to [get_pins {PCIE_STREAMER/s_FIFO_overflow_sticky_data_reg_reg/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_FIFO_overflow_sticky_data_reg*/C}] -to [get_pins {PCIE_STREAMER/s_FIFO_overflow_sticky_reg_reg/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_FIFO_overflow_sticky_clr_reg_reg*/C}] -to [get_pins {PCIE_STREAMER/s_FIFO_overflow_sticky_clr_data_reg/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_int_status_reg*/C}] -to [get_pins {PCIE_STREAMER/s_int_status_reg_reg/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_axis_state_reg[*]*/C}] -to [get_pins {PCIE_STREAMER/s_axis_state_reg_reg[*]/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_end_addr_reg_reg[*]*/C}] -to [get_pins {PCIE_STREAMER/s_end_addr_reg[*]/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_start_addr_reg_reg[*]*/C}] -to [get_pins {PCIE_STREAMER/s_start_addr_reg[*]/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_int_lvl_reg_reg[*]*/C}] -to [get_pins {PCIE_STREAMER/s_int_lvl_reg[*]/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_packed_mode_reg_reg[*]*/C}] -to [get_pins {PCIE_STREAMER/s_packed_mode_reg[*]/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_int_clr_tog_reg_reg*/C}] -to [get_pins {PCIE_STREAMER/s_int_clr_tog_meta_reg/D}]
set_false_path -from [get_pins {PCIE_STREAMER/s_srst_reg_reg*/C}] -to [get_pins {PCIE_STREAMER/s_srst_m_reg/D}]

# 
set_false_path -from [get_pins {PCIE_DMA_INST/s_tx_tlp_max_num_words_reg_reg[*]*/C}] -to [get_pins {PCIE_DMA_INST/s_tx_tlp_max_num_words_meta_reg[*]/D}]
set_false_path -from [get_pins {PCIE_DMA_INST/s_srst_reg_reg*/C}] -to [get_pins {PCIE_DMA_INST/s_srst_m_reg/D}]
set_false_path -from [get_pins {PCIE_DMA_INST/s_srst_reg_reg*/C}] -to [get_pins {PCIE_DMA_INST/s_srst_axi_meta_reg/D}]







