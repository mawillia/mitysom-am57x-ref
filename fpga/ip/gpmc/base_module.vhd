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
--- Date: 12/31/2019
--- Version: 1.00
--- Revisions: 
---   1.00 - Initial release.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MitySOM_AM57_pkg.all;

entity base_module is
	generic (
		IRQ0_CPU     : integer := 0;
		IRQ1_CPU     : integer := 1;
		CONFIG       : string := "UNKNOWN" -- "MitySOM_AM57"
	);
	port (
		i_clk           : in  std_logic;
		i_cs            : in  std_logic;
		i_ID            : in  std_logic_vector(7 downto 0);    -- assigned Application ID number, 0xFF if unassigned
		i_version_major : in  std_logic_vector(3 downto 0);    -- major version number 1-15
		i_version_minor : in  std_logic_vector(3 downto 0);    -- minor version number 0-15
		i_year          : in  std_logic_vector(4 downto 0);    -- year since 2000
		i_month         : in  std_logic_vector(3 downto 0);    -- month (1-12)
		i_day           : in  std_logic_vector(4 downto 0);    -- day (1-32)
		i_ABus          : in  std_logic_vector(5 downto 0);
		i_DBus          : in  std_logic_vector(15 downto 0);
		o_DBus          : out std_logic_vector(15 downto 0);
		i_wr_en         : in  std_logic;
		i_rd_en         : in  std_logic;
		i_be_r          : in  std_logic_vector(1 downto 0);

		i_irq_map       : in  bus16_vector(1 downto 0) := (others=>(others=>'0'));
		o_sys_nirq      : out std_logic_vector(1 downto 0)
	);
end base_module;

architecture rtl of base_module is

	constant CORE_APPLICATION_ID: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned( 0, 8));
	constant CORE_VERSION_MAJOR:  std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 1, 4));
	constant CORE_VERSION_MINOR:  std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 0, 4));
	constant CORE_YEAR:           std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(20, 5));
	constant CORE_MONTH:          std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(01, 4));
	constant CORE_DAY:            std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(03, 5));
	
	constant OFFSET_BASE_VERSION: std_logic_vector(7 downto 0) := x"00";
	constant OFFSET_IRQ0_MASKED:  std_logic_vector(7 downto 0) := x"02";
	constant OFFSET_IRQ0_ENABLES: std_logic_vector(7 downto 0) := x"04";
	constant OFFSET_IRQ1_MASKED:  std_logic_vector(7 downto 0) := x"06";
	constant OFFSET_IRQ1_ENABLES: std_logic_vector(7 downto 0) := x"08";
	constant OFFSET_IRQ_CPU_MAP:  std_logic_vector(7 downto 0) := x"0A";
	constant OFFSET_FPGA_VERSION: std_logic_vector(7 downto 0) := x"0C";
	
	signal ABus : std_logic_vector(7 downto 0);
	
	signal fpga_version_reg : std_logic_vector(15 downto 0) := (others=>'0');
	signal base_version_reg : std_logic_vector(15 downto 0) := (others=>'0');
	
	signal fpga_version_rd : std_logic;
	signal base_version_rd : std_logic;
	
	signal scratch_ram_l : bus8_vector(0 to 31) := (others=>(others=>'0'));
	signal scratch_ram_u : bus8_vector(0 to 31) := (others=>(others=>'0'));
	attribute ram_style : string;
	attribute ram_style of scratch_ram_l: signal is "distributed";
	attribute ram_style of scratch_ram_u: signal is "distributed";
	
	signal masked_irqs : bus16_vector(1 downto 0);
	signal irq_enables : bus16_vector(1 downto 0) := (others=>(others=>'0'));
	
	begin -- architecture: rtl
	
	assert CONFIG="MitySOM_AM57"
	report "CONFIG generic must be MitySOM_AM57."
	severity FAILURE;

	fpga_version : core_version
		port map(
			clk           => i_clk,
			rd            => fpga_version_rd,
			ID            => i_ID,
			version_major => i_version_major,
			version_minor => i_version_minor,
			year          => i_year,
			month         => i_month,
			day           => i_day,
			o_data        => fpga_version_reg
		);

	base_version : core_version
		port map(
			clk           => i_clk,
			rd            => base_version_rd,
			ID            => CORE_APPLICATION_ID,
			version_major => CORE_VERSION_MAJOR,
			version_minor => CORE_VERSION_MINOR,
			year          => CORE_YEAR,
			month         => CORE_MONTH,
			day           => CORE_DAY,
			o_data        => base_version_reg
		);

	-- inputs bus is in 16 bit words, we are using byte addresses in decode logic
	ABus <= '0' & i_ABus & '0';

	reg_read : process (i_clk)
	begin
		if rising_edge(i_clk) then
			base_version_rd <= '0';
			fpga_version_rd <= '0';
			o_DBus <= x"0000"; -- default
	
			if i_cs = '1' then
				case ABus is
					when OFFSET_BASE_VERSION =>
						o_DBus <= base_version_reg;
						base_version_rd <= i_rd_en;
					when OFFSET_IRQ0_MASKED =>
						o_DBus <= masked_irqs(0);
					when OFFSET_IRQ0_ENABLES =>
						o_DBus <= irq_enables(0);
					when OFFSET_IRQ1_MASKED =>
						o_DBus <= masked_irqs(1);
					when OFFSET_IRQ1_ENABLES =>
						o_DBus <= irq_enables(1);
					when OFFSET_IRQ_CPU_MAP =>
						if IRQ0_CPU = 0 then
							o_DBus(0) <= '0';
						else
							o_DBus(0) <= '1';
						end if;
						if IRQ1_CPU = 0 then
							o_DBus(1) <= '0';
						else
							o_DBus(1) <= '1';
						end if;
					when OFFSET_FPGA_VERSION =>
						o_DBus <= fpga_version_reg;
						fpga_version_rd <= i_rd_en;
					when others =>
						if i_ABus(5) = '1' then
							o_DBus <= scratch_ram_u(to_integer(unsigned(i_ABus(4 downto 0))))
							        & scratch_ram_l(to_integer(unsigned(i_ABus(4 downto 0))));
						else
							o_DBus <= x"0000";
						end if;
				end case;
			end if;
		end if;
	end process reg_read;

	reg_write : process (i_clk)
	begin
		if rising_edge(i_clk) then
			if i_cs='1' and i_wr_en='1' then
				if i_ABus(5)='1' then
					if i_be_r(1)='1' then
						scratch_ram_u(to_integer(unsigned(i_ABus(4 downto 0)))) <= i_DBus(15 downto 8);
					end if;
					if i_be_r(0)='1' then
						scratch_ram_l(to_integer(unsigned(i_ABus(4 downto 0)))) <= i_DBus(7 downto 0);
					end if;
				end if;
				
				case ABus is
					when OFFSET_IRQ0_ENABLES =>
						irq_enables(0) <= i_DBus;
					when OFFSET_IRQ1_ENABLES =>
						irq_enables(1) <= i_DBus;
					when others => NULL;
				end case;
			end if;
		end if;
	end process reg_write;

	-- IRQ masking logic
	gen_irqs : for i in 0 to 1 generate
	begin
		o_sys_nirq(i) <= '0' when masked_irqs(i) /= x"0000" else '1';
	
		gen_mask: for j in 0 to 15 generate
		begin
			masked_irqs(i)(j) <= i_irq_map(i)(j) and irq_enables(i)(j);
		end generate gen_mask;
	end generate gen_irqs;

end rtl;
