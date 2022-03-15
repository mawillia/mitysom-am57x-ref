--- Title: header_create.vhd
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
--! Note this is a simple unit. If there are errors they will be caught by the 
--!  header_decode unit.
entity header_create is
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
		i_clk : in std_logic; --! Clock for creating header data.
		i_srst : in std_logic; --! Synchronous reset.

		i_num_cols : in std_logic_vector(g_dim_size_bits-1 downto 0); --! Number of columns in frame. Must be valid when i_frame_sync = '1'. 
			--! Should always be even when g_pixels_per_clk = 2, and a multiple of 4 when g_pixels_per_clk = 4.
		i_num_rows : in std_logic_vector(g_dim_size_bits-1 downto 0); --! Number of rows in frame. Must be valid when i_frame_sync = '1'.

		i_roi_offset_x : in std_logic_vector(g_dim_size_bits-1 downto 0) := (others=>'0'); --! Number of pixels in horizontal direction from pixel (0, 0)
			--! that marks where this frame (ROI) exists in full frame. Must be valid for up to 1 cycle after i_frame_sync = '1'.
		i_roi_offset_y : in std_logic_vector(g_dim_size_bits-1 downto 0) := (others=>'0'); --! Number of pixels in vertical direction from pixel (0, 0)
			--! that marks where this frame (ROI) exists in full frame. Must be valid for up to 1 cycle after i_frame_sync = '1'.

		i_frame_index : in std_logic_vector(31 downto 0) := (others=>'0'); --! Index value/indentifier for current frame.
			--! Must be valid for up to 2 cycles after i_frame_sync = '1'.

		i_timestamp : in std_logic_vector(31 downto 0) := (others=>'0'); --! Timestamp to mark capture time of current frame.
			--! Must be valid for up to 3 cycles after i_frame_sync = '1'.

		i_timestamp_slow : in std_logic_vector(31 downto 0) := (others=>'0'); --! Slow Timestamp to mark capture time of current frame.
			--! Must be valid for up to 3 cycles after i_frame_sync = '1'.

		i_pixel_format : in std_logic_vector(31 downto 0) := (others => '0'); --! Code to define the format of the pixel data and
			--! how it should be interpreted (i.e. mono, bayer, RGB).

		i_frame_sync : in std_logic; --! Single cycle pulse high at beginning of a frame. Indicates that header data is inputs are all
			--! valid. Note that overflow can occur if this is set high before the previous frame has finished sending. It is the 
			--! parent components responsibility to make sure this does not happen.

		i_ready : in std_logic := '1'; --! '0' indicates data output should pause where it is because receiving component
			--! is not ready. 

		o_overflow_sticky : out std_logic; --! Sticks high if we receive i_frame_sync before we finish sending the current frame data.
		i_overflow_sticky_clr : in std_logic := '0'; --! Used to clear overflow sticky output status bit.
	
		i_pair0_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		i_pair0_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
		i_pair1_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair1_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair2_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair2_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair3_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair3_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair4_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair4_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair5_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair5_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair6_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair6_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair7_even_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pair7_odd_pixel : in std_logic_vector(g_bits_per_pixel-1 downto 0) := (others => '0'); --! See Documentation for details.
		i_pixel_v : in std_logic; --! Tells when output data is valid.

		o_packet_data : out std_logic_vector((g_pixels_per_clk*g_bits_per_pixel)-1 downto 0); --! Either header data or pixel values.
		o_packet_data_startofpacket : out std_logic; --! High for first packet of header.
		o_packet_data_v : out std_logic; --! High for valid packet data.
		o_packet_data_endofpacket : out std_logic --! High for last packet of header.
	);
end entity header_create;

architecture rtl of header_create is

	------------------------------------------------------------------------------
	-- Constants
	------------------------------------------------------------------------------
	constant SHIFT_REG_SIZE : natural := 8/(g_pixels_per_clk/2); --! The number cycles it takes to output the header. 
		--! This is the number of pixel pairs/tuples we need to buffer.

	constant SR_PIX_V_LOC : natural := (2*g_bits_per_pixel) * (g_pixels_per_clk/2); --! Offset in shift register where pixel valid is stored.
	subtype SR_PAIR7_ODD_PIX_LOC is natural range  ((16*g_bits_per_pixel)-1) downto (15*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR7_EVEN_PIX_LOC is natural range ((15*g_bits_per_pixel)-1) downto (14*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR6_ODD_PIX_LOC is natural range  ((14*g_bits_per_pixel)-1) downto (13*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR6_EVEN_PIX_LOC is natural range ((13*g_bits_per_pixel)-1) downto (12*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR5_ODD_PIX_LOC is natural range  ((12*g_bits_per_pixel)-1) downto (11*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR5_EVEN_PIX_LOC is natural range ((11*g_bits_per_pixel)-1) downto (10*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR4_ODD_PIX_LOC is natural range  ((10*g_bits_per_pixel)-1) downto ( 9*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR4_EVEN_PIX_LOC is natural range (( 9*g_bits_per_pixel)-1) downto ( 8*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR3_ODD_PIX_LOC is natural range  (( 8*g_bits_per_pixel)-1) downto ( 7*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR3_EVEN_PIX_LOC is natural range (( 7*g_bits_per_pixel)-1) downto ( 6*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR2_ODD_PIX_LOC is natural range  (( 6*g_bits_per_pixel)-1) downto ( 5*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR2_EVEN_PIX_LOC is natural range (( 5*g_bits_per_pixel)-1) downto ( 4*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR1_ODD_PIX_LOC is natural range  (( 4*g_bits_per_pixel)-1) downto ( 3*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR1_EVEN_PIX_LOC is natural range (( 3*g_bits_per_pixel)-1) downto ( 2*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.
	subtype SR_PAIR0_ODD_PIX_LOC is natural range  (( 2*g_bits_per_pixel)-1) downto ( 1*g_bits_per_pixel); --! Offset in shift register where odd pixel data is stored.
	subtype SR_PAIR0_EVEN_PIX_LOC is natural range (( 1*g_bits_per_pixel)-1) downto ( 0*g_bits_per_pixel); --! Offset in shift register where even pixel data is stored.

	------------------------------------------------------------------------------
	-- Signals
	------------------------------------------------------------------------------
	type t_shift_reg is array(SHIFT_REG_SIZE-1 downto 0) of std_logic_vector(SR_PIX_V_LOC downto 0); --! Each array entry is 32 bits of data, 1 bit pixel valid flag and 1 bit frame valid flag.
	signal s_shift_reg : t_shift_reg; --! Shift register to make up for delay time needed to send out header data.

	type t_state is
		(
			PACKET_HDR_SIZE_STATE, --! We are waiting for (or receiving) the part of the header that contains the number of rows and columns in the frame.
			PACKET_HDR_ROI_STATE, --! Output x, y ROI offsets in 2 pixels per clock mode.
			PACKET_HDR_FRAME_INDEX_STATE, --! Output frame index.
			PACKET_HDR_TIMESTAMP_STATE, --! Output timestamp in 2 pixels per clock mode.
			PACKET_HDR_SPARE0_STATE, --! Output spare word.
			PACKET_HDR_SPARE1_STATE, --! Output second spare word in 2 pixels per clock mode.
			PACKET_HDR_SPARE2_STATE, --! Output third spare word.
			PACKET_HDR_SPARE3_STATE, --! Output fourth spare word in 2 pixels per clock mode.
			PACKET_FRAME_DATA_STATE --! We are waiting for (or receiving) the pixel data of a frame.
		);
	signal s_state : t_state := PACKET_HDR_SIZE_STATE;

	signal s_o_packet_data : std_logic_vector((g_pixels_per_clk*g_bits_per_pixel)-1 downto 0) := (others => '0'); --! Either header data or pixel values.
	signal s_o_packet_data_startofpacket : std_logic := '0'; --! High for first packet of header.
	signal s_o_packet_data_v : std_logic := '0'; --! High for valid packet data.
	signal s_o_packet_data_endofpacket : std_logic := '0'; --! High for last packet of header.
	
	signal s_row_cnt : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Used to know which 0-based row we are currently outputting.
	signal s_col_cnt : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Used to know which 0-based column we are currently outputting.
	signal s_num_rows_min1 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Input adjusted (minus 1) for 0-based counter.
	signal s_num_cols_min2 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Input adjusted (minus 2) for 0-based even (increments by 2) counter.
		--! g_pixels_per_clk = 2 case.
	signal s_num_cols_min4 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Input adjusted (minus 4) for 0-based even (increments by 4) counter.
		--! g_pixels_per_clk = 4 case.
	signal s_num_cols_min8 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Input adjusted (minus 8) for 0-based even (increments by 8) counter.
		--! g_pixels_per_clk = 8 case.
	signal s_num_cols_min16 : unsigned(g_dim_size_bits-1 downto 0) := (others => '0'); --! Input adjusted (minus 16) for 0-based even (increments by 8) counter.
		--! g_pixels_per_clk = 16 case.
	
	signal s_eop_sent : std_logic := '0';

	signal s_o_overflow_sticky : std_logic := '0';

	------------------------------------------------------------------------------
	-- Components 
	------------------------------------------------------------------------------

begin

	--! Shift register to account for delay of starting to send header data when first pixel pair is received.
	SHIFT_REG_PROC : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_ready = '1') then
				s_shift_reg(0)(SR_PIX_V_LOC) <= i_pixel_v;
				s_shift_reg(SHIFT_REG_SIZE-1 downto 1) <= s_shift_reg(SHIFT_REG_SIZE-2 downto 0);
			end if;
		end if;
	end process SHIFT_REG_PROC;

	SHIFT_REG_GEN_X2 : if (g_pixels_per_clk >= 2) generate
		SHIFT_REG_PROC_X2 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					s_shift_reg(0)(SR_PAIR0_ODD_PIX_LOC) <= i_pair0_odd_pixel;
					s_shift_reg(0)(SR_PAIR0_EVEN_PIX_LOC) <= i_pair0_even_pixel;
				end if;
			end if;
		end process SHIFT_REG_PROC_X2;
	end generate SHIFT_REG_GEN_X2;

	SHIFT_REG_GEN_X4 : if (g_pixels_per_clk >= 4) generate
		SHIFT_REG_PROC_X4 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					s_shift_reg(0)(SR_PAIR1_ODD_PIX_LOC) <= i_pair1_odd_pixel;
					s_shift_reg(0)(SR_PAIR1_EVEN_PIX_LOC) <= i_pair1_even_pixel;
				end if;
			end if;
		end process SHIFT_REG_PROC_X4;
	end generate SHIFT_REG_GEN_X4;

	SHIFT_REG_GEN_X8 : if (g_pixels_per_clk >= 8) generate
		SHIFT_REG_PROC_X8 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					s_shift_reg(0)(SR_PAIR2_ODD_PIX_LOC) <= i_pair2_odd_pixel;
					s_shift_reg(0)(SR_PAIR2_EVEN_PIX_LOC) <= i_pair2_even_pixel;
					s_shift_reg(0)(SR_PAIR3_ODD_PIX_LOC) <= i_pair3_odd_pixel;
					s_shift_reg(0)(SR_PAIR3_EVEN_PIX_LOC) <= i_pair3_even_pixel;
				end if;
			end if;
		end process SHIFT_REG_PROC_X8;
	end generate SHIFT_REG_GEN_X8;

	SHIFT_REG_GEN_X16 : if (g_pixels_per_clk >= 16) generate
		SHIFT_REG_PROC_X16 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_ready = '1') then
					s_shift_reg(0)(SR_PAIR4_ODD_PIX_LOC) <= i_pair4_odd_pixel;
					s_shift_reg(0)(SR_PAIR4_EVEN_PIX_LOC) <= i_pair4_even_pixel;
					s_shift_reg(0)(SR_PAIR5_ODD_PIX_LOC) <= i_pair5_odd_pixel;
					s_shift_reg(0)(SR_PAIR5_EVEN_PIX_LOC) <= i_pair5_even_pixel;
					s_shift_reg(0)(SR_PAIR6_ODD_PIX_LOC) <= i_pair6_odd_pixel;
					s_shift_reg(0)(SR_PAIR6_EVEN_PIX_LOC) <= i_pair6_even_pixel;
					s_shift_reg(0)(SR_PAIR7_ODD_PIX_LOC) <= i_pair7_odd_pixel;
					s_shift_reg(0)(SR_PAIR7_EVEN_PIX_LOC) <= i_pair7_even_pixel;
				end if;
			end if;
		end process SHIFT_REG_PROC_X16;
	end generate SHIFT_REG_GEN_X16;

	o_overflow_sticky <= s_o_overflow_sticky;

	OVERFLOW_CHECK_PROC : process (i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_overflow_sticky_clr = '1') then
				s_o_overflow_sticky <= '0';
			end if;

			if (s_state /= PACKET_HDR_SIZE_STATE and i_frame_sync = '1') then
				-- Mark as overflow if we get header data when we are sending out
				--  data from a previous frame.
				s_o_overflow_sticky <= '1';
			end if;
		end if;
	end process OVERFLOW_CHECK_PROC;

	--! Process for packetizing data for output.
	PACKET_OUTPUT_GEN_X2 : if (g_pixels_per_clk = 2) generate
		PACKET_OUTPUT_PROC_X2 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_srst = '1') then
					s_o_packet_data_startofpacket <= '0';
					s_o_packet_data_endofpacket <= '0';
					s_o_packet_data_v <= '0';
					s_state <= PACKET_HDR_SIZE_STATE;
				else
					if (i_ready = '1') then
						s_o_packet_data_startofpacket <= '0';
						s_o_packet_data_endofpacket <= '0';
						s_o_packet_data_v <= '0';
						s_o_packet_data <= (others => '0');
						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_o_packet_data(31 downto 0) <= std_logic_vector(resize(unsigned(i_num_rows),16)) & std_logic_vector(resize(unsigned(i_num_cols),16));
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');
								s_num_rows_min1 <= unsigned(i_num_rows)-1;
								s_num_cols_min2 <= unsigned(i_num_cols)-2;
								s_eop_sent <= '0';

								if (i_frame_sync = '1') then
									s_o_packet_data_startofpacket <= '1';
									s_o_packet_data_v <= '1';
									s_state <= PACKET_HDR_ROI_STATE;
								end if;

							when PACKET_HDR_ROI_STATE =>
								s_o_packet_data(31 downto 0) <= std_logic_vector(resize(unsigned(i_roi_offset_y),16)) & std_logic_vector(resize(unsigned(i_roi_offset_x),16));
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_FRAME_INDEX_STATE;

							when PACKET_HDR_FRAME_INDEX_STATE =>
								s_o_packet_data(31 downto 0) <= i_frame_index;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_TIMESTAMP_STATE;

							when PACKET_HDR_TIMESTAMP_STATE =>
								s_o_packet_data(31 downto 0) <= i_timestamp;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_SPARE0_STATE;

							when PACKET_HDR_SPARE0_STATE =>
								s_o_packet_data(31 downto 0) <= i_timestamp_slow;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_SPARE1_STATE;

							when PACKET_HDR_SPARE1_STATE =>
								s_o_packet_data(31 downto 0) <= i_pixel_format;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_SPARE2_STATE;

							when PACKET_HDR_SPARE2_STATE =>
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_SPARE3_STATE;

							when PACKET_HDR_SPARE3_STATE =>
								s_o_packet_data_v <= '1';
								s_state <= PACKET_FRAME_DATA_STATE;

							when PACKET_FRAME_DATA_STATE =>
								if (s_shift_reg(SHIFT_REG_SIZE-1)(SR_PIX_V_LOC) = '1') then
									-- We send out delayed pixel data now
									s_o_packet_data <= s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_EVEN_PIX_LOC);
									if (s_col_cnt < s_num_cols_min2) then
										s_col_cnt <= s_col_cnt + 2;
										s_o_packet_data_v <= '1';
									else
										s_row_cnt <= s_row_cnt + 1;
										s_col_cnt <= (others => '0');
										if (s_row_cnt < s_num_rows_min1) then
											s_o_packet_data_v <= '1';
										elsif s_eop_sent = '0' then
											s_o_packet_data_endofpacket <= '1';
											s_o_packet_data_v <= '1';
											s_eop_sent <= '1';
											s_state <= PACKET_HDR_SIZE_STATE;
										end if;
									end if;						
								end if;
						end case;
					end if;
				end if;	
			end if;
		end process PACKET_OUTPUT_PROC_X2;
	end generate PACKET_OUTPUT_GEN_X2;

	PACKET_OUTPUT_GEN_X4 : if (g_pixels_per_clk = 4) generate
		PACKET_OUTPUT_PROC_X4 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_srst = '1') then
					s_state <= PACKET_HDR_SIZE_STATE;
					s_o_packet_data_startofpacket <= '0';
					s_o_packet_data_endofpacket <= '0';
					s_o_packet_data_v <= '0';
				else
					if (i_ready = '1') then
						s_o_packet_data_startofpacket <= '0';
						s_o_packet_data_endofpacket <= '0';
						s_o_packet_data_v <= '0';
						s_o_packet_data <= (others => '0');
						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_o_packet_data(63 downto 0) <= std_logic_vector(resize(unsigned(i_roi_offset_y),16)) & std_logic_vector(resize(unsigned(i_roi_offset_x),16)) & std_logic_vector(resize(unsigned(i_num_rows),16)) & std_logic_vector(resize(unsigned(i_num_cols),16));
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');
								s_num_rows_min1 <= unsigned(i_num_rows)-1;
								s_num_cols_min4 <= unsigned(i_num_cols)-4;
								s_eop_sent <= '0';

								if (i_frame_sync = '1') then
									s_o_packet_data_startofpacket <= '1';
									s_o_packet_data_v <= '1';
									s_state <= PACKET_HDR_FRAME_INDEX_STATE;
								end if;

							when PACKET_HDR_FRAME_INDEX_STATE =>
								s_o_packet_data(63 downto 0) <= i_timestamp & i_frame_index;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_SPARE0_STATE;

							when PACKET_HDR_SPARE0_STATE =>
								s_o_packet_data(63 downto 0) <= i_pixel_format & i_timestamp_slow;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_HDR_SPARE3_STATE;

							when PACKET_HDR_SPARE3_STATE =>
								s_o_packet_data_v <= '1';
								s_state <= PACKET_FRAME_DATA_STATE;

							when PACKET_FRAME_DATA_STATE =>
								if (s_shift_reg(SHIFT_REG_SIZE-1)(SR_PIX_V_LOC) = '1') then
									-- We send out delayed pixel data now
									s_o_packet_data <= s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR1_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR1_EVEN_PIX_LOC) &
										s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_EVEN_PIX_LOC);
									if (s_col_cnt < s_num_cols_min4) then
										s_col_cnt <= s_col_cnt + 4;
										s_o_packet_data_v <= '1';
									else
										s_row_cnt <= s_row_cnt + 1;
										s_col_cnt <= (others => '0');
										if (s_row_cnt < s_num_rows_min1) then
											s_o_packet_data_v <= '1';
										elsif s_eop_sent = '0' then
											s_o_packet_data_endofpacket <= '1';
											s_o_packet_data_v <= '1';
											s_eop_sent <= '1';
											s_state <= PACKET_HDR_SIZE_STATE;
										end if;
									end if;						
								end if;

							when others =>
								null;

						end case;
					end if;
				end if;	
			end if;
		end process PACKET_OUTPUT_PROC_X4;
	end generate PACKET_OUTPUT_GEN_X4;

	PACKET_OUTPUT_GEN_X8 : if (g_pixels_per_clk = 8) generate
		PACKET_OUTPUT_PROC_X8 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_srst = '1') then
					s_state <= PACKET_HDR_SIZE_STATE;
					s_o_packet_data_startofpacket <= '0';
					s_o_packet_data_endofpacket <= '0';
					s_o_packet_data_v <= '0';
				else
					if (i_ready = '1') then
						s_o_packet_data_startofpacket <= '0';
						s_o_packet_data_endofpacket <= '0';
						s_o_packet_data_v <= '0';
						s_o_packet_data <= (others => '0');

						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_o_packet_data(127 downto 64) <= i_timestamp & i_frame_index;
								s_o_packet_data(63 downto 0) <= std_logic_vector(resize(unsigned(i_roi_offset_y),16)) & std_logic_vector(resize(unsigned(i_roi_offset_x),16)) & std_logic_vector(resize(unsigned(i_num_rows),16)) & std_logic_vector(resize(unsigned(i_num_cols),16));
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');
								s_num_rows_min1 <= unsigned(i_num_rows)-1;
								s_num_cols_min8 <= unsigned(i_num_cols)-8;
								s_eop_sent <= '0';

								if (i_frame_sync = '1') then
									s_o_packet_data_startofpacket <= '1';
									s_o_packet_data_v <= '1';
									s_state <= PACKET_HDR_SPARE0_STATE;
								end if;

							when PACKET_HDR_SPARE0_STATE =>
								s_o_packet_data(31 downto 0) <= i_timestamp_slow;
								s_o_packet_data(63 downto 32) <= i_pixel_format;
								s_o_packet_data_v <= '1';
								s_state <= PACKET_FRAME_DATA_STATE;

							when PACKET_FRAME_DATA_STATE =>
								if (s_shift_reg(SHIFT_REG_SIZE-1)(SR_PIX_V_LOC) = '1') then
									-- We send out delayed pixel data now
									s_o_packet_data <= s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR3_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR3_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR2_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR2_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR1_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR1_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_EVEN_PIX_LOC);
									if (s_col_cnt < s_num_cols_min8) then
										s_col_cnt <= s_col_cnt + 8;
										s_o_packet_data_v <= '1';
									else
										s_row_cnt <= s_row_cnt + 1;
										s_col_cnt <= (others => '0');
										if (s_row_cnt < s_num_rows_min1) then
											s_o_packet_data_v <= '1';
										elsif s_eop_sent = '0' then
											s_o_packet_data_endofpacket <= '1';
											s_o_packet_data_v <= '1';
											s_eop_sent <= '1';
											s_state <= PACKET_HDR_SIZE_STATE;
										end if;
									end if;						
								end if;

							when others =>
								null;

						end case;
					end if;
				end if;
			end if;
		end process PACKET_OUTPUT_PROC_X8;
	end generate PACKET_OUTPUT_GEN_X8;

	PACKET_OUTPUT_GEN_X16 : if (g_pixels_per_clk = 16) generate
		PACKET_OUTPUT_PROC_X16 : process(i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_srst = '1') then
					s_state <= PACKET_HDR_SIZE_STATE;
					s_o_packet_data_startofpacket <= '0';
					s_o_packet_data_endofpacket <= '0';
					s_o_packet_data_v <= '0';
				else
					if (i_ready = '1') then
						s_o_packet_data_startofpacket <= '0';
						s_o_packet_data_endofpacket <= '0';
						s_o_packet_data_v <= '0';
						s_o_packet_data <= (others => '0');

						case s_state is
							when PACKET_HDR_SIZE_STATE => 
								s_o_packet_data(191 downto 160) <= i_pixel_format;
								s_o_packet_data(159 downto 128) <= i_timestamp_slow;
								s_o_packet_data(127 downto 64) <= i_timestamp & i_frame_index;
								s_o_packet_data(63 downto 0) <= std_logic_vector(resize(unsigned(i_roi_offset_y),16)) & std_logic_vector(resize(unsigned(i_roi_offset_x),16)) & std_logic_vector(resize(unsigned(i_num_rows),16)) & std_logic_vector(resize(unsigned(i_num_cols),16));
								s_row_cnt <= (others => '0');
								s_col_cnt <= (others => '0');
								s_num_rows_min1 <= unsigned(i_num_rows)-1;
								s_num_cols_min16 <= unsigned(i_num_cols)-16;
								s_eop_sent <= '0';

								if (i_frame_sync = '1') then
									s_o_packet_data_startofpacket <= '1';
									s_o_packet_data_v <= '1';
									s_state <= PACKET_FRAME_DATA_STATE;
								end if;

							when PACKET_FRAME_DATA_STATE =>
								if (s_shift_reg(SHIFT_REG_SIZE-1)(SR_PIX_V_LOC) = '1') then
									-- We send out delayed pixel data now
									s_o_packet_data <= s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR7_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR7_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR6_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR6_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR5_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR5_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR4_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR4_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR3_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR3_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR2_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR2_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR1_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR1_EVEN_PIX_LOC) &
											   s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_ODD_PIX_LOC) & s_shift_reg(SHIFT_REG_SIZE-1)(SR_PAIR0_EVEN_PIX_LOC);
									if (s_col_cnt < s_num_cols_min16) then
										s_col_cnt <= s_col_cnt + 16;
										s_o_packet_data_v <= '1';
									else
										s_row_cnt <= s_row_cnt + 1;
										s_col_cnt <= (others => '0');
										if (s_row_cnt < s_num_rows_min1) then
											s_o_packet_data_v <= '1';
										elsif s_eop_sent = '0' then
											s_o_packet_data_endofpacket <= '1';
											s_o_packet_data_v <= '1';
											s_eop_sent <= '1';
											s_state <= PACKET_HDR_SIZE_STATE;
										end if;
									end if;						
								end if;

							when others =>
								null;

						end case;
					end if;
				end if;	
			end if;
		end process PACKET_OUTPUT_PROC_X16;
	end generate PACKET_OUTPUT_GEN_X16;

	o_packet_data <= s_o_packet_data;
	o_packet_data_startofpacket <= s_o_packet_data_startofpacket;
	o_packet_data_v <= s_o_packet_data_v;
	o_packet_data_endofpacket <= s_o_packet_data_endofpacket;

end architecture; -- of header_create

