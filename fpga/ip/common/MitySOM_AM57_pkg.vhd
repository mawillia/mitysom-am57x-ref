--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 


library IEEE;
use IEEE.STD_LOGIC_1164.all;

package MitySOM_AM57_pkg is

-- Declare types

	type bus32_vector is array(natural range <>) of std_logic_vector(31 downto 0);
	
	type bus16_vector is array(natural range <>) of std_logic_vector(15 downto 0);
	
	type bus12_vector is array(natural range <>) of std_logic_vector(11 downto 0);
	
	type bus11_vector is array(natural range <>) of std_logic_vector(10 downto 0);
	
	type bus10_vector is array(natural range <>) of std_logic_vector(9 downto 0);
	
	type bus9_vector is array(natural range <>) of std_logic_vector(8 downto 0);
	
	type bus8_vector is array(natural range <>) of std_logic_vector(7 downto 0);
	
	type bus5_vector is array(natural range <>) of std_logic_vector(4 downto 0);
	
	type bus4_vector is array(natural range <>) of std_logic_vector(3 downto 0);

component core_version
	port (
		clk           : in std_logic;                       -- system clock
		rd            : in std_logic;                       -- read enable
		ID            : in std_logic_vector(7 downto 0);    -- assigned ID number, 0xF0-0xFF are reserved for customers
		version_major : in std_logic_vector(3 downto 0);    -- major version number 1-15
		version_minor : in std_logic_vector(3 downto 0);    -- minor version number 0-15
		year          : in std_logic_vector(4 downto 0);    -- year since 2000
		month         : in std_logic_vector(3 downto 0);    -- month (1-12)
		day           : in std_logic_vector(4 downto 0);    -- day (1-32)
		ilevel        : in std_logic_vector(1 downto 0) := "00";       -- interrupt level (0=4,1=5,2=6,3=7)
		ivector       : in std_logic_vector(3 downto 0) := "0000";    -- interrupt vector (0 through 31)
		o_data        : out std_logic_vector(15 downto 0)
	);
end component;

component base_module is
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
end component;

component GPMC_iface is
	generic ( 
		DECODE_BITS   : integer range 1 to 9 := 5;
		CONFIG        : string := "ASYNC_MODE"        -- "ASYNC_MODE" 
	);
	port (
		i_core_clk    : in  std_logic;
		
		-- GPMC direct-connect signals
		i_gpmc_cs_n   : in  std_logic;
		io_gpmc_ad    : inout std_logic_vector(15 downto 0);
		i_gpmc_adv_n  : in  std_logic; -- address valid
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
end component;

component gpio is
	Generic (
	   NUM_BANKS       : integer range 1 to 4 := 1;
	   NUM_IO_PER_BANK : integer range 1 to 16 := 16
	);
	Port ( 
	   clk             : in  std_logic;
	   i_ABus          : in  std_logic_vector(5 downto 0);
	   i_DBus          : in  std_logic_vector(15 downto 0);
	   o_DBus          : out std_logic_vector(15 downto 0);
	   i_wr_en         : in  std_logic;
	   i_rd_en         : in  std_logic;
	   i_cs            : in  std_logic;
	   o_irq           : out std_logic := '0';
	   i_ilevel        : in  std_logic_vector(1 downto 0) := "00";      
	   i_ivector       : in  std_logic_vector(3 downto 0) := "0000";   
	   i_io            : in  std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
	   t_io            : out std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0); --! Desired direction of io by driver. '0' = output. '1' = input.
	   o_io            : out std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0);
	   i_initdir       : in  std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0'); --! Initial direction of io. '1' is output. '0' is input.
	   i_initoutval    : in  std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0')  --! Default output state.
	);
 end component;
 
--  type <new_type> is
--    record
--        <type_name>        : std_logic_vector( 7 downto 0);
--        <type_name>        : std_logic;
--    end record;

-- Declare constants

--  constant <constant_name>		: time := <time_unit> ns;
--  constant <constant_name>		: integer := <value>;
 
-- Declare library component entities

-- Declare functions and procedure

--  function <function_name>  (signal <signal_name> : in <type_declaration>) return <type_declaration>;
--  procedure <procedure_name>	(<type_declaration> <constant_name>	: in <type_declaration>);

end MitySOM_AM57_pkg;


package body MitySOM_AM57_pkg is

-- Example 1
--  function <function_name>  (signal <signal_name> : in <type_declaration>  ) return <type_declaration> is
--    variable <variable_name>     : <type_declaration>;
--  begin
--    <variable_name> := <signal_name> xor <signal_name>);
--    return <variable_name>; 
--  end <function_name>;


-- Example 2
--  function <function_name>  (signal <signal_name> : in <type_declaration>;
--                         signal <signal_name>   : in <type_declaration>  ) return <type_declaration> is
--  begin
--    if (<signal_name> = '1') then
--      return <signal_name>;
--    else
--      return 'Z';
--    end if;
--  end <function_name>;

-- Procedure Example
--  procedure <procedure_name>  (<type_declaration> <constant_name>  : in <type_declaration>) is
--    
--  begin
--    
--  end <procedure_name>;
 
end MitySOM_AM57_pkg;
