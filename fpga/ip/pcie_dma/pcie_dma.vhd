-------------------------------------------------------------------------------
--
-- (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
-------------------------------------------------------------------------------
-- Project    : Series-7 Integrated Block for PCI Express
-- File       : pcie_dma.vhd
-- Version    : 3.3
--
-- Description:  PCI Express Endpoint example FPGA design
--
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity pcie_dma is
  generic (
	INIT_PATTERN_WIDTH            : integer := 8;
	INIT_PATTERN1                 : std_logic_vector(7 downto 0) := X"12";
	INIT_PATTERN2                 : std_logic_vector(7 downto 0) := X"9a";
	PCIE_EXT_CLK                  : string := "TRUE";  -- Use External Clocking Module
	PCIE_EXT_GT_COMMON            : string := "FALSE";
	PL_FAST_TRAIN                 : string := "FALSE";
	C_DATA_WIDTH                  : integer range 64 to 128 := 64
  );
  port (
	i_reg_clk             : in  std_logic;
	i_ABus          : in  std_logic_vector(5 downto 0);
	i_DBus          : in  std_logic_vector(15 downto 0);
	o_DBus          : out std_logic_vector(15 downto 0);
	i_wr_en         : in  std_logic;
	i_rd_en         : in  std_logic;
	i_cs            : in  std_logic;
	o_irq           : out std_logic := '0';
	i_ilevel        : in  std_logic_vector(1 downto 0) := "00";      
	i_ivector       : in  std_logic_vector(3 downto 0) := "0000";   

	pci_exp_txp                   : out std_logic_vector(1 downto 0);
	pci_exp_txn                   : out std_logic_vector(1 downto 0);
	pci_exp_rxp                   : in  std_logic_vector(1 downto 0);
	pci_exp_rxn                   : in  std_logic_vector(1 downto 0);

	sys_clk_p                     : in std_logic;
	sys_clk_n                     : in std_logic;
	sys_rst_n                     : in std_logic;

	o_sys_clk                       : out std_logic
);
end pcie_dma;

architecture rtl of pcie_dma is
	attribute DowngradeIPIdentifiedWarnings: string;
	attribute DowngradeIPIdentifiedWarnings of rtl : architecture is "yes";

	constant PCI_EXP_EP_OUI      : std_logic_vector(23 downto 0) := x"000A35";
	constant PCI_EXP_EP_DSN_1    : std_logic_vector(31 downto 0) := x"01" & PCI_EXP_EP_OUI;
	constant PCI_EXP_EP_DSN_2    : std_logic_vector(31 downto 0) := x"00000001";

	signal s_srst : std_logic := '0';

	signal s_go : std_logic := '0';
	signal s_go_meta : std_logic := '0';
	signal s_go_r1 : std_logic := '0';
	signal s_go_r2 : std_logic := '0';

	signal s_td : std_logic := '0';
	signal s_ep : std_logic := '0';

	signal s_attr : std_logic_vector(1 downto 0) := (others => '0');
	signal s_length : std_logic_vector(9 downto 0) := (others => '0');

	signal s_fmt : std_logic_vector(1 downto 0) := (others => '0');
	signal s_type : std_logic_vector(4 downto 0) := (others => '0');
	signal s_tc : std_logic_vector(2 downto 0) := (others => '0');

	signal s_tag : std_logic_vector(7 downto 0) := (others => '0');
	signal s_last_dw_be : std_logic_vector(3 downto 0) := (others => '0');
	signal s_1st_dw_be : std_logic_vector(3 downto 0) := (others => '0');

	signal s_requestor_id : std_logic_vector(15 downto 0) := (others => '0');

	signal s_addr : std_logic_vector(31 downto 0) := (others => '0');
	signal s_data : std_logic_vector(31 downto 0) := (others => '0');

	signal s_tx_cntr : integer := 420;

	signal s_data_rx : std_logic_vector(63 downto 0) := (others => '0');

	signal s_rx_cntr : integer := 0;

	signal s_dbg_cntr : integer := 0;

	component pcie_7x_0_support is
	generic (
	   LINK_CAP_MAX_LINK_WIDTH : integer := 8;       
	   C_DATA_WIDTH            : integer range 64 to 128 := 64;
	   KEEP_WIDTH              : integer range 8 to 16   := 8;
	   PCIE_REFCLK_FREQ        : integer := 0;             -- 0 - 100 MHz , 1 - 125 MHz , 2 - 250 MHz
	   PCIE_LINK_SPEED         : integer := 3;
	   PCIE_USERCLK1_FREQ      : integer := 2;             -- PCIe user clock 1 frequency
	   PCIE_USERCLK2_FREQ      : integer := 2;             -- PCIe user clock 2 frequency
	   PCIE_GT_DEVICE          : string := "GTX";          -- Select the GT to use (GTP for Artix-7, GTX for K7/V7)
	   PCIE_USE_MODE           : string := "2.1"           -- 1.0=K325T IES, 1.1=VX48T IES, 3.0 = K325T GES
	  );
	  port (
	  ---------------------------------------------------------------------------------------------------------------
	  -- PCI Express (pci_exp) Interface                                                                         
	  ---------------------------------------------------------------------------------------------------------------
	  pci_exp_txp                                : out std_logic_vector(1 downto 0);
	  pci_exp_txn                                : out std_logic_vector(1 downto 0);
	  pci_exp_rxp                                : in std_logic_vector(1 downto 0);
	  pci_exp_rxn                                : in std_logic_vector(1 downto 0);

	  ----------------------------------------------------------------------------------------------------------------
	  -- Clock Sharing Interface                                                                      
	  ----------------------------------------------------------------------------------------------------------------
	  pipe_pclk_out_slave                        : out std_logic;  
	  pipe_rxusrclk_out                          : out std_logic;
	  pipe_rxoutclk_out                          : out std_logic_vector(1 downto 0);
	  pipe_dclk_out                              : out std_logic;   
	  pipe_userclk1_out                          : out std_logic;
	  pipe_userclk2_out                          : out std_logic;
	  pipe_oobclk_out                            : out std_logic;
	  pipe_mmcm_lock_out                         : out std_logic;
	  pipe_pclk_sel_slave                        : in std_logic_vector(1 downto 0);
	  pipe_mmcm_rst_n                            : in std_logic;   --     // Async      | Async


	  ----------------------------------------------------------------------------------------------------------------
	  -- AXI-S Interface                                                                                            
	  ----------------------------------------------------------------------------------------------------------------
	  -- Common
	  -----------
	  user_clk_out                               : out std_logic;
	  user_reset_out                             : out std_logic;   
	  user_lnk_up                                : out std_logic;  
	  user_app_rdy                               : out std_logic; 
	  -----------
	  -- AXI TX
	  -----------
	  s_axis_tx_tdata                            : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
	  s_axis_tx_tvalid                           : in std_logic;
	  s_axis_tx_tready                           : out std_logic;
	  s_axis_tx_tkeep                            : in std_logic_vector((C_DATA_WIDTH / 8 - 1) downto 0);
	  s_axis_tx_tlast                            : in std_logic;
	  s_axis_tx_tuser                            : in std_logic_vector(3 downto 0);
	  -----------
	  -- AXI RX
	  -----------
	  m_axis_rx_tdata                            : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);  
	  m_axis_rx_tvalid                           : out std_logic;
	  m_axis_rx_tready                           : in std_logic;
	  m_axis_rx_tkeep                            : out std_logic_vector((C_DATA_WIDTH / 8 - 1) downto 0);
	  m_axis_rx_tlast                            : out std_logic;
	  m_axis_rx_tuser                            : out std_logic_vector(21 downto 0);

	  -- Flow Control
	  fc_cpld                                    : out std_logic_vector(11 downto 0);  
	  fc_cplh                                    : out std_logic_vector(7 downto 0);  
	  fc_npd                                     : out std_logic_vector(11 downto 0); 
	  fc_nph                                     : out std_logic_vector(7 downto 0); 
	  fc_pd                                      : out std_logic_vector(11 downto 0); 
	  fc_ph                                      : out std_logic_vector(7 downto 0);
	  fc_sel                                     : in std_logic_vector(2 downto 0); 

	  -- Management Interface
	  cfg_mgmt_do                                : out std_logic_vector (31 downto 0);
	  cfg_mgmt_rd_wr_done                        : out std_logic;
	  cfg_mgmt_di                                : in std_logic_vector (31 downto 0);
	  cfg_mgmt_byte_en                           : in std_logic_vector (3 downto 0);
	  cfg_mgmt_dwaddr                            : in std_logic_vector (9 downto 0);
	  cfg_mgmt_wr_en                             : in std_logic;
	  cfg_mgmt_rd_en                             : in std_logic;
	  cfg_mgmt_wr_readonly                       : in std_logic;
	  cfg_mgmt_wr_rw1c_as_rw                     : in std_logic;

	  -- Error Reporting Interface
	  cfg_err_ecrc                               : in std_logic;
	  cfg_err_ur                                 : in std_logic;
	  cfg_err_cpl_timeout                        : in std_logic;
	  cfg_err_cpl_unexpect                       : in std_logic;
	  cfg_err_cpl_abort                          : in std_logic;
	  cfg_err_posted                             : in std_logic;
	  cfg_err_cor                                : in std_logic;
	  cfg_err_atomic_egress_blocked              : in std_logic;
	  cfg_err_internal_cor                       : in std_logic;
	  cfg_err_malformed                          : in std_logic;
	  cfg_err_mc_blocked                         : in std_logic;
	  cfg_err_poisoned                           : in std_logic;
	  cfg_err_norecovery                         : in std_logic;
	  cfg_err_tlp_cpl_header                     : in std_logic_vector(47 downto 0);
	  cfg_err_cpl_rdy                            : out std_logic;
	  cfg_err_locked                             : in std_logic;
	  cfg_err_acs                                : in std_logic;
	  cfg_err_internal_uncor                     : in std_logic;
	  ----------------------------------------------------------------------------------------------------------------
	  -- AER interface                                                                                             
	  ----------------------------------------------------------------------------------------------------------------
	  cfg_err_aer_headerlog                      : in std_logic_vector(127 downto 0);
	  cfg_aer_interrupt_msgnum                   : in std_logic_vector(4 downto 0);
	  cfg_err_aer_headerlog_set                  : out std_logic;
	  cfg_aer_ecrc_check_en                      : out std_logic;
	  cfg_aer_ecrc_gen_en                        : out std_logic;

	  tx_cfg_gnt                                 : in std_logic;
	  rx_np_ok                                   : in std_logic;
	  rx_np_req                                  : in std_logic;
	  cfg_turnoff_ok                             : in std_logic;
	  cfg_trn_pending                            : in std_logic;
	  cfg_pm_halt_aspm_l0s                       : in std_logic;
	  cfg_pm_halt_aspm_l1                        : in std_logic;
	  cfg_pm_force_state_en                      : in std_logic;
	  cfg_pm_force_state                         : in std_logic_vector(1 downto 0);
	  cfg_dsn                                    : in std_logic_vector(63 downto 0);
	  cfg_pm_send_pme_to                         : in std_logic;
	  cfg_ds_bus_number                          : in std_logic_vector(7 downto 0);
	  cfg_ds_device_number                       : in std_logic_vector(4 downto 0);
	  cfg_ds_function_number                     : in std_logic_vector(2 downto 0);
	  cfg_pm_wake                                : in std_logic;

	  ------------------------------------------------
	  -- EP Only                                        
	  ------------------------------------------------
	  -- Interrupt Interface Signals
	  cfg_interrupt                              : in std_logic;
	  cfg_interrupt_rdy                          : out std_logic;
	  cfg_interrupt_assert                       : in std_logic;
	  cfg_interrupt_di                           : in std_logic_vector(7 downto 0);
	  cfg_interrupt_do                           : out std_logic_vector(7 downto 0);
	  cfg_interrupt_mmenable                     : out std_logic_vector(2 downto 0);
	  cfg_interrupt_msienable                    : out std_logic;
	  cfg_interrupt_msixenable                   : out std_logic;
	  cfg_interrupt_msixfm                       : out std_logic;
	  cfg_interrupt_stat                         : in std_logic;
	  cfg_pciecap_interrupt_msgnum               : in std_logic_vector(4 downto 0);

	  ----------------------------------------------------------------------------------------------------------------
	  -- Configuration (CFG) Interface                                                                               
	  ----------------------------------------------------------------------------------------------------------------
	  cfg_status                                 : out std_logic_vector(15 downto 0);    
	  cfg_command                                : out std_logic_vector(15 downto 0);     
	  cfg_dstatus                                : out std_logic_vector(15 downto 0);       
	  cfg_dcommand                               : out std_logic_vector(15 downto 0);            
	  cfg_lstatus                                : out std_logic_vector(15 downto 0);           
	  cfg_lcommand                               : out std_logic_vector(15 downto 0);        
	  cfg_dcommand2                              : out std_logic_vector(15 downto 0);      
	  cfg_pcie_link_state                        : out std_logic_vector(2 downto 0);  

	  cfg_pmcsr_pme_en                           : out std_logic;
	  cfg_pmcsr_powerstate                       : out std_logic_vector(1 downto 0);
	  cfg_pmcsr_pme_status                       : out std_logic;
	  cfg_received_func_lvl_rst                  : out std_logic;
	  tx_err_drop                                : out std_logic;
	  tx_cfg_req                                 : out std_logic;
	  tx_buf_av                                  : out std_logic_vector(5 downto 0);
	  cfg_to_turnoff                             : out std_logic;
	  cfg_bus_number                             : out std_logic_vector(7 downto 0);
	  cfg_device_number                          : out std_logic_vector(4 downto 0);
	  cfg_function_number                        : out std_logic_vector(2 downto 0);
	  cfg_bridge_serr_en                         : out std_logic;
	  cfg_slot_control_electromech_il_ctl_pulse  : out std_logic;
	  cfg_root_control_syserr_corr_err_en        : out std_logic;
	  cfg_root_control_syserr_non_fatal_err_en   : out std_logic;
	  cfg_root_control_syserr_fatal_err_en       : out std_logic;
	  cfg_root_control_pme_int_en                : out std_logic;
	  cfg_aer_rooterr_corr_err_reporting_en      : out std_logic;
	  cfg_aer_rooterr_non_fatal_err_reporting_en : out std_logic;
	  cfg_aer_rooterr_fatal_err_reporting_en     : out std_logic;
	  cfg_aer_rooterr_corr_err_received          : out std_logic;
	  cfg_aer_rooterr_non_fatal_err_received     : out std_logic;
	  cfg_aer_rooterr_fatal_err_received         : out std_logic;
	  ----------------------------------------------------------------------------------------------------------------
	  -- VC interface                                                                                              
	  ----------------------------------------------------------------------------------------------------------------
	  cfg_vc_tcvc_map                            : out std_logic_vector(6 downto 0);

	  cfg_msg_received                           : out std_logic;
	  cfg_msg_data                               : out std_logic_vector(15 downto 0);
	  cfg_msg_received_pm_as_nak                 : out std_logic;
	  cfg_msg_received_setslotpowerlimit         : out std_logic;
	  cfg_msg_received_err_cor                   : out std_logic;
	  cfg_msg_received_err_non_fatal             : out std_logic;
	  cfg_msg_received_err_fatal                 : out std_logic;
	  cfg_msg_received_pm_pme                    : out std_logic;
	  cfg_msg_received_pme_to_ack                : out std_logic;
	  cfg_msg_received_assert_int_a              : out std_logic;
	  cfg_msg_received_assert_int_b              : out std_logic;
	  cfg_msg_received_assert_int_c              : out std_logic;
	  cfg_msg_received_assert_int_d              : out std_logic;
	  cfg_msg_received_deassert_int_a            : out std_logic;
	  cfg_msg_received_deassert_int_b            : out std_logic;
	  cfg_msg_received_deassert_int_c            : out std_logic;
	  cfg_msg_received_deassert_int_d            : out std_logic;

	  -------------------------------------------------------------------------------------------------
	  -- Physical Layer Control and Status (PL) Interface                                                          
	  -------------------------------------------------------------------------------------------------
	  ------------------------------------------------
	  -- EP and RP                                    
	  ------------------------------------------------
	  pl_directed_link_change                    : in std_logic_vector(1 downto 0);
	  pl_directed_link_width                     : in std_logic_vector(1 downto 0);
	  pl_directed_link_speed                     : in std_logic;
	  pl_directed_link_auton                     : in std_logic;
	  pl_upstream_prefer_deemph                  : in std_logic;
	  pl_sel_lnk_rate                            : out std_logic;
	  pl_sel_lnk_width                           : out std_logic_vector(1 downto 0);
	  pl_ltssm_state                             : out std_logic_vector(5 downto 0);
	  pl_lane_reversal_mode                      : out std_logic_vector(1 downto 0);
	  pl_phy_lnk_up                              : out std_logic;
	  pl_tx_pm_state                             : out std_logic_vector(2 downto 0);
	  pl_rx_pm_state                             : out std_logic_vector(1 downto 0);
	  pl_link_upcfg_cap                          : out std_logic;
	  pl_link_gen2_cap                           : out std_logic;
	  pl_link_partner_gen2_supported             : out std_logic;
	  pl_initial_link_width                      : out std_logic_vector(2 downto 0);
	  pl_directed_change_done                    : out std_logic;

	  ------------------------------------------------
	  -- EP Only                                      
	  ------------------------------------------------
	  pl_received_hot_rst                        : out std_logic;

	  ------------------------------------------------
	  -- RP Only                                      
	  ------------------------------------------------
	  pl_transmit_hot_rst                        : in std_logic;
	  pl_downstream_deemph_source                : in std_logic;


	  ----------------------------------------------------------------------------------------------------------------
	  -- PCIe DRP (PCIe DRP) Interface                                                                             
	  ----------------------------------------------------------------------------------------------------------------
	  pcie_drp_clk                               : in std_logic;
	  pcie_drp_en                                : in std_logic;
	  pcie_drp_we                                : in std_logic;
	  pcie_drp_addr                              : in std_logic_vector(8 downto 0);
	  pcie_drp_di                                : in std_logic_vector(15 downto 0);
	  pcie_drp_do                                : out std_logic_vector(15 downto 0);
	  pcie_drp_rdy                               : out std_logic;



	  ------------------------------------------------------------------------------------------------------------------
	  -- System(SYS) Interface                                                                                      --
	  ------------------------------------------------------------------------------------------------------------------
	  sys_clk                                    : in std_logic;
	  sys_rst_n                                  : in std_logic );

	  end component;

  constant TCQ                  : time           := 1 ps;

   function get_userClk2 (
    DIV2   : string;
    UC_FREQ  : integer)
    return integer is
  begin  -- wr_mode
    if (DIV2 = "TRUE") then
      if (UC_FREQ = 4) then
        return 3;
      elsif (UC_FREQ = 3) then
        return 2;
      else
        return UC_FREQ;
      end if;
    else
      return UC_FREQ;
    end if;
  end get_userClk2;

   -- purpose: Determine Link Speed Configuration for GT
   function get_gt_lnk_spd_cfg (
     constant simulation : string)
     return integer is
   begin  -- get_gt_lnk_spd_cfg
     if (simulation = "TRUE") then
       return 2;
     else
       return 3;
     end if;
   end get_gt_lnk_spd_cfg;

  -- PCI Express Fast Config Initialization pattern


  constant USER_CLK_FREQ        : integer := 2;
  constant USER_CLK2_DIV2       : string  := "FALSE";
  constant USERCLK2_FREQ        : integer := get_userClk2(USER_CLK2_DIV2,USER_CLK_FREQ);
  constant LNK_SPD              : integer := get_gt_lnk_spd_cfg(PL_FAST_TRAIN);

  -- Common
  signal user_lnk_up            : std_logic;
  signal user_lnk_up_q          : std_logic;
  signal user_clk               : std_logic;
  signal user_reset             : std_logic;
  signal user_reset_i           : std_logic;
  signal user_reset_q           : std_logic;

  -- Tx
  signal s_axis_tx_tready       : std_logic;
  signal s_axis_tx_tuser        : std_logic_vector (3 downto 0);
  signal s_axis_tx_tdata        : std_logic_vector((C_DATA_WIDTH - 1) downto 0);
  signal s_axis_tx_tkeep        : std_logic_vector((C_DATA_WIDTH/8 - 1) downto 0);
  signal s_axis_tx_tlast        : std_logic;
  signal s_axis_tx_tvalid       : std_logic;

  -- Rx
  signal m_axis_rx_tdata        : std_logic_vector((C_DATA_WIDTH - 1) downto 0);
  signal m_axis_rx_tkeep        : std_logic_vector((C_DATA_WIDTH/8- 1) downto 0);
  signal m_axis_rx_tlast        : std_logic;
  signal m_axis_rx_tvalid       : std_logic;
  signal m_axis_rx_tready       : std_logic;
  signal m_axis_rx_tuser        : std_logic_vector (21 downto 0);

  signal tx_cfg_gnt             : std_logic;
  signal rx_np_ok               : std_logic;
  signal rx_np_req              : std_logic;
  signal cfg_turnoff_ok         : std_logic := '1';
  signal cfg_trn_pending        : std_logic;
  signal cfg_pm_halt_aspm_l0s   : std_logic;
  signal cfg_pm_halt_aspm_l1    : std_logic;
  signal cfg_pm_force_state_en  : std_logic;
  signal cfg_pm_force_state     : std_logic_vector(1 downto 0);
  signal cfg_pm_wake            : std_logic;
  signal cfg_dsn                : std_logic_vector(63 downto 0);

  signal fc_sel                 : std_logic_vector(2 downto 0);

  ---------------------------------------------------------
  -- 3. Configuration (CFG) Interface
  ---------------------------------------------------------
  signal cfg_err_cor                   : std_logic;
  signal cfg_err_atomic_egress_blocked : std_logic;
  signal cfg_err_internal_cor          : std_logic;
  signal cfg_err_malformed             : std_logic;
  signal cfg_err_mc_blocked            : std_logic;
  signal cfg_err_poisoned              : std_logic;
  signal cfg_err_norecovery            : std_logic;
  signal cfg_err_ur                    : std_logic;
  signal cfg_err_ecrc                  : std_logic;
  signal cfg_err_cpl_timeout           : std_logic;
  signal cfg_err_cpl_abort             : std_logic;
  signal cfg_err_cpl_unexpect          : std_logic;
  signal cfg_err_posted                : std_logic;
  signal cfg_err_locked                : std_logic;
  signal cfg_err_acs                   : std_logic;
  signal cfg_err_internal_uncor        : std_logic;
  signal cfg_err_tlp_cpl_header        : std_logic_vector(47 downto 0);
  signal cfg_err_aer_headerlog         : std_logic_vector(127 downto 0);
  signal cfg_aer_interrupt_msgnum      : std_logic_vector(4 downto 0);

  signal cfg_interrupt                 : std_logic;
  signal cfg_interrupt_assert          : std_logic;
  signal cfg_interrupt_di              : std_logic_vector(7 downto 0);
  signal cfg_interrupt_stat            : std_logic;
  signal cfg_pciecap_interrupt_msgnum  : std_logic_vector(4 downto 0);

  signal cfg_to_turnoff                : std_logic;
  signal cfg_bus_number                : std_logic_vector(7 downto 0);
  signal cfg_device_number             : std_logic_vector(4 downto 0);
  signal cfg_function_number           : std_logic_vector(2 downto 0);

  signal cfg_mgmt_di                   : std_logic_vector(31 downto 0);
  signal cfg_mgmt_byte_en              : std_logic_vector(3 downto 0);
  signal cfg_mgmt_dwaddr               : std_logic_vector(9 downto 0);
  signal cfg_mgmt_wr_en                : std_logic;
  signal cfg_mgmt_rd_en                : std_logic;
  signal cfg_mgmt_wr_readonly          : std_logic;

  ---------------------------------------------------------
  -- Physical Layer Control and Status (PL) Interface
  ---------------------------------------------------------
  signal pl_ltssm_state                 : std_logic_vector(5 downto 0);
  signal pl_directed_link_auton         : std_logic;
  signal pl_directed_link_change        : std_logic_vector(1 downto 0);
  signal pl_directed_link_speed         : std_logic;
  signal pl_directed_link_width         : std_logic_vector(1 downto 0);
  signal pl_upstream_prefer_deemph      : std_logic;

  signal sys_clk                        : std_logic;
  signal sys_rst_n_c                    : std_logic;
  signal sys_rst                        : std_logic;

  signal pipe_mmcm_rst_n                : std_logic := '1';
  -------------------------------------------------------

begin

  o_sys_clk <= sys_clk;

  process(user_clk)
  begin
    if (user_clk'event and user_clk='1') then
     if (user_reset = '1') then
       user_reset_q  <= '1' after TCQ;
       user_lnk_up_q <= '0' after TCQ;
     else
       user_reset_q  <= user_reset after TCQ;
       user_lnk_up_q <= user_lnk_up after TCQ;
     end if;
    end if;
  end process;

  refclk_ibuf : IBUFDS_GTE2
     port map(
       O       => sys_clk,
       ODIV2   => open,
       I       => sys_clk_p,
       IB      => sys_clk_n,
       CEB     => '0');

  sys_reset_n_ibuf : IBUF
     port map(
       O       => sys_rst_n_c,
       I       => sys_rst_n);

  -- Convert sys_rst to active high to adhere to AXI requirements
  -- sys_reset_c              <= not sys_rst_n_c;
--  user_reset_i             <= not user_reset;



	REG_READ_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			o_DBus <= (others => '0');

			if (i_cs = '1') then
				case i_ABus is
					-- 0x180
					when "000000" =>
						o_DBus <= x"B00F";

					-- 0x182
					when "000001" =>
						o_DBus(0) <= s_srst;
						o_DBus(1) <= s_go;

					-- 0x184
					when "000010" => 
						o_DBus(15) <= s_td;
						o_DBus(14) <= s_ep;

						o_DBus(13 downto 12) <= s_attr;

						o_DBus(9 downto 0) <= s_length;

					-- 0x186
					when "000011" => 

						o_DBus(14 downto 13) <= s_fmt;
						o_DBus(12 downto 8) <= s_type;

						o_DBus(6 downto 4) <= s_tc;

					-- 0x188
					when "000100" => 
						o_DBus(15 downto 8) <= s_tag;
						o_DBus(7 downto 4) <= s_last_dw_be;
						o_DBus(3 downto 0) <= s_1st_dw_be;

					-- 0x18a
					when "000101" => 
						o_DBus(15 downto 0) <= s_requestor_id;

					-- 0x18c
					when "000110" => 
						o_DBus(15 downto 0) <= s_addr(15 downto 0);

					-- 0x18e
					when "000111" => 
						o_DBus(15 downto 0) <= s_addr(31 downto 16);

					-- 0x190
					when "001000" => 
						o_DBus(15 downto 0) <= s_data(15 downto 0);

					-- 0x192
					when "001001" => 
						o_DBus(15 downto 0) <= s_data(31 downto 16);

					-- 0x194
					when "001010" => 
						o_DBus(15 downto 0) <= s_data_rx(15 downto 0);
												
					-- 0x196
					when "001011" => 
						o_DBus(15 downto 0) <= s_data_rx(31 downto 16);

					-- 0x198
					when "001100" => 
						o_DBus(15 downto 0) <= s_data_rx(47 downto 32);

					-- 0x19a
					when "001101" => 
						o_DBus(15 downto 0) <= s_data_rx(63 downto 48);

					-- 0x19c
					when "001110" => 
						o_DBus(15 downto 0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(s_rx_cntr, 16));

					-- 0x19e
					when "001111" => 
						o_DBus(15 downto 0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(s_dbg_cntr, 16));

					when others =>
						o_DBus <= x"DEAD";
				end case;
			end if;
		end if;
	end process REG_READ_PROC;

	s_requestor_id <= cfg_bus_number & cfg_device_number & cfg_function_number;

	REG_WRITE_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			if (i_cs = '1' and i_wr_en = '1') then
				case i_ABus is
					-- 0x180
					when "000000" =>
						null;

					-- 0x182
					when "000001" =>
						s_srst <= i_DBus(0);
						s_go <= i_DBus(1);

					-- 0x184
					when "000010" => 
						s_td <= i_DBus(15);
						s_ep <= i_DBus(14);

						s_attr <= i_DBus(13 downto 12);

						s_length <= i_DBus(9 downto 0);

					-- 0x186
					when "000011" => 

						s_fmt <= i_DBus(14 downto 13);
						s_type <= i_DBus(12 downto 8);

						s_tc <= i_DBus(6 downto 4);

					-- 0x188
					when "000100" => 
						s_tag <= i_DBus(15 downto 8);
						s_last_dw_be <= i_DBus(7 downto 4);
						s_1st_dw_be <= i_DBus(3 downto 0);

					-- 0x18a
					when "000101" => 
						--s_requestor_id <= i_DBus(15 downto 0);

					-- 0x18c
					when "000110" => 
						s_addr(15 downto 0) <= i_DBus(15 downto 2) & "00";

					-- 0x18e
					when "000111" => 
						s_addr(31 downto 16) <= i_DBus(15 downto 0);

					-- 0x190
					when "001000" => 
						s_data(15 downto 0) <= i_DBus(15 downto 0);

					-- 0x192
					when "001001" => 
						s_data(31 downto 16) <= i_DBus(15 downto 0);
						
					when others =>
						null;
				end case;
			end if;
		end if;
	end process REG_WRITE_PROC;

	m_axis_rx_tready <= '1';

	process(user_clk)
	begin
		if rising_edge(user_clk) then
			if (m_axis_rx_tvalid = '1') then
				s_data_rx <= m_axis_rx_tdata;

				s_rx_cntr <= s_rx_cntr + 1;
			end if;

			s_go_meta <= s_go;
			s_go_r1 <= s_go_meta;
			s_go_r2 <= s_go_r1;

			if (s_go_r2 = '0' and s_go_r1 = '1') then
				s_tx_cntr <= 0;
			end if;

			s_axis_tx_tvalid <= '0';

			if (s_tx_cntr < 2) then
				s_axis_tx_tvalid <= '1';

				if (s_tx_cntr = 0) then
					s_axis_tx_tdata <= (others => '0');

					s_axis_tx_tdata(15 downto 0) <= s_td & s_ep & s_attr & "00" & s_length;
					s_axis_tx_tdata(31 downto 16) <= "0" & s_fmt & s_type & "0" & s_tc & "0000";
					s_axis_tx_tdata(47 downto 32) <= s_tag & s_last_dw_be & s_1st_dw_be;
					s_axis_tx_tdata(63 downto 48) <= s_requestor_id;

					s_axis_tx_tkeep <= "11111111";

					s_axis_tx_tlast <= '0';
				end if;

				if (s_tx_cntr = 1) then
					s_axis_tx_tdata <= (others => '0');

					s_axis_tx_tdata(31 downto 0) <= s_addr;
					s_axis_tx_tdata(63 downto 32) <= s_data;

					if (s_fmt = "00") then
						s_axis_tx_tkeep <= "00001111";
					else
						s_axis_tx_tkeep <= "11111111";
					end if;

					s_axis_tx_tlast <= '1';
				end if;

				if (s_axis_tx_tready = '1') then
					s_tx_cntr <= s_tx_cntr + 1;

					s_dbg_cntr <= s_dbg_cntr + 1;
				end if;
			end if;
		end if;
	end process;

	s_axis_tx_tuser <= (others => '0');

	pcie_7x_0_support_i : pcie_7x_0_support 
	 generic map
	   (	 
	    LINK_CAP_MAX_LINK_WIDTH       =>   2 ,  -- PCIe Lane Width
	    C_DATA_WIDTH                  =>   C_DATA_WIDTH ,                       -- RX/TX interface data width
	    KEEP_WIDTH                    =>   C_DATA_WIDTH/8 ,                         -- TSTRB width
	    PCIE_REFCLK_FREQ              =>   0 , -- PCIe reference clock frequency
	    PCIE_LINK_SPEED               =>   LNK_SPD,
	    PCIE_USERCLK1_FREQ            =>   USER_CLK_FREQ +1 ,                   -- PCIe user clock 1 frequency
	    PCIE_USERCLK2_FREQ            =>   USERCLK2_FREQ +1 ,                   -- PCIe user clock 2 frequency             
	    PCIE_USE_MODE                 =>  "1.0",           -- PCIe use mode
	    PCIE_GT_DEVICE                =>  "GTP"              -- PCIe GT device
	   )
	  port map 
	  (
	  ----------------------------------------------------------------------------------------------------------------  
	  -- PCI Express (pci_exp) Interface                                                                            --   
	  ----------------------------------------------------------------------------------------------------------------  
	  -- Tx
	  pci_exp_txn                                => pci_exp_txn,
	  pci_exp_txp                                => pci_exp_txp,

	  -- Rx
	  pci_exp_rxn                                => pci_exp_rxn,
	  pci_exp_rxp                                => pci_exp_rxp,

	  ----------------------------------------------------------------------------------------------------------------  
	  -- Clocking Sharing Interface                                                                                 --  
	  ----------------------------------------------------------------------------------------------------------------  
	  pipe_pclk_out_slave                        => open ,
	  pipe_rxusrclk_out                          => open ,
	  pipe_rxoutclk_out                          => open ,
	  pipe_dclk_out                              => open ,
	  pipe_userclk1_out                          => open ,
	  pipe_oobclk_out                            => open ,
	  pipe_userclk2_out                          => open ,
	  pipe_mmcm_lock_out                         => open ,
	  pipe_pclk_sel_slave                        => ( others => '0'),
	  pipe_mmcm_rst_n                            => pipe_mmcm_rst_n ,       -- // Async      | Async


	  ----------------------------------------------------------------------------------------------------------------
	  -- AXI-S Interface                                                                                            --  
	  ----------------------------------------------------------------------------------------------------------------
	  -- Common
	  user_clk_out                               => user_clk ,
	  user_reset_out                             => user_reset ,
	  user_lnk_up                                => user_lnk_up ,
	  user_app_rdy                               => open ,

	  -- TX
	  s_axis_tx_tready                           => s_axis_tx_tready ,
	  s_axis_tx_tdata                            => s_axis_tx_tdata ,
	  s_axis_tx_tkeep                            => s_axis_tx_tkeep ,
	  s_axis_tx_tuser                            => s_axis_tx_tuser ,
	  s_axis_tx_tlast                            => s_axis_tx_tlast ,
	  s_axis_tx_tvalid                           => s_axis_tx_tvalid ,

	  -- Rx
	  m_axis_rx_tdata                            => m_axis_rx_tdata ,
	  m_axis_rx_tkeep                            => m_axis_rx_tkeep ,
	  m_axis_rx_tlast                            => m_axis_rx_tlast ,
	  m_axis_rx_tvalid                           => m_axis_rx_tvalid ,
	  m_axis_rx_tready                           => m_axis_rx_tready ,
	  m_axis_rx_tuser                            => m_axis_rx_tuser ,

	  -- Flow Control
	  fc_cpld                                    => open, 
	  fc_cplh                                    => open, 
	  fc_npd                                     => open, 
	  fc_nph                                     => open, 
	  fc_pd                                      => open, 
	  fc_ph                                      => open, 
	  fc_sel                                     => "000",

	  -- Management Interface
	  cfg_mgmt_di                                => x"00000000", -- Zero out CFG MGMT input data bus
	  cfg_mgmt_byte_en                           => x"0", -- Zero out CFG MGMT byte enables
	  cfg_mgmt_dwaddr                            => "0000000000", -- Zero out CFG MGMT 10-bit address port
	  cfg_mgmt_wr_en                             => '0', -- Do not write CFG space
	  cfg_mgmt_rd_en                             => '0', -- Do not read CFG space
	  cfg_mgmt_wr_readonly                       => '0', -- Never treat RO bit as RW
	  cfg_mgmt_do                                => open ,
	  cfg_mgmt_rd_wr_done                        => open ,
	  cfg_mgmt_wr_rw1c_as_rw                     => '0' ,

	  -- Error Reporting Interface
	  cfg_err_ecrc                               => '0', -- Never report ECRC Error
	  cfg_err_ur                                 => '0', -- Never report UR
	  cfg_err_cpl_timeout                        => '0', -- Never report Completion Timeout
	  cfg_err_cpl_unexpect                       => '0', -- Never report unexpected completion
	  cfg_err_cpl_abort                          => '0', -- Never report Completion Abort
	  cfg_err_posted                             => '0', -- Never qualify cfg_err_* inputs
	  cfg_err_cor                                => '0', -- Never report Correctable Error
	  cfg_err_atomic_egress_blocked              => '0', -- Never report Atomic TLP blocked
	  cfg_err_internal_cor                       => '0', -- Never report internal error occurred
	  cfg_err_malformed                          => '0', -- Never report malformed error
	  cfg_err_mc_blocked                         => '0', -- Never report multi-cast TLP blocked
	  cfg_err_poisoned                           => '0', -- Never report poisoned TLP received
	  cfg_err_norecovery                         => '0', -- Never qualify cfg_err_poisoned or cfg_err_cpl_timeout
	  cfg_err_tlp_cpl_header                     => x"000000000000", -- Zero out the header information
	  cfg_err_cpl_rdy                            => open,
	  cfg_err_locked                             => '0', -- Never qualify cfg_err_ur or cfg_err_cpl_abort
	  cfg_err_acs                                => '0', -- Never report an ACS violation
	  cfg_err_internal_uncor                     => '0', -- Never report internal uncorrectable error
	  ---------------------------------------------------------------------------------------------
	  -- AER Interface                                                                           --
	  ---------------------------------------------------------------------------------------------
	  cfg_err_aer_headerlog                      => (others => '0'), -- Zero out the AER Header Log
	  cfg_err_aer_headerlog_set                  => open , 
	  cfg_aer_ecrc_check_en                      => open , 
	  cfg_aer_ecrc_gen_en                        => open , 
	  cfg_aer_interrupt_msgnum                   => "00000", -- Zero out the AER Root Error Status Register

	  tx_cfg_gnt                                 => '1', -- Always allow transmission of Config traffic within block --tx_cfg_gnt ,
	  rx_np_ok                                   => '1', -- Allow Reception of Non-posted Traffic
	  rx_np_req                                  => '1', -- Always request Non-posted Traffic if available
	  cfg_trn_pending                            => '0', -- Never set the transaction pending bit in the Device Status Register
	  cfg_pm_halt_aspm_l0s                       => '0', -- Allow entry into L0s
	  cfg_pm_halt_aspm_l1                        => '0', -- Allow entry into L1 
	  cfg_pm_force_state_en                      => '0', -- Do not qualify cfg_pm_force_state 
	  cfg_pm_force_state                         => "00", -- Do not move force core into specific PM state 
	  cfg_dsn                                    => PCI_EXP_EP_DSN_2 & PCI_EXP_EP_DSN_1, -- Assign the input DSN
	  cfg_turnoff_ok                             => cfg_turnoff_ok ,
	  cfg_pm_wake                                => '0', -- Never direct the core to send a PM_PME Message
	  cfg_pm_send_pme_to                         => '0' ,
	  cfg_ds_bus_number                          => "00000000" ,
	  cfg_ds_device_number                       => "00000" ,
	  cfg_ds_function_number                     => "000" ,

	  ----------------------------------------------------
	  -- EP Only                                        --
	  ----------------------------------------------------
	  cfg_interrupt                              => '0', -- Never drive interrupt by qualifying cfg_interrupt_assert
	  cfg_interrupt_rdy                          => open ,
	  cfg_interrupt_assert                       => '0', -- Always drive interrupt de-assert
	  cfg_interrupt_di                           => x"00", -- Do not set interrupt fields
	  cfg_interrupt_do                           => open ,
	  cfg_interrupt_mmenable                     => open , 
	  cfg_interrupt_msienable                    => open , 
	  cfg_interrupt_msixenable                   => open , 
	  cfg_interrupt_msixfm                       => open , 
	  cfg_interrupt_stat                         => '0', -- Never set the Interrupt Status bit
	  cfg_pciecap_interrupt_msgnum               => "00000", -- Zero out Interrupt Message Number

	  ----------------------------------------------------------------------------------------------------------------
	  -- Configuration (CFG) Interface                                                                              --  
	  ----------------------------------------------------------------------------------------------------------------
	  cfg_status                                 => open, 
	  cfg_command                                => open, 
	  cfg_dstatus                                => open, 
	  cfg_lstatus                                => open, 
	  cfg_pcie_link_state                        => open, 
	  cfg_dcommand                               => open, 
	  cfg_lcommand                               => open, 
	  cfg_dcommand2                              => open, 

	  cfg_pmcsr_pme_en                           => open,
	  cfg_pmcsr_powerstate                       => open,
	  cfg_pmcsr_pme_status                       => open,
	  cfg_received_func_lvl_rst                  => open,
	  tx_buf_av                                  => open, 
	  tx_err_drop                                => open, 
	  tx_cfg_req                                 => open,
	  cfg_to_turnoff                             => cfg_to_turnoff ,
	  cfg_bus_number                             => cfg_bus_number ,
	  cfg_device_number                          => cfg_device_number ,
	  cfg_function_number                        => cfg_function_number ,
	  cfg_bridge_serr_en                         => open,
	  cfg_slot_control_electromech_il_ctl_pulse  => open,
	  cfg_root_control_syserr_corr_err_en        => open,
	  cfg_root_control_syserr_non_fatal_err_en   => open,
	  cfg_root_control_syserr_fatal_err_en       => open,
	  cfg_root_control_pme_int_en                => open,
	  cfg_aer_rooterr_corr_err_reporting_en      => open,
	  cfg_aer_rooterr_non_fatal_err_reporting_en => open,
	  cfg_aer_rooterr_fatal_err_reporting_en     => open,
	  cfg_aer_rooterr_corr_err_received          => open,
	  cfg_aer_rooterr_non_fatal_err_received     => open,
	  cfg_aer_rooterr_fatal_err_received         => open,
	  ----------------------------------------------------------------------------------------------
	  -- VC interface                                                                             --
	  ----------------------------------------------------------------------------------------------
	  cfg_vc_tcvc_map                            => open,

	  cfg_msg_received                           => open ,
	  cfg_msg_data                               => open ,
	  cfg_msg_received_pm_as_nak                 => open,
	  cfg_msg_received_setslotpowerlimit         => open,
	  cfg_msg_received_err_cor                   => open,
	  cfg_msg_received_err_non_fatal             => open,
	  cfg_msg_received_err_fatal                 => open,
	  cfg_msg_received_pm_pme                    => open,
	  cfg_msg_received_pme_to_ack                => open,
	  cfg_msg_received_assert_int_a              => open,
	  cfg_msg_received_assert_int_b              => open,
	  cfg_msg_received_assert_int_c              => open,
	  cfg_msg_received_assert_int_d              => open,
	  cfg_msg_received_deassert_int_a            => open,
	  cfg_msg_received_deassert_int_b            => open,
	  cfg_msg_received_deassert_int_c            => open,
	  cfg_msg_received_deassert_int_d            => open,

	  ----------------------------------------- ------------------------------------------------------
	  -- Physical Layer Control and Status (PL ) Interface                                          --                 
	  ----------------------------------------- ------------------------------------------------------
	  ------------------------------------------------
	  -- EP and RP                                    
	  ------------------------------------------------
	  pl_directed_link_change                    => "00", -- Never initiate link change
	  pl_directed_link_width                     => "00", -- Zero out directed link width
	  pl_directed_link_speed                     => '0', -- Zero out directed link speed
	  pl_directed_link_auton                     => '0', -- Zero out link autonomous input
	  pl_upstream_prefer_deemph                  => '1', -- Zero out preferred de-emphasis of upstream port
	  pl_sel_lnk_rate                            => open, 
	  pl_sel_lnk_width                           => open, 
	  pl_ltssm_state                             => open, 
	  pl_lane_reversal_mode                      => open, 
	  pl_phy_lnk_up                              => open,
	  pl_tx_pm_state                             => open,
	  pl_rx_pm_state                             => open,
	  pl_link_upcfg_cap                          => open, 
	  pl_link_gen2_cap                           => open, 
	  pl_link_partner_gen2_supported             => open, 
	  pl_initial_link_width                      => open, 
	  pl_directed_change_done                    => open,

	  --------------------------------------------------   
	  -- EP Only                                      --  
	  --------------------------------------------------  
	  pl_received_hot_rst                        => open, 

	  --------------------------------------------------
	  -- RP Only                                      --
	  --------------------------------------------------
	  pl_transmit_hot_rst                        => '0' ,
	  pl_downstream_deemph_source                => '0' ,



	  -----------------------------------------------------------------------------------------------------
	  -- PCIe DRP (PCIe DRP) Interface                                                                   --
	  -----------------------------------------------------------------------------------------------------
	  pcie_drp_clk                               => '1',
	  pcie_drp_en                                => '0',
	  pcie_drp_we                                => '0',
	  pcie_drp_addr                              => "000000000",
	  pcie_drp_di                                => x"0000",
	  pcie_drp_do                                => open,
	  pcie_drp_rdy                               => open,



	  ------------------------------------------------------------------------------------------------------
	  -- System  (SYS) Interface                                                                          -- 
	  ------------------------------------------------------------------------------------------------------
	  sys_clk                                   =>  sys_clk ,
	  sys_rst_n                                 =>  sys_rst_n_c 

	);

end rtl;
