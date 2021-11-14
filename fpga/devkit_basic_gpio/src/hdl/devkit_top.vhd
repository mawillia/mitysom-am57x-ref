--- Title: base_module.vhd
--- Description: 
---
---     o  0
---     | /       Copyright (c) 2020
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.
--- Date: 7/13/2020
--- Version: 1.00
--- Revisions: 
---   1.00 - Initial release.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;
use WORK.MitySOM_AM57_pkg.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity devkit_top is
	generic ( DECODE_BITS   : integer := 2 ) ;
	port (
		-- GPMC interface
		-- i_gpmc_clk    : in  std_logic;
		i_gpmc_cs_n   : in  std_logic;
		io_gpmc_ad    : inout std_logic_vector(15 downto 0);
		-- i_gpmc_adv_n  : in  std_logic; -- address valid
		i_gpmc_oe_n   : in  std_logic; -- output enable
		i_gpmc_we_n   : in  std_logic; -- write enable
		i_gpmc_be_n   : in  std_logic_vector(1 downto 0); -- byte enable
		
		-- VIN4A interface (MUST USE EMBEDDED SYNC MODES)
		o_vin_hsync   : out std_logic := '0'; -- external sync option (active high)
		o_vin_vsync   : out std_logic := '0'; -- external sync option (active high)
		o_vin_d       : out std_logic_vector(23 downto 0);
		o_vin_clk     : out std_logic;
		
		-- irq interface
		o_sys_nirq    : out std_logic_vector(1 downto 0);
		o_cpu_nmi_n   : out std_logic;

		-- misc id pins
		i_id          : in std_logic_vector(1 downto 0);

		-- PCIe x2 signals
		pci_exp_txp                   : out std_logic_vector(1 downto 0);
		pci_exp_txn                   : out std_logic_vector(1 downto 0);
		pci_exp_rxp                   : in  std_logic_vector(1 downto 0);
		pci_exp_rxn                   : in  std_logic_vector(1 downto 0);
		
		sys_clk_p                     : in std_logic; -- 100 MHz clock used for PCIe
		sys_clk_n                     : in std_logic; -- 100 MHz clock used for PCIe
		sys_rst_n                     : in std_logic;

		-- ADC signals
		VN_0                          : in std_logic;
		VP_0                          : in std_logic;

		-- HSMC connector
		LA18_N                        : inout std_logic;
		LA18_P                        : inout std_logic;
		LA23_N                        : inout std_logic;
		LA23_P                        : inout std_logic;
		LA14_N                        : inout std_logic;
		LA14_P                        : inout std_logic;
		LA17_N                        : inout std_logic;
		LA17_P                        : inout std_logic;
		LA10_N                        : inout std_logic;
		LA10_P                        : inout std_logic;
		LA13_P                        : inout std_logic;
		LA13_N                        : inout std_logic;
		LA06_P                        : inout std_logic;
		LA06_N                        : inout std_logic;
		LA09_N                        : inout std_logic;
		LA09_P                        : inout std_logic;
		LA02_N                        : inout std_logic;
		LA02_P                        : inout std_logic;
		LA05_N                        : inout std_logic;
		LA05_P                        : inout std_logic;
		LA00_N                        : inout std_logic;
		LA00_P                        : inout std_logic;
		LA01_N                        : inout std_logic;
		LA01_P                        : inout std_logic;
		LA28_N                        : inout std_logic;
		LA28_P                        : inout std_logic;
		LA26_P                        : inout std_logic;
		LA26_N                        : inout std_logic;
		LA31_P                        : inout std_logic;
		LA31_N                        : inout std_logic;
		LA27_P                        : inout std_logic;
		LA27_N                        : inout std_logic;
		LA30_N                        : inout std_logic;
		LA30_P                        : inout std_logic;
		LA25_P                        : inout std_logic;
		LA25_N                        : inout std_logic;
		LA33_P                        : inout std_logic;
		LA33_N                        : inout std_logic;
		LA24_N                        : inout std_logic;
		LA24_P                        : inout std_logic;
		LA32_N                        : inout std_logic;
		LA32_P                        : inout std_logic;
		LA29_N                        : inout std_logic;
		LA29_P                        : inout std_logic;
		HA00_N                        : inout std_logic;
		HA00_P                        : inout std_logic;
		HA01_P                        : inout std_logic;
		HA01_N                        : inout std_logic;
		LA21_N                        : inout std_logic;
		LA21_P                        : inout std_logic;
		LA22_N                        : inout std_logic;
		LA22_P                        : inout std_logic;
		LA19_P                        : inout std_logic;
		LA19_N                        : inout std_logic;
		LA20_N                        : inout std_logic;
		LA20_P                        : inout std_logic;
		LA15_N                        : inout std_logic;
		LA15_P                        : inout std_logic;
		LA16_N                        : inout std_logic;
		LA16_P                        : inout std_logic;
		LA11_N                        : inout std_logic;
		LA11_P                        : inout std_logic;
		LA12_N                        : inout std_logic;
		LA12_P                        : inout std_logic;
		LA07_N                        : inout std_logic;
		LA07_P                        : inout std_logic;
		LA08_N                        : inout std_logic;
		LA08_P                        : inout std_logic;
		LA04_N                        : inout std_logic;
		LA04_P                        : inout std_logic;
		LA03_N                        : inout std_logic;
		LA03_P                        : inout std_logic;
		HA12_P                        : inout std_logic;
		HA12_N                        : inout std_logic;
		HA13_P                        : inout std_logic;
		HA13_N                        : inout std_logic;
		HA08_N                        : inout std_logic;
		HA08_P                        : inout std_logic;
		HA09_P                        : inout std_logic;
		HA09_N                        : inout std_logic;
		HA07_N                        : inout std_logic;
		HA07_P                        : inout std_logic;
		HA04_P                        : inout std_logic;
		HA04_N                        : inout std_logic;
		HA05_P                        : inout std_logic;
		HA05_N                        : inout std_logic;
		HA11_P                        : inout std_logic;
		HA11_N                        : inout std_logic;
		HA10_P                        : inout std_logic;
		HA10_N                        : inout std_logic;
		HA02_N                        : inout std_logic;
		HA02_P                        : inout std_logic;
		HA03_P                        : inout std_logic;
		HA03_N                        : inout std_logic;
		HA06_P                        : inout std_logic;
		HA06_N                        : inout std_logic

		);
end devkit_top;

architecture rtl of devkit_top is

	constant APPLICATION_ID: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned( 1, 8));
	constant VERSION_MAJOR:  std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 1, 4));
	constant VERSION_MINOR:  std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 1, 4));
	constant YEAR:           std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(20, 5));
	constant MONTH:          std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(11, 4));
	constant DAY:            std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(04, 5));

	constant BM_CORE_CS:    integer := 0;
	constant GPIO1_CORE_CS: integer := 1;
	constant GPIO2_CORE_CS: integer := 2;
	constant XADC_CORE_CS:  integer := 3;

	constant GPIO1_IRQ_NUM: integer := 0;
	constant GPIO2_IRQ_NUM: integer := 0;
	constant GPIO1_IRQ_VEC: integer := 0;
	constant GPIO2_IRQ_VEC: integer := 1;

	component xilinx_pcie_2_1_ep_7x is
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
			pci_exp_txp                   : out std_logic_vector(1 downto 0);
			pci_exp_txn                   : out std_logic_vector(1 downto 0);
			pci_exp_rxp                   : in  std_logic_vector(1 downto 0);
			pci_exp_rxn                   : in  std_logic_vector(1 downto 0);
		
			sys_clk_p                     : in std_logic;
			sys_clk_n                     : in std_logic;
			sys_rst_n                     : in std_logic;
			o_sys_clk                     : out std_logic
		);
	end component xilinx_pcie_2_1_ep_7x;
	
	component clk_wiz_0 is
		Port ( 
			clk_out1 : out STD_LOGIC;
			clk_out2 : out STD_LOGIC;
			clk_out3 : out STD_LOGIC;
			locked : out STD_LOGIC;
			clk_in1 : in STD_LOGIC
		);
	end component clk_wiz_0;

	component vip_sim is
		generic (
			H_PORCH_ADJ  : integer := 0;
			V_PORCH_ADJ  : integer := 0
		);
		port (
			i_clk         : in std_logic; -- reference clock, 148.5 MHz for 60 Hz timing
			i_go          : in std_logic; -- when high, generate frames, when low, stop after frame completes
			o_vin_hsync   : out std_logic := '0'; -- external sync option (active high)
			o_vin_vsync   : out std_logic := '0'; -- external sync option (active high)
			o_vin_d       : out std_logic_vector(23 downto 0);
			o_vin_clk     : out std_logic
		);
	end component vip_sim;

	component xadc_wiz_0 is
		port (
			daddr_in        : in  STD_LOGIC_VECTOR (6 downto 0);     -- Address bus for the dynamic reconfiguration port
			den_in          : in  STD_LOGIC;                         -- Enable Signal for the dynamic reconfiguration port
			di_in           : in  STD_LOGIC_VECTOR (15 downto 0);    -- Input data bus for the dynamic reconfiguration port
			dwe_in          : in  STD_LOGIC;                         -- Write Enable for the dynamic reconfiguration port
			do_out          : out  STD_LOGIC_VECTOR (15 downto 0);   -- Output data bus for dynamic reconfiguration port
			drdy_out        : out  STD_LOGIC;                        -- Data ready signal for the dynamic reconfiguration port
			dclk_in         : in  STD_LOGIC;                         -- Clock input for the dynamic reconfiguration port
			busy_out        : out  STD_LOGIC;                        -- ADC Busy signal
			channel_out     : out  STD_LOGIC_VECTOR (4 downto 0);    -- Channel Selection Outputs
			eoc_out         : out  STD_LOGIC;                        -- End of Conversion Signal
			eos_out         : out  STD_LOGIC;                        -- End of Sequence Signal
			alarm_out       : out STD_LOGIC;                         -- OR'ed output of all the Alarms
			vp_in           : in  STD_LOGIC;                         -- Dedicated Analog Input Pair
			vn_in           : in  STD_LOGIC
							
	     	);
	end component xadc_wiz_0;
	
	signal sys_clk,clk_100,clk_200,clk_150 : std_logic := '1';
	signal s_vip_clk : std_logic := '0';
	signal s_core_be : std_logic_vector(1 downto 0) := "00";
	signal s_core_addr : std_logic_vector(5 downto 0) := (others=>'0');
	signal s_core_cs : std_logic_vector((2**DECODE_BITS)-1 downto 0) := (others=>'0');
	signal s_core_edi : std_logic_vector(15 downto 0) := (others=>'0');
	signal s_core_edo : bus16_vector((2**DECODE_BITS)-1 downto 0) := (others=>(others=>'0'));
	signal s_core_rd : std_logic := '0';
	signal s_core_wr : std_logic := '0';
	
	signal s_irq_map : bus32_vector(1 downto 0) := (others=>(others=>'0'));
	
	constant NUM_IO : integer := 99;

	-- gpio pins
	signal t_gpio     : std_logic_vector(NUM_IO-1 downto 0) := (others=>'0');
	signal s_gpio_out : std_logic_vector(NUM_IO-1 downto 0) := (others=>'0');
	signal s_gpio_in  : std_logic_vector(NUM_IO-1 downto 0) := (others=>'0');

	signal s_vip_m, s_vip_go : std_logic := '0';
	-- debug
	signal s_vid_hsync, s_vid_vsync : std_logic := '0';
	

begin

	o_cpu_nmi_n <= '1'; -- NMI is not used in this project, but should be deasserted
	
	--! Infer the PCIe interface block.
	pcie_block : xilinx_pcie_2_1_ep_7x
		port map (
			pci_exp_txp                   => pci_exp_txp,
			pci_exp_txn                   => pci_exp_txn,
			pci_exp_rxp                   => pci_exp_rxp,
			pci_exp_rxn                   => pci_exp_rxn,
			sys_clk_p                     => sys_clk_p,
			sys_clk_n                     => sys_clk_n,
			sys_rst_n                     => sys_rst_n,
			o_sys_clk                     => sys_clk
		);
		
	mmcm : clk_wiz_0 
	Port Map ( 
		clk_out1 => clk_100,
		clk_out2 => clk_200,
		clk_out3 => clk_150,
		locked => open,
		clk_in1 => sys_clk
	);

	s_vip_clk <= clk_150; -- should be 148.5 MHz

	-- video simulation block
	video_sim : vip_sim
		generic map (
			H_PORCH_ADJ  => 26, -- tweak timings because we are using 150 MHz instead of 148.5 (60.001 Hz)
			V_PORCH_ADJ  => -2
		)
		port map (
			i_clk         => s_vip_clk,
			i_go          => s_vip_go,
			-- VIN4A interface (MUST USE EMBEDDED SYNC MODES)
			o_vin_hsync   => s_vid_hsync,
			o_vin_vsync   => s_vid_vsync,
			o_vin_d       => o_vin_d,
			o_vin_clk     => o_vin_clk
		);

	o_vin_hsync <= s_vid_hsync;
	o_vin_vsync <= s_vid_vsync;
	go_resample : process(s_vip_clk)
	begin
		if rising_edge(s_vip_clk) then
			s_vip_go <= s_vip_m;
		end if;
	end process go_resample;


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
		o_sys_nirq      => o_sys_nirq
	);

	gp1 : gpio 
		Generic map (
			NUM_BANKS       => 4,
			NUM_IO_PER_BANK => 16
		)
		Port Map ( 
			clk             => clk_100,
			i_ABus          => s_core_addr,
			i_DBus          => s_core_edi,
			o_DBus          => s_core_edo(GPIO1_CORE_CS),
			i_wr_en         => s_core_wr,
			i_rd_en         => s_core_rd,
			i_cs            => s_core_cs(GPIO1_CORE_CS),
			o_irq           => s_irq_map(GPIO1_IRQ_NUM)(GPIO1_IRQ_VEC),
			i_ilevel        => '0',
			i_ivector       => "00000",  
			i_io            => s_gpio_in(63 downto 0),
			t_io            => t_gpio(63 downto 0),
			o_io            => s_gpio_out(63 downto 0),
			i_initdir       => (others=>'0'),
			i_initoutval    => (others=>'0')
		);

	gp2 : gpio 
		Generic map (
			NUM_BANKS       => 3,
			NUM_IO_PER_BANK => 16
		)
		Port Map ( 
			clk             => clk_100,
			i_ABus          => s_core_addr,
			i_DBus          => s_core_edi,
			o_DBus          => s_core_edo(GPIO2_CORE_CS),
			i_wr_en         => s_core_wr,
			i_rd_en         => s_core_rd,
			i_cs            => s_core_cs(GPIO2_CORE_CS),
			o_irq           => s_irq_map(GPIO2_IRQ_NUM)(GPIO2_IRQ_VEC),
			i_ilevel        => '0',
			i_ivector       => "00001",  
			i_io(34 downto 0)  => s_gpio_in(98 downto 64),
			i_io(47 downto 35) => (others=>'0'),
			t_io(34 downto 0)  => t_gpio(98 downto 64),
			t_io(47 downto 35) => open,
			o_io(34 downto 0)  => s_gpio_out(98 downto 64),
			o_io(47 downto 35) => open,
			i_initdir          => (others=>'0'),
			i_initoutval       => (others=>'0')
		);

	

	xadc : xadc_wiz_0
                port map (
                        daddr_in        => '0' & s_core_addr,
                        den_in          => s_core_cs(XADC_CORE_CS),
                        di_in           => s_core_edi,
                        dwe_in          => s_core_wr,
                        do_out          => s_core_edo(XADC_CORE_CS),
                        drdy_out        => open,
                        dclk_in         => clk_100,
                        busy_out        => open,
                        channel_out     => open,
                        eoc_out         => open,
                        eos_out         => open,
                        alarm_out       => open,
                        vp_in           => VP_0,
                        vn_in           => VN_0
                 );

	LA18_N <= s_gpio_out(0) when t_gpio(0)   = '0' else 'Z';
	LA18_P <= s_gpio_out(1) when t_gpio(1)   = '0' else 'Z';	
	LA23_N <= s_gpio_out(2) when t_gpio(2)   = '0' else 'Z';
	LA23_P <= s_gpio_out(3) when t_gpio(3)   = '0' else 'Z';
	LA14_N <= s_gpio_out(4) when t_gpio(4)   = '0' else 'Z';
	LA14_P <= s_gpio_out(5) when t_gpio(5)   = '0' else 'Z';
	LA17_N <= s_gpio_out(6) when t_gpio(6)   = '0' else 'Z';
	LA17_P <= s_gpio_out(7) when t_gpio(7)   = '0' else 'Z';
	LA10_N <= s_gpio_out(8) when t_gpio(8)   = '0' else 'Z';
	LA10_P <= s_gpio_out(9) when t_gpio(9)   = '0' else 'Z';
	LA13_P <= s_gpio_out(10) when t_gpio(10) = '0' else 'Z';
	LA13_N <= s_gpio_out(11) when t_gpio(11) = '0' else 'Z';
	LA06_P <= s_gpio_out(12) when t_gpio(12) = '0' else 'Z';
	LA06_N <= s_gpio_out(13) when t_gpio(13) = '0' else 'Z';
	LA09_N <= s_gpio_out(14) when t_gpio(14) = '0' else 'Z';
	LA09_P <= s_gpio_out(15) when t_gpio(15) = '0' else 'Z';
	LA02_N <= s_gpio_out(16) when t_gpio(16) = '0' else 'Z';
	LA02_P <= s_gpio_out(17) when t_gpio(17) = '0' else 'Z';
	LA05_N <= s_gpio_out(18) when t_gpio(18) = '0' else 'Z';
	LA05_P <= s_gpio_out(19) when t_gpio(19) = '0' else 'Z';
	LA00_N <= s_gpio_out(20) when t_gpio(20) = '0' else 'Z';
	LA00_P <= s_gpio_out(21) when t_gpio(21) = '0' else 'Z';
	LA01_N <= s_gpio_out(22) when t_gpio(22) = '0' else 'Z';
	LA01_P <= s_gpio_out(23) when t_gpio(23) = '0' else 'Z';
	LA28_N <= s_gpio_out(24) when t_gpio(24) = '0' else 'Z';
	LA28_P <= s_gpio_out(25) when t_gpio(25) = '0' else 'Z';
	LA26_P <= s_gpio_out(26) when t_gpio(26) = '0' else 'Z';
	LA26_N <= s_gpio_out(27) when t_gpio(27) = '0' else 'Z';
	LA31_P <= s_gpio_out(28) when t_gpio(28) = '0' else 'Z';
	LA31_N <= s_gpio_out(29) when t_gpio(29) = '0' else 'Z';
	LA27_P <= s_gpio_out(30) when t_gpio(30) = '0' else 'Z';
	LA27_N <= s_gpio_out(31) when t_gpio(31) = '0' else 'Z';
	LA30_N <= s_gpio_out(32) when t_gpio(32) = '0' else 'Z';
	LA30_P <= s_gpio_out(33) when t_gpio(33) = '0' else 'Z';
	LA25_P <= s_gpio_out(34) when t_gpio(34) = '0' else 'Z';
	LA25_N <= s_gpio_out(35) when t_gpio(35) = '0' else 'Z';
	LA33_P <= s_gpio_out(36) when t_gpio(36) = '0' else 'Z';
	LA33_N <= s_gpio_out(37) when t_gpio(37) = '0' else 'Z';
	LA24_N <= s_gpio_out(38) when t_gpio(38) = '0' else 'Z';
	LA24_P <= s_gpio_out(39) when t_gpio(39) = '0' else 'Z';
	LA32_N <= s_gpio_out(40) when t_gpio(40) = '0' else 'Z';
	LA32_P <= s_gpio_out(41) when t_gpio(41) = '0' else 'Z';
	LA29_N <= s_gpio_out(42) when t_gpio(42) = '0' else 'Z';
	LA29_P <= s_gpio_out(43) when t_gpio(43) = '0' else 'Z';
	HA00_N <= s_gpio_out(44) when t_gpio(44) = '0' else 'Z';
	HA00_P <= s_gpio_out(45) when t_gpio(45) = '0' else 'Z';
	HA01_P <= s_gpio_out(46) when t_gpio(46) = '0' else 'Z';
	HA01_N <= s_gpio_out(47) when t_gpio(47) = '0' else 'Z';
	LA21_N <= s_gpio_out(48) when t_gpio(48) = '0' else 'Z';
	LA21_P <= s_gpio_out(49) when t_gpio(49) = '0' else 'Z';
	LA22_N <= s_gpio_out(50) when t_gpio(50) = '0' else 'Z';
	LA22_P <= s_gpio_out(51) when t_gpio(51) = '0' else 'Z';
	LA19_P <= s_gpio_out(52) when t_gpio(52) = '0' else 'Z';
	LA19_N <= s_gpio_out(53) when t_gpio(53) = '0' else 'Z';
	LA20_N <= s_gpio_out(54) when t_gpio(54) = '0' else 'Z';
	LA20_P <= s_gpio_out(55) when t_gpio(55) = '0' else 'Z';
	LA15_N <= s_gpio_out(56) when t_gpio(56) = '0' else 'Z';
	LA15_P <= s_gpio_out(57) when t_gpio(57) = '0' else 'Z';
	LA16_N <= s_gpio_out(58) when t_gpio(58) = '0' else 'Z';
	LA16_P <= s_gpio_out(59) when t_gpio(59) = '0' else 'Z';
	LA11_N <= s_gpio_out(60) when t_gpio(60) = '0' else 'Z';
	LA11_P <= s_gpio_out(61) when t_gpio(61) = '0' else 'Z';
	LA12_N <= s_gpio_out(62) when t_gpio(62) = '0' else 'Z';
	LA12_P <= s_gpio_out(63) when t_gpio(63) = '0' else 'Z';
	LA07_N <= s_gpio_out(64) when t_gpio(64) = '0' else 'Z';
	LA07_P <= s_gpio_out(65) when t_gpio(65) = '0' else 'Z';
	LA08_N <= s_gpio_out(66) when t_gpio(66) = '0' else 'Z';
	LA08_P <= s_gpio_out(67) when t_gpio(67) = '0' else 'Z';
	LA04_N <= s_gpio_out(68) when t_gpio(68) = '0' else 'Z';
	LA04_P <= s_gpio_out(69) when t_gpio(69) = '0' else 'Z';
	LA03_N <= s_gpio_out(70) when t_gpio(70) = '0' else 'Z';
	LA03_P <= s_gpio_out(71) when t_gpio(71) = '0' else 'Z';
	HA12_P <= s_gpio_out(72) when t_gpio(72) = '0' else 'Z';
	HA12_N <= s_gpio_out(73) when t_gpio(73) = '0' else 'Z';
	HA13_P <= s_gpio_out(74) when t_gpio(74) = '0' else 'Z';
	HA13_N <= s_gpio_out(75) when t_gpio(75) = '0' else 'Z';
	HA08_N <= s_gpio_out(76) when t_gpio(76) = '0' else 'Z';
	HA08_P <= s_gpio_out(77) when t_gpio(77) = '0' else 'Z';
	HA09_P <= s_gpio_out(78) when t_gpio(78) = '0' else 'Z';
	HA09_N <= s_gpio_out(79) when t_gpio(79) = '0' else 'Z';
	HA07_N <= s_gpio_out(80) when t_gpio(80) = '0' else 'Z';
	HA07_P <= s_gpio_out(81) when t_gpio(81) = '0' else 'Z';
	HA04_P <= s_gpio_out(82) when t_gpio(82) = '0' else 'Z';
	HA04_N <= s_gpio_out(83) when t_gpio(83) = '0' else 'Z';
	HA05_P <= s_gpio_out(84) when t_gpio(84) = '0' else 'Z';
	HA05_N <= s_gpio_out(85) when t_gpio(85) = '0' else 'Z';
	HA11_P <= s_gpio_out(86) when t_gpio(86) = '0' else 'Z';
	HA11_N <= s_gpio_out(87) when t_gpio(87) = '0' else 'Z';
	HA10_P <= s_gpio_out(88) when t_gpio(88) = '0' else 'Z';
	HA10_N <= s_gpio_out(89) when t_gpio(89) = '0' else 'Z';
	HA02_N <= s_gpio_out(90) when t_gpio(90) = '0' else 'Z';
	HA02_P <= s_gpio_out(91) when t_gpio(91) = '0' else 'Z';
	HA03_P <= s_gpio_out(92) when t_gpio(92) = '0' else 'Z';
	HA03_N <= s_gpio_out(93) when t_gpio(93) = '0' else 'Z';
	HA06_P <= s_gpio_out(94) when t_gpio(94) = '0' else 'Z';
	HA06_N <= s_gpio_out(95) when t_gpio(95) = '0' else 'Z';
	-- (96) id input only
	-- (97) id input only
	s_vip_m <= s_gpio_out(98);

	s_gpio_in(0) <= LA18_N;
	s_gpio_in(1) <= LA18_P;
	s_gpio_in(2) <= LA23_N;
	s_gpio_in(3) <= LA23_P;
	s_gpio_in(4) <= LA14_N;
	s_gpio_in(5) <= LA14_P;
	s_gpio_in(6) <= LA17_N;
	s_gpio_in(7) <= LA17_P;
	s_gpio_in(8) <= LA10_N;
	s_gpio_in(9) <= LA10_P;
	s_gpio_in(10) <= LA13_P;
	s_gpio_in(11) <= LA13_N;
	s_gpio_in(12) <= LA06_P;
	s_gpio_in(13) <= LA06_N;
	s_gpio_in(14) <= LA09_N;
	s_gpio_in(15) <= LA09_P;
	s_gpio_in(16) <= LA02_N;
	s_gpio_in(17) <= LA02_P;
	s_gpio_in(18) <= LA05_N;
	s_gpio_in(19) <= LA05_P;
	s_gpio_in(20) <= LA00_N;
	s_gpio_in(21) <= LA00_P;
	s_gpio_in(22) <= LA01_N;
	s_gpio_in(23) <= LA01_P;
	s_gpio_in(24) <= LA28_N;
	s_gpio_in(25) <= LA28_P;
	s_gpio_in(26) <= LA26_P;
	s_gpio_in(27) <= LA26_N;
	s_gpio_in(28) <= LA31_P;
	s_gpio_in(29) <= LA31_N;
	s_gpio_in(30) <= LA27_P;
	s_gpio_in(31) <= LA27_N;
	s_gpio_in(32) <= LA30_N;
	s_gpio_in(33) <= LA30_P;
	s_gpio_in(34) <= LA25_P;
	s_gpio_in(35) <= LA25_N;
	s_gpio_in(36) <= LA33_P;
	s_gpio_in(37) <= LA33_N;
	s_gpio_in(38) <= LA24_N;
	s_gpio_in(39) <= LA24_P;
	s_gpio_in(40) <= LA32_N;
	s_gpio_in(41) <= LA32_P;
	s_gpio_in(42) <= LA29_N;
	s_gpio_in(43) <= LA29_P;
	s_gpio_in(44) <= HA00_N;
	s_gpio_in(45) <= HA00_P;
	s_gpio_in(46) <= HA01_P;
	s_gpio_in(47) <= HA01_N;
	s_gpio_in(48) <= LA21_N;
	s_gpio_in(49) <= LA21_P;
	s_gpio_in(50) <= LA22_N;
	s_gpio_in(51) <= LA22_P;
	s_gpio_in(52) <= LA19_P;
	s_gpio_in(53) <= LA19_N;
	s_gpio_in(54) <= LA20_N;
	s_gpio_in(55) <= LA20_P;
	s_gpio_in(56) <= LA15_N;
	s_gpio_in(57) <= LA15_P;
	s_gpio_in(58) <= LA16_N;
	s_gpio_in(59) <= LA16_P;
	s_gpio_in(60) <= LA11_N;
	s_gpio_in(61) <= LA11_P;
	s_gpio_in(62) <= LA12_N;
	s_gpio_in(63) <= LA12_P;
	s_gpio_in(64) <= LA07_N;
	s_gpio_in(65) <= LA07_P;
	s_gpio_in(66) <= LA08_N;
	s_gpio_in(67) <= LA08_P;
	s_gpio_in(68) <= LA04_N;
	s_gpio_in(69) <= LA04_P;
	s_gpio_in(70) <= LA03_N;
	s_gpio_in(71) <= LA03_P;
	s_gpio_in(72) <= HA12_P;
	s_gpio_in(73) <= HA12_N;
	s_gpio_in(74) <= HA13_P;
	s_gpio_in(75) <= HA13_N;
	s_gpio_in(76) <= HA08_N;
	s_gpio_in(77) <= HA08_P;
	s_gpio_in(78) <= HA09_P;
	s_gpio_in(79) <= HA09_N;
	s_gpio_in(80) <= HA07_N;
	s_gpio_in(81) <= HA07_P;
	s_gpio_in(82) <= HA04_P;
	s_gpio_in(83) <= HA04_N;
	s_gpio_in(84) <= HA05_P;
	s_gpio_in(85) <= HA05_N;
	s_gpio_in(86) <= HA11_P;
	s_gpio_in(87) <= HA11_N;
	s_gpio_in(88) <= HA10_P;
	s_gpio_in(89) <= HA10_N;
	s_gpio_in(90) <= HA02_N;
	s_gpio_in(91) <= HA02_P;
	s_gpio_in(92) <= HA03_P;
	s_gpio_in(93) <= HA03_N;
	s_gpio_in(94) <= HA06_P;
	s_gpio_in(95) <= HA06_N;
	s_gpio_in(96) <= i_id(0);
	s_gpio_in(97) <= i_id(1);
	s_gpio_in(98) <= s_vip_m; -- loopback internal control signal


end rtl;
