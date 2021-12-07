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
		INCLUDE_SCRATCH_RAM : boolean := true;
		CONFIG              : string := "UNKNOWN" -- "MitySOM_AM57"
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

		i_irq_map       : in  bus32_vector(1 downto 0) := (others=>(others=>'0'));
		o_sys_nirq      : out std_logic_vector(1 downto 0)
	);
end base_module;

architecture rtl of base_module is

	constant CORE_APPLICATION_ID: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned( 0, 8));
	constant CORE_VERSION_MAJOR:  std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 3, 4));
	constant CORE_VERSION_MINOR:  std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned( 0, 4));
	constant CORE_YEAR:           std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(21, 5));
	constant CORE_MONTH:          std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(11, 4));
	constant CORE_DAY:            std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(12, 5));
	
	constant OFFSET_BASE_VERSION:       std_logic_vector(7 downto 0) := x"00";
	constant OFFSET_IRQ0_FLAGS_1:       std_logic_vector(7 downto 0) := x"02";
	constant OFFSET_IRQ0_FLAGS_2:       std_logic_vector(7 downto 0) := x"04";
	constant OFFSET_IRQ0_ENABLES_1:     std_logic_vector(7 downto 0) := x"06";
	constant OFFSET_IRQ0_ENABLES_2:     std_logic_vector(7 downto 0) := x"08";
	constant OFFSET_IRQ0_ENABLES_SET_1: std_logic_vector(7 downto 0) := x"0A";
	constant OFFSET_IRQ0_ENABLES_SET_2: std_logic_vector(7 downto 0) := x"0C";
	constant OFFSET_IRQ0_ENABLES_CLR_1: std_logic_vector(7 downto 0) := x"0E";
	constant OFFSET_IRQ0_ENABLES_CLR_2: std_logic_vector(7 downto 0) := x"10";
	constant OFFSET_IRQ1_FLAGS_1:       std_logic_vector(7 downto 0) := x"12";
	constant OFFSET_IRQ1_FLAGS_2:       std_logic_vector(7 downto 0) := x"14";
	constant OFFSET_IRQ1_ENABLES_1:     std_logic_vector(7 downto 0) := x"16";
	constant OFFSET_IRQ1_ENABLES_2:     std_logic_vector(7 downto 0) := x"18";
	constant OFFSET_IRQ1_ENABLES_SET_1: std_logic_vector(7 downto 0) := x"1A";
	constant OFFSET_IRQ1_ENABLES_SET_2: std_logic_vector(7 downto 0) := x"1C";
	constant OFFSET_IRQ1_ENABLES_CLR_1: std_logic_vector(7 downto 0) := x"1E";
	constant OFFSET_IRQ1_ENABLES_CLR_2: std_logic_vector(7 downto 0) := x"20";
	constant OFFSET_IRQ_CPU_MAP_SET:    std_logic_vector(7 downto 0) := x"22"; -- 15 : IRQ0/1, 4 2:0 Core
	constant OFFSET_IRQ_CPU_MAP_1:      std_logic_vector(7 downto 0) := x"24"; -- IRQ0  4:0
	constant OFFSET_IRQ_CPU_MAP_2:      std_logic_vector(7 downto 0) := x"26"; -- IRQ0  9:5
	constant OFFSET_IRQ_CPU_MAP_3:      std_logic_vector(7 downto 0) := x"28"; -- IRQ0 14:10
	constant OFFSET_IRQ_CPU_MAP_4:      std_logic_vector(7 downto 0) := x"2A"; -- IRQ0 19:15
	constant OFFSET_IRQ_CPU_MAP_5:      std_logic_vector(7 downto 0) := x"2C"; -- IRQ0 24:20
	constant OFFSET_IRQ_CPU_MAP_6:      std_logic_vector(7 downto 0) := x"2E"; -- IRQ0 29:25
	constant OFFSET_IRQ_CPU_MAP_7:      std_logic_vector(7 downto 0) := x"30"; -- IRQ0 31:30
	constant OFFSET_IRQ_CPU_MAP_8:      std_logic_vector(7 downto 0) := x"32"; -- IRQ1  4:0
	constant OFFSET_IRQ_CPU_MAP_9:      std_logic_vector(7 downto 0) := x"34"; -- IRQ1  9:5
	constant OFFSET_IRQ_CPU_MAP_10:     std_logic_vector(7 downto 0) := x"36"; -- IRQ1 14:10
	constant OFFSET_IRQ_CPU_MAP_11:     std_logic_vector(7 downto 0) := x"38"; -- IRQ1 19:15
	constant OFFSET_IRQ_CPU_MAP_12:     std_logic_vector(7 downto 0) := x"3A"; -- IRQ1 24:20
	constant OFFSET_IRQ_CPU_MAP_13:     std_logic_vector(7 downto 0) := x"3C"; -- IRQ1 29:25
	constant OFFSET_IRQ_CPU_MAP_14:     std_logic_vector(7 downto 0) := x"40"; -- IRQ1 31:30
	constant OFFSET_FPGA_VERSION:       std_logic_vector(7 downto 0) := x"42";
	
	signal ABus : std_logic_vector(7 downto 0);
	
	signal fpga_version_reg : std_logic_vector(15 downto 0) := (others=>'0');
	signal base_version_reg : std_logic_vector(15 downto 0) := (others=>'0');
	
	signal fpga_version_rd : std_logic;
	signal base_version_rd : std_logic;
	
	signal scratch_ram_l : bus8_vector(0 to 15) := (others=>(others=>'0'));
	signal scratch_ram_u : bus8_vector(0 to 15) := (others=>(others=>'0'));
	attribute ram_style : string;
	attribute ram_style of scratch_ram_l: signal is "distributed";
	attribute ram_style of scratch_ram_u: signal is "distributed";

	type cpu_map_array is array(integer range 0 to 1, integer range 0 to 32) of std_logic_vector(2 downto 0);
	
	signal irq_flags : bus32_vector(1 downto 0);
	signal irq_enables : bus32_vector(1 downto 0) := (others=>(others=>'0'));
	signal cpu_map : cpu_map_array := (others=>(others=>"000"));
	
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
					when OFFSET_IRQ0_FLAGS_1 =>
						o_DBus <= irq_flags(0)(15 downto 0);
					when OFFSET_IRQ0_FLAGS_2 =>
						o_DBus <= irq_flags(0)(31 downto 16);
					when OFFSET_IRQ0_ENABLES_1 =>
						o_DBus <= irq_enables(0)(15 downto 0);
					when OFFSET_IRQ0_ENABLES_2 =>
						o_DBus <= irq_enables(0)(31 downto 16);
					when OFFSET_IRQ1_FLAGS_1 =>
						o_DBus <= irq_flags(1)(15 downto 0);
					when OFFSET_IRQ1_FLAGS_2 =>
						o_DBus <= irq_flags(1)(31 downto 16);
					when OFFSET_IRQ1_ENABLES_1 =>
						o_DBus <= irq_enables(1)(15 downto 0);
					when OFFSET_IRQ1_ENABLES_2 =>
						o_DBus <= irq_enables(1)(31 downto 16);
					when OFFSET_IRQ_CPU_MAP_1  =>
						o_DBus <= '0' & cpu_map(0,4) & cpu_map(0,3) &
							cpu_map(0,2) & cpu_map(0,1) & cpu_map(0,0);
					when OFFSET_IRQ_CPU_MAP_2  =>
						o_DBus <= '0' & cpu_map(0,9) & cpu_map(0,8) &
							cpu_map(0,7) & cpu_map(0,6) & cpu_map(0,5);
					when OFFSET_IRQ_CPU_MAP_3  =>
						o_DBus <= '0' & cpu_map(0,14) & cpu_map(0,13) &
							cpu_map(0,12) & cpu_map(0,11) & cpu_map(0,10);
					when OFFSET_IRQ_CPU_MAP_4  =>
						o_DBus <= '0' & cpu_map(0,19) & cpu_map(0,18) &
							cpu_map(0,17) & cpu_map(0,16) & cpu_map(0,15);
					when OFFSET_IRQ_CPU_MAP_5  =>
						o_DBus <= '0' & cpu_map(0,24) & cpu_map(0,23) &
							cpu_map(0,22) & cpu_map(0,21) & cpu_map(0,20);
					when OFFSET_IRQ_CPU_MAP_6  =>
						o_DBus <= '0' & cpu_map(0,29) & cpu_map(0,28) &
							cpu_map(0,27) & cpu_map(0,26) & cpu_map(0,25);
					when OFFSET_IRQ_CPU_MAP_7  =>
						o_DBus <= "0000000000" & cpu_map(0,31) & cpu_map(0,30);
					when OFFSET_IRQ_CPU_MAP_8  =>
						o_DBus <= '1' & cpu_map(1,4) & cpu_map(1,3) &
							cpu_map(1,2) & cpu_map(1,1) & cpu_map(1,0);
					when OFFSET_IRQ_CPU_MAP_9  =>
						o_DBus <= '1' & cpu_map(1,9) & cpu_map(1,8) &
							cpu_map(1,7) & cpu_map(1,6) & cpu_map(1,5);
					when OFFSET_IRQ_CPU_MAP_10 =>
						o_DBus <= '1' & cpu_map(1,14) & cpu_map(1,13) &
							cpu_map(1,12) & cpu_map(1,11) & cpu_map(1,10);
					when OFFSET_IRQ_CPU_MAP_11 =>
						o_DBus <= '1' & cpu_map(1,19) & cpu_map(1,18) &
							cpu_map(1,17) & cpu_map(1,16) & cpu_map(1,15);
					when OFFSET_IRQ_CPU_MAP_12 =>
						o_DBus <= '1' & cpu_map(1,24) & cpu_map(1,23) &
							cpu_map(1,22) & cpu_map(1,21) & cpu_map(1,20);
					when OFFSET_IRQ_CPU_MAP_13 =>
						o_DBus <= '1' & cpu_map(1,29) & cpu_map(1,28) &
							cpu_map(1,27) & cpu_map(1,26) & cpu_map(1,25);
					when OFFSET_IRQ_CPU_MAP_14 =>
						o_DBus <= "1000000000" & cpu_map(1,31) & cpu_map(1,30);
					when OFFSET_FPGA_VERSION =>
						o_DBus <= fpga_version_reg;
						fpga_version_rd <= i_rd_en;
					when others => -- scratch RAM
						if (INCLUDE_SCRATCH_RAM=true) and (unsigned(ABus(6 downto 4)) >= 6) then
							o_DBus <= scratch_ram_u(to_integer(unsigned(i_ABus(3 downto 0))))
							        & scratch_ram_l(to_integer(unsigned(i_ABus(3 downto 0))));
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
				if (INCLUDE_SCRATCH_RAM=true) and (unsigned(ABus(6 downto 4)) >= 6) then
					if i_be_r(1)='1' then
						scratch_ram_u(to_integer(unsigned(i_ABus(3 downto 0)))) <= i_DBus(15 downto 8);
					end if;
					if i_be_r(0)='1' then
						scratch_ram_l(to_integer(unsigned(i_ABus(3 downto 0)))) <= i_DBus(7 downto 0);
					end if;
				end if;
				
				case ABus is
					when OFFSET_IRQ0_ENABLES_SET_1 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(0)(i) <= '1';
							end if;
						end loop;
					when OFFSET_IRQ0_ENABLES_SET_2 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(0)(16+i) <= '1';
							end if;
					end loop;
					when OFFSET_IRQ0_ENABLES_CLR_1 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(0)(i) <= '0';
							end if;
						end loop;
					when OFFSET_IRQ0_ENABLES_CLR_2 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(0)(16+i) <= '0';
							end if;
					end loop;
					when OFFSET_IRQ1_ENABLES_SET_1 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(1)(i) <= '1';
							end if;
						end loop;
					when OFFSET_IRQ1_ENABLES_SET_2 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(1)(16+i) <= '1';
							end if;
						end loop;
					when OFFSET_IRQ1_ENABLES_CLR_1 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(1)(i) <= '0';
							end if;
						end loop;
					when OFFSET_IRQ1_ENABLES_CLR_2 =>
						for i in 0 to 15 loop
							if i_DBus(i)='1' then
								irq_enables(1)(16+i) <= '0';
							end if;
						end loop;
					when OFFSET_IRQ_CPU_MAP_SET =>
						cpu_map(to_integer(unsigned'('0' & i_DBus(15))),
							to_integer(unsigned(i_DBus(12 downto 8)))) <= i_DBus(2 downto 0);
						
					when others => NULL;
				end case;
			end if;
		end if;
	end process reg_write;

	-- IRQ masking logic
	gen_irqs : for i in 0 to 1 generate
	begin
		o_sys_nirq(i) <= '0' when (irq_flags(i) and irq_enables(i)) /= x"00000000" else '1';
	
		gen_mask: for j in 0 to 31 generate
		begin
			irq_flags(i)(j) <= i_irq_map(i)(j);
			irq_flags(i)(j) <= i_irq_map(i)(j);
		end generate gen_mask;
	end generate gen_irqs;

end rtl;
