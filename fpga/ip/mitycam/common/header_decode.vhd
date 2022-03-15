--- Title: header_decode.vhd
---
---
---     o  0
---     | /       Copyright (c) 2013
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

--! Unit to decode received frame headers. 
entity header_decode is
	generic
	(
		g_bits_per_pixel : natural := 16; -- minimum of 16
		g_dim_size_bits : natural := 12; --! Number of bits needed to be able to count rows and
			--! columns. Must be greater than or equal to 12.
		g_pixels_per_clk : natural := 2 --! The number of pixels to transmit per clock. Currently 
			--! only values of 2, 4, 8 and 16 are currently supported.
	);
	port 
	(
		i_clk : in std_logic; --! Clock for processing header data.
		i_srst : in std_logic; --! Synchronous reset.

		i_packet_sync_error_clr : in std_logic; --! Active high clear of sync error sticky bit.
		o_packet_sync_error_sticky : out std_logic; --! Sticky error bit when there is an error decoding the incoming packet.

		i_test_pattern_en : in std_logic := '0'; --! Active high enable of test pattern where output pixels are replaced with counting pattern.

		i_ready : in std_logic := '1'; --! High indicates operate as normal. '0' indicates pause pipeline immediately.

		i_packet_data : in std_logic_vector((g_bits_per_pixel*g_pixels_per_clk)-1 downto 0); --! Either header data or pixel values.
		i_packet_data_startofpacket : in std_logic; --! High for first packet of header.
		i_packet_data_v : in std_logic; --! High for valid packet data.
		i_packet_data_endofpacket : in std_logic; --! High for last packet of header.
		
		o_num_cols : out std_logic_vector(g_dim_size_bits-1 downto 0); --! Number of columns in frame. Valid when o_pixel_v is high.
		o_num_rows : out std_logic_vector(g_dim_size_bits-1 downto 0); --! Number of rows in frame. Valid when o_pixel_v is high.

		o_roi_offset_x : out std_logic_vector(g_dim_size_bits-1 downto 0); --! Number of pixels in horizontal direction from pixel (0, 0)
			--! that marks where this frame (ROI) exists in full frame. Valid when o_pixel_v is high.
		o_roi_offset_y : out std_logic_vector(g_dim_size_bits-1 downto 0); --! Number of pixels in vertical direction from pixel (0, 0)
			--! that marks where this frame (ROI) exists in full frame. Valid when o_pixel_v is high.

		o_frame_index : out std_logic_vector(31 downto 0); --! Index value/indentifier for current frame.
			--! Valid when o_pixel_v is high.

		o_timestamp : out std_logic_vector(31 downto 0); --! Timestamp to mark capture time of current frame.
			--! Valid when o_pixel_v is high.
		o_timestamp_slow : out std_logic_vector(31 downto 0); --! Slow timestamp to mark capture time of current frame.
			--! Valid when o_pixel_v is high.

		o_pixel_format : out std_logic_vector(31 downto 0); --! Code to define the format of the pixel data and
			--! how it should be interpreted (i.e. mono, bayer, RGB).

		o_frame_sync : out std_logic; --! Single cycle pulse high at beginning of a frame.
		o_line_sync : out std_logic; --! Single cycle pulse high at beginning of a line.
		o_last_sample : out std_logic; --! Active high to mark last sample of a packet (in case that is all you care about
			--! and don't want to add logic for counting and comparisons).

		o_col_num : out std_logic_vector(g_dim_size_bits-1 downto 0); --! Current 0-based pixel X coordinate. Will always be even and increment by 2 as we are dealing with pixel pairs here.
		o_row_num : out std_logic_vector(g_dim_size_bits-1 downto 0); --! Current 0-based pixel y coordinate.

		o_pair0_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair0_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair1_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair1_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair2_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair2_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair3_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair3_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair4_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair4_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair5_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair5_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair6_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair6_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair7_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pair7_odd_pixel  : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		o_pixel_v : out std_logic --! Tells when output data is valid.
	);
end entity header_decode;

architecture rtl of header_decode is

	------------------------------------------------------------------------------
	-- Constants
	------------------------------------------------------------------------------

	------------------------------------------------------------------------------
	-- Signals
	------------------------------------------------------------------------------
	type t_state is
		(
			PACKET_HDR_SIZE_STATE, --! We are waiting for (or receiving) the part of the header that contains the number of rows and columns in the frame.
			PACKET_HDR_ROI_STATE, --! Receiving header portion that contains x, y ROI offsets in 2 pixels per clock mode.
			PACKET_HDR_FRAME_INDEX_STATE, --! Receiving header portion that contains frame index.
			PACKET_HDR_TIMESTAMP_STATE, --! Receiving header portion that contains timestamp in 2 pixels per clock mode.
			PACKET_HDR_SPARE0_STATE, --! Receiving header portion that contains spare word.
			PACKET_HDR_SPARE1_STATE, --! Receiving header portion that contains second spare word in 2 pixels per clock mode.
			PACKET_HDR_SPARE2_STATE, --! Output third spare word.
			PACKET_HDR_SPARE3_STATE, --! Output fourth spare word in 2 pixels per clock mode.
			PACKET_FRAME_DATA_STATE --! We are waiting for (or receiving) the pixel data of a frame.
		);
	signal s_state : t_state := PACKET_HDR_SIZE_STATE;
	
	signal s_o_pair0_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair0_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair1_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair1_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair2_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair2_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair3_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair3_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair4_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair4_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair5_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair5_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair6_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair6_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair7_even_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.
	signal s_o_pair7_odd_pixel : std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! Register for output pixel to sync up with row/col counts and valid signals.

	signal s_o_roi_offset_x : std_logic_vector(g_dim_size_bits-1 downto 0) := (others => '0'); --! Number of pixels in horizontal direction from pixel (0, 0)
		--! that marks where this frame (ROI) exists in full frame. Valid when o_pixel_v is high.
	signal s_o_roi_offset_y : std_logic_vector(g_dim_size_bits-1 downto 0) := (others => '0'); --! Number of pixels in vertical direction from pixel (0, 0)
		--! that marks where this frame (ROI) exists in full frame. Valid when o_pixel_v is high.

	signal s_o_frame_index : std_logic_vector(31 downto 0) := (others => '0'); --! Index value/indentifier for current frame.
		--! Valid when o_pixel_v is high.

	signal s_o_timestamp : std_logic_vector(31 downto 0) := (others => '0'); --! Timestamp to mark capture time of current frame.
		--! Valid when o_pixel_v is high.
	signal s_o_timestamp_slow : std_logic_vector(31 downto 0) := (others => '0'); --! Slow Timestamp to mark capture time of current frame.
		--! Valid when o_pixel_v is high.

	signal s_o_pixel_format : std_logic_vector(31 downto 0) := (others => '0'); --! Code to define the format of the pixel data and
			--! how it should be interpreted (i.e. mono, bayer, RGB).

	signal s_o_frame_sync : std_logic := '0'; --! Single cycle pulse high at start of frame.
	signal s_o_line_sync : std_logic := '0'; --! Single cycle pulse high at start of each line.
	signal s_o_pixel_v : std_logic := '0'; --! Marks output values as valid.
	signal s_o_last_sample : std_logic := '0'; --! Propagation of endofpacket to mark last output sample of frame data.

	signal s_num_rows : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! The total number of rows expected in this packet.
	signal s_num_cols : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! The number of pixels per row expected in this packet.
	signal s_num_cols_min16 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! The number of pixels per row expected in this packet.
	signal s_num_cols_min8 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! The number of pixels per row expected in this packet.
	signal s_num_cols_min4 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! The number of pixels per row expected in this packet.
	signal s_num_cols_min2 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! The number of pixels per row expected in this packet.
	signal s_num_rows_min1 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0');

	signal s_row_cnt : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Used to know which 0-based row we are currently outputting.
	signal s_col_cnt : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Used to know which 0-based column we are currently outputting.

	signal s_row_cnt_r1 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Pipeline delay.
	signal s_col_cnt_r1 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Pipeline delay.

	signal s_packet_sync_error : std_logic := '0'; --! Sticky bit to report error when we received too much or too little data. Or header could be incorrect.

	-- attribute mark_debug : string;
	-- attribute mark_debug of i_packet_data_v : signal is "true";
	-- attribute mark_debug of s_state : signal is "true";
	-- attribute mark_debug of s_o_frame_sync : signal is "true";
	-- attribute mark_debug of s_o_pixel_v : signal is "true";
	-- attribute mark_debug of i_srst : signal is "true";

	------------------------------------------------------------------------------
	-- Components 
	------------------------------------------------------------------------------

begin

	OUTPUT_REG_GEN_X2 : if (g_pixels_per_clk >= 2) generate
		OUTPUT_REG_PROC_X2 : process (i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					-- Pipeline delay to help with timing
					s_o_pair0_even_pixel <= i_packet_data((1*g_bits_per_pixel)-1 downto 0*g_bits_per_pixel);
					s_o_pair0_odd_pixel  <= i_packet_data((2*g_bits_per_pixel)-1 downto 1*g_bits_per_pixel);
				end if;
			end if;
		end process OUTPUT_REG_PROC_X2;
	end generate OUTPUT_REG_GEN_X2;

	OUTPUT_REG_GEN_X4 : if (g_pixels_per_clk >= 4) generate
		OUTPUT_REG_PROC_X4 : process (i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					-- Pipeline delay to help with timing
					s_o_pair1_even_pixel <= i_packet_data((3*g_bits_per_pixel)-1 downto 2*g_bits_per_pixel);
					s_o_pair1_odd_pixel  <= i_packet_data((4*g_bits_per_pixel)-1 downto 3*g_bits_per_pixel);
				end if;
			end if;
		end process OUTPUT_REG_PROC_X4;
	end generate OUTPUT_REG_GEN_X4;

	OUTPUT_REG_GEN_X8 : if (g_pixels_per_clk >= 8) generate
		OUTPUT_REG_PROC_X8 : process (i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					-- Pipeline delay to help with timing
					s_o_pair2_even_pixel <= i_packet_data((5*g_bits_per_pixel)-1 downto 4*g_bits_per_pixel);
					s_o_pair2_odd_pixel  <= i_packet_data((6*g_bits_per_pixel)-1 downto 5*g_bits_per_pixel);
					s_o_pair3_even_pixel <= i_packet_data((7*g_bits_per_pixel)-1 downto 6*g_bits_per_pixel);
					s_o_pair3_odd_pixel  <= i_packet_data((8*g_bits_per_pixel)-1 downto 7*g_bits_per_pixel);
				end if;
			end if;
		end process OUTPUT_REG_PROC_X8;
	end generate OUTPUT_REG_GEN_X8;

	OUTPUT_REG_GEN_X16 : if (g_pixels_per_clk >= 16) generate
		OUTPUT_REG_PROC_X16 : process (i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					-- Pipeline delay to help with timing
					s_o_pair4_even_pixel <= i_packet_data((9*g_bits_per_pixel)-1 downto 8*g_bits_per_pixel);
					s_o_pair4_odd_pixel  <= i_packet_data((10*g_bits_per_pixel)-1 downto 9*g_bits_per_pixel);
					s_o_pair5_even_pixel <= i_packet_data((11*g_bits_per_pixel)-1 downto 10*g_bits_per_pixel);
					s_o_pair5_odd_pixel  <= i_packet_data((12*g_bits_per_pixel)-1 downto 11*g_bits_per_pixel);
					s_o_pair6_even_pixel <= i_packet_data((13*g_bits_per_pixel)-1 downto 12*g_bits_per_pixel);
					s_o_pair6_odd_pixel  <= i_packet_data((14*g_bits_per_pixel)-1 downto 13*g_bits_per_pixel);
					s_o_pair7_even_pixel <= i_packet_data((15*g_bits_per_pixel)-1 downto 14*g_bits_per_pixel);
					s_o_pair7_odd_pixel  <= i_packet_data((16*g_bits_per_pixel)-1 downto 15*g_bits_per_pixel);
				end if;
			end if;
		end process OUTPUT_REG_PROC_X16;
	end generate OUTPUT_REG_GEN_X16;

	--! Process for handling packetized input data.
	PACKET_INPUT_PROC : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_srst = '1') then
				s_state <= PACKET_HDR_SIZE_STATE;	

				s_o_last_sample <= '0';
				s_row_cnt <= (others => '0');
				s_col_cnt <= (others => '0');
				s_row_cnt_r1 <= (others => '0');
				s_col_cnt_r1 <= (others => '0');

				-- Default to no valid output data
				s_o_frame_sync <= '0';
				s_o_line_sync <= '0';
				s_o_pixel_v <= '0';
			else
				if (i_ready = '1') then
					if (i_packet_data_v = '1') then
						s_o_last_sample <= i_packet_data_endofpacket;
					else
						s_o_last_sample <= '0';
					end if;
					s_row_cnt_r1 <= s_row_cnt;
					s_col_cnt_r1 <= s_col_cnt;

					-- Default to no valid output data
					s_o_frame_sync <= '0';
					s_o_line_sync <= '0';
					s_o_pixel_v <= '0';

					if (g_pixels_per_clk = 2) then
						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');

								if (i_packet_data_startofpacket = '1' and i_packet_data_v = '1') then
									-- Currently packet header is a single word. So we can just capture the frame size and move onto capturing frame data.
									s_num_rows <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16));
									s_num_cols <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0));
									s_num_cols_min2 <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0))-2;
									s_num_rows_min1 <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16))-1;
									s_state <= PACKET_HDR_ROI_STATE;
								elsif (i_packet_data_v = '1') then
									-- If packet data is valid when not marked as start and end of packet we must be off sync...
									s_packet_sync_error <= '1';
								end if;

							when PACKET_HDR_ROI_STATE =>
								if (i_packet_data_v = '1') then
									s_o_roi_offset_y <= i_packet_data(16+g_dim_size_bits-1 downto 16);
									s_o_roi_offset_x <= i_packet_data(g_dim_size_bits-1 downto 0);
									s_state <= PACKET_HDR_FRAME_INDEX_STATE;
								end if;

							when PACKET_HDR_FRAME_INDEX_STATE =>
								if (i_packet_data_v = '1') then
									s_o_frame_index <= i_packet_data(31 downto 0);
									s_state <= PACKET_HDR_TIMESTAMP_STATE;
								end if;

							when PACKET_HDR_TIMESTAMP_STATE =>
								if (i_packet_data_v = '1') then
									s_o_timestamp <= i_packet_data(31 downto 0);
									s_state <= PACKET_HDR_SPARE0_STATE;
								end if;

							when PACKET_HDR_SPARE0_STATE =>
								if (i_packet_data_v = '1') then
									s_o_timestamp_slow <= i_packet_data(31 downto 0);
									s_state <= PACKET_HDR_SPARE1_STATE;
								end if;

							when PACKET_HDR_SPARE1_STATE =>
								if (i_packet_data_v = '1') then
									s_o_pixel_format <= i_packet_data(31 downto 0);
									s_state <= PACKET_HDR_SPARE2_STATE;
								end if;

							when PACKET_HDR_SPARE2_STATE =>
								if (i_packet_data_v = '1') then
									s_state <= PACKET_HDR_SPARE3_STATE;
								end if;

							when PACKET_HDR_SPARE3_STATE =>
								if (i_packet_data_v = '1') then
									s_state <= PACKET_FRAME_DATA_STATE;
								end if;

							when PACKET_FRAME_DATA_STATE =>
									
								-- Delay so pixel data matches with counts and frame and line valid
								s_o_pixel_v <= i_packet_data_v;
							
								if (i_packet_data_v = '1') then
									if (i_packet_data_startofpacket = '1') then
										-- We should not get a startofpacket pulse.
										s_packet_sync_error <= '1';
									end if;
									-- end of pack logic, allow for early termination or
									-- finish at end of rows+cols
									if (i_packet_data_endofpacket = '1') or
									   ((s_row_cnt = s_num_rows-1) and (s_col_cnt = s_num_cols_min2)) then
										s_state <= PACKET_HDR_SIZE_STATE;
									end if;
									
									if (s_col_cnt = 0) then
										-- Single pulse high at beginning of each row
										s_o_line_sync <= '1';

										if (s_row_cnt = 0) then
											-- Single pulse high at beginning of each column
											s_o_frame_sync <= '1';
										end if;
									end if;
					
									if (s_col_cnt < s_num_cols_min2) then
										-- Increment by two, since we are in parallel mode and receiving odd and even pixels simulataneously
										s_col_cnt <= s_col_cnt + 2;	
									else
										-- This pair of pixels is the last in the current row
										s_col_cnt <= (others => '0');

										if (s_row_cnt < s_num_rows_min1) then
											s_row_cnt <= s_row_cnt + 1;
										else
											-- This is the last pixel of the last row of the frame. This should be the end of the frame data for this packet.
											s_row_cnt <= (others => '0');
										end if;
									end if;
								end if;
						end case;
					elsif (g_pixels_per_clk = 4) then
						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');

								if (i_packet_data_startofpacket = '1' and i_packet_data_v = '1') then
									-- Currently packet header is a single word. So we can just capture the frame size and move onto capturing frame data.
									s_num_rows <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16));
									s_num_cols <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0));
									s_num_cols_min4 <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0))-4;
									s_num_rows_min1 <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16))-1;
									s_o_roi_offset_y <= i_packet_data(48+g_dim_size_bits-1 downto 48);
									s_o_roi_offset_x <= i_packet_data(32+g_dim_size_bits-1 downto 32);
									s_state <= PACKET_HDR_FRAME_INDEX_STATE;
								elsif (i_packet_data_v = '1') then
									-- If packet data is valid when not marked as start and end of packet we must be off sync...
									s_packet_sync_error <= '1';
								end if;

							when PACKET_HDR_FRAME_INDEX_STATE =>
								if (i_packet_data_v = '1') then
									s_o_frame_index <= i_packet_data(31 downto 0);
									s_o_timestamp <= i_packet_data(63 downto 32);
									s_state <= PACKET_HDR_SPARE0_STATE;
								end if;

							when PACKET_HDR_SPARE0_STATE =>
								if (i_packet_data_v = '1') then
									s_o_timestamp_slow <= i_packet_data(31 downto 0);
									s_o_pixel_format <= i_packet_data(63 downto 32);
									s_state <= PACKET_HDR_SPARE3_STATE;
								end if;

							when PACKET_HDR_SPARE3_STATE =>
								if (i_packet_data_v = '1') then
									s_state <= PACKET_FRAME_DATA_STATE;
								end if;

							when PACKET_FRAME_DATA_STATE =>
									
								-- Delay so pixel data matches with counts and frame and line valid
								s_o_pixel_v <= i_packet_data_v;
							
								if (i_packet_data_v = '1') then
									if (i_packet_data_startofpacket = '1') then
										-- We should not get a startofpacket pulse.
										s_packet_sync_error <= '1';
									end if;
									-- end of pack logic, allow for early termination or
									-- finish at end of rows+cols
									if (i_packet_data_endofpacket = '1') or
									   ((s_row_cnt = s_num_rows-1) and (s_col_cnt = s_num_cols_min4)) then
										s_state <= PACKET_HDR_SIZE_STATE;
									end if;
									
									if (s_col_cnt = 0) then
										-- Single pulse high at beginning of each row
										s_o_line_sync <= '1';

										if (s_row_cnt = 0) then
											-- Single pulse high at beginning of each column
											s_o_frame_sync <= '1';
										end if;
									end if;
					
									if (s_col_cnt < s_num_cols_min4) then
										-- Increment by two, since we are in parallel mode and receiving odd and even pixels simulataneously
										s_col_cnt <= s_col_cnt + 4;	
									else
										-- This pair of pixels is the last in the current row
										s_col_cnt <= (others => '0');

										if (s_row_cnt < s_num_rows_min1) then
											s_row_cnt <= s_row_cnt + 1;
										else
											-- This is the last pixel of the last row of the frame. This should be the end of the frame data for this packet.
											s_row_cnt <= (others => '0');
										end if;
									end if;
								end if;

							when others =>
								null;

						end case;

					elsif (g_pixels_per_clk = 8) then
						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');

								if (i_packet_data_startofpacket = '1' and i_packet_data_v = '1') then
									-- Currently packet header is a single word. So we can just capture the frame size and move onto capturing frame data.
									s_num_rows <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16));
									s_num_cols <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0));
									s_num_cols_min8 <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0))-8;
									s_num_rows_min1 <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16))-1;
									s_o_roi_offset_y <= i_packet_data(48+g_dim_size_bits-1 downto 48);
									s_o_roi_offset_x <= i_packet_data(32+g_dim_size_bits-1 downto 32);
									s_o_frame_index <= i_packet_data(95 downto 64);
									s_o_timestamp <= i_packet_data(127 downto 96);
									s_state <= PACKET_HDR_SPARE0_STATE;
								elsif (i_packet_data_v = '1') then
									-- If packet data is valid when not marked as start and end of packet we must be off sync...
									s_packet_sync_error <= '1';
								end if;

							when PACKET_HDR_SPARE0_STATE =>
								if (i_packet_data_v = '1') then
									s_o_timestamp_slow <= i_packet_data(31 downto 0);
									s_o_pixel_format <= i_packet_data(63 downto 32);
									s_state <= PACKET_FRAME_DATA_STATE;
								end if;

							when PACKET_FRAME_DATA_STATE =>
									
								-- Delay so pixel data matches with counts and frame and line valid
								s_o_pixel_v <= i_packet_data_v;
							
								if (i_packet_data_v = '1') then
									if (i_packet_data_startofpacket = '1') then
										-- We should not get a startofpacket pulse.
										s_packet_sync_error <= '1';
									end if;
									-- end of pack logic, allow for early termination or
									-- finish at end of rows+cols
									if (i_packet_data_endofpacket = '1') or
									   ((s_row_cnt = s_num_rows-1) and (s_col_cnt = s_num_cols_min8)) then
										s_state <= PACKET_HDR_SIZE_STATE;
									end if;
									
									if (s_col_cnt = 0) then
										-- Single pulse high at beginning of each row
										s_o_line_sync <= '1';

										if (s_row_cnt = 0) then
											-- Single pulse high at beginning of each column
											s_o_frame_sync <= '1';
										end if;
									end if;
					
									if (s_col_cnt < s_num_cols_min8) then
										-- Increment by two, since we are in parallel mode and receiving odd and even pixels simulataneously
										s_col_cnt <= s_col_cnt + 8;	
									else
										-- This pair of pixels is the last in the current row
										s_col_cnt <= (others => '0');

										if (s_row_cnt < s_num_rows_min1) then
											s_row_cnt <= s_row_cnt + 1;
										else
											-- This is the last pixel of the last row of the frame. This should be the end of the frame data for this packet.
											s_row_cnt <= (others => '0');
										end if;
									end if;
								end if;

							when others =>
								null;

						end case;

					elsif (g_pixels_per_clk = 16) then
						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');

								if (i_packet_data_startofpacket = '1' and i_packet_data_v = '1') then
									-- Currently packet header is a single word. So we can just capture the frame size and move onto capturing frame data.
									s_num_rows <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16));
									s_num_cols <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0));
									s_num_cols_min16 <= UNSIGNED(i_packet_data(g_dim_size_bits-1 downto 0))-16;
									s_num_rows_min1 <= UNSIGNED(i_packet_data(16+g_dim_size_bits-1 downto 16))-1;
									s_o_roi_offset_y <= i_packet_data(48+g_dim_size_bits-1 downto 48);
									s_o_roi_offset_x <= i_packet_data(32+g_dim_size_bits-1 downto 32);
									s_o_frame_index <= i_packet_data(95 downto 64);
									s_o_timestamp <= i_packet_data(127 downto 96);
									s_o_timestamp_slow <= i_packet_data(159 downto 128);
									s_o_pixel_format <= i_packet_data(191 downto 160);
									s_state <= PACKET_FRAME_DATA_STATE;
								elsif (i_packet_data_v = '1') then
									-- If packet data is valid when not marked as start and end of packet we must be off sync...
									s_packet_sync_error <= '1';
								end if;

							when PACKET_FRAME_DATA_STATE =>
									
								-- Delay so pixel data matches with counts and frame and line valid
								s_o_pixel_v <= i_packet_data_v;
							
								if (i_packet_data_v = '1') then
									if (i_packet_data_startofpacket = '1') then
										-- We should not get a startofpacket pulse.
										s_packet_sync_error <= '1';
									end if;
									-- end of pack logic, allow for early termination or
									-- finish at end of rows+cols
									if (i_packet_data_endofpacket = '1') or
									   ((s_row_cnt = s_num_rows-1) and (s_col_cnt = s_num_cols_min16)) then
										s_state <= PACKET_HDR_SIZE_STATE;
									end if;
									
									if (s_col_cnt = 0) then
										-- Single pulse high at beginning of each row
										s_o_line_sync <= '1';

										if (s_row_cnt = 0) then
											-- Single pulse high at beginning of each column
											s_o_frame_sync <= '1';
										end if;
									end if;
					
									if (s_col_cnt < s_num_cols_min16) then
										-- Increment by two, since we are in parallel mode and receiving odd and even pixels simulataneously
										s_col_cnt <= s_col_cnt + 16;	
									else
										-- This pair of pixels is the last in the current row
										s_col_cnt <= (others => '0');

										if (s_row_cnt < s_num_rows_min1) then
											s_row_cnt <= s_row_cnt + 1;
										else
											-- This is the last pixel of the last row of the frame. This should be the end of the frame data for this packet.
											s_row_cnt <= (others => '0');
										end if;
									end if;
								end if;

							when others =>
								null;

						end case;
					end if;
				end if;

				if (i_packet_sync_error_clr = '1') then
					s_packet_sync_error <= '0';
				end if;
			end if;
		end if;
	end process PACKET_INPUT_PROC;

	o_packet_sync_error_sticky <= s_packet_sync_error;

	o_num_cols <= STD_LOGIC_VECTOR(s_num_cols);
	o_num_rows <= STD_LOGIC_VECTOR(s_num_rows);

	o_roi_offset_x <= s_o_roi_offset_x;
	o_roi_offset_y <= s_o_roi_offset_y;

	o_frame_index <= s_o_frame_index;

	o_timestamp <= s_o_timestamp;
	o_timestamp_slow <= s_o_timestamp_slow;

	o_pixel_format <= s_o_pixel_format;

	o_frame_sync <= s_o_frame_sync;
	o_line_sync <= s_o_line_sync;
	o_last_sample <= s_o_last_sample;

	o_col_num <= STD_LOGIC_VECTOR(s_col_cnt_r1);
	o_row_num <= STD_LOGIC_VECTOR(s_row_cnt_r1);

	o_pair0_even_pixel <= s_o_pair0_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 0), g_bits_per_pixel));
	o_pair0_odd_pixel  <= s_o_pair0_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 1)&"1", g_bits_per_pixel));
	o_pair1_even_pixel <= s_o_pair1_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 2)&"10", g_bits_per_pixel));
	o_pair1_odd_pixel  <= s_o_pair1_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 2)&"11", g_bits_per_pixel));
	o_pair2_even_pixel <= s_o_pair2_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 3)&"100", g_bits_per_pixel));
	o_pair2_odd_pixel  <= s_o_pair2_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 3)&"101", g_bits_per_pixel));
	o_pair3_even_pixel <= s_o_pair3_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 3)&"110", g_bits_per_pixel));
	o_pair3_odd_pixel  <= s_o_pair3_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 3)&"111", g_bits_per_pixel));
	o_pair4_even_pixel <= s_o_pair4_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1000", g_bits_per_pixel));
	o_pair4_odd_pixel  <= s_o_pair4_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1001", g_bits_per_pixel));
	o_pair5_even_pixel <= s_o_pair5_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1010", g_bits_per_pixel));
	o_pair5_odd_pixel  <= s_o_pair5_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1011", g_bits_per_pixel));
	o_pair6_even_pixel <= s_o_pair6_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1100", g_bits_per_pixel));
	o_pair6_odd_pixel  <= s_o_pair6_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1101", g_bits_per_pixel));
	o_pair7_even_pixel <= s_o_pair7_even_pixel when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1110", g_bits_per_pixel));
	o_pair7_odd_pixel  <= s_o_pair7_odd_pixel  when i_test_pattern_en = '0' else STD_LOGIC_VECTOR(resize(s_row_cnt_r1(3 downto 0)&s_col_cnt_r1(11 downto 4)&"1111", g_bits_per_pixel));
	o_pixel_v <= s_o_pixel_v;

end architecture; -- of header_decode
