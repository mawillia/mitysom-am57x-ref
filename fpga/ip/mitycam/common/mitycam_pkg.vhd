--- Title: mitycam_pkg.vhd
---
---
---     o  0
---     | /       Copyright (c) 2014
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.
library IEEE;
use IEEE.STD_LOGIC_1164.all;

package mitycam_pkg is

	--! Unit to decode received frame headers. 
	--! Note this is a simple unit. If there are errors they will be caught by the 
	--!  header_decode unit.
	component header_create is
		generic
		(
			g_bits_per_pixel : natural := 16;
			g_dim_size_bits : natural := 12;
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
	end component header_create;

	--! Unit to decode received frame headers. 
	component header_decode is
		generic
		(
			g_bits_per_pixel : natural := 16;
			g_dim_size_bits : natural := 12;
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
			o_pair0_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair1_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair1_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair2_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair2_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair3_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair3_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair4_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair4_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair5_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair5_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair6_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair6_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair7_even_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pair7_odd_pixel : out std_logic_vector(g_bits_per_pixel-1 downto 0); --! See Documentation for details.
			o_pixel_v : out std_logic --! Tells when output data is valid.
		);
	end component header_decode;

	component stream_to_pcie is
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
	end component;

	component test_pattern_gen is
		generic(
			g_packed_pixels_per_clk        : natural := 16;
			g_bits_per_pixel               : natural := 16;
			g_number_rows                  : natural := 2048;
			g_number_cols                  : natural := 2048;
			g_tp_type                      : std_logic_vector(2 downto 0) := "000";
			g_static_val                   : natural := 0;
			g_line_porch                   : natural := 10
		);
		port(
			i_reg_clk : in  std_logic;
	
			i_reg_addr : in  std_logic_vector(5 downto 0);
			i_reg_data : in  std_logic_vector(15 downto 0);
			o_reg_data : out std_logic_vector(15 downto 0);
			i_reg_wr   : in  std_logic;
			i_reg_rd   : in  std_logic;
			i_reg_cs   : in  std_logic;
	
			o_irq      : out std_logic := '0';
			i_ilevel   : in  std_logic := '0';      
			i_ivector  : in  std_logic_vector(4 downto 0) := "00000";   
	
			i_pixel_data_in                : in  std_logic_vector(g_packed_pixels_per_clk*g_bits_per_pixel - 1 downto 0) := (others => '0'); --   pixel_data_in.data
			i_pixel_data_in_valid          : in  std_logic                                                               := '0'; --                .valid
			i_pixel_data_in_endofpacket    : in  std_logic                                                               := '0'; --                .endofpacket
			i_pixel_data_in_startofpacket  : in  std_logic                                                               := '0'; --                .startofpacket
	
			o_pixel_data_out               : out std_logic_vector(g_packed_pixels_per_clk*g_bits_per_pixel - 1 downto 0); --  pixel_data_out.data
			o_pixel_data_out_valid         : out std_logic; --                .valid
			o_pixel_data_out_endofpacket   : out std_logic; --                .endofpacket
			o_pixel_data_out_startofpacket : out std_logic; --                .startofpacket
	
			i_data_clk                     : in  std_logic
		);
	end component;

end mitycam_pkg;
