
--- Title: tb_gpmc_cocotb.vhd
--- Description: 
---
--- GPMC interface for AM57xx series CPU platform.
---
---     o  0
---     | /       Copyright (c) 2019
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.
--- Date: 12/31/2019
--- Version: 1.00
--- Revisions:
---   1.00 - Baseline

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MitySOM_AM57_pkg.all;

entity tb_gpmc_cocotb is
	generic ( 
		DECODE_BITS   : integer range 1 to 9 := 5;
		CONFIG        : string := "ASYNC_MODE"        -- "ASYNC_MODE" 
	);
	port (
		-- TODO add interrupt pins

		-- GPMC direct-connect signals
		gpmc_clk    : in  std_logic;
		gpmc_cs_n   : in  std_logic;
		gpmc_ad     : inout std_logic_vector(15 downto 0);
		gpmc_adv_n  : in  std_logic; -- address valid
		gpmc_oe_n   : in  std_logic; -- output enable
		gpmc_we_n   : in  std_logic; -- write enable
		gpmc_be_n   : in  std_logic_vector(1 downto 0) -- byte enable
	);
end tb_gpmc_cocotb;

architecture behave of tb_gpmc_cocotb is

	constant NUM_BANKS : integer := 4;
	constant NUM_IO_PER_BANK : integer := 16;
	constant CLK_HALF_PERIOD : time := 5 ns;
	signal s_core_clk : std_logic := '0';

	-- used by cocotb framework
	signal gpmc_fclk : std_logic := '0';

	signal s_core_be     : std_logic_vector(1 downto 0) := (others=>'0');
	signal s_core_addr   : std_logic_vector(5 downto 0) := (others=>'0');
	signal s_core_cs     : std_logic_vector((2**DECODE_BITS)-1 downto 0)  := (others=>'0');
	signal s_core_edi    : std_logic_vector(15 downto 0)  := (others=>'0');
	signal s_core_edo    : bus16_vector((2**DECODE_BITS)-1 downto 0) := (others=>(others=>'0'));
	signal s_core_rd     : std_logic := '0';
	signal s_core_wr     : std_logic := '0';

	signal s_irq_map     : bus16_vector(1 downto 0) := (others=>(others=>'0'));
	signal s_sys_nirq    : std_logic_vector(1 downto 0) := "11";

	-- gpio pins
	signal s_gpio     : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'Z');
	signal t_gpio   : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
	signal gpio_out : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');

begin

	-- create internal core clock via simulation for now.
	gen_core_clock : process
	begin
		wait for CLK_HALF_PERIOD;
		s_core_clk <= not s_core_clk;
	end process gen_core_clock;

	gpmc_int : GPMC_iface
		generic map ( 
			DECODE_BITS   => 5,
			CONFIG        => "ASYNC_MODE"
		)
		port map (
			i_core_clk    => s_core_clk,
			
			-- GPMC direct-connect signals
			i_gpmc_cs_n   => gpmc_cs_n,
			io_gpmc_ad    => gpmc_ad,
			i_gpmc_adv_n  => gpmc_adv_n,
			i_gpmc_oe_n   => gpmc_oe_n,
			i_gpmc_we_n   => gpmc_we_n,
			i_gpmc_be_n   => gpmc_be_n,
			
			-- FPGA core interface signals
			o_core_be     => s_core_be,
			o_core_addr   => s_core_addr,
			o_core_cs     => s_core_cs,
			o_core_edi    => s_core_edi,
			i_core_edo    => s_core_edo,
			o_core_rd     => s_core_rd,
			o_core_wr     => s_core_wr
		);


	mb : base_module
		generic map (
			IRQ0_CPU     => 0,
			IRQ1_CPU     => 0,
			CONFIG       => "MitySOM_AM57"
		)
		port map (
			i_clk           => s_core_clk,
			i_cs            => s_core_cs(0),
			i_ID            => x"BC",
			i_version_major => x"1",
			i_version_minor => x"0",
			i_year          => "10100",
			i_month         => x"7",
			i_day           => "01100",
			i_ABus          => s_core_addr,
			i_DBus          => s_core_edi,
			o_DBus          => s_core_edo(0),
			i_wr_en         => s_core_wr,
			i_rd_en         => s_core_rd,
			i_be_r          => s_core_be,
	
			i_irq_map       => s_irq_map,
			o_sys_nirq      => s_sys_nirq
		);

	gpio_pins : for i in 0 to 15 generate
		s_gpio(i) <= 'Z' when t_gpio(i) = '0' else gpio_out(i);
	end generate;

	gp : gpio 
		Generic map (
			NUM_BANKS       => NUM_BANKS,
			NUM_IO_PER_BANK => NUM_IO_PER_BANK
		)
		Port Map ( 
			clk             => s_core_clk,
			i_ABus          => s_core_addr,
			i_DBus          => s_core_edi,
			o_DBus          => s_core_edo(1),
			i_wr_en         => s_core_wr,
			i_rd_en         => s_core_rd,
			i_cs            => s_core_cs(1),
			o_irq           => s_irq_map(0)(0),
			i_ilevel        => "00",
			i_ivector       => "0000",  
			i_io            => s_gpio,
			t_io            => t_gpio,
			o_io            => gpio_out,
			i_initdir       => (others=>'0'),
			i_initoutval    => (others=>'0')
		);

end architecture behave;