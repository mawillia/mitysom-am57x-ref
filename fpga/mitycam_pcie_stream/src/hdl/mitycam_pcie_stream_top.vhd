--- Title: mitycam_pcie_stream_top.vhd
--- Description: 
---
---     o  0
---     | /       Copyright (c) 2022
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;
use WORK.MitySOM_AM57_pkg.ALL;
use WORK.mitycam_pkg.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity mitycam_pcie_stream_top is
	generic 
	( 
		g_pixels_per_clock : integer := 4;
		DECODE_BITS : integer := 3 
	);
	port 
	(
		-- GPMC interface
		-- i_gpmc_clk : in  std_logic;
		i_gpmc_cs_n : in  std_logic;
		io_gpmc_ad : inout std_logic_vector(15 downto 0);
		-- i_gpmc_adv_n  : in  std_logic; -- address valid
		i_gpmc_oe_n : in  std_logic; -- output enable
		i_gpmc_we_n : in  std_logic; -- write enable
		i_gpmc_be_n : in  std_logic_vector(1 downto 0); -- byte enable
				
		-- irq interface
		o_sys_nirq : out std_logic_vector(1 downto 0);
		o_cpu_nmi_n : out std_logic;

		-- misc id pins
		i_id : in std_logic_vector(1 downto 0);

		-- PCIe x2 signals
		pci_exp_txp : out std_logic_vector(1 downto 0);
		pci_exp_txn : out std_logic_vector(1 downto 0);
		pci_exp_rxp : in  std_logic_vector(1 downto 0);
		pci_exp_rxn : in  std_logic_vector(1 downto 0);
		
		sys_clk_p : in std_logic; -- 100 MHz clock used for PCIe
		sys_clk_n : in std_logic; -- 100 MHz clock used for PCIe
		sys_rst_n : in std_logic

	);
end mitycam_pcie_stream_top;

architecture rtl of mitycam_pcie_stream_top is

	------------------------------------
	-- Constants
	------------------------------------
	constant APPLICATION_ID : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(42, 8));
	constant VERSION_MAJOR : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 1, 4));
	constant VERSION_MINOR : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 0, 4));
	constant YEAR : std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(22, 5));
	constant MONTH : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(03, 4));
	constant DAY : std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(03, 5));

	constant BM_CORE_CS               : integer := 0;
	constant PCIE_DMA_CORE_CS         : integer := 1;
	constant STREAM_TO_PCIE_CORE_CS   : integer := 2;
	constant TEST_PATTERN_GEN_CORE_CS : integer := 3;

	constant STREAM_TO_PCIE_NUM       : integer := 0;
	constant TEST_PATTERN_GEN_IRQ_NUM : integer := 0;
	constant STREAM_TO_PCIE_VEC       : integer := 0;
	constant TEST_PATTERN_GEN_IRQ_VEC : integer := 1;


	------------------------------------
	-- Signals 
	------------------------------------
	signal sys_clk,clk_100,clk_200,clk_150 : std_logic := '1';
	signal sys_rst_n_c : std_logic := '0';
	signal s_core_be : std_logic_vector(1 downto 0) := "00";
	signal s_core_addr : std_logic_vector(5 downto 0) := (others=>'0');
	signal s_core_cs : std_logic_vector((2**DECODE_BITS)-1 downto 0) := (others=>'0');
	signal s_core_edi : std_logic_vector(15 downto 0) := (others=>'0');
	signal s_core_edo : bus16_vector((2**DECODE_BITS)-1 downto 0) := (others=>(others=>'0'));
	signal s_core_rd : std_logic := '0';
	signal s_core_wr : std_logic := '0';

	signal s_sys_nirq : std_logic_vector(1 downto 0) := (others => '0');
	signal s_debug_irq : std_logic := '0';
	signal s_debug_irq_counter : unsigned(31 downto 0) := (others => '0');
	
	signal s_irq_map : bus32_vector(1 downto 0) := (others=>(others=>'0'));

	signal s_pcie_dma_axi_clk : std_logic; --! Data on *_axis_* is synchronous to this clock.


	signal s_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0) := x"B0BAB4B1DEADBEEF";
	signal s_axis_tlast : STD_LOGIC := '0';
	signal s_axis_tvalid : STD_LOGIC := '1';
	signal s_axis_tready : STD_LOGIC := '0';
	signal s_axis_tkeep : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
	signal s_dma_data_start_addr : std_logic_Vector(31 downto 0) := (others => '0');
	signal s_dma_data_complete_status_sel : std_logic := '0';
	signal s_dma_data_complete : std_logic := '0';

	signal s_test_pattern_data : std_logic_vector(g_pixels_per_clock*16-1 downto 0) := (others=>'0');
	signal s_test_pattern_data_startofpacket : std_logic := '0';
	signal s_test_pattern_data_endofpacket : std_logic := '0';
	signal s_test_pattern_data_ready : std_logic := '0';
	signal s_test_pattern_data_valid : std_logic := '0';

	------------------------------------
	-- Components
	------------------------------------
	component clk_wiz_0 is
		Port ( 
			clk_out1 : out STD_LOGIC;
			clk_out2 : out STD_LOGIC;
			clk_out3 : out STD_LOGIC;
			locked : out STD_LOGIC;
			clk_in1 : in STD_LOGIC
		);
	end component clk_wiz_0;

begin

	o_cpu_nmi_n <= '1'; -- NMI is not used in this project, but should be deasserted

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
	
	mmcm : clk_wiz_0 
		Port Map 
		( 
			clk_out1 => clk_100,
			clk_out2 => clk_200,
			clk_out3 => clk_150,
			locked => open,
			clk_in1 => sys_clk
		);

	async_iface : GPMC_iface
		generic map ( 
			DECODE_BITS   => DECODE_BITS,
			CONFIG        => "ASYNC_MODE"
		)
		port map (
			i_core_clk    => clk_100,
	
			-- GPMC direct-connect signals
			i_gpmc_cs_n   => i_gpmc_cs_n,
			io_gpmc_ad    => io_gpmc_ad,
			i_gpmc_adv_n  => '0',
			i_gpmc_oe_n   => i_gpmc_oe_n,
			i_gpmc_we_n   => i_gpmc_we_n,
			i_gpmc_be_n   => i_gpmc_be_n,

			-- FPGA core interface signals
			o_core_be     => s_core_be,
			o_core_addr   => s_core_addr,
			o_core_cs     => s_core_cs,
			o_core_edi    => s_core_edi,
			i_core_edo    => s_core_edo,
			o_core_rd     => s_core_rd,
			o_core_wr     => s_core_wr
		);
		
	bm : base_module
	generic map (
		CONFIG       => "MitySOM_AM57"
	)
	port map (
		i_clk           => clk_100,
		i_cs            => s_core_cs(BM_CORE_CS),
		i_ID            => APPLICATION_ID,
		i_version_major => VERSION_MAJOR,
		i_version_minor => VERSION_MINOR,
		i_year          => YEAR,
		i_month         => MONTH,
		i_day           => DAY,
		i_ABus          => s_core_addr,
		i_DBus          => s_core_edi,
		o_DBus          => s_core_edo(BM_CORE_CS),
		i_wr_en         => s_core_wr,
		i_rd_en         => s_core_rd,
		i_be_r          => s_core_be,
		i_irq_map       => s_irq_map,
		o_sys_nirq      => s_sys_nirq
	);

	--! Infer the PCIe interface block.
	PCIE_DMA_INST : pcie_dma
		generic map (
			g_num_driving_cores => 1
		)
		port map (
			i_reg_clk => clk_100,

			i_reg_addr => s_core_addr,
			i_reg_data => s_core_edi,
			o_reg_data => s_core_edo(PCIE_DMA_CORE_CS),
			i_reg_wr => s_core_wr,
			i_reg_rd => s_core_rd,
			i_reg_cs => s_core_cs(PCIE_DMA_CORE_CS),

			i_pcie_sys_clk => sys_clk,
			i_pcie_sys_rst_n => sys_rst_n_c,

			o_pci_exp_txp => pci_exp_txp,
			o_pci_exp_txn => pci_exp_txn,
			i_pci_exp_rxp => pci_exp_rxp,
			i_pci_exp_rxn => pci_exp_rxn,

			o_pcie_axi_clk => s_pcie_dma_axi_clk,

			i_dma_data_clk                     => s_pcie_dma_axi_clk,
			i_dma_data_axis_tdata              => s_tdata,
			i_dma_data_axis_tlast(0)           => s_axis_tlast,
			i_dma_data_axis_tvalid(0)          => s_axis_tvalid,
			o_dma_data_axis_tready(0)          => s_axis_tready,
			i_dma_data_axis_tkeep              => s_axis_tkeep,
			i_dma_data_start_addr              => s_dma_data_start_addr,
			i_dma_data_complete_en(0)          => s_dma_data_complete_status_sel,
			o_dma_data_complete(0)             => s_dma_data_complete
		);

	PCIE_STREAMER : stream_to_pcie
			generic map (
				g_packed_pixels_per_clk  => g_pixels_per_clock
			)
			port map (
				i_reg_clk => clk_100,

				i_reg_addr => s_core_addr,
				i_reg_data => s_core_edi,
				o_reg_data => s_core_edo(STREAM_TO_PCIE_CORE_CS),
				i_reg_wr   => s_core_wr,
				i_reg_rd   => s_core_rd,
				i_reg_cs   => s_core_cs(STREAM_TO_PCIE_CORE_CS),
		
				o_irq      => s_irq_map(STREAM_TO_PCIE_NUM)(STREAM_TO_PCIE_VEC),
				i_ilevel   => std_logic'('0'),
				i_ivector  => std_logic_vector(to_unsigned(STREAM_TO_PCIE_VEC,5)),
		
				-- MityCAM streaming interface input
				i_data_clk           => s_pcie_dma_axi_clk,
				i_data_data          => s_test_pattern_data,
				i_data_startofpacket => s_test_pattern_data_startofpacket,
				i_data_endofpacket   => s_test_pattern_data_endofpacket,
				o_data_ready         => s_test_pattern_data_ready,
				i_data_valid         => s_test_pattern_data_valid,
		
				--! Used to stream data to pcie_dma core which is to be DMA'ed into AM57 memory. Used in conjunction with *_dma_* signals.
				i_axi_clk     => s_pcie_dma_axi_clk,
				o_axis_tdata  => s_tdata,
				o_axis_tlast  => s_axis_tlast,
				o_axis_tvalid => s_axis_tvalid,
				i_axis_tready => s_axis_tready,
				o_axis_tkeep  => s_axis_tkeep,
		
				o_dma_data_start_addr => s_dma_data_start_addr,
				o_dma_complete_en     => s_dma_data_complete_status_sel,
				i_dma_data_complete   => s_dma_data_complete
			);

	TP_STREAM : test_pattern_gen 
		generic map (
			g_packed_pixels_per_clk        => g_pixels_per_clock,
			g_bits_per_pixel               => 16,
			g_number_rows                  => 2048,
			g_number_cols                  => 2048,
			g_tp_type                      => std_logic_vector'("000"),
			g_static_val                   => 0,
			g_line_porch                   => 10
		)
		port map (
			i_reg_clk => clk_100,

			i_reg_addr => s_core_addr,
			i_reg_data => s_core_edi,
			o_reg_data => s_core_edo(TEST_PATTERN_GEN_CORE_CS),
			i_reg_wr   => s_core_wr,
			i_reg_rd   => s_core_rd,
			i_reg_cs   => s_core_cs(TEST_PATTERN_GEN_CORE_CS),
	
			o_irq      => s_irq_map(TEST_PATTERN_GEN_IRQ_NUM)(TEST_PATTERN_GEN_IRQ_VEC),
			i_ilevel   => std_logic'('0'),
			i_ivector  => std_logic_vector(to_unsigned(TEST_PATTERN_GEN_IRQ_VEC,5)),

			i_pixel_data_in                => std_logic_vector'(others=>'0'),
			i_pixel_data_in_valid          => std_logic'('0'),
			i_pixel_data_in_endofpacket    => std_logic'('0'),
			i_pixel_data_in_startofpacket  => std_logic'('0'),
	
			o_pixel_data_out               => s_test_pattern_data,
			o_pixel_data_out_valid         => s_test_pattern_data_valid,
			o_pixel_data_out_endofpacket   => s_test_pattern_data_endofpacket,
			o_pixel_data_out_startofpacket => s_test_pattern_data_startofpacket,
	
			i_data_clk                     => s_pcie_dma_axi_clk
		);
		
	o_sys_nirq <= s_sys_nirq;

end rtl;
