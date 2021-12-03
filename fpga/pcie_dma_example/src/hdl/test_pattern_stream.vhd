--- Title: test_pattern_stream.vhd
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

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity test_pattern_stream is
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
		      
		i_axi_clk : in std_logic; --! Data on *_axis_* is synchronous to this clock.

		--! Used to stream data to pcie_dma core which is to be DMA'ed into AM57 memory. Used in conjunction with *_dma_* signals.
		o_axis_tdata : out STD_LOGIC_VECTOR(63 DOWNTO 0); 
		o_axis_tlast : out STD_LOGIC; 
		o_axis_tvalid : out STD_LOGIC;
		i_axis_tready : in STD_LOGIC;
		o_axis_tkeep : out STD_LOGIC_VECTOR(7 DOWNTO 0);

		o_dma_data_start_addr : out std_logic_vector(31 downto 0); --! Indicates the AM57 physical address where the incoming packet data will start being written.
			--! Must be constant and valid throughout entire packet.

		o_dma_complete_en : out std_logic; --! If high this requests that the PCIe core report back via i_dma_data_complete once that 
			--! last TLP has been successfully written. 
		i_dma_data_complete : in std_logic --! Either edge transition on bit indicates that final TLP write has finished and AM57 can be 
			--! interrupted too access memory
	);
end test_pattern_stream;

architecture rtl of test_pattern_stream is

	------------------------------------
	-- Constants
	------------------------------------

	constant VER_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(0, 6));
	constant CTRL_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1, 6));

	constant ISR_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2, 6));

	constant AM57_WADDR_REG_LO_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(4, 6));
	constant AM57_WADDR_REG_HI_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(5, 6));

	constant BRAM_WADDR_REG_LO_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(6, 6));

	constant RAM_DATA_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(8, 6));

	constant TP_PACKET_SIZE_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(10, 6));
	constant TP_PACKET_SIZE_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(11, 6));

	constant BRAM_START_ADDR_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(12, 6));


	constant FCBUFF_MAX_SIZE : integer := 8;


	------------------------------------
	-- Signals 
	------------------------------------

	signal s_srst_reg : std_logic := '1';
	signal s_srst_meta : std_logic := '1';
	signal s_srst_axi : std_logic := '1';

	signal s_tp_data_ram_start_raddr_reg : std_logic_vector(9 downto 0) := (others => '0');
	signal s_tp_data_ram_start_raddr_meta : std_logic_vector(9 downto 0) := (others => '0');
	signal s_tp_data_ram_start_raddr : std_logic_vector(9 downto 0) := (others => '0');

	signal s_tp_packet_size_reg : std_logic_vector(31 downto 0) := (others => '0');
	signal s_tp_packet_size_meta : std_logic_vector(31 downto 0) := (others => '0');
	signal s_tp_packet_size : std_logic_vector(31 downto 0) := (others => '0');

	signal s_i_dma_data_complete_meta : std_logic := '0';
	signal s_i_dma_data_complete_r1 : std_logic := '0';
	signal s_i_dma_data_complete_r2 : std_logic := '0';

	signal s_dma_complete : std_logic := '0'; 

	signal s_tp_data_cntr : integer := 0; -- Counts how many 64-bit samples to read from BRAM when generating a packet for PCIe 

	type t_axi_fcbuff_data is array(0 to FCBUFF_MAX_SIZE-1) of std_logic_vector(64 downto 0);
	signal s_axi_fcbuff_data : t_axi_fcbuff_data := (others => (others => '0'));

	signal s_axi_fcbuff_raddr : integer range 0 to FCBUFF_MAX_SIZE-1 := 0;
	signal s_axi_fcbuff_waddr : integer range 0 to FCBUFF_MAX_SIZE-1 := 0;
	signal s_axi_fcbuff_cnt : integer range 0 to FCBUFF_MAX_SIZE-1 := 0;

	signal s_tp_data_ram_we : std_logic := '0';
	signal s_tp_data_ram_waddr : std_logic_vector(11 downto 0) := (others => '0');
	signal s_tp_data_ram_wdata: std_logic_vector(15 downto 0) := (others => '0');

	signal s_tp_data_ram_re : std_logic := '0';
	signal s_tp_data_ram_re_r1 : std_logic := '0';
	signal s_tp_data_ram_raddr : std_logic_vector(9 downto 0) := (others => '0');
	signal s_tp_data_ram_rdata: std_logic_vector(63 downto 0) := (others => '0');

	signal s_tp_data_last : std_logic := '0';
	signal s_tp_data_last_r1 : std_logic := '0';

	signal s_o_axis_tvalid : STD_LOGIC := '0';

	signal s_o_dma_start_addr : std_logic_vector(31 downto 0) := (others => '0');


	------------------------------------
	-- Components 
	------------------------------------

	component xpm_memory_sdpram                                                     
	  generic (                                                                     
											
	    -- Common module generics                                                   
	    MEMORY_SIZE             : integer := 2048           ;                       
	    MEMORY_PRIMITIVE        : string  := "auto"         ;                       
	    CLOCKING_MODE           : string  := "common_clock" ;                       
	    ECC_MODE                : string  := "no_ecc"       ;                       
	    MEMORY_INIT_FILE        : string  := "none"         ;                       
	    MEMORY_INIT_PARAM       : string  := ""             ;                       
	    USE_MEM_INIT            : integer := 1              ;                       
	    WAKEUP_TIME             : string  := "disable_sleep";                       
	    AUTO_SLEEP_TIME         : integer := 0              ;                       
	    MESSAGE_CONTROL         : integer := 0              ;                       
	    USE_EMBEDDED_CONSTRAINT : integer := 0              ;                       
	    MEMORY_OPTIMIZATION     : string  := "true";                                
	    CASCADE_HEIGHT          : integer := 0               ;                      
	    SIM_ASSERT_CHK          : integer := 0               ;                      
											
	    -- Port A module generics                                                   
	    WRITE_DATA_WIDTH_A      : integer := 32 ;                                   
	    BYTE_WRITE_WIDTH_A      : integer := 32 ;                                   
	    ADDR_WIDTH_A            : integer := 6  ;                                   
	    RST_MODE_A              : string  := "SYNC";                                
											
	    -- Port B module generics                                                   
	    READ_DATA_WIDTH_B       : integer := 32          ;                          
	    ADDR_WIDTH_B            : integer := 6           ;                          
	    READ_RESET_VALUE_B      : string  := "0"         ;                          
	    READ_LATENCY_B          : integer := 2           ;                          
	    WRITE_MODE_B            : string  := "no_change" ;                          
	    RST_MODE_B              : string  := "SYNC"                                 
											
											
	  );                          
	  port (                                                                        
											
	    -- Common module ports                                                      
	    sleep          : in  std_logic;                                             
											
	    -- Port A module ports                                                      
	    clka           : in  std_logic;                                             
	    ena            : in  std_logic;                                             
	    wea            : in  std_logic_vector((WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1 downto 0);
	    addra          : in  std_logic_vector(ADDR_WIDTH_A-1 downto 0);             
	    dina           : in  std_logic_vector(WRITE_DATA_WIDTH_A-1 downto 0);       
	    injectsbiterra : in  std_logic;                                             
	    injectdbiterra : in  std_logic;                                             
											
	    -- Port B module ports                                                      
	    clkb           : in  std_logic;                                             
	    rstb           : in  std_logic;                                             
	    enb            : in  std_logic;                                             
	    regceb         : in  std_logic;                                             
	    addrb          : in  std_logic_vector(ADDR_WIDTH_B-1 downto 0);             
	    doutb          : out std_logic_vector(READ_DATA_WIDTH_B-1 downto 0);        
	    sbiterrb       : out std_logic;                                             
	    dbiterrb       : out std_logic                                              
	  );                                                                            
	end component;         

begin

	REG_WRITE_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then

			s_tp_data_ram_we <= '0';
				
			s_i_dma_data_complete_meta <= i_dma_data_complete;
			s_i_dma_data_complete_r1 <= s_i_dma_data_complete_meta;
			s_i_dma_data_complete_r2 <= s_i_dma_data_complete_r1;

			if (s_i_dma_data_complete_r1 /= s_i_dma_data_complete_r2) then
				s_dma_complete <= '1';
				--TODO: also drive o_irq appropriately. Probably need mask register, etc.
			end if;

			if (s_tp_data_ram_we = '1') then
				s_tp_data_ram_waddr <= STD_LOGIC_VECTOR(UNSIGNED(s_tp_data_ram_waddr) + 1);
			end if;

			if (i_reg_cs = '1' and i_reg_wr = '1') then
				case i_reg_addr is
					when VER_REG_OFFSET =>
						null;

					when CTRL_REG_OFFSET =>
						s_srst_reg <= i_reg_data(0);


					when ISR_REG_OFFSET =>
						if (i_reg_data(0) = '1') then
							s_dma_complete <= '0';
						end if;


					when AM57_WADDR_REG_LO_OFFSET =>
						s_o_dma_start_addr(15 downto 0) <= i_reg_data;

					when AM57_WADDR_REG_HI_OFFSET => 
						s_o_dma_start_addr(31 downto 16) <= i_reg_data;


					when BRAM_WADDR_REG_LO_OFFSET => 
						s_tp_data_ram_waddr <= i_reg_data(11 downto 0);


					when RAM_DATA_REG_OFFSET => 
						s_tp_data_ram_wdata <= i_reg_data(15 downto 0);
						s_tp_data_ram_we <= '1';


					when TP_PACKET_SIZE_LO_REG_OFFSET => 
						s_tp_packet_size_reg(15 downto 0) <= i_reg_data;

					when TP_PACKET_SIZE_HI_REG_OFFSET => 
						s_tp_packet_size_reg(31 downto 16) <= i_reg_data;


					when BRAM_START_ADDR_REG_OFFSET => 
						s_tp_data_ram_start_raddr_reg <= i_reg_data(9 downto 0);

						
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

			if (i_reg_cs = '1') then
				case i_reg_addr is
					when VER_REG_OFFSET =>
						o_reg_data <= x"BAB7";


					when CTRL_REG_OFFSET =>
						o_reg_data(0) <= s_srst_reg;


					when ISR_REG_OFFSET =>
						o_reg_data(0) <= s_dma_complete;


					when AM57_WADDR_REG_LO_OFFSET =>
						o_reg_data(15 downto 0) <= s_o_dma_start_addr(15 downto 0);

					when AM57_WADDR_REG_HI_OFFSET => 
						o_reg_data(15 downto 0) <= s_o_dma_start_addr(31 downto 16);


					when BRAM_WADDR_REG_LO_OFFSET => 
						o_reg_data(11 downto 0) <= s_tp_data_ram_waddr;


					when RAM_DATA_REG_OFFSET => 
						o_reg_data(15 downto 0) <= s_tp_data_ram_wdata;


					when TP_PACKET_SIZE_LO_REG_OFFSET => 
						o_reg_data(15 downto 0) <= s_tp_packet_size_reg(15 downto 0);

					when TP_PACKET_SIZE_HI_REG_OFFSET => 
						o_reg_data(15 downto 0) <= s_tp_packet_size_reg(31 downto 16);


					when BRAM_START_ADDR_REG_OFFSET => 
						o_reg_data(9 downto 0) <= s_tp_data_ram_start_raddr_reg;


					when others =>
						o_reg_data <= x"DEAD";
				end case;
			end if;
		end if;
	end process REG_READ_PROC;


	TEST_PATTERN_DATA_SDPRAM_INST : xpm_memory_sdpram                                                     
	  generic map 
          (
	    -- Common module generics                                                   
	    MEMORY_SIZE => 65536,
	    MEMORY_PRIMITIVE => "auto",
	    CLOCKING_MODE => "independent_clock",
	    ECC_MODE => "no_ecc",
	    MEMORY_INIT_FILE => "none",
	    MEMORY_INIT_PARAM => "",
	    USE_MEM_INIT => 0,
	    WAKEUP_TIME => "disable_sleep",
	    AUTO_SLEEP_TIME => 0,
	    MESSAGE_CONTROL => 0,
	    USE_EMBEDDED_CONSTRAINT => 0,
	    MEMORY_OPTIMIZATION => "true",
	    CASCADE_HEIGHT => 0,
	    SIM_ASSERT_CHK => 0, 
											
	    -- Port A module generics                                                   
	    WRITE_DATA_WIDTH_A => 16,
	    BYTE_WRITE_WIDTH_A => 16,
	    ADDR_WIDTH_A => 12,
	    RST_MODE_A => "SYNC",
											
	    -- Port B module generics                                                   
	    READ_DATA_WIDTH_B => 64,
	    ADDR_WIDTH_B => 10,
	    READ_RESET_VALUE_B => "0",
	    READ_LATENCY_B => 1,
	    WRITE_MODE_B => "no_change",
	    RST_MODE_B => "SYNC"
	  )                          
	  port map 
          (                                                                        
	    -- Common module ports                                                      
	    sleep => '0',
											
	    -- Port A module ports                                                      
	    clka => i_reg_clk,
	    ena => s_tp_data_ram_we,
	    wea(0) => s_tp_data_ram_we,
	    addra => s_tp_data_ram_waddr,
	    dina => s_tp_data_ram_wdata,
	    injectsbiterra => '0',
	    injectdbiterra => '0',
											
	    -- Port B module ports                                                      
	    clkb => i_axi_clk,
	    rstb => '0',
	    enb => s_tp_data_ram_re,
	    regceb => s_tp_data_ram_re,
	    addrb => s_tp_data_ram_raddr,
	    doutb => s_tp_data_ram_rdata,
	    sbiterrb => open,
	    dbiterrb => open
	  );                                                                            

	PATTERN_DATA_OUT_PROC : process(i_axi_clk)
		variable v_axi_fcbuff_cnt : integer := 0;
	begin
		if rising_edge(i_axi_clk) then
			s_srst_meta <= s_srst_reg;
			s_srst_axi <= s_srst_meta;

			s_tp_data_ram_start_raddr_meta <= s_tp_data_ram_start_raddr_reg;
			s_tp_data_ram_start_raddr <= s_tp_data_ram_start_raddr_meta;

			s_tp_packet_size_meta <= s_tp_packet_size_reg;
			s_tp_packet_size <= s_tp_packet_size_meta;

			s_o_axis_tvalid <= '0';

			v_axi_fcbuff_cnt := s_axi_fcbuff_cnt;

			s_tp_data_ram_re <= '0';

			s_tp_data_last <= '0';

			s_tp_data_ram_re_r1 <= s_tp_data_ram_re;

			if (s_srst_axi = '1') then
				s_axi_fcbuff_cnt <= 0;
				s_axi_fcbuff_raddr <= 0;

				s_tp_data_ram_raddr <= s_tp_data_ram_start_raddr;
				
				s_tp_data_cntr <= 0;
			else
				-- Logic for reading data from buffer and reacting to flow control from AXI bus
				if (s_axi_fcbuff_cnt > 0) then
					s_o_axis_tvalid <= '1';

					if (i_axis_tready = '1') then
						v_axi_fcbuff_cnt := v_axi_fcbuff_cnt - 1;
					end if;
				end if;	

				-- Increment address after sample on output of FIFO marked as valid
				if (s_o_axis_tvalid = '1') then
					s_axi_fcbuff_raddr <= s_axi_fcbuff_raddr + 1;
				end if;

				-- Logic for filling flow control buffer (and pushing test pattern data out of RAM at desired rate)
				if (s_tp_data_ram_re = '1') then
					v_axi_fcbuff_cnt := v_axi_fcbuff_cnt + 1;
					s_tp_data_ram_raddr <= STD_LOGIC_VECTOR(UNSIGNED(s_tp_data_ram_raddr) + 1);
					s_tp_data_last_r1 <= s_tp_data_last;
				end if;

				if (s_tp_data_ram_re_r1 = '1') then
					s_axi_fcbuff_data(s_axi_fcbuff_waddr)(63 downto 0) <= s_tp_data_ram_rdata;
					s_axi_fcbuff_data(s_axi_fcbuff_waddr)(64) <= s_tp_data_last_r1;
					s_axi_fcbuff_waddr <= s_axi_fcbuff_waddr + 1;
				end if;

				if (v_axi_fcbuff_cnt < FCBUFF_MAX_SIZE-3) then
					--TODO: add way to queue multiple requests with delays (if desired) inbetween??
					-- Currently we handle one packet output request when taken out of reset
					if (s_tp_data_cntr < TO_INTEGER(UNSIGNED(s_tp_packet_size))) then
						s_tp_data_ram_re <= '1';

						s_tp_data_cntr <= s_tp_data_cntr + 1;
					end if;

					if (s_tp_data_cntr = s_tp_packet_size-1) then
						s_tp_data_last <= '1';
					end if;
				end if;
			end if;

			s_axi_fcbuff_cnt <= v_axi_fcbuff_cnt;
		end if;
	end process PATTERN_DATA_OUT_PROC;

	--TODO: make register so we can enable interrupts if desired?
	o_dma_complete_en <= '1';

	o_dma_data_start_addr <= s_o_dma_start_addr;

	o_axis_tdata <= s_axi_fcbuff_data(s_axi_fcbuff_raddr)(63 downto 0);
	o_axis_tvalid <= s_o_axis_tvalid;
	o_axis_tlast <= s_axi_fcbuff_data(s_axi_fcbuff_raddr)(64);
	o_axis_tkeep <= "11111111";

end rtl;

