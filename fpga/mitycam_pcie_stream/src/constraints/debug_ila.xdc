








set_false_path -from [get_pins {TP_STREAM/s_frame_cnt_reg[*]/C}] -to [get_pins {TP_STREAM/s_frame_cnt_m_reg[*]/D}]

connect_debug_port u_ila_0/clk [get_nets [list PCIE_DMA_INST/pcie_7x_0_support_i/pipe_clock_i/CLK_USERCLK2]]
connect_debug_port u_ila_0/probe8 [get_nets [list PCIE_DMA_INST/s_i_pcie_axis_tx_tlast]]
connect_debug_port u_ila_0/probe9 [get_nets [list PCIE_DMA_INST/s_i_pcie_axis_tx_tvalid]]
connect_debug_port u_ila_0/probe11 [get_nets [list PCIE_DMA_INST/s_o_pcie_axis_tx_tready]]

connect_debug_port u_ila_0/clk [get_nets [list PCIE_DMA_INST/pcie_7x_0_support_i/pipe_clock_i/pipe_userclk2_in]]



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list PCIE_DMA_INST/pcie_7x_0_support_i/pipe_clock_i/CLK_USERCLK2]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {PCIE_DMA_INST/s_tlp_4k_max_count[0]} {PCIE_DMA_INST/s_tlp_4k_max_count[1]} {PCIE_DMA_INST/s_tlp_4k_max_count[2]} {PCIE_DMA_INST/s_tlp_4k_max_count[3]} {PCIE_DMA_INST/s_tlp_4k_max_count[4]} {PCIE_DMA_INST/s_tlp_4k_max_count[5]} {PCIE_DMA_INST/s_tlp_4k_max_count[6]} {PCIE_DMA_INST/s_tlp_4k_max_count[7]} {PCIE_DMA_INST/s_tlp_4k_max_count[8]} {PCIE_DMA_INST/s_tlp_4k_max_count[9]} {PCIE_DMA_INST/s_tlp_4k_max_count[10]} {PCIE_DMA_INST/s_tlp_4k_max_count[11]} {PCIE_DMA_INST/s_tlp_4k_max_count[12]} {PCIE_DMA_INST/s_tlp_4k_max_count[13]} {PCIE_DMA_INST/s_tlp_4k_max_count[14]} {PCIE_DMA_INST/s_tlp_4k_max_count[15]} {PCIE_DMA_INST/s_tlp_4k_max_count[16]} {PCIE_DMA_INST/s_tlp_4k_max_count[17]} {PCIE_DMA_INST/s_tlp_4k_max_count[18]} {PCIE_DMA_INST/s_tlp_4k_max_count[19]} {PCIE_DMA_INST/s_tlp_4k_max_count[20]} {PCIE_DMA_INST/s_tlp_4k_max_count[21]} {PCIE_DMA_INST/s_tlp_4k_max_count[22]} {PCIE_DMA_INST/s_tlp_4k_max_count[23]} {PCIE_DMA_INST/s_tlp_4k_max_count[24]} {PCIE_DMA_INST/s_tlp_4k_max_count[25]} {PCIE_DMA_INST/s_tlp_4k_max_count[26]} {PCIE_DMA_INST/s_tlp_4k_max_count[27]} {PCIE_DMA_INST/s_tlp_4k_max_count[28]} {PCIE_DMA_INST/s_tlp_4k_max_count[29]} {PCIE_DMA_INST/s_tlp_4k_max_count[30]} {PCIE_DMA_INST/s_tlp_4k_max_count[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 10 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[0]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[1]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[2]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[3]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[4]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[5]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[6]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[7]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[8]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_len[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[0]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[1]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[2]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[3]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[4]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[5]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[6]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[7]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[8]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[9]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[10]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[11]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[12]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[13]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[14]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[15]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[16]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[17]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[18]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[19]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[20]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[21]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[22]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[23]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[24]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[25]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[26]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[27]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[28]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[29]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[30]} {PCIE_DMA_INST/s_dma_data_in_tlp_word_cntr[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 3 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {PCIE_DMA_INST/s_tx_tlp_state[0]} {PCIE_DMA_INST/s_tx_tlp_state[1]} {PCIE_DMA_INST/s_tx_tlp_state[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 10 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {PCIE_DMA_INST/s_tx_tlp_wr_length[0]} {PCIE_DMA_INST/s_tx_tlp_wr_length[1]} {PCIE_DMA_INST/s_tx_tlp_wr_length[2]} {PCIE_DMA_INST/s_tx_tlp_wr_length[3]} {PCIE_DMA_INST/s_tx_tlp_wr_length[4]} {PCIE_DMA_INST/s_tx_tlp_wr_length[5]} {PCIE_DMA_INST/s_tx_tlp_wr_length[6]} {PCIE_DMA_INST/s_tx_tlp_wr_length[7]} {PCIE_DMA_INST/s_tx_tlp_wr_length[8]} {PCIE_DMA_INST/s_tx_tlp_wr_length[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 64 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[0]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[1]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[2]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[3]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[4]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[5]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[6]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[7]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[8]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[9]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[10]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[11]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[12]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[13]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[14]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[15]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[16]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[17]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[18]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[19]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[20]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[21]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[22]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[23]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[24]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[25]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[26]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[27]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[28]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[29]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[30]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[31]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[32]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[33]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[34]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[35]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[36]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[37]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[38]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[39]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[40]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[41]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[42]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[43]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[44]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[45]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[46]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[47]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[48]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[49]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[50]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[51]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[52]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[53]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[54]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[55]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[56]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[57]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[58]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[59]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[60]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[61]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[62]} {PCIE_DMA_INST/s_i_pcie_axis_tx_tdata[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[0]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[1]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[2]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[3]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[4]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[5]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[6]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[7]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[8]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[9]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[10]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[11]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[12]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[13]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[14]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[15]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[16]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[17]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[18]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[19]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[20]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[21]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[22]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[23]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[24]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[25]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[26]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[27]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[28]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[29]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[30]} {PCIE_DMA_INST/s_tlp_desc_fifo_din_addr[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {PCIE_DMA_INST/s_tx_tlp_addr[0]} {PCIE_DMA_INST/s_tx_tlp_addr[1]} {PCIE_DMA_INST/s_tx_tlp_addr[2]} {PCIE_DMA_INST/s_tx_tlp_addr[3]} {PCIE_DMA_INST/s_tx_tlp_addr[4]} {PCIE_DMA_INST/s_tx_tlp_addr[5]} {PCIE_DMA_INST/s_tx_tlp_addr[6]} {PCIE_DMA_INST/s_tx_tlp_addr[7]} {PCIE_DMA_INST/s_tx_tlp_addr[8]} {PCIE_DMA_INST/s_tx_tlp_addr[9]} {PCIE_DMA_INST/s_tx_tlp_addr[10]} {PCIE_DMA_INST/s_tx_tlp_addr[11]} {PCIE_DMA_INST/s_tx_tlp_addr[12]} {PCIE_DMA_INST/s_tx_tlp_addr[13]} {PCIE_DMA_INST/s_tx_tlp_addr[14]} {PCIE_DMA_INST/s_tx_tlp_addr[15]} {PCIE_DMA_INST/s_tx_tlp_addr[16]} {PCIE_DMA_INST/s_tx_tlp_addr[17]} {PCIE_DMA_INST/s_tx_tlp_addr[18]} {PCIE_DMA_INST/s_tx_tlp_addr[19]} {PCIE_DMA_INST/s_tx_tlp_addr[20]} {PCIE_DMA_INST/s_tx_tlp_addr[21]} {PCIE_DMA_INST/s_tx_tlp_addr[22]} {PCIE_DMA_INST/s_tx_tlp_addr[23]} {PCIE_DMA_INST/s_tx_tlp_addr[24]} {PCIE_DMA_INST/s_tx_tlp_addr[25]} {PCIE_DMA_INST/s_tx_tlp_addr[26]} {PCIE_DMA_INST/s_tx_tlp_addr[27]} {PCIE_DMA_INST/s_tx_tlp_addr[28]} {PCIE_DMA_INST/s_tx_tlp_addr[29]} {PCIE_DMA_INST/s_tx_tlp_addr[30]} {PCIE_DMA_INST/s_tx_tlp_addr[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list PCIE_DMA_INST/s_dma_complete_status_sel]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list PCIE_DMA_INST/s_dma_data_fifo_full]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list PCIE_DMA_INST/s_dma_tlp_last]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list PCIE_DMA_INST/s_i_pcie_axis_tx_tlast]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list PCIE_DMA_INST/s_i_pcie_axis_tx_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list PCIE_DMA_INST/s_o_dma_data_axis_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list PCIE_DMA_INST/s_o_dma_data_complete]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list PCIE_DMA_INST/s_o_pcie_axis_tx_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list PCIE_DMA_INST/s_tlp_desc_fifo_rd_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list PCIE_DMA_INST/s_tlp_desc_fifo_wr_en]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets s_pcie_dma_axi_clk]
