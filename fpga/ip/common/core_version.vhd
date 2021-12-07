-- Module: core_version.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MitySOM_AM57_pkg.all;

entity core_version is
	port (
		clk           : in std_logic;                       -- system clock
		rd            : in std_logic;                       -- read enable
		ID            : in std_logic_vector(7 downto 0);    -- assigned ID number, 0xF0-0xFF are reserved for customers
		version_major : in std_logic_vector(3 downto 0);    -- major version number 1-15
		version_minor : in std_logic_vector(3 downto 0);    -- minor version number 0-15
		year          : in std_logic_vector(4 downto 0);    -- year since 2000
		month         : in std_logic_vector(3 downto 0);    -- month (1-12)
		day           : in std_logic_vector(4 downto 0);    -- day (1-32)
		ilevel        : in std_logic := '0';                -- interrupt level (0=SYS_NIRQ2 or 1=SYS_NIRQ1)
		ivector       : in std_logic_vector(4 downto 0) := "00000";    -- interrupt vector (0 through 31)
		o_data        : out std_logic_vector(15 downto 0)
	);
end core_version;

architecture rtl of core_version is

signal addr : std_logic_vector(1 downto 0) := "00";

-- debugging, uncomment to ease locating nets for ILA insertion
-- attribute mark_debug : string;
-- attribute syn_keep : boolean;
-- attribute mark_debug of addr : signal is "true";
-- attribute syn_keep of addr : signal is true;

begin

-- generate 4 "FIFO" addresses for version information to be packed in
-- one location in core address space....  Align stuff up on nibble
-- boundaries if we can...
mux_reg_out : process(addr, ilevel, ivector, ID, year, month, version_major, version_minor, day)
begin
	case addr is
		when "00" =>
			o_data <= "00" & ilevel & ivector & ID; 
		when "01" =>
			o_data <= "01" & '0' & year & version_major & version_minor;
		when "10" =>
			o_data <= "10" & "00" & month & "000" & day; 
		when "11" =>
			o_data <= "11" & "00" & x"000";
		when others => NULL;
	end case;
end process mux_reg_out;

-- bump FIFO address and let it roll around...
addr_proc : process (clk)
begin
	if rising_edge(clk) then
		if rd='1' then
			addr <= std_logic_vector(unsigned(addr)+1);
		end if;
	end if;
end process addr_proc; 

end rtl;  
