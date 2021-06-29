--- Title: pcie_dma.vhd
--- Description: 
---
---     o  0
---     | /       Copyright (c) 2021
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.
-------------------------------------------------------------------------------
-- Note: This started as demo code supplied by Xilinx for a an EP that acts
--  as memory. It was been reworked to create a PCIe DMA example. Leaving
--  original copyright, etc. from Xilinx below since some of this was their
--  code.
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
use ieee.math_real.all;

library unisim;
use unisim.vcomponents.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library xpm;
use xpm.VCOMPONENTS.all;

entity pcie_dma is
	generic 
	(
		g_max_tx_descs : natural := 16 --! Maximum number of tx (FPGA
			--! to AM57) DMA descriptors that can be queued.
	);
	port (
		i_reg_clk : in  std_logic;

		i_reg_addr : in  std_logic_vector(5 downto 0);
		i_reg_data : in  std_logic_vector(15 downto 0);
		o_reg_data : out std_logic_vector(15 downto 0);
		i_reg_wr : in  std_logic;
		i_reg_rd : in  std_logic;
		i_reg_cs : in  std_logic;

		o_irq  : out std_logic := '0';
		i_ilevel : in  std_logic_vector(1 downto 0) := "00";      
		i_ivector : in  std_logic_vector(3 downto 0) := "0000";   
		      
		i_pcie_sys_clk : in std_logic; --! 100 MHz Clock use for PCIe
		i_pcie_sys_rst_n : in std_logic;

		--! PCIe pins:
		pci_exp_txp : out std_logic_vector(1 downto 0);
		pci_exp_txn : out std_logic_vector(1 downto 0);
		pci_exp_rxp : in  std_logic_vector(1 downto 0);
		pci_exp_rxn : in  std_logic_vector(1 downto 0);

		o_axi_clk : out std_logic; --! Data on *_axis_* is synchronous to this clock.

		--! Card (FPGA) to Host (AM57) data interface. This data will be DMA'ed to the AM57 RC (Memory Rd/Wr access L3_MAIN in AM57):
		--!  Note: There is no buffering of this data before it is sent to the PCIe core. It is
		--!	unknown if a full TLP's worth of data needs to be sent without pauses or not.
		--!	TODO: Update this comment once we know if there can be pauses or not.
		--!	 Maybe we need a buffer in this core to counter this caveat??
		i_axis_c2h_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0); --! Data words to be written to AM57 Memory Space
		i_axis_c2h_tlast : IN STD_LOGIC; --! TODO: should probably be doing something with this?!? (Error checking input stream against DMA descriptor??)
		i_axis_c2h_tvalid : IN STD_LOGIC;
		o_axis_c2h_tready : OUT STD_LOGIC;
		i_axis_c2h_tkeep : IN STD_LOGIC_VECTOR(7 DOWNTO 0) --TODO: should probably be doing something with this?? (Error checking input stream against DMA descriptor??)
	);
end pcie_dma;

architecture rtl of pcie_dma is
	attribute DowngradeIPIdentifiedWarnings: string;
	attribute DowngradeIPIdentifiedWarnings of rtl : architecture is "yes";

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

	------------------------------------
	-- Constants
	------------------------------------
	constant VER_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(0, 6));
	constant CTRL_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1, 6));

	constant INT_STATUS_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2, 6));


	constant TX_DMA_START_ADDR_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(4, 6));
	constant TX_DMA_START_ADDR_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(5, 6));

	constant TX_DMA_TOTAL_WORDS_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(6, 6));
	constant TX_DMA_TOTAL_WORDS_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(7, 6));

	constant TX_TLP_MAX_WORDS_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(8, 6));
	constant TX_DMA_NUM_DESC_QUEUE_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(9, 6));


	constant TX_WORD_CNT_TOTAL_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(14, 6));
	constant TX_WORD_CNT_TOTAL_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(15, 6));

	constant TX_DMA_WORDS_REMAIN_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(16, 6));
	constant TX_DMA_WORDS_REMAIN_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(17, 6));

	constant TX_TLP_CNTR_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(18, 6));
	constant TX_TLP_CNTR_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(19, 6));

	constant TX_TLP_CLK_CNTR_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(20, 6));
	constant TX_TLP_CLK_CNTR_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(21, 6));

	constant RX_TLP_DATA_LO_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(24, 6));
	constant RX_TLP_DATA_LO_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(25, 6));
	constant RX_TLP_DATA_HI_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(26, 6));
	constant RX_TLP_DATA_HI_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(27, 6));

	constant RX_TLP_CNTR_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(28, 6));


	constant TX_DMA_DESC_FIFO_COUNT_WIDTH : integer := integer(ceil(log2(real(g_max_tx_descs))));

	constant PCI_EXP_EP_OUI : std_logic_vector(23 downto 0) := x"000A35";
	constant PCI_EXP_EP_DSN_1 : std_logic_vector(31 downto 0) := x"01" & PCI_EXP_EP_OUI;
	constant PCI_EXP_EP_DSN_2 : std_logic_vector(31 downto 0) := x"00000001";

	constant s_axi_clk_FREQ : integer := 2;
	constant s_axi_clk2_DIV2 : string  := "FALSE";
	constant USERCLK2_FREQ : integer := get_userClk2(s_axi_clk2_DIV2, s_axi_clk_FREQ);
	constant LNK_SPD : integer := get_gt_lnk_spd_cfg("FALSE");


	------------------------------------
	-- Signals 
	------------------------------------
	signal s_srst_reg : std_logic := '0';
	signal s_srst_meta : std_logic := '0';
	signal s_srst : std_logic := '0';

	signal s_tx_tlp_send_comp_int : std_logic := '0'; --! Rising edge interrupt set when final write TLP is sent
		--! Only set if requested as part of DMA descriptor and read completion not requested instead.
	signal s_tx_tlp_send_comp_int_meta : std_logic := '0'; 
	signal s_tx_tlp_send_comp_int_reg : std_logic := '0'; 

	signal s_tx_tlp_send_comp_int_en_reg : std_logic := '0'; 

	signal s_tx_tlp_send_comp_int_clr_reg : std_logic := '0'; 
	signal s_tx_tlp_send_comp_int_clr_meta : std_logic := '0'; 
	signal s_tx_tlp_send_comp_int_clr : std_logic := '0'; 
	signal s_tx_tlp_send_comp_int_clr_r1 : std_logic := '0'; 


	signal s_rd_comp_rcved_int : std_logic := '0'; --! Rising edge interrupt set when read request received.
		--! Request for read completion is sent at end of TX DMA if bit is set in DMA descriptor request.
	signal s_rd_comp_rcved_int_meta : std_logic := '0';
	signal s_rd_comp_rcved_int_reg : std_logic := '0';

	signal s_rd_comp_rcved_int_en_reg : std_logic := '0'; 

	signal s_rd_comp_rcved_int_clr_reg : std_logic := '0'; 
	signal s_rd_comp_rcved_int_clr_meta : std_logic := '0'; 
	signal s_rd_comp_rcved_int_clr : std_logic := '0'; 
	signal s_rd_comp_rcved_int_clr_r1 : std_logic := '0'; 

	type t_tx_tlp_state is 
		(
			TX_TLP_IDLE_STATE,
			TX_TLP_CLOCK0_STATE, -- First 64 bits of TLP data as seen in Figure 3-2 in 7 Series FPGAs Integrated Block for PCI Express v3.3 LogiCORE IP Product Guide
			TX_TLP_CLOCK1_STATE, -- Second 64 bits of TLP data as seen in Figure 3-2 in 7 Series FPGAs Integrated Block for PCI Express v3.3 LogiCORE IP Product Guide
			TX_TLP_DATA_STATE, -- Sending remaing 32-bit data words of TLP
			TX_RD_REQ_PREP_STATE, -- Prep to send request at end of DMA request
			TX_RD_REQ_CLOCK0_STATE, -- Send first 64 bits of TLP for read request
			TX_RD_REQ_CLOCK1_STATE -- Send final 32 bits of TLP for read request
		);
	signal s_tx_tlp_state : t_tx_tlp_state := TX_TLP_IDLE_STATE;
	signal s_tx_tlp_state_meta : t_tx_tlp_state := TX_TLP_IDLE_STATE;

	signal s_tx_dma_words_remain_cntr : unsigned(31 downto 0) := (others => '0'); --! Number of 32-bit words remaining to transmit for current DMA request.
	signal s_tx_dma_words_remain_cntr_meta : unsigned(31 downto 0) := (others => '0'); --! Number of 32-bit words remaining to transmit for current DMA request.
	signal s_tx_dma_words_remain_cntr_reg : unsigned(31 downto 0) := (others => '0'); --! Number of 32-bit words remaining to transmit for current DMA request.

	signal s_tx_tlp_max_num_words_reg : std_logic_vector(9 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(32, 10)); --! Maximum number of words per TLP payload.
		--! Must be a power of 2.
	signal s_tx_tlp_max_num_words_meta : unsigned(9 downto 0) := (others => '0');

	signal s_tx_tlp_word_cntr : integer := 0; --! Number of 32-bit words remaining to transmit for current TLP.

	signal s_req_rd_compl : std_logic := '0'; --! Indicates that at end of current TX DMA we do a read request and wait for completion before
		--! generating an interrupt.
	signal s_gen_interrupt : std_logic := '0'; --! Indicates we generate an interrupt once the TX DMA is complete.
	
	signal s_o_axis_c2h_tready : std_logic := '0'; --! Indicates if DMA to AM57 stream needs to pause.

	signal s_tx_tlp_td : std_logic := '0';
	signal s_tx_tlp_ep : std_logic := '0';

	signal s_tx_tlp_attr : std_logic_vector(1 downto 0) := (others => '0');
	signal s_tx_tlp_length : std_logic_vector(9 downto 0) := (others => '0');

	signal s_tx_tlp_fmt : std_logic_vector(1 downto 0) := (others => '0');
	signal s_tx_tlp_type : std_logic_vector(4 downto 0) := (others => '0');
	signal s_tx_tlp_tc : std_logic_vector(2 downto 0) := (others => '0');

	signal s_tx_tlp_tag : std_logic_vector(7 downto 0) := (others => '0');
	signal s_tx_tlp_last_dw_be : std_logic_vector(3 downto 0) := (others => '0');
	signal s_tx_tlp_1st_dw_be : std_logic_vector(3 downto 0) := (others => '0');

	signal s_requestor_id : std_logic_vector(15 downto 0) := (others => '0');

	signal s_tx_tlp_addr : unsigned(31 downto 0) := (others => '0');
	signal s_rd_req_addr : unsigned(31 downto 0) := (others => '0'); -- Keeps track of last address written to in case final read completion is requested at end of DMA

	signal s_i_axis_c2h_tdata : std_logic_vector(63 downto 0) := (others => '0'); 
	signal s_i_axis_c2h_tdata_prev : std_logic_vector(63 downto 0) := (others => '0'); --! Most previously valid data from input stream to DMA to Host (AM57)

	signal s_rx_tlp_data : std_logic_vector(63 downto 0) := (others => '0'); --! Last valid Long Word received from PCIe core AXR RX interface (sent by Host (AM57))
	signal s_rx_tlp_data_meta : std_logic_vector(63 downto 0) := (others => '0'); 
	signal s_rx_tlp_data_reg : std_logic_vector(63 downto 0) := (others => '0'); 
	signal s_rx_tlp_cntr : integer := 0;
	signal s_rx_tlp_cntr_meta : integer := 0;
	signal s_rx_tlp_cntr_reg : integer := 0;

	signal s_tx_word_cnt_total : integer := 0;
	signal s_tx_word_cnt_total_meta : integer := 0;
	signal s_tx_word_cnt_total_reg : std_logic_vector(31 downto 0) := (others => '0');

	signal s_tx_tlp_cntr : integer := 0;
	signal s_tx_tlp_cntr_meta : integer := 0;
	signal s_tx_tlp_cntr_reg : std_logic_vector(31 downto 0) := (others => '0');

	signal s_tx_tlp_clk_cntr : integer := 0;
	signal s_tx_tlp_clk_cntr_meta : integer := 0;
	signal s_tx_tlp_clk_cntr_reg : std_logic_vector(31 downto 0) := (others => '0');

	-- PCIe Core Common
	signal s_axi_clk : std_logic;
	signal user_reset : std_logic;

	-- PCIe Core Tx
	signal s_o_pcie_axis_tx_tready : std_logic := '0';
	signal s_i_pcie_axis_tx_tuser : std_logic_vector (3 downto 0) := (others => '0');
	signal s_i_pcie_axis_tx_tdata : std_logic_vector(63 downto 0) := (others => '0');
	signal s_i_pcie_axis_tx_tkeep : std_logic_vector(7 downto 0) := (others => '0');
	signal s_i_pcie_axis_tx_tlast : std_logic := '0';
	signal s_i_pcie_axis_tx_tvalid : std_logic := '0';

	-- PCIe Core Rx
	signal s_o_pcie_axis_rx_tdata : std_logic_vector(63 downto 0) := (others => '0');
	signal s_o_pcie_axis_rx_tkeep : std_logic_vector(7 downto 0) := (others => '0');
	signal s_o_pcie_axis_rx_tlast : std_logic := '0';
	signal s_o_pcie_axis_rx_tvalid : std_logic := '0';
	signal s_i_pcie_axis_rx_tready : std_logic := '0';
	signal s_o_pcie_axis_rx_tuser : std_logic_vector (21 downto 0) := (others => '0');

	-- PCIe Core Config
	signal cfg_bus_number : std_logic_vector(7 downto 0);
	signal cfg_device_number : std_logic_vector(4 downto 0);
	signal cfg_function_number : std_logic_vector(2 downto 0);

	signal s_tx_dma_desc_fifo_rst : std_logic := '0'; --TODO: needs timing ignore

	signal s_tx_dma_desc_fifo_data_wr_en : std_logic := '0';
	signal s_tx_dma_desc_fifo_data_in : std_logic_vector(63 downto 0) := (others => '0');
	signal s_tx_dma_desc_fifo_overflow : std_logic := '0';
	signal s_tx_dma_desc_fifo_overflow_sticky : std_logic := '0';
	signal s_tx_dma_desc_fifo_overflow_clr : std_logic := '0';
	signal s_tx_dma_desc_fifo_wr_data_count : std_logic_vector(TX_DMA_DESC_FIFO_COUNT_WIDTH-1 downto 0) := (others => '0');

	signal s_tx_dma_desc_fifo_rd_en : std_logic := '0';
	signal s_tx_dma_desc_fifo_data_out : std_logic_vector(63 downto 0) := (others => '0');
	signal s_tx_dma_desc_fifo_empty : std_logic := '0';


	------------------------------------
	-- Components
	------------------------------------
	component xpm_fifo_async 
	      generic(
	      CDC_SYNC_STAGES     : integer := 2;       -- DECIMAL
	      DOUT_RESET_VALUE    : string  := "0";    -- String
	      ECC_MODE            : string  := "no_ecc";       -- String
	      FIFO_MEMORY_TYPE    : string  := "auto"; -- String
	      FIFO_READ_LATENCY   : integer := 1;     -- DECIMAL
	      FIFO_WRITE_DEPTH    : integer := 2048;   -- DECIMAL
	      FULL_RESET_VALUE    : integer := 0;      -- DECIMAL
	      PROG_EMPTY_THRESH   : integer := 10;    -- DECIMAL
	      PROG_FULL_THRESH    : integer := 10;     -- DECIMAL
	      RD_DATA_COUNT_WIDTH : integer := 1;   -- DECIMAL
	      READ_DATA_WIDTH     : integer := 32;      -- DECIMAL
	      READ_MODE           : string  := "std";         -- String
	      RELATED_CLOCKS      : integer := 0;        -- DECIMAL
	      USE_ADV_FEATURES    : string  := "0707"; -- String
	      WAKEUP_TIME         : integer := 0;           -- DECIMAL
	      WRITE_DATA_WIDTH    : integer := 32;     -- DECIMAL
	      WR_DATA_COUNT_WIDTH : integer := 1    -- DECIMAL
	   );
	    port (sleep, rst, wr_clk, wr_en, rd_en, rd_clk, injectdbiterr, injectsbiterr: in std_logic; 
		      wr_rst_busy, wr_ack, almost_empty, almost_full, data_valid, empty, full, overflow, underflow, rd_rst_busy, prog_empty, prog_full, sbiterr, dbiterr: out std_logic;
		      din: in std_logic_vector (WRITE_DATA_WIDTH-1 downto 0);
		      dout: out std_logic_vector (READ_DATA_WIDTH-1 downto 0);
		      rd_data_count: out std_logic_vector (RD_DATA_COUNT_WIDTH-1 downto 0);
		      wr_data_count: out std_logic_vector (WR_DATA_COUNT_WIDTH-1 downto 0));
	end component;

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

begin

	o_irq <= (s_tx_tlp_send_comp_int and s_tx_tlp_send_comp_int_en_reg) or (s_rd_comp_rcved_int and s_rd_comp_rcved_int_en_reg);

	REG_WRITE_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			s_tx_dma_desc_fifo_rst <= s_srst_reg;

			s_tx_dma_desc_fifo_data_wr_en <= '0';

			if (i_reg_cs = '1' and i_reg_wr = '1') then
				case i_reg_addr is
					when VER_REG_OFFSET =>
						null;

					when CTRL_REG_OFFSET =>
						s_srst_reg <= i_reg_data(0);

						s_tx_tlp_send_comp_int_en_reg <= i_reg_data(4);
						s_rd_comp_rcved_int_en_reg <= i_reg_data(5);

					when INT_STATUS_REG_OFFSET =>
						if (i_reg_data(0) = '1') then
							s_tx_tlp_send_comp_int_clr_reg <= not(s_tx_tlp_send_comp_int_clr_reg);
						end if;
						if (i_reg_data(1) = '1') then
							s_rd_comp_rcved_int_clr_reg <= not(s_rd_comp_rcved_int_clr_reg);
						end if;

					when TX_DMA_START_ADDR_LO_REG_OFFSET =>
						s_tx_dma_desc_fifo_data_in(15 downto 0) <= i_reg_data(15 downto 0);

					when TX_DMA_START_ADDR_HI_REG_OFFSET =>
						s_tx_dma_desc_fifo_data_in(31 downto 16) <= i_reg_data(15 downto 0);


					when TX_DMA_TOTAL_WORDS_LO_REG_OFFSET =>
						s_tx_dma_desc_fifo_data_in(47 downto 32) <= i_reg_data(15 downto 0);

					when TX_DMA_TOTAL_WORDS_HI_REG_OFFSET =>
						s_tx_dma_desc_fifo_data_in(63) <= i_reg_data(15); -- Request DMA read completion as part of this DMA
							-- to prevent race condition if not using MSI
						s_tx_dma_desc_fifo_data_in(62) <= i_reg_data(14); -- Generate interrupt at end of DMA
						s_tx_dma_desc_fifo_data_in(61 downto 48) <= i_reg_data(13 downto 0);

						s_tx_dma_desc_fifo_data_wr_en <= '1';


					when TX_TLP_MAX_WORDS_REG_OFFSET =>
						s_tx_tlp_max_num_words_reg(9 downto 0) <= i_reg_data(9 downto 0);
						
					when others =>
						null;
				end case;
			end if;
		end if;
	end process REG_WRITE_PROC;


	REG_READ_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			o_reg_data <= (others => '0');

			s_tx_tlp_state_meta <= s_tx_tlp_state;

			s_tx_tlp_send_comp_int_meta <= s_tx_tlp_send_comp_int;
			s_tx_tlp_send_comp_int_reg <= s_tx_tlp_send_comp_int_meta;

			s_rd_comp_rcved_int_meta <= s_rd_comp_rcved_int;
			s_rd_comp_rcved_int_reg <= s_rd_comp_rcved_int_meta;

			s_rx_tlp_data_meta <= s_rx_tlp_data;
			s_rx_tlp_data_reg <= s_rx_tlp_data_meta;

			s_rx_tlp_cntr_meta <= s_rx_tlp_cntr;
			s_rx_tlp_cntr_reg <= s_rx_tlp_cntr_meta;

			s_tx_word_cnt_total_meta <= s_tx_word_cnt_total;
			s_tx_word_cnt_total_reg <= STD_LOGIC_VECTOR(TO_UNSIGNED(s_tx_word_cnt_total_meta, 32));

			s_tx_dma_words_remain_cntr_meta	<= s_tx_dma_words_remain_cntr;
			s_tx_dma_words_remain_cntr_reg <= s_tx_dma_words_remain_cntr_meta;

			s_tx_tlp_cntr_meta <= s_tx_tlp_cntr;
			s_tx_tlp_cntr_reg <= STD_LOGIC_VECTOR(TO_UNSIGNED(s_tx_tlp_cntr_meta, 32));

			s_tx_tlp_clk_cntr_meta <= s_tx_tlp_clk_cntr;
			s_tx_tlp_clk_cntr_reg <= STD_LOGIC_VECTOR(TO_UNSIGNED(s_tx_tlp_clk_cntr_meta, 32));

			if (i_reg_cs = '1') then
				case i_reg_addr is
					when VER_REG_OFFSET =>
						o_reg_data <= x"B0B9";

					when CTRL_REG_OFFSET =>
						o_reg_data(0) <= s_srst_reg;

						o_reg_data(4) <= s_tx_tlp_send_comp_int_en_reg;
						o_reg_data(5) <= s_rd_comp_rcved_int_en_reg;


						if (s_tx_tlp_state_meta = TX_TLP_IDLE_STATE) then
							o_reg_data(8) <= '1';
						end if;
						if (s_tx_tlp_state_meta = TX_TLP_CLOCK0_STATE) then
							o_reg_data(9) <= '1';
						end if;
						if (s_tx_tlp_state_meta = TX_TLP_CLOCK1_STATE) then
							o_reg_data(10) <= '1';
						end if;
						if (s_tx_tlp_state_meta = TX_TLP_DATA_STATE) then
							o_reg_data(11) <= '1';
						end if;
						if (s_tx_tlp_state_meta = TX_RD_REQ_PREP_STATE) then
							o_reg_data(12) <= '1';
						end if;
						if (s_tx_tlp_state_meta = TX_RD_REQ_CLOCK0_STATE) then
							o_reg_data(13) <= '1';
						end if;
						if (s_tx_tlp_state_meta = TX_RD_REQ_CLOCK1_STATE) then
							o_reg_data(14) <= '1';
						end if;

					when INT_STATUS_REG_OFFSET =>
						o_reg_data(0) <= s_tx_tlp_send_comp_int_reg;
						o_reg_data(1) <= s_rd_comp_rcved_int_reg;

					when TX_DMA_START_ADDR_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_dma_desc_fifo_data_in(15 downto 0);

					when TX_DMA_START_ADDR_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_dma_desc_fifo_data_in(31 downto 16);


					when TX_DMA_TOTAL_WORDS_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_dma_desc_fifo_data_in(47 downto 32);

					when TX_DMA_TOTAL_WORDS_HI_REG_OFFSET =>
						o_reg_data(15) <= s_tx_dma_desc_fifo_data_in(63); -- Request DMA read completion as part of this DMA
							-- to prevent race condition if not using MSI
						o_reg_data(14) <= s_tx_dma_desc_fifo_data_in(62); -- Generate interrupt at end of DMA
						o_reg_data(13 downto 0) <= s_tx_dma_desc_fifo_data_in(61 downto 48);


					when TX_TLP_MAX_WORDS_REG_OFFSET =>
						o_reg_data(9 downto 0) <= s_tx_tlp_max_num_words_reg(9 downto 0);


					when TX_DMA_NUM_DESC_QUEUE_REG_OFFSET => 
						o_reg_data(TX_DMA_DESC_FIFO_COUNT_WIDTH-1 downto 0) <= s_tx_dma_desc_fifo_wr_data_count;


					when RX_TLP_DATA_LO_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_rx_tlp_data_reg(15 downto 0);

					when RX_TLP_DATA_LO_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_rx_tlp_data_reg(31 downto 16);

					when RX_TLP_DATA_HI_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_rx_tlp_data_reg(47 downto 32);

					when RX_TLP_DATA_HI_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_rx_tlp_data_reg(63 downto 48);


					when RX_TLP_CNTR_REG_OFFSET =>
						o_reg_data(15 downto 0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(s_rx_tlp_cntr_reg, 16));


					when TX_WORD_CNT_TOTAL_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_word_cnt_total_reg(15 downto 0);

					when TX_WORD_CNT_TOTAL_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_word_cnt_total_reg(31 downto 16);


					when TX_DMA_WORDS_REMAIN_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= STD_LOGIC_VECTOR(s_tx_dma_words_remain_cntr_reg(15 downto 0));

					when TX_DMA_WORDS_REMAIN_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= STD_LOGIC_VECTOR(s_tx_dma_words_remain_cntr_reg(31 downto 16));


					when TX_TLP_CNTR_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_tlp_cntr_reg(15 downto 0);

					when TX_TLP_CNTR_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_tlp_cntr_reg(31 downto 16);


					when TX_TLP_CLK_CNTR_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_tlp_clk_cntr_reg(15 downto 0);

					when TX_TLP_CLK_CNTR_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_tx_tlp_clk_cntr_reg(31 downto 16);


					when others =>
						o_reg_data <= x"DEAD";
				end case;
			end if;
		end if;
	end process REG_READ_PROC;

	--! FIFO for queueing transmit (FPGA to AM57) DMA Descriptors
	--!  See UG953 for further details on this component
	TX_DMA_DESC_FIFO_INST : xpm_fifo_async
		generic map 
		(
			FIFO_MEMORY_TYPE        => "auto",  --string; "auto", "block", or "distributed";
			ECC_MODE                => "no_ecc", --string; "no_ecc" or "en_ecc";
			RELATED_CLOCKS          => 0, --positive integer; 0 or 1
			FIFO_WRITE_DEPTH        => g_max_tx_descs, --positive integer
			WRITE_DATA_WIDTH        => 64, --positive integer
			WR_DATA_COUNT_WIDTH     => TX_DMA_DESC_FIFO_COUNT_WIDTH, --positive integer
			PROG_FULL_THRESH        => g_max_tx_descs-5, --positive integer
			FULL_RESET_VALUE        => 0, --positive integer; 0 or 1;
			READ_MODE               => "fwft", --string; "std" or "fwft";
			FIFO_READ_LATENCY       => 0, --positive integer;
			READ_DATA_WIDTH         => 64, --positive integer
			RD_DATA_COUNT_WIDTH     => TX_DMA_DESC_FIFO_COUNT_WIDTH, --positive integer
			PROG_EMPTY_THRESH       => 10, --positive integer
			USE_ADV_FEATURES        => "0006", 	-- [0] to 1 enables overflow flag
								-- [2] to 1 enables wr_data_count
			DOUT_RESET_VALUE        => "0", --string
			CDC_SYNC_STAGES         => 2, --positive integer
			WAKEUP_TIME             => 0 --positive integer; 0 or 2;
		)
		port map 
		(
			sleep            => '0',
			rst              => s_tx_dma_desc_fifo_rst,
			wr_clk           => i_reg_clk,
			wr_ack           => open,
			wr_en            => s_tx_dma_desc_fifo_data_wr_en, 
			din              => s_tx_dma_desc_fifo_data_in,
			full             => open, 
			almost_full      => open, 
			overflow         => s_tx_dma_desc_fifo_overflow,
			wr_rst_busy      => open,
			rd_clk           => s_axi_clk,
			rd_en            => s_tx_dma_desc_fifo_rd_en,
			dout             => s_tx_dma_desc_fifo_data_out, 
			empty            => s_tx_dma_desc_fifo_empty,
			almost_empty     => open, 
			underflow        => open, 
			data_valid       => open, 
			rd_rst_busy      => open, 
			prog_full        => open,
			wr_data_count    => s_tx_dma_desc_fifo_wr_data_count,
			prog_empty       => open,
			rd_data_count    => open,
			injectsbiterr    => '0',
			injectdbiterr    => '0',
			sbiterr          => open,
			dbiterr          => open
		);


	s_requestor_id <= cfg_bus_number & cfg_device_number & cfg_function_number;

	--! Control state for building TLPs (and DMAing input data
	TX_TLP_STATE_PROC : process(s_axi_clk)
		variable v_tx_dma_total_word_cntr : unsigned(31 downto 0) := (others => '0');
	begin
		if rising_edge(s_axi_clk) then
			s_srst_meta <= s_srst_reg;
			s_srst <= s_srst_meta;

			s_tx_tlp_max_num_words_meta <= UNSIGNED(s_tx_tlp_max_num_words_reg);

			s_tx_dma_desc_fifo_rd_en <= '0';

			if (i_axis_c2h_tvalid = '1' and s_o_axis_c2h_tready = '1') then
				s_i_axis_c2h_tdata_prev <= s_i_axis_c2h_tdata;
			end if;

			s_tx_tlp_send_comp_int_clr_meta <= s_tx_tlp_send_comp_int_clr_reg;
			s_tx_tlp_send_comp_int_clr <= s_tx_tlp_send_comp_int_clr_meta;
			s_tx_tlp_send_comp_int_clr_r1 <= s_tx_tlp_send_comp_int_clr;

			if (s_tx_tlp_send_comp_int_clr_r1 /= s_tx_tlp_send_comp_int_clr) then
				s_tx_tlp_send_comp_int <= '0';
			end if;

			if (s_srst = '1') then
				s_tx_tlp_state <= TX_TLP_IDLE_STATE;
				s_tx_dma_words_remain_cntr <= (others => '0');
				s_tx_word_cnt_total <= 0;
				s_tx_tlp_cntr <= 0;
			else
				case s_tx_tlp_state is
					when TX_TLP_IDLE_STATE =>
						v_tx_dma_total_word_cntr := s_tx_dma_words_remain_cntr;

						-- If we are done with current DMA...
						if (s_tx_dma_words_remain_cntr = 0) then
							-- Check if we need to generate an interrupt or if another DMA is request is queue in FIFO
							if (s_req_rd_compl = '1') then
								s_req_rd_compl <= '0';

								s_tx_tlp_state <= TX_RD_REQ_PREP_STATE;
							elsif (s_gen_interrupt = '1' ) then
								s_gen_interrupt <= '0';

								s_tx_tlp_send_comp_int <= '1';
							elsif (s_tx_dma_desc_fifo_empty = '0') then
								s_req_rd_compl <= s_tx_dma_desc_fifo_data_out(63);

								s_gen_interrupt <= s_tx_dma_desc_fifo_data_out(62);

								-- Set up total number of words to be transferred as part of this DMA
								v_tx_dma_total_word_cntr := UNSIGNED("00" & s_tx_dma_desc_fifo_data_out(61 downto 32));

								s_tx_tlp_addr <= UNSIGNED(s_tx_dma_desc_fifo_data_out(31 downto 0));

								-- We have registered DMA descriptor info, clear it from FIFO
								s_tx_dma_desc_fifo_rd_en <= '1';

								s_tx_tlp_clk_cntr <= 0;
							end if;
						end if;

						-- Check if we need to send another TLP to continue working on current DMA
						if (TO_INTEGER(v_tx_dma_total_word_cntr) > 0) then
							s_tx_tlp_state <= TX_TLP_CLOCK0_STATE;
						end if;

						-- Reset counter for number of words to send for next TLP
						if (v_tx_dma_total_word_cntr > s_tx_tlp_max_num_words_meta) then 
							s_tx_tlp_word_cntr <= TO_INTEGER(s_tx_tlp_max_num_words_meta);
						else
							s_tx_tlp_word_cntr <= TO_INTEGER(v_tx_dma_total_word_cntr);
						end if;

						-- Will not be adding extra CRC to TLP data
						s_tx_tlp_td <= '0';
						-- Unused (for now at least)
						s_tx_tlp_ep <= '0';
						-- Unused (for now at least)
						s_tx_tlp_attr <= "00";
						-- Calculate number of 32-bit words in this TLP
						if (v_tx_dma_total_word_cntr > s_tx_tlp_max_num_words_meta) then
							s_tx_tlp_length <= STD_LOGIC_VECTOR(s_tx_tlp_max_num_words_meta(9 downto 0));
						else
							s_tx_tlp_length <= STD_LOGIC_VECTOR(v_tx_dma_total_word_cntr(9 downto 0));
						end if;

						-- Setup TLP Header values:
						-- Mark this as a memory write
						s_tx_tlp_fmt <= "10";
						-- Mark this as a memory write
						s_tx_tlp_type <= "00000";
						-- Unused (for now at least)
						s_tx_tlp_tc <= "000";
						-- Tag unused in write requests
						s_tx_tlp_tag <= "00000000";

						-- Case of transmitting only one word is special
						if (TO_INTEGER(v_tx_dma_total_word_cntr) = 1) then
							s_tx_tlp_last_dw_be <= "0000";
						else
							s_tx_tlp_last_dw_be <= "1111";
						end if;

						-- Always transmist at least 4 bytes
						s_tx_tlp_1st_dw_be <= "1111";
						
						s_tx_dma_words_remain_cntr <= v_tx_dma_total_word_cntr;

					when TX_TLP_CLOCK0_STATE => 
						if (s_o_pcie_axis_tx_tready = '1') then
							s_tx_tlp_state <= TX_TLP_CLOCK1_STATE;

							s_tx_tlp_cntr <= s_tx_tlp_cntr + 1;
						end if;

						s_tx_tlp_clk_cntr <= s_tx_tlp_clk_cntr + 1;

					when TX_TLP_CLOCK1_STATE =>
						if (s_o_pcie_axis_tx_tready = '1' and i_axis_c2h_tvalid = '1') then
							if (s_tx_tlp_word_cntr > 1) then
								s_tx_tlp_state <= TX_TLP_DATA_STATE;
							else 
								s_tx_tlp_state <= TX_TLP_IDLE_STATE;
							end if;

							s_tx_dma_words_remain_cntr <= s_tx_dma_words_remain_cntr - 1;


							s_tx_tlp_word_cntr <= s_tx_tlp_word_cntr - 1;

							s_tx_tlp_addr <= s_tx_tlp_addr + 4;

							-- Want to read last word written
							s_rd_req_addr <= s_tx_tlp_addr;

							s_tx_word_cnt_total <= s_tx_word_cnt_total + 1;
						end if;

						s_tx_tlp_clk_cntr <= s_tx_tlp_clk_cntr + 1;

					when TX_TLP_DATA_STATE =>
						if (s_o_pcie_axis_tx_tready = '1' and i_axis_c2h_tvalid = '1') then
							if (s_tx_tlp_word_cntr >= 2) then
								s_tx_dma_words_remain_cntr <= s_tx_dma_words_remain_cntr - 2;

								s_tx_tlp_word_cntr <= s_tx_tlp_word_cntr - 2;

								s_tx_tlp_addr <= s_tx_tlp_addr + 8;

								-- Want to read last word written
								s_rd_req_addr <= s_tx_tlp_addr + 4;

								s_tx_word_cnt_total <= s_tx_word_cnt_total + 2;
							else
								s_tx_dma_words_remain_cntr <= s_tx_dma_words_remain_cntr - 1;

								s_tx_tlp_word_cntr <= s_tx_tlp_word_cntr - 1;

								s_tx_tlp_addr <= s_tx_tlp_addr + 4;

								-- Want to read last word written
								s_rd_req_addr <= s_tx_tlp_addr;

								s_tx_word_cnt_total <= s_tx_word_cnt_total + 1;
							end if;

							if (s_tx_tlp_word_cntr <= 2) then
								s_tx_tlp_state <= TX_TLP_IDLE_STATE;
							end if;
						end if;

						s_tx_tlp_clk_cntr <= s_tx_tlp_clk_cntr + 1;

					when TX_RD_REQ_PREP_STATE =>
						s_tx_tlp_state <= TX_RD_REQ_CLOCK0_STATE;

						-- Will not be adding extra CRC to TLP data
						s_tx_tlp_td <= '0';
						-- Unused (for now at least)
						s_tx_tlp_ep <= '0';
						-- Unused (for now at least)
						s_tx_tlp_attr <= "00";
						-- Requesting one 1 32-bit read
						s_tx_tlp_length <= "0000000001";

						-- Setup TLP Header values:
						-- Mark this as a memory read 
						s_tx_tlp_fmt <= "00";
						-- Mark this as a memory read
						s_tx_tlp_type <= "00000";
						-- Unused (for now at least)
						s_tx_tlp_tc <= "000";
						-- Tag unused in read requests
						s_tx_tlp_tag <= "00000000";

						-- Unused in read requests
						s_tx_tlp_last_dw_be <= "0000";

						-- Always transmist at least 4 bytes
						s_tx_tlp_1st_dw_be <= "1111";
						
					when TX_RD_REQ_CLOCK0_STATE => 
						if (s_o_pcie_axis_tx_tready = '1') then
							s_tx_tlp_state <= TX_RD_REQ_CLOCK1_STATE;
						end if;

						s_tx_tlp_clk_cntr <= s_tx_tlp_clk_cntr + 1;

					when TX_RD_REQ_CLOCK1_STATE =>
						if (s_o_pcie_axis_tx_tready = '1') then
							s_tx_tlp_state <= TX_TLP_IDLE_STATE;
						end if;

						s_tx_tlp_clk_cntr <= s_tx_tlp_clk_cntr + 1;
				end case;	
			end if;
		end if;
	end process TX_TLP_STATE_PROC;

	-- Not using PCIe core data ECRC generation or other features enabled by these bits
	s_i_pcie_axis_tx_tuser <= "0000";

	-- Adjust endianness of incoming data
	s_i_axis_c2h_tdata(7 downto 0) <= i_axis_c2h_tdata(31 downto 24);
	s_i_axis_c2h_tdata(15 downto 8) <= i_axis_c2h_tdata(23 downto 16);
	s_i_axis_c2h_tdata(23 downto 16) <= i_axis_c2h_tdata(15 downto 8);
	s_i_axis_c2h_tdata(31 downto 24) <= i_axis_c2h_tdata(7 downto 0);

	s_i_axis_c2h_tdata(39 downto 32) <= i_axis_c2h_tdata(63 downto 56);
	s_i_axis_c2h_tdata(47 downto 40) <= i_axis_c2h_tdata(55 downto 48);
	s_i_axis_c2h_tdata(55 downto 48) <= i_axis_c2h_tdata(47 downto 40);
	s_i_axis_c2h_tdata(63 downto 56) <= i_axis_c2h_tdata(39 downto 32);

	--! State for changing what goes into s_axis_tx_* PCIe core input interface based on state
	PCIE_AXI_TX_PROC : process(s_axi_clk)
	begin
		case s_tx_tlp_state is
			when TX_TLP_IDLE_STATE =>
				s_i_pcie_axis_tx_tdata <= (others => '0');

				s_i_pcie_axis_tx_tvalid <= '0';

				s_i_pcie_axis_tx_tlast <= '0';

				s_i_pcie_axis_tx_tkeep <= "11111111";

				s_o_axis_c2h_tready <= '0';

			when TX_TLP_CLOCK0_STATE =>
				s_i_pcie_axis_tx_tdata(15 downto 0) <= s_tx_tlp_td & s_tx_tlp_ep & s_tx_tlp_attr & "00" & s_tx_tlp_length;
				s_i_pcie_axis_tx_tdata(31 downto 16) <= "0" & s_tx_tlp_fmt & s_tx_tlp_type & "0" & s_tx_tlp_tc & "0000";
				s_i_pcie_axis_tx_tdata(47 downto 32) <= s_tx_tlp_tag & s_tx_tlp_last_dw_be & s_tx_tlp_1st_dw_be;
				s_i_pcie_axis_tx_tdata(63 downto 48) <= s_requestor_id;

				s_i_pcie_axis_tx_tvalid <= '1';

				s_i_pcie_axis_tx_tlast <= '0';

				s_i_pcie_axis_tx_tkeep <= "11111111";

				s_o_axis_c2h_tready <= '0';

			when TX_TLP_CLOCK1_STATE =>
				s_i_pcie_axis_tx_tdata(31 downto 0) <= std_logic_vector(s_tx_tlp_addr(31 downto 2)) & "00";
				s_i_pcie_axis_tx_tdata(63 downto 32) <= s_i_axis_c2h_tdata(31 downto 0);

				s_i_pcie_axis_tx_tvalid <= i_axis_c2h_tvalid;

				if (s_tx_tlp_word_cntr > 1) then
					s_i_pcie_axis_tx_tlast <= '0';
				else
					s_i_pcie_axis_tx_tlast <= '1';
				end if;

				s_i_pcie_axis_tx_tkeep <= "11111111";

				s_o_axis_c2h_tready <= s_o_pcie_axis_tx_tready;

			when TX_TLP_DATA_STATE =>
				s_i_pcie_axis_tx_tdata(31 downto 0) <= s_i_axis_c2h_tdata_prev(63 downto 32);
				s_i_pcie_axis_tx_tdata(63 downto 32) <= s_i_axis_c2h_tdata(31 downto 0);

				s_i_pcie_axis_tx_tvalid <= i_axis_c2h_tvalid;

				if (s_tx_tlp_word_cntr > 2) then
					s_i_pcie_axis_tx_tlast <= '0';
				else
					s_i_pcie_axis_tx_tlast <= '1';
				end if;


				-- Smallest data unit we care about is words in this core
				--  so there are only ever two options for specifying bytes to keep
				if (s_tx_tlp_word_cntr > 1) then
					s_i_pcie_axis_tx_tkeep <= "11111111";
				else
					s_i_pcie_axis_tx_tkeep <= "00001111";
				end if;

				if (s_tx_tlp_word_cntr = 1) then
					-- If only transmitting 1 32-bit word we only use s_i_axis_c2h_tdata_prev data and should
					--  not say we used any of the current data on the buss
					s_o_axis_c2h_tready <= '0';
				else
					s_o_axis_c2h_tready <= s_o_pcie_axis_tx_tready;
				end if;

			when TX_RD_REQ_PREP_STATE =>
				s_i_pcie_axis_tx_tdata <= (others => '0');

				s_i_pcie_axis_tx_tvalid <= '0';

				s_i_pcie_axis_tx_tlast <= '0';

				s_i_pcie_axis_tx_tkeep <= "11111111";

				s_o_axis_c2h_tready <= '0';

			when TX_RD_REQ_CLOCK0_STATE =>
				s_i_pcie_axis_tx_tdata(15 downto 0) <= s_tx_tlp_td & s_tx_tlp_ep & s_tx_tlp_attr & "00" & s_tx_tlp_length;
				s_i_pcie_axis_tx_tdata(31 downto 16) <= "0" & s_tx_tlp_fmt & s_tx_tlp_type & "0" & s_tx_tlp_tc & "0000";
				s_i_pcie_axis_tx_tdata(47 downto 32) <= s_tx_tlp_tag & s_tx_tlp_last_dw_be & s_tx_tlp_1st_dw_be;
				s_i_pcie_axis_tx_tdata(63 downto 48) <= s_requestor_id;

				s_i_pcie_axis_tx_tvalid <= '1';

				s_i_pcie_axis_tx_tlast <= '0';

				s_i_pcie_axis_tx_tkeep <= "11111111";

				s_o_axis_c2h_tready <= '0';

			when TX_RD_REQ_CLOCK1_STATE =>
				s_i_pcie_axis_tx_tdata(31 downto 0) <= std_logic_vector(s_rd_req_addr(31 downto 2)) & "00";
				s_i_pcie_axis_tx_tdata(63 downto 32) <= (others => '0');

				s_i_pcie_axis_tx_tvalid <= '1';

				s_i_pcie_axis_tx_tlast <= '1';

				s_i_pcie_axis_tx_tkeep <= "00001111";

				s_o_axis_c2h_tready <= '0';
		end case;
	end process PCIE_AXI_TX_PROC;

	o_axis_c2h_tready <= s_o_axis_c2h_tready;

	--! Process for receiving TLPs from AM57. For now debug, but eventually will maybe add logic for DMA from Host (AM57) to Card (FPGA)
	PCIE_AXI_RX_PROC : process(s_axi_clk)
	begin
		if rising_edge(s_axi_clk) then
			-- For now always accept TLP data from PCIe Host (AM57)
			s_i_pcie_axis_rx_tready <= '1';

			s_rd_comp_rcved_int_clr_meta <= s_rd_comp_rcved_int_clr_reg;	
			s_rd_comp_rcved_int_clr <= s_rd_comp_rcved_int_clr_meta;	
			s_rd_comp_rcved_int_clr_r1 <= s_rd_comp_rcved_int_clr;	

			if (s_rd_comp_rcved_int_clr_r1 /= s_rd_comp_rcved_int_clr) then
				s_rd_comp_rcved_int <= '0';
			end if;

			if (s_srst = '1') then
				s_rx_tlp_data <= (others => '0');

				s_rx_tlp_cntr <= 0;
			else
				if (s_o_pcie_axis_rx_tvalid = '1') then
					s_rx_tlp_data <= s_o_pcie_axis_rx_tdata;

					-- Generate interrupt on last word received
					--  We should only received requested read completions in current used case
					--   but maybe we should add some checks rather than interrupting blindly??
					if (s_o_pcie_axis_rx_tlast = '1') then
						s_rd_comp_rcved_int <= '1';
					end if;

					s_rx_tlp_cntr <= s_rx_tlp_cntr + 1;
				end if;
			end if;
		end if;
	end process PCIE_AXI_RX_PROC;

	-- DO NOT CHANGE INSTANTIATION NAME! constraints (.xdc) file looks for this for properly constrain PCIe core
	pcie_7x_0_support_i : pcie_7x_0_support 
	 generic map
	   (	 
	    LINK_CAP_MAX_LINK_WIDTH       =>   2 ,  -- PCIe Lane Width
	    C_DATA_WIDTH                  =>   64,                       -- RX/TX interface data width
	    KEEP_WIDTH                    =>   8 ,                         -- TSTRB width
	    PCIE_REFCLK_FREQ              =>   0 , -- PCIe reference clock frequency
	    PCIE_LINK_SPEED               =>   LNK_SPD,
	    PCIE_USERCLK1_FREQ            =>   s_axi_clk_FREQ +1 ,                   -- PCIe user clock 1 frequency
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
	  pipe_pclk_sel_slave                        => (others => '0'),
	  pipe_mmcm_rst_n                            => '1',       -- // Async      | Async


	  ----------------------------------------------------------------------------------------------------------------
	  -- AXI-S Interface                                                                                            --  
	  ----------------------------------------------------------------------------------------------------------------
	  -- Common
	  user_clk_out                               => s_axi_clk ,
	  user_reset_out                             => user_reset ,
	  user_lnk_up                                => open,
	  user_app_rdy                               => open ,

	  -- TX
	  s_axis_tx_tready                           => s_o_pcie_axis_tx_tready,
	  s_axis_tx_tdata                            => s_i_pcie_axis_tx_tdata,
	  s_axis_tx_tkeep                            => s_i_pcie_axis_tx_tkeep,
	  s_axis_tx_tuser                            => s_i_pcie_axis_tx_tuser,
	  s_axis_tx_tlast                            => s_i_pcie_axis_tx_tlast,
	  s_axis_tx_tvalid                           => s_i_pcie_axis_tx_tvalid,

	  -- Rx
	  m_axis_rx_tdata                            => s_o_pcie_axis_rx_tdata,
	  m_axis_rx_tkeep                            => s_o_pcie_axis_rx_tkeep,
	  m_axis_rx_tlast                            => s_o_pcie_axis_rx_tlast,
	  m_axis_rx_tvalid                           => s_o_pcie_axis_rx_tvalid,
	  m_axis_rx_tready                           => s_i_pcie_axis_rx_tready,
	  m_axis_rx_tuser                            => s_o_pcie_axis_rx_tuser,

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
	  cfg_turnoff_ok                             => '1',
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
	  cfg_to_turnoff                             => open,
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
	  sys_clk                                   =>  i_pcie_sys_clk,
	  sys_rst_n                                 =>  i_pcie_sys_rst_n 

	);

	o_axi_clk <= s_axi_clk;

end rtl;
