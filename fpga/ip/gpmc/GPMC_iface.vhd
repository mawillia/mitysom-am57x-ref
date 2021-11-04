--- Title: GPMC_iface.vhd
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

library WORK;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_std.ALL;
use WORK.MitySOM_AM57_pkg.ALL;

entity GPMC_iface is
	generic ( 
		DECODE_BITS   : integer range 1 to 9 := 5;
		CONFIG        : string := "ASYNC_MODE"        -- "ASYNC_MODE" 
	);
	port (
		i_core_clk    : in  std_logic;
		
		-- GPMC direct-connect signals
		i_gpmc_cs_n   : in  std_logic;
		io_gpmc_ad    : inout std_logic_vector(15 downto 0);
		i_gpmc_adv_n  : in  std_logic; -- address valid (NOT USED)
		i_gpmc_oe_n   : in  std_logic; -- output enable
		i_gpmc_we_n   : in  std_logic; -- write enable
		i_gpmc_be_n   : in  std_logic_vector(1 downto 0); -- byte enable
		
		-- FPGA core interface signals
		o_core_be     : out std_logic_vector(1 downto 0);
		o_core_addr   : out std_logic_vector(5 downto 0);
		o_core_cs     : out std_logic_vector((2**DECODE_BITS)-1 downto 0);
		o_core_edi    : out std_logic_vector(15 downto 0);
		i_core_edo    : in  bus16_vector((2**DECODE_BITS)-1 downto 0);
		o_core_rd     : out std_logic;
		o_core_wr     : out std_logic
	);
end GPMC_iface;

architecture rtl of GPMC_iface is
	
	signal s_cs_n_r : std_logic_vector(3 downto 0) := (others=>'1');
	signal s_oe_n_r : std_logic_vector(3 downto 0) := (others=>'1');
	signal s_we_n_r : std_logic_vector(3 downto 0) := (others=>'1');
	
	signal s_core_addr : std_logic_vector(15 downto 0) := (others=>'0');
	signal s_core_cs   : std_logic_vector((2**DECODE_BITS)-1 downto 0) := (others=>'0');
	signal s_be        : std_logic_vector(1 downto 0) := (others=>'0');
	signal s_core_decode : integer range 0 to 2**DECODE_BITS-1 := 0;
	signal s_core_edo  : std_logic_vector(15 downto 0) := (others=>'0');
	signal s_core_rd : std_logic := '0';
	signal s_core_wr : std_logic := '0';

	-- debugging, uncomment to ease locating nets for ILA insertion
	-- attribute mark_debug : string;
	-- attribute syn_keep : boolean;
	-- attribute mark_debug of s_cs_n_r : signal is "true";
	-- attribute mark_debug of s_oe_n_r : signal is "true";
	-- attribute mark_debug of s_we_n_r : signal is "true";
	-- attribute mark_debug of s_core_addr : signal is "true";
	-- attribute mark_debug of s_core_cs : signal is "true";
	-- attribute mark_debug of s_be : signal is "true";
	-- attribute mark_debug of s_core_decode : signal is "true";
	-- attribute mark_debug of s_core_edo : signal is "true";
	-- attribute mark_debug of s_core_rd : signal is "true";
	-- attribute mark_debug of s_core_wr : signal is "true";
	-- attribute syn_keep of s_cs_n_r : signal is true;
	-- attribute syn_keep of s_oe_n_r : signal is true;
	-- attribute syn_keep of s_we_n_r : signal is true;
	-- attribute syn_keep of s_core_addr : signal is true;
	-- attribute syn_keep of s_core_cs : signal is true;
	-- attribute syn_keep of s_be : signal is true;
	-- attribute syn_keep of s_core_decode : signal is true;
	-- attribute syn_keep of s_core_edo : signal is true;
	-- attribute syn_keep of s_core_rd : signal is true;
	-- attribute syn_keep of s_core_wr : signal is true;


begin -- architecture: rtl

	io_gpmc_ad <= s_core_edo when i_gpmc_oe_n = '0' else (others=>'Z');
	
	o_core_be   <= s_be;
	o_core_cs   <= s_core_cs;
	o_core_rd   <= s_core_rd;
	o_core_wr   <= s_core_wr;

	-- ASYNC mode processing
	process (i_core_clk)
	begin
		if rising_edge(i_core_clk) then
			-- defaults
			s_core_rd <= '0';
			s_core_wr <= '0';
			
			-- metastable / latch input strobes
			s_cs_n_r      <= s_cs_n_r(s_cs_n_r'length-2 downto 0) & i_gpmc_cs_n;
			s_oe_n_r      <= s_oe_n_r(s_oe_n_r'length-2 downto 0) & i_gpmc_oe_n;
			s_we_n_r      <= s_we_n_r(s_we_n_r'length -2 downto 0) & i_gpmc_we_n;

			-- 1 clock delay address
			s_core_addr   <= io_gpmc_ad;

			if s_cs_n_r(2) = '1' then
				s_core_cs <= (others=>'0');
			end if;

			-- address and BE latch
			if s_cs_n_r(2 downto 0) = "100" then
				o_core_addr <= s_core_addr(5 downto 0);
				s_core_decode <= to_integer(unsigned(s_core_addr(DECODE_BITS+5 downto 6)));
				s_core_cs(to_integer(unsigned(s_core_addr(DECODE_BITS+5 downto 6)))) <= '1';
				s_be(0) <= not i_gpmc_be_n(0);
				s_be(1) <= not i_gpmc_be_n(1);
			end if;
			
			if i_gpmc_oe_n='0' then
				s_core_edo <= i_core_edo(s_core_decode);
			end if;
			
			if s_cs_n_r(1) = '0' and s_we_n_r(1 downto 0) = "00" then
				o_core_edi <= s_core_addr;
			end if;

			-- post read and write strobes to support FIFO / auto-address logic
			if s_oe_n_r(2 downto 0) = "001" then
				s_core_rd <= '1';
			end if;

			if s_we_n_r(2 downto 0) = "001" then
				s_core_wr <= '1';
			end if;
		end if;
	end process;

end rtl;
