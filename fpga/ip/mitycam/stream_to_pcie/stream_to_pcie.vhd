--- Title: stream_to_pcie.vhd
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
use ieee.numeric_std.all;
use IEEE.math_real.all;

library xpm;
use xpm.vcomponents.all;

library work;
use WORK.MitySOM_AM57_pkg.ALL;
use work.mitycam_pkg.all;

entity stream_to_pcie is
	generic (
		g_packed_pixels_per_clk       : integer := 4;
		g_axis_width                  : integer := 64;
		pixel_fifo_depth              : natural := 2048 --! Number of pixels to buffer in RAM
	);
	port (
		i_reg_clk : in  std_logic;

		i_reg_addr : in  std_logic_vector(5 downto 0);
		i_reg_data : in  std_logic_vector(15 downto 0);
		o_reg_data : out std_logic_vector(15 downto 0);
		i_reg_wr : in  std_logic;
		i_reg_rd : in  std_logic;
		i_reg_cs : in  std_logic;

		o_irq : out std_logic := '0';
		i_ilevel : in  std_logic := '0';      
		i_ivector : in  std_logic_vector(4 downto 0) := "00000";   

		-- MityCAM streaming interface input
		i_data_clk           : in std_logic;
		i_data_data          : in std_logic_vector(g_packed_pixels_per_clk*16-1 downto 0);
		i_data_startofpacket : in std_logic;
		i_data_endofpacket   : in std_logic;
		o_data_ready         : out std_logic;
		i_data_valid         : in std_logic;

		--! Used to stream data to pcie_dma core which is to be DMA'ed into AM57 memory. Used in conjunction with *_dma_* signals.
		i_axi_clk : in std_logic; --! Data on *_axis_* is synchronous to this clock.
		o_axis_tdata  : out STD_LOGIC_VECTOR(g_axis_width-1 DOWNTO 0); 
		o_axis_tlast  : out STD_LOGIC; 
		o_axis_tvalid : out STD_LOGIC;
		i_axis_tready : in STD_LOGIC;
		o_axis_tkeep  : out STD_LOGIC_VECTOR(g_axis_width/8-1 DOWNTO 0);

		o_dma_data_start_addr : out std_logic_vector(31 downto 0); --! Indicates the AM57 physical address where the incoming packet data will start being written.
		o_dma_complete_en : out std_logic; --! If high this requests that the PCIe core report back via i_dma_data_complete once that 
		i_dma_data_complete : in std_logic --! Either edge transition on bit indicates that final TLP write has finished and AM57 can be 
	);
end stream_to_pcie;

architecture rtl of stream_to_pcie is

	------------------------------------
	-- Constants
	------------------------------------
	constant VERSION_REG_OFFSET         : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(0*2, 6));
	constant CTRL_REG_OFFSET_LOW        : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1*2, 6));
	constant CTRL_REG_OFFSET_HIGH       : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1*2+1, 6));
	constant START_ADDR_REG_OFFSET_LOW  : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2*2, 6));
	constant START_ADDR_REG_OFFSET_HIGH : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2*2+1, 6));
	constant END_ADDR_REG_OFFSET_LOW    : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(3*2, 6));
	constant END_ADDR_REG_OFFSET_HIGH   : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(3*2+1, 6));
	-- Hole left for Frame Size register offset. Only used for CIS2521 specific implementation.
	constant INT_LVL_REG_OFFSET         : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(5*2, 6));
	constant NUM_FRAMES_REG_OFFSET      : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(6*2, 6));

	constant ADDR_INC : natural := g_axis_width/8; --! Defines how the output address should be incremented depending on the  axis write data width.

	constant SHIFT_REG_SIZE : natural := 1 + 8/(g_packed_pixels_per_clk/2); --! The number cycles it takes to write the 256-bit word before the imager data, which contains header information.

	constant FCBUFF_MAX_SIZE : integer := 8;
	constant SR_LAST_SAMP_LOC : natural := 257; --! Offset in shift register where "last pixel" marker is stored.
	constant SR_PIX_V_LOC : natural := 256; --! Offset in shift register where pixel valid is stored.

	constant CORE_VERSION_MAJOR:  std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 01, 4));
	constant CORE_VERSION_MINOR:  std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 00, 4));
	constant CORE_ID:             std_logic_vector(7 downto 0) := std_logic_vector( to_unsigned( 64, 8));
	constant CORE_YEAR:           std_logic_vector(4 downto 0) := std_logic_vector( to_unsigned( 22, 5));
	constant CORE_MONTH:          std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 03, 4));
	constant CORE_DAY:            std_logic_vector(4 downto 0) := std_logic_vector( to_unsigned( 03, 5));

	------------------------------------
	-- Signals 
	------------------------------------
	type t_shift_reg is array(SHIFT_REG_SIZE-1 downto 0) of std_logic_vector(SR_LAST_SAMP_LOC downto 0); --! Each array entry is 32 bits of data, 1 bit pixel valid flag and 1 bit frame valid flag.
	signal s_shift_reg : t_shift_reg; --! Shift register to make up for delay time needed to send out header data.

	signal s_int_en_reg : std_logic := '0'; 

	signal s_srst, s_srst_m : std_logic := '0';
	signal s_srst_data, s_srst_data_m : std_logic := '0';
	signal s_srst_reg : std_logic := '0';

	signal s_packed_mode_reg : std_logic_vector(1 downto 0) := "00";
	signal s_packed_mode_data  : std_logic_vector(1 downto 0) := "00";
	signal s_packed_mode : std_logic_vector(1 downto 0) := "00";

	signal s_i_test_pattern_en_reg:  std_logic := '0';
	signal s_i_test_pattern_en_data : std_logic := '0';

	signal s_int_status_reg : std_logic := '0'; --! Active high to indicate interrupt condition has occurred.
	signal s_int_status : std_logic := '0'; --! Active high to indicate interrupt condition has occurred.
	signal s_int_clr_tog_reg : std_logic := '0'; --! Toggled when HPS writes to clear interrupt status bit.
	signal s_int_clr_tog_meta : std_logic := '0'; --! History for edge detection.
	signal s_int_clr_tog : std_logic := '0'; --! History for edge detection.
	signal s_int_clr_tog_r1 : std_logic := '0'; --! History for edge detection.

	signal s_axis_tvalid_addr : unsigned(31 downto 0) := (others=>'0');
	signal s_start_addr_reg : std_logic_vector(31 downto 0) := x"30000000";
	signal s_start_addr : unsigned(31 downto 0) := x"30000000";

	signal s_end_addr_reg : std_logic_vector(31 downto 0) := x"60000000";
	signal s_end_addr : unsigned(31 downto 0) := x"60000000";

	signal s_int_lvl_reg : std_logic_vector(15 downto 0) := (others => '0');
	signal s_int_lvl : std_logic_vector(15 downto 0) := (others => '0');

	signal s_num_cap_frames_reg : unsigned(15 downto 0) := (others => '0');
	signal s_num_cap_frames : unsigned(15 downto 0) := (others => '0');

	signal s_i_packet_sync_error_clr_reg : std_logic := '0';
	signal s_i_packet_sync_error_clr_data : std_logic := '0';
	signal s_i_packet_sync_error_sticky_reg : std_logic := '0';
	signal s_i_packet_sync_error_sticky_data : std_logic := '0';

	signal s_FIFO_overflow_sticky_reg : std_logic := '0';
	signal s_FIFO_overflow_sticky_data : std_logic := '0';
	signal s_FIFO_overflow_sticky_clr_reg : std_logic := '0';
	signal s_FIFO_overflow_sticky_clr_data : std_logic := '0';

	signal s_buff_rdempty : std_logic := '0';
	signal s_buff_valid   : std_logic := '0';

	signal s_dma_data_complete_r1 : std_logic := '0';

	-- Data packing related:
	type t_pack_state is
		(
			IDLE_PACK_STATE, --! Waiting for start of packet.
			HDR_PACK_STATE, --! Write 256 word (in 32-bit chunks) to FIFO. Includes packet header data.
			NO_PACK_STATE, --! Packing is disabled and all 16 bits of each pixel are kept.
			PACK_STATE_1, --! We have received 24 bits of data (two 16 bit pixels trimmed to 12 bits each). Not enough to write to FIFO.
			PACK_STATE_2, --! Write 24 bits saved from last state and  8 bits from this cycle. Save top 16 bits from this cycle.
			PACK_STATE_3, --! Write 16 bits saved from last state and 16 bits from this cycle. Save top  8 bits from this cycle.
			PACK_STATE_4, --! Write  8 bits saved from last state and 24 bits from this cycle. No bits left to save from this cycle.
			PACK_FLUSH_STATE_1, --! If we receive last frame samples in PACK_STATE_1, we need to flush to flush saved pack data.
			PACK_FLUSH_STATE_2, --! If we receive last frame samples in PACK_STATE_2, we need to flush to flush saved pack data.
			PACK_FLUSH_STATE_3, --! If we receive last frame samples in PACK_STATE_3, we need to flush to flush saved pack data.
			PACK8_STATE_1, -- ! State used for 8 bit packing mode
			PACK8_STATE_2, -- ! State used for 8 bit packing mode
			PACK8_FLUSH_STATE_1, -- ! Status used for 8 bit packing mode
			PACK_FLUSH_END_STATE  --! Check if we need to write any final 32-bit words to make sure we end on a clean g_axis_width-bit 
				--! word in the FIFO.
		);
	attribute pack_state_one_hot_encoding : string;
	attribute pack_state_one_hot_encoding of t_pack_state: type is "00000000001 00000000010 00000000100 00000001000 00000010000 00000100000 00001000000 00010000000 00100000000 01000000000 10000000000";
	signal s_pack_state : t_pack_state := IDLE_PACK_STATE; --! State for optional packing of 12-bit pixels.

	signal s_hdr_pack_word : std_logic_vector(255 downto 0) := (others => '0'); --! Contents of 256 bit word preceeding image data to be written to AXI Stream (contains packet header data).
	signal s_hdr_pack_cnt : unsigned(2 downto 0) := (others => '0'); --! Counts number of 32 bit writes required for writing 256 bit word.

	signal s_last_sample : std_logic := '0';
	type bus16_vector is array(natural range <>) of std_logic_vector(15 downto 0);
	signal s_pixel : bus16_vector(15 downto 0) := (others=>(others=>'0'));
	signal s_pixel_v : std_logic := '0';

	signal s_pack_save : std_logic_vector((16*12)-1 downto 0) := (others => '0'); --! Used to save partial words state to state when 
		--! 12-bit packing is enabled.
	signal s_word_flush_cnt : unsigned(2 downto 0) := (others => '0'); --! Counts 32-bit words written to 32-to-g_axis_width FIFO. In this
		--! way we can check and flush zeros into FIFO to ensure we end with a final clean g_axis_width word in the FIFO.

	signal s_num_cols : std_logic_vector(13 downto 0) := (others => '0');
	signal s_num_rows : std_logic_vector(13 downto 0) := (others => '0');
	signal s_roi_offset_x : std_logic_vector(13 downto 0) := (others => '0'); 
	signal s_roi_offset_y : std_logic_vector(13 downto 0) := (others => '0'); 
	signal s_frame_index : std_logic_vector(31 downto 0) := (others => '0'); 
	signal s_timestamp : std_logic_vector(31 downto 0) := (others => '0'); 
	signal s_timestamp_slow : std_logic_vector(31 downto 0) := (others => '0'); 
	signal s_pixels_per_frame_data : unsigned(27 downto 0) := (others => '0'); --! Total number of pixels per frame.
	signal s_pixels_per_frame_meta : unsigned(27 downto 0) := (others => '0'); --! Total number of pixels per frame.
	signal s_pixels_per_frame : unsigned(27 downto 0) := (others => '0'); --! Total number of pixels per frame.

	-- Connections to Frame Data Buffer:
	signal s_buff_aclr : std_logic := '0';
	signal s_buff_wr_data : STD_LOGIC_VECTOR (g_packed_pixels_per_clk*16-1 DOWNTO 0) := (others => '0');
	signal s_buff_rd : STD_LOGIC := '0'; --! Directly connected to FIFO. Gated verseion of s_buff_rd_req, based on AXI Stream tready.
	signal s_buff_rd_req : STD_LOGIC := '0';
	signal s_buff_wr_req : STD_LOGIC := '0';
	signal s_buff_rd_data : STD_LOGIC_VECTOR (g_axis_width-1 DOWNTO 0) := (others => '0');
	signal s_buff_rd_data_r1 : STD_LOGIC_VECTOR (g_axis_width-1 DOWNTO 0) := (others => '0');
	signal s_buff_rd_cnt : STD_LOGIC_VECTOR (integer(ceil(log2(real(pixel_fifo_depth * 16 / g_axis_width))))-1 downto 0) := (others => '0');
	signal s_buff_wr_full : STD_LOGIC := '0';
	signal rd_cnt_stable : std_logic := '0';
	signal s_buff_rd_r1 : std_logic := '0';

	-- AXI Stream write related
	type t_axis_state is 
		(
			IDLE_AXIS_STATE, --! Idle waiting for beginning of frame data to appear on read port of dual width FIFO. 
			SETUP_AXIS_STATE_1, --! Setup required before writing each frame to AXI Stream.
			SETUP_AXIS_STATE_2, --! Setup required before writing each frame to AXI Stream.
			WRITE_FRAME_AXIS_STATE, --! State to write all the g_axis_width bit words that make up an entire frame.
			WAIT_FOR_PCIE_DONE, --! wait for PCIE side to complete transfer
			DONE_AXIS_STATE --! State to end in, if non-continuous writing was requested and we wrote all the request frames.
		);
	signal s_axis_state : t_axis_state := IDLE_AXIS_STATE ; --! State machine for writing to AXI Stream.
	signal s_axis_state_reg : t_axis_state := IDLE_AXIS_STATE ; 

	signal s_frame_done_cnt : unsigned(15 downto 0) := (others => '0'); --! Counts number of frames until we are done, for finite
		--! transaction requests.
	signal s_frame_int_cnt : unsigned(15 downto 0) := (others => '0'); --! Counts number of frames until we generate interrupt.

	signal s_xfer_words_remaining : unsigned(27 downto 0) := (others => '0'); --! Number of g_axis_width bit words left to write to AXI Stream for current frame

	signal s_buffer_rd_cnt : unsigned(23 downto 0) := (others=>'0');
	signal s_axis_tvalid_cnt : unsigned(23 downto 0) := (others=>'0');
	signal s_axis_tvalid : std_logic := '0';
	signal s_axis_transfer_finished : std_logic := '0';

	signal s_ver_rd : std_logic := '0';
	signal s_version_reg : std_logic_vector(15 downto 0);

	-- debugging
	-- attribute mark_debug : string;
	-- attribute mark_debug of o_dma_data_start_addr : signal is "true";
	-- attribute mark_debug of i_dma_data_complete : signal is "true";
	-- attribute mark_debug of s_xfer_words_remaining : signal is "true";
	-- attribute mark_debug of s_axis_state : signal is "true";
	-- attribute mark_debug of s_axis_tvalid : signal is "true";
	-- attribute mark_debug of s_buffer_rd_cnt : signal is "true";
	-- attribute mark_debug of s_axis_tvalid_cnt : signal is "true";
	-- attribute mark_debug of s_buff_rd : signal is "true";
	-- attribute mark_debug of s_buff_rd_cnt : signal is "true";
	-- attribute mark_debug of s_buff_rdempty : signal is "true";
	-- attribute mark_debug of s_buff_rd_data : signal is "true";
	-- attribute mark_debug of o_axis_tlast : signal is "true";
	-- attribute mark_debug of s_buff_valid : signal is "true";
	-- attribute mark_debug of s_buff_wr_req : signal is "true";
	-- attribute mark_debug of s_buff_wr_data : signal is "true";
	-- attribute mark_debug of s_pixel_v : signal is "true";
	-- attribute mark_debug of s_pixel : signal is "true";

begin
	version : core_version
	   port map(
	      clk           => i_reg_clk,
	      rd            => s_ver_rd,
	      ID            => CORE_ID,              -- assigned ID number, 0xFF if unassigned
	      version_major => CORE_VERSION_MAJOR,   -- major version number 1-15
	      version_minor => CORE_VERSION_MINOR,   -- minor version number 0-15
	      year          => CORE_YEAR,            -- year since 2000
	      month         => CORE_MONTH,           -- month (1-12)
	      day           => CORE_DAY,             -- day (1-31)
	      ilevel        => i_ilevel,
	      ivector       => i_ivector,
	      o_data        => s_version_reg
	      );

	o_irq <= s_int_status_reg when (s_int_en_reg = '1') else '0';

	o_dma_complete_en <= '1';

	REG_WRITE_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then

			if (i_reg_cs = '1' and i_reg_wr = '1') then
				case i_reg_addr is
					when CTRL_REG_OFFSET_LOW =>
						s_srst_reg <= i_reg_data(0);
						s_int_en_reg <= i_reg_data(1);
						s_FIFO_overflow_sticky_clr_reg <= i_reg_data(2);
						s_i_packet_sync_error_clr_reg <= i_reg_data(3);
						s_packed_mode_reg <= i_reg_data(5 downto 4);
				
						s_i_test_pattern_en_reg <= i_reg_data(8);

					when CTRL_REG_OFFSET_HIGH =>
						if (i_reg_data(15) = '1') then
							s_int_clr_tog_reg <= not(s_int_clr_tog_reg);
						end if;

					when START_ADDR_REG_OFFSET_LOW => 
						s_start_addr_reg(15 downto 0) <= i_reg_data;
					when START_ADDR_REG_OFFSET_HIGH => 
						s_start_addr_reg(31 downto 16) <= i_reg_data;

					when END_ADDR_REG_OFFSET_LOW => 
						s_end_addr_reg(15 downto 0) <= i_reg_data;
					when END_ADDR_REG_OFFSET_HIGH => 
						s_end_addr_reg(31 downto 16) <= i_reg_data;

					when INT_LVL_REG_OFFSET => 
						s_int_lvl_reg <= i_reg_data;

					when NUM_FRAMES_REG_OFFSET => 
						s_num_cap_frames_reg <= UNSIGNED(i_reg_data);

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

			s_ver_rd <= '0';

			if (i_reg_cs = '1') then
				case i_reg_addr is
					when VERSION_REG_OFFSET =>
						o_reg_data <= s_version_reg;
						s_ver_rd <= i_reg_rd;
						
					when CTRL_REG_OFFSET_LOW =>
						o_reg_data(0) <= s_srst_reg;
						o_reg_data(1) <= s_int_en_reg;
						o_reg_data(2) <= s_FIFO_overflow_sticky_reg;
						o_reg_data(3) <= s_i_packet_sync_error_sticky_reg;
						o_reg_data(5 downto 4) <= s_packed_mode_reg;
						o_reg_data(8) <= s_i_test_pattern_en_reg;
					
					when CTRL_REG_OFFSET_HIGH =>
						-- Mark when we are IDLE from any final AXIS stream writes so that HPS knows we can be taken out of reset
						if (s_axis_state_reg = IDLE_AXIS_STATE) then
							o_reg_data(12) <= '1';
						else
							o_reg_data(12) <= '0';
						end if;
						o_reg_data(15) <= s_int_status_reg; 

					when START_ADDR_REG_OFFSET_LOW => 
						o_reg_data <= s_start_addr_reg(15 downto 0);
					when START_ADDR_REG_OFFSET_HIGH => 
						o_reg_data <= s_start_addr_reg(31 downto 16);

					when END_ADDR_REG_OFFSET_LOW => 
						o_reg_data <= s_end_addr_reg(15 downto 0);
					when END_ADDR_REG_OFFSET_HIGH => 
						o_reg_data <= s_end_addr_reg(31 downto 16);

					when INT_LVL_REG_OFFSET => 
						o_reg_data <= s_int_lvl_reg;

					when NUM_FRAMES_REG_OFFSET => 
						o_reg_data <= STD_LOGIC_VECTOR(s_num_cap_frames_reg);

					when others => null;
				end case;
			end if;
		end if;
	end process REG_READ_PROC;

	--! Process for clock domain crossing to half word clock (good place for timing ignores)
	TO_DATA_CLK_PROC : process (i_data_clk)
	begin
		if rising_edge(i_data_clk) then
			s_srst_data_m <= s_srst_reg;
			s_srst_data <= s_srst_data_m;
			s_packed_mode_data <= s_packed_mode_reg;
			s_buff_aclr <= s_srst_data or s_axis_transfer_finished;
			s_FIFO_overflow_sticky_clr_data <= s_FIFO_overflow_sticky_clr_reg;
			s_i_packet_sync_error_clr_data <= s_i_packet_sync_error_clr_reg;
			s_i_test_pattern_en_data <= s_i_test_pattern_en_reg;
		end if;
	end process TO_DATA_CLK_PROC;

	--! Process for clock domain crossing to half word clock (good place for timing ignores)
	TO_REG_CLK_PROC : process (i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			s_FIFO_overflow_sticky_reg <= s_FIFO_overflow_sticky_data;
			s_i_packet_sync_error_sticky_reg <= s_i_packet_sync_error_sticky_data;
			s_axis_state_reg <= s_axis_state;
			s_int_status_reg <= s_int_status;
		end if;
	end process TO_REG_CLK_PROC;

	--! Process for clock domain crossing to half word clock (good place for timing ignores)
	TO_AXIS_CLK_PROC : process (i_axi_clk)
	begin
		if rising_edge(i_axi_clk) then
			s_srst_m <= s_srst_reg;
			s_srst <= s_srst_m;
			s_int_clr_tog_meta <= s_int_clr_tog_reg;
			s_int_clr_tog <= s_int_clr_tog_meta;

			s_packed_mode <= s_packed_mode_reg;

			s_start_addr <= unsigned(s_start_addr_reg);
			s_end_addr <= unsigned(s_end_addr_reg);
			s_int_lvl <= s_int_lvl_reg;
			s_num_cap_frames <= s_num_cap_frames_reg;
		end if;
	end process TO_AXIS_CLK_PROC;

	DECODE_MITYCAM : header_decode
			generic map
			(
				g_bits_per_pixel => 16,
				g_dim_size_bits  => 14,
				g_pixels_per_clk => g_packed_pixels_per_clk
			)
			port map
			(
				i_clk                        => i_data_clk,
				i_srst                       => s_srst_data,
	
				i_packet_sync_error_clr      => std_logic'('0'),
				o_packet_sync_error_sticky   => open,
				i_test_pattern_en            => std_logic'('0'),
				i_ready                      => std_logic'('1'),
				i_packet_data                => i_data_data,
				i_packet_data_startofpacket  => i_data_startofpacket,
				i_packet_data_v              => i_data_valid,
				i_packet_data_endofpacket    => i_data_endofpacket,
				o_num_cols                   => s_num_cols,
				o_num_rows                   => s_num_rows,
				o_roi_offset_x               => s_roi_offset_x,
				o_roi_offset_y               => s_roi_offset_y,
				o_frame_index                => s_frame_index,
				o_timestamp                  => s_timestamp,
				o_timestamp_slow             => s_timestamp_slow,
				o_pixel_format               => open,
				o_frame_sync                 => open,
				o_line_sync                  => open,
				o_last_sample                => s_last_sample,
	
				o_col_num                    => open,
				o_row_num                    => open,
	
				o_pair0_even_pixel           => s_pixel(0),
				o_pair0_odd_pixel            => s_pixel(1),
				o_pair1_even_pixel           => s_pixel(2),
				o_pair1_odd_pixel            => s_pixel(3),
				o_pair2_even_pixel           => s_pixel(4),
				o_pair2_odd_pixel            => s_pixel(5),
				o_pair3_even_pixel           => s_pixel(6),
				o_pair3_odd_pixel            => s_pixel(7),
				o_pair4_even_pixel           => s_pixel(8),
				o_pair4_odd_pixel            => s_pixel(9),
				o_pair5_even_pixel           => s_pixel(10),
				o_pair5_odd_pixel            => s_pixel(11),
				o_pair6_even_pixel           => s_pixel(12),
				o_pair6_odd_pixel            => s_pixel(13),
				o_pair7_even_pixel           => s_pixel(14),
				o_pair7_odd_pixel            => s_pixel(15),
				o_pixel_v                    => s_pixel_v
			);

	-- xpm_fifo_async: Asynchronous FIFO
	-- Xilinx Parameterized Macro, version 2021.2
	xpm_fifo_async_inst : xpm_fifo_async
		generic map (
			CASCADE_HEIGHT      => 0, -- DECIMAL
			CDC_SYNC_STAGES     => 2, -- DECIMAL
			DOUT_RESET_VALUE    => "0", -- String
			ECC_MODE            => "no_ecc", -- String
			FIFO_MEMORY_TYPE    => "auto", -- String
			FIFO_READ_LATENCY   => 1, -- DECIMAL (must be zero if READ_MODE = "fwft")
			FIFO_WRITE_DEPTH    => pixel_fifo_depth / g_packed_pixels_per_clk, -- DECIMAL
			FULL_RESET_VALUE    => 0, -- DECIMAL
			PROG_EMPTY_THRESH   => 10, -- DECIMAL
			PROG_FULL_THRESH    => 10, -- DECIMAL
			RD_DATA_COUNT_WIDTH => integer(ceil(log2(real((pixel_fifo_depth*16)/g_axis_width)))), -- DECIMAL (Log2(FIFO_READ_DEPTH)+1)
			READ_DATA_WIDTH     => g_axis_width, -- DECIMAL
			READ_MODE           => "fwft", -- String (std or fwft)
			RELATED_CLOCKS      => 0, -- DECIMAL
			SIM_ASSERT_CHK      => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
			USE_ADV_FEATURES    => "1707", -- String
			WAKEUP_TIME         => 0, -- DECIMAL
			WRITE_DATA_WIDTH    => g_packed_pixels_per_clk*16, -- DECIMAL
			WR_DATA_COUNT_WIDTH => integer(ceil(log2(real(pixel_fifo_depth / g_packed_pixels_per_clk))))+1 -- DECIMAL (Log2(FIFO_WRITE_DEPTH)+1)
		)
		port map (
			almost_empty   => open,
			almost_full    => open,
			data_valid     => s_buff_valid,
			dbiterr        => open,
			dout           => s_buff_rd_data,
			empty          => s_buff_rdempty,
			full           => s_buff_wr_full,
			overflow       => open,
			prog_empty     => open,
			prog_full      => open,
			rd_data_count  => s_buff_rd_cnt,
			rd_rst_busy    => open,
			sbiterr        => open,
			underflow      => open,
			wr_ack         => open,
			wr_data_count  => open,
			wr_rst_busy    => open,
			din            => s_buff_wr_data,
			injectdbiterr  => std_logic'('0'),
			injectsbiterr  => std_logic'('0'),
			rd_clk         => i_axi_clk,
			rd_en          => s_buff_rd,
			rst            => s_buff_aclr, -- 1-bit input: Reset: Must be synchronous to wr_clk. 
			sleep          => std_logic'('0'),
			wr_clk         => i_data_clk, 
			wr_en          => s_buff_wr_req
		);

	------------------------------------------------------------------------------------------------------
	-- this block of code packs the inbound pixel / header data into a mixed width FIFO
	-- where the input side is 16*pixels_per_clock and the output side is g_axis_width bits (the width of the PCIe interface)
	-- this will also pack up 12 bit or 8 bit pixel data appropriately.  10 bit packing is not yet supported.

	--! Shift register to account for delay in writing 256 bit block (contains header data) before pixel data.
	SHIFT_REG_PROC : process(i_data_clk)
	begin
		if rising_edge(i_data_clk) then
			s_shift_reg(0)(SR_LAST_SAMP_LOC)       <= s_last_sample;
			s_shift_reg(0)(SR_PIX_V_LOC)           <= s_pixel_v;
			for i in 0 to g_packed_pixels_per_clk-1 loop
				s_shift_reg(0)(i*16+15 downto i*16)  <= s_pixel(i);
			end loop;
			s_shift_reg(SHIFT_REG_SIZE-1 downto 1) <= s_shift_reg(SHIFT_REG_SIZE-2 downto 0);
		end if;
	end process SHIFT_REG_PROC;

	--! Process to potentially pack frame data and write it to dual width buffer.
	PACK_FRAME_DATA_PROC : process(i_data_clk)
		variable v_sr_last_sample : std_logic := '0'; --! Marks last sample of a frame as read from Shift Register.
		variable v_sr_pixel_v : std_logic := '0'; --! Marks Shift Register output as valid or not.
		variable v_temp_pixel : std_logic_vector(15 downto 0) := (others => '0');

		variable v_curr_packed_pixels : std_logic_vector(16*12-1 downto 0) := (others => '0'); --! Packed pixels in
			--! a single vector for easy access.
	begin
		if rising_edge(i_data_clk) then
			-- Set shift register outputs to variables for easier access and indexing (if necessary)
			v_sr_last_sample := s_shift_reg(SHIFT_REG_SIZE-1)(SR_LAST_SAMP_LOC);
			v_sr_pixel_v := s_shift_reg(SHIFT_REG_SIZE-1)(SR_PIX_V_LOC);

			-- handle the packing modes
			for i in 1 to 8 loop
				if (g_packed_pixels_per_clk >= i*2) then
					case s_packed_mode_data is
						when "01" => -- 12 bit packing Mono12p
							v_temp_pixel := s_shift_reg(SHIFT_REG_SIZE-1)((i*2-1)*16-1 downto (i*2-2)*16);
							v_curr_packed_pixels((i*2-1)*12-1 downto (i*2-2)*12) := v_temp_pixel(11 downto 0);
							v_temp_pixel := s_shift_reg(SHIFT_REG_SIZE-1)((i*2)*16-1 downto (i*2-1)*16);
							v_curr_packed_pixels((i*2)*12-1 downto (i*2-1)*12) := v_temp_pixel(11 downto 0);
						when "10" => -- 8 bit packing
							v_temp_pixel := s_shift_reg(SHIFT_REG_SIZE-1)((i*2-1)*16-1 downto (i*2-2)*16);
							v_curr_packed_pixels((i*2-1)*8-1 downto (i*2-2)*8) := v_temp_pixel(15 downto 8);
							v_temp_pixel := s_shift_reg(SHIFT_REG_SIZE-1)((i*2)*16-1 downto (i*2-1)*16);
							v_curr_packed_pixels((i*2)*8-1 downto (i*2-1)*8) := v_temp_pixel(15 downto 8);					
						when "11" => -- 12 bit packing Mono12packed (GigE Standard)
							v_temp_pixel := s_shift_reg(SHIFT_REG_SIZE-1)((i*2-1)*16-1 downto (i*2-2)*16);
							v_curr_packed_pixels((i*2-1)*12-1 downto (i*2-2)*12) := v_temp_pixel(3 downto 0) & v_temp_pixel(11 downto 4);
							v_temp_pixel := s_shift_reg(SHIFT_REG_SIZE-1)((i*2)*16-1 downto (i*2-1)*16);
							v_curr_packed_pixels((i*2)*12-1 downto (i*2-1)*12) := v_temp_pixel(11 downto 0);
						when others => NULL;
					end case;
				end if;
			end loop;
			
			-- By defaults no writes.
			s_buff_wr_req <= '0';
			-- Always save last valid 12-bit values, in the cases we need them in 12-bit packing mode
			if (v_sr_pixel_v = '1') then
				s_pack_save <= v_curr_packed_pixels;
			end if;

			if s_srst_data = '1' then
				s_pack_state <= IDLE_PACK_STATE;
				s_word_flush_cnt <= (others => '0');
			else
				-- Count multiples of g_packed_pixels_per_clk-bit writes to FIFO to ensure we end with a final
				--  clean g_axis_width bit word in the FIFO.
				if (s_buff_wr_req = '1') then
					s_word_flush_cnt <= s_word_flush_cnt + 1;
				end if;

				case s_pack_state is
					when IDLE_PACK_STATE => 
						s_hdr_pack_cnt <= (others => '0');
						-- Fill in 256 pre-image word	
						s_hdr_pack_word <= (others => '0');
						s_hdr_pack_word(31 downto 0) <= "00" & s_num_rows & "00" & s_num_cols;
						s_hdr_pack_word(63 downto 32) <= "00" & s_roi_offset_y & "00" & s_roi_offset_x;
						s_hdr_pack_word(95 downto 64) <= s_frame_index;
						s_hdr_pack_word(127 downto 96) <= s_timestamp;
						s_hdr_pack_word(159 downto 128) <= s_timestamp_slow;
						-- Wait until all header data is valid, then start writing it.
						if (s_pixel_v = '1') then
							s_pack_state <= HDR_PACK_STATE;
						end if;

					when HDR_PACK_STATE => 
						s_buff_wr_req <= '1';
						s_buff_wr_data <= s_hdr_pack_word((g_packed_pixels_per_clk*16)-1 downto 0);
						-- Rotate down so we write entire 256 bit word in this state
						--  Rotation only required for smaller than x16 pixels per clock, as 16 pixels per clock
						--  results in 256 write width and only requires a single clock
						if (g_packed_pixels_per_clk < 16) then
							s_hdr_pack_word(255-(g_packed_pixels_per_clk*16) downto 0) <= s_hdr_pack_word(255 downto (g_packed_pixels_per_clk*16));
						end if;

						s_hdr_pack_cnt <= s_hdr_pack_cnt + 1;
						-- Given the number of pixels per clock, which defines the FIFO write width, write the number
						--  of words until we've written the 256 bit header
						if (s_hdr_pack_cnt = TO_UNSIGNED((256/(g_packed_pixels_per_clk*16))-1, 3)) then
							-- Transition to either packing or passthrough state loops
							case s_packed_mode_data is
								when "01" | "11" => -- 12 bit packing
									s_pack_state <= PACK_STATE_1;
								when "10" => -- 8 bit packing
									s_pack_state <= PACK8_STATE_1;
								when others => -- no packing
									s_pack_state <= NO_PACK_STATE;
							end case;
						end if;

					when NO_PACK_STATE =>
						-- Check to make sure we've written a proper multiple of 32-bit words, so we produce a final
						--  final valid g_axis_width word to be read from the FIFO
						if (v_sr_last_sample = '1') then
							s_pack_state <= PACK_FLUSH_END_STATE;
						end if;
						-- No packing state is simply  a passthrough of decoded pixel data
						s_buff_wr_req <= v_sr_pixel_v;
						s_buff_wr_data <= s_shift_reg(SHIFT_REG_SIZE-1)(g_packed_pixels_per_clk*16-1 downto 0);
						-- Calculate total number of pixels per frame.
						s_pixels_per_frame_data <= UNSIGNED(s_num_cols) * UNSIGNED(s_num_rows);

					when PACK8_STATE_1 => 
						if (v_sr_pixel_v = '1') then
							if (v_sr_last_sample = '1') then
								s_pack_state <= PACK8_FLUSH_STATE_1;
							else
								s_pack_state <= PACK8_STATE_2;
							end if;
							s_buff_wr_req <= '0';
						end if;
						-- Calculate total number of pixels per frame.
						s_pixels_per_frame_data <= UNSIGNED(s_num_cols) * UNSIGNED(s_num_rows);
						
					when PACK8_STATE_2 => 
						if (v_sr_pixel_v = '1') then
							if (v_sr_last_sample = '1') then
								-- Potentially perfect packing case
								s_pack_state <= PACK_FLUSH_END_STATE;
							else
								s_pack_state <= PACK8_STATE_1;
							end if;
							s_buff_wr_req <= '1';
							s_buff_wr_data <= v_curr_packed_pixels(g_packed_pixels_per_clk*8-1 downto 0) & 
											  s_pack_save(g_packed_pixels_per_clk*8-1 downto 0);
						end if;

					when PACK8_FLUSH_STATE_1 => 
						-- Final 0 padded write of remaining data
						s_buff_wr_req <= '1';
						s_buff_wr_data <= (others => '0');
						s_buff_wr_data(g_packed_pixels_per_clk*8-1 downto 0) <= s_pack_save(g_packed_pixels_per_clk*8-1 downto 0);
						s_pack_state <= PACK_FLUSH_END_STATE;

					when PACK_STATE_1 => -- 12 bit packing
						if (v_sr_pixel_v = '1') then
							if (v_sr_last_sample = '1') then
								-- Potentially perfect packing case
								s_pack_state <= PACK_FLUSH_STATE_1;
							else
								s_pack_state <= PACK_STATE_2;
							end if;
							-- Not enough data to write to buffer yet
							s_buff_wr_req <= '0';
						end if;
						-- Calculate total number of pixels per frame.
						s_pixels_per_frame_data <= UNSIGNED(s_num_cols) * UNSIGNED(s_num_rows);

					when PACK_STATE_2 => -- 12 bit packing
						if (v_sr_pixel_v = '1') then
							if (v_sr_last_sample = '1') then
								-- Potentially perfect packing case
								s_pack_state <= PACK_FLUSH_STATE_2;
							else
								s_pack_state <= PACK_STATE_3;
							end if;
							s_buff_wr_req <= '1';
							s_buff_wr_data <= v_curr_packed_pixels(g_packed_pixels_per_clk*(16-12)-1 downto 0) &
											  s_pack_save(g_packed_pixels_per_clk*12-1 downto 0);
						end if;

					when PACK_STATE_3 => 
						if (v_sr_pixel_v = '1') then
							if (v_sr_last_sample = '1') then
								-- Potentiall perfect packing case
								s_pack_state <= PACK_FLUSH_STATE_3;
							else
								s_pack_state <= PACK_STATE_4;
							end if;
							s_buff_wr_req <= '1';
							s_buff_wr_data <= v_curr_packed_pixels(g_packed_pixels_per_clk*8-1 downto 0) &
											  s_pack_save(g_packed_pixels_per_clk*12-1 downto g_packed_pixels_per_clk*(16-12));
						end if;

					when PACK_STATE_4 => 
						if (v_sr_pixel_v = '1') then
							if (v_sr_last_sample = '1') then
								-- No saved partial 32-bit data to flush.
								s_pack_state <= PACK_FLUSH_END_STATE;
							else
								s_pack_state <= PACK_STATE_1;
							end if;
							s_buff_wr_req <= '1';
							s_buff_wr_data <= v_curr_packed_pixels(g_packed_pixels_per_clk*12-1 downto 0) &
											  s_pack_save(g_packed_pixels_per_clk*12-1 downto g_packed_pixels_per_clk*8);
						end if;

					when PACK_FLUSH_STATE_1 => 
						-- Final 0 padded write of remaining data
						s_buff_wr_req <= '1';
						s_buff_wr_data <= (others => '0');
						s_buff_wr_data(g_packed_pixels_per_clk*12-1 downto 0) <= s_pack_save(g_packed_pixels_per_clk*12-1 downto 0);
						s_pack_state <= PACK_FLUSH_END_STATE;

					when PACK_FLUSH_STATE_2 => 
						-- Final 0 padded write of remaining data
						s_buff_wr_req <= '1';
						s_buff_wr_data <= (others => '0');
						s_buff_wr_data(g_packed_pixels_per_clk*8-1 downto 0) <= s_pack_save(g_packed_pixels_per_clk*12-1 downto g_packed_pixels_per_clk*4);
						s_pack_state <= PACK_FLUSH_END_STATE;

					when PACK_FLUSH_STATE_3 => 
						-- Final 0 padded write of remaining data
						s_buff_wr_req <= '1';
						s_buff_wr_data <= (others => '0');
						s_buff_wr_data(g_packed_pixels_per_clk*4-1 downto 0) <= s_pack_save(g_packed_pixels_per_clk*12-1 downto g_packed_pixels_per_clk*8);
						s_pack_state <= PACK_FLUSH_END_STATE;

					when PACK_FLUSH_END_STATE =>
						if (g_packed_pixels_per_clk = 2) then
							-- Keep zero filling FIFO until we've ended on a proper multiple of 32-bit words
							--  so that we produce a clean final g_axis_width bit output for the FIFO.
							if (g_axis_width = 256) then
								if (s_word_flush_cnt = "111") then
									s_pack_state <= IDLE_PACK_STATE;
								else
									s_buff_wr_req <= '1';
									s_buff_wr_data <= (others => '0');
								end if;	
							end if;
							if (g_axis_width = 128) then
								if (s_word_flush_cnt(1 downto 0) = "11") then
									s_pack_state <= IDLE_PACK_STATE;
								else
									s_buff_wr_req <= '1';
									s_buff_wr_data <= (others => '0');
								end if;	
							end if;
							if (g_axis_width = 64) then
								if (s_word_flush_cnt(0) = '1') then
									s_pack_state <= IDLE_PACK_STATE;
								else
									s_buff_wr_req <= '1';
									s_buff_wr_data <= (others => '0');
								end if;	
							end if;
							if (g_axis_width = 32) then
								s_pack_state <= IDLE_PACK_STATE;
							end if;
						end if;
						if (g_packed_pixels_per_clk = 4) then
							-- Keep zero filling FIFO until we've ended on a proper multiple of 64-bit words
							--  so that we produce a clean final g_axis_width bit output for the FIFO.
							if (g_axis_width = 256) then
								if (s_word_flush_cnt(1 downto 0) = "11") then
									s_pack_state <= IDLE_PACK_STATE;
								else
									s_buff_wr_req <= '1';
									s_buff_wr_data <= (others => '0');
								end if;	
							elsif (g_axis_width = 128) then
								if (s_word_flush_cnt(0) = '1') then
									s_pack_state <= IDLE_PACK_STATE;
								else
									s_buff_wr_req <= '1';
									s_buff_wr_data <= (others => '0');
								end if;	
							else -- all other write sizes will be multiples of 64, no never need to flush.
								s_pack_state <= IDLE_PACK_STATE;
							end if;
						end if;
						if (g_packed_pixels_per_clk = 8) then
							-- Keep zero filling FIFO until we've ended on a proper multiple of 128-bit words
							--  so that we produce a clean final g_axis_width bit output for the FIFO.
							if (g_axis_width = 256) then
								if (s_word_flush_cnt(0) = '1') then
									s_pack_state <= IDLE_PACK_STATE;
								else
									s_buff_wr_req <= '1';
									s_buff_wr_data <= (others => '0');
								end if;	
							else -- all other write sizes will be multiples of 128, no never need to flush.
								s_pack_state <= IDLE_PACK_STATE;
							end if;
						end if;
						if (g_packed_pixels_per_clk = 16) then
							-- We are writing 256-bits on this end of the FIFO. Max read size is 256, and smaller
							--  read sizes are all multiplees of 256. So never need to flush.
							s_pack_state <= IDLE_PACK_STATE;
						end if;
				end case;
			end if;
		end if;
	end process PACK_FRAME_DATA_PROC;

	--! Process to check for and clear overflow sticky bit when overflow occurs in FRAME_DATA_BUFFER_INST.
	FIFO_OVERFLOW_PROC : process(i_data_clk)
	begin
		if rising_edge(i_data_clk) then
			if (s_FIFO_overflow_sticky_clr_data = '1') then
				s_FIFO_overflow_sticky_data <= '0';
			elsif (s_buff_aclr = '0' and s_buff_wr_full = '1') then
				s_FIFO_overflow_sticky_data <= '1';
			end if;
			
		end if;
	end process FIFO_OVERFLOW_PROC;

	-- end of packing logic
	-----------------------------------------------------------------------------------------------------------------
	-- start of logic for streaming to the PCIE interface.
	-- this logic figures out the DMA address pointer, stream packet size, and reads the data from the mixed width
	-- FIFO to the PCIe AXI streaming interface.

	-- whenever a successful write is posted, read out the FIFO
	s_buff_rd <= '1' when (s_axis_tvalid='1' and i_axis_tready='1') else '0';

	rd_cnt_stable <= '1' when s_buff_rd_r1 = '0' and s_buff_rd = '0' else '0';

	o_axis_tdata <= s_buff_rd_data;
	o_axis_tvalid <= s_axis_tvalid;
	-- always write the full word
	o_axis_tkeep <= (others=>'1');
	o_axis_tlast <= '1' when s_xfer_words_remaining = 1 and s_axis_tvalid = '1' else '0';

	-- assert axi tvalid when we are in writing state and valid data is presented by FIFO
	s_axis_tvalid <= s_buff_valid when s_axis_state = WRITE_FRAME_AXIS_STATE else '0';

	--! Process to write frame data to AXI Stream after packing and FIFO for width conversion.
	AXIS_WRITE_PROC : process(i_axi_clk)
	begin
		if rising_edge(i_axi_clk) then

			-- By default mark we are not finished writing to AXI and require a reset.
			s_axis_transfer_finished <= '0';

			-- History for edge detection on clear of interrupt
			s_int_clr_tog_r1 <= s_int_clr_tog;

			-- Bring pixels per frame to this domain for words per frame calculations
			s_pixels_per_frame_meta <= s_pixels_per_frame_data;
			s_pixels_per_frame <= s_pixels_per_frame_meta;
			
			-- Edge indicates write to clear interrupt status bit
			if (s_int_clr_tog_r1 /= s_int_clr_tog) then
				s_int_status <= '0';
			end if;

			-- count number of buffers transferred
			if s_srst = '1' then
				s_buffer_rd_cnt <= (others=>'0');
			elsif s_buff_rd = '1' then
				s_buffer_rd_cnt <= s_buffer_rd_cnt + 1;
			end if;

			-- count number of data words transferred
			if s_srst = '1' then
				s_axis_tvalid_cnt  <= (others=>'0');
			elsif s_axis_tvalid = '1' and i_axis_tready='1' then
				s_axis_tvalid_cnt <= s_axis_tvalid_cnt + 1;
			end if;
			
			s_buff_rd_r1 <= s_buff_rd;

			case s_axis_state is
				when IDLE_AXIS_STATE =>
					-- Reset various counters
					s_frame_int_cnt <= (others => '0');
					s_frame_done_cnt <= (others => '0');
					-- Set starting address
					s_axis_tvalid_addr <= s_start_addr;
					
					-- As soon as there is data in the FIFO (and we're no longer in reset), we can start writing to the AXI Stream
					if (s_srst = '0' and s_buff_rd_cnt /= std_logic_vector(to_unsigned(0,s_buff_rd_cnt'length))) then
						s_axis_state <= SETUP_AXIS_STATE_1;
					end if;
				
				when SETUP_AXIS_STATE_1 => 
					-- First state in calculating number of g_axis_width-bit words per frame
					--  Subtract off 1/4 of pixels, if 12-bit packing is enabled
					--  Result is number of 16 bit words per frame (rounded up).
					s_dma_data_complete_r1 <= i_dma_data_complete;
					o_dma_data_start_addr <= std_logic_vector(s_axis_tvalid_addr);
					case s_packed_mode is
						when "01" | "11" => -- 12 bit packing
							s_xfer_words_remaining <= s_pixels_per_frame
								- UNSIGNED("00"&s_pixels_per_frame(s_pixels_per_frame'length-1 downto 2));
						when "10" => -- 8 bit packing
							s_xfer_words_remaining <= UNSIGNED('0' & s_pixels_per_frame(s_pixels_per_frame'length-1 downto 1));
						when others => -- no packing
							s_xfer_words_remaining <= s_pixels_per_frame;
					end case;
					if (s_srst = '0') then
						s_axis_state <= SETUP_AXIS_STATE_2;
					else
						s_axis_state <= IDLE_AXIS_STATE;
					end if;

				when SETUP_AXIS_STATE_2 =>
					-- Note that static value is also added in to account for the 256 bits of header now in the FIFO
					if (g_axis_width = 256) then
						-- Convert number of 16-bit words, to 256-bit words by dividing by 16, but ceiling
						--  result as we will fill FIFO to make sure we end on a full 256-bit word
						if (s_xfer_words_remaining(3 downto 0) /= "0000") then
							s_xfer_words_remaining <= "0000"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 4) + 1 + 1;
						else
							s_xfer_words_remaining <= "0000"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 4) + 1;
						end if;
					end if;
					if (g_axis_width = 128) then
						-- Convert number of 16-bit words, to 128-bit words by dividing by 8, but ceiling
						--  result as we will fill FIFO to make sure we end on a full 128-bit word
						if (s_xfer_words_remaining(2 downto 0) /= "000") then
							s_xfer_words_remaining <= "000"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 3) + 2 + 1;
						else
							s_xfer_words_remaining <= "000"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 3) + 2;
						end if;
					end if;
					if (g_axis_width = 64) then
						-- Convert number of 16-bit words, to 64-bit words by dividing by 4, but ceiling
						--  result as we will fill FIFO to make sure we end on a full 64-bit word
						if (s_xfer_words_remaining(1 downto 0) /= "00") then
							s_xfer_words_remaining <= "00"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 2) + 4 + 1;
						else
							s_xfer_words_remaining <= "00"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 2) + 4;
						end if;
					end if;
					if (g_axis_width = 32) then
						-- Convert number of 16-bit words, to 32-bit words by dividing by 2, but ceiling
						--  result as we will fill FIFO to make sure we end on a full 32-bit word
						if (s_xfer_words_remaining(0) /= '0') then
							s_xfer_words_remaining <= "0"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 1) + 8 + 1;
						else
							s_xfer_words_remaining <= "0"&s_xfer_words_remaining(s_xfer_words_remaining'length-1 downto 1) + 8;
						end if;
					end if;
					if (s_srst = '0') then
						s_axis_state <= WRITE_FRAME_AXIS_STATE;
					else
						s_axis_state <= IDLE_AXIS_STATE;
					end if;

				when WRITE_FRAME_AXIS_STATE =>
					-- if reset requested
					if (s_srst = '1') then
						s_axis_state <= IDLE_AXIS_STATE;
					-- else not reset
					else
						-- If we were writing and it was accepted, bump our counters
						if (s_axis_tvalid = '1' and i_axis_tready = '1') then
							-- One more word written as part of this frame
							s_xfer_words_remaining <= s_xfer_words_remaining - 1;

							-- Increment (potentially wrap) address for next write
							if (s_axis_tvalid_addr < s_end_addr-ADDR_INC) then
								s_axis_tvalid_addr <= s_axis_tvalid_addr + ADDR_INC;
							else
								s_axis_tvalid_addr <= s_start_addr;
							end if;

							-- Was this the last word in the frame?
							if s_xfer_words_remaining = 1 then
								-- Mark interrupt if necessary
								if (s_frame_int_cnt < UNSIGNED(s_int_lvl)-1) then
									s_frame_int_cnt <= s_frame_int_cnt + 1;
								else
									s_frame_int_cnt <= (others => '0');
									s_int_status <= '1';
								end if;
									
								-- Calculate if we pause until reset, or go for another frame
								--  Note s_num_cap_frames = 0 is continuous mode
								if (s_num_cap_frames > 0) then	
									if (s_frame_done_cnt < UNSIGNED(s_num_cap_frames)-1) then
										s_frame_done_cnt <= s_frame_done_cnt + 1;
										-- Update xfer words remaining for next frame.
										s_axis_state <= WAIT_FOR_PCIE_DONE;
									else
										-- flag interrupt if we are complete
										s_int_status <= '1';
										s_axis_state <= DONE_AXIS_STATE;
									end if;
								else
									-- Update xfer words remaining for next frame.
									s_axis_state <= WAIT_FOR_PCIE_DONE;
								end if;
							end if;
						end if;

					end if; -- not reset

				when WAIT_FOR_PCIE_DONE =>
					s_dma_data_complete_r1 <= i_dma_data_complete;
					if (s_srst = '1') then
						s_axis_state <= IDLE_AXIS_STATE;
					elsif i_dma_data_complete /= s_dma_data_complete_r1 then
						s_axis_state <= SETUP_AXIS_STATE_1;
					end if;

				when DONE_AXIS_STATE =>
					-- We've completed a finite task. Just wait here until unit is reset.
					-- Put FIFO into reset so we don't accidentally mark overflow.
					s_axis_transfer_finished <= '1';
					if (s_srst = '1') then
						s_axis_state <= IDLE_AXIS_STATE;
					end if;
				
				when others => 
					NULL;
				
			end case;

			if (s_srst = '1') then
				-- No interrupts allowed when in reset
				s_int_status <= '0';
			end if;
		end if;
	end process AXIS_WRITE_PROC;

end rtl;

