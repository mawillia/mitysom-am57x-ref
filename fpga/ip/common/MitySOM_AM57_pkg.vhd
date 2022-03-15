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

component core_version is
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

		i_irq_map       : in  bus32_vector(1 downto 0) := (others=>(others=>'0'));
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
	   i_ilevel        : in  std_logic := '0';      
	   i_ivector       : in  std_logic_vector(4 downto 0) := "00000";   
	   i_io            : in  std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
	   t_io            : out std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0); --! Desired direction of io by driver. '0' = output. '1' = input.
	   o_io            : out std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0);
	   i_initdir       : in  std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0'); --! Initial direction of io. '1' is output. '0' is input.
	   i_initoutval    : in  std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0')  --! Default output state.
	);
end component;

component pcie_dma is
	generic 
	(
		g_max_tlp_size : natural := 32; --! Maximum number of 32-bit
			--! words per TLP sent via PCIe. The larger this is
			--! the more efficiently we can use PCIe bandwith at
			--! the cost of needing a largerFIFO in this core.
			--! Note that the AM57 reports it is limited to TLPs
			--! of 64, but testing shows it's actually limited to
			--! to 32. 
		g_num_driving_cores: natural := 1 --! Defines how many different
			--! Cores are using PCIe output. This defines how
			--! big of a mux we need to round robin and allow
			--! each input core to send data.
	);
	port (
		--! Register interface to change some configurations)
		--! Probably won't need to use this as FPGA core that generates
		--! data for this core will control address, interrupts, etc.
		i_reg_clk : in  std_logic;

		i_reg_addr : in  std_logic_vector(5 downto 0);
		i_reg_data : in  std_logic_vector(15 downto 0);
		o_reg_data : out std_logic_vector(15 downto 0);
		i_reg_wr : in  std_logic;
		i_reg_rd : in  std_logic;
		i_reg_cs : in  std_logic;
		      
		--! 100 MHz Clock use for PCIe
		i_pcie_sys_clk : in std_logic; 
		i_pcie_sys_rst_n : in std_logic;

		--! PCIe physical layer pins:
		o_pci_exp_txp : out std_logic_vector(1 downto 0);
		o_pci_exp_txn : out std_logic_vector(1 downto 0);
		i_pci_exp_rxp : in  std_logic_vector(1 downto 0);
		i_pci_exp_rxn : in  std_logic_vector(1 downto 0);

		o_pcie_axi_clk : out std_logic; --! 125 MHz clock used by PCIe Core. Feel free to use 
			--! use this as i_dma_data_clk, but read notes for that signal regarding throughput
			--! and backpressure!

		--! Interface for FPGA core to provide data to core for DMAing to AM57 via PCIe
		i_dma_data_clk : in std_logic; --! Clock that is synchronous to incoming data to be DMA'ed. Note that 
			--! internally the core runs on a clock of 125 MHz so be sure to design properly to make sure
			--! you are not using too much bandwidth (and watch tready in case the core needs to apply back pressure).
			--! Note that max throughput to the PCIe sub core is 8 Gbit/s (2 lanes at 5.0 GT/s with 8b10b encoding).
			--! Also note that in order to create TLPs header data needs to be added so you will get back pressure
			--! if you try to use full 8 Gbit/s throughput (overhead is 3 32-bit words per TLP).

		--! Note that for the following g_num_driving_cores defines width of bus so that if there are multiple cores both using PCIe
		--!  this component can round robin handle input data.
		i_dma_data_axis_tdata : IN STD_LOGIC_VECTOR((g_num_driving_cores * 64)-1 DOWNTO 0); --! Data words to be written to AM57 Memory Space
		i_dma_data_axis_tlast : IN STD_LOGIC_VECTOR(g_num_driving_cores-1 downto 0); --! Indicates last data word of a packet.
		i_dma_data_axis_tvalid : IN STD_LOGIC_VECTOR(g_num_driving_cores-1 downto 0); --! Indicates when i_*_axis inputs are valid.
		o_dma_data_axis_tready : OUT STD_LOGIC_VECTOR(g_num_driving_cores-1 downto 0); --! Indicates backpressure (i.e. if current data word needs to be held as is).
		i_dma_data_axis_tkeep : IN STD_LOGIC_VECTOR((g_num_driving_cores * 8)-1 DOWNTO 0); --! Should always be all '1'

		i_dma_data_start_addr : in std_logic_vector((g_num_driving_cores * 32)-1 downto 0); --! Indicates the AM57 physical address where the incoming packet data will start being written.
			--! Must be constant and valid throughout entire packet.

		i_dma_data_complete_en : in std_logic_vector(g_num_driving_cores-1 downto 0); --! Indicates if driving core(s) wants a complete signal
			--! sent back once final write TLP is verified to be in AM57 memory.
		o_dma_data_complete : out std_logic_vector(g_num_driving_cores-1 downto 0) --! Either edge transition on bit indicates that final TLP write has finished and AM57 can be 
			--! interrupted to indicate data is ready to be read. 
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
