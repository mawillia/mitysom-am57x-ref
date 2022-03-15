-- test_pattern_gen.vhd

-- This file was auto-generated as a prototype implementation of a module
-- created in component editor.  It ties off all outputs to ground and
-- ignores all inputs.  It needs to be edited to make it do something
-- useful.
-- 
-- This file will not be automatically regenerated.  You should check it in
-- to your version control system if you want to keep it.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library WORK;
use WORK.mitycam_pkg.all;
use WORK.MitySOM_AM57_pkg.all;

entity test_pattern_gen is
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
end entity test_pattern_gen;

architecture rtl of test_pattern_gen is

	constant CORE_VERSION_MAJOR:  std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 01, 4));
	constant CORE_VERSION_MINOR:  std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 00, 4));
	constant CORE_ID:             std_logic_vector(7 downto 0) := std_logic_vector( to_unsigned( 71, 8));
	constant CORE_YEAR:           std_logic_vector(4 downto 0) := std_logic_vector( to_unsigned( 22, 5));
	constant CORE_MONTH:          std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 03, 4));
	constant CORE_DAY:            std_logic_vector(4 downto 0) := std_logic_vector( to_unsigned( 03, 5));

	constant VERS_REG_OFFSET        : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(0, 6));
	constant CTRL_REG_OFFSET        : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2, 6));
	constant PORCH_REG_OFFSET_LOW   : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(4, 6));
	constant PORCH_REG_OFFSET_HIGH  : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(5, 6));
	constant ROWS_REG_OFFSET        : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(6, 6));
	constant COLS_REG_OFFSET        : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(8, 6));
	constant FRAME_CNT_REGS_OFFSET_LOW   : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(10, 6));
	constant FRAME_CNT_REGS_OFFSET_HIGH  : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(11, 6));
	constant STATIC_VAL_REGS_OFFSET_LOW  : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(12, 6));
	constant STATIC_VAL_REGS_OFFSET_HIGH : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(13, 6));
	constant LINE_PORCH_REGS_OFFSET_LOW  : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(14, 6));
	constant LINE_PORCH_REGS_OFFSET_HIGH : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(15, 6));
	constant DATA_DIV_REGS_OFFSET_LOW    : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(16, 6));
	constant DATA_DIV_REGS_OFFSET_HIGH   : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(17, 6));

	constant TP_H_GRADIENT          : std_logic_vector(2 downto 0) := "000"; -- Horizontal gradient 
	constant TP_V_GRADIENT          : std_logic_vector(2 downto 0) := "001"; -- Vertical gradient 
	constant TP_COUNT_STATIC        : std_logic_vector(2 downto 0) := "010"; -- Incrementing count for each new pixel in raster order (no reset on row boundaries). Count starts at static pixel value.
	constant TP_COUNT_FRAME_NUM     : std_logic_vector(2 downto 0) := "011"; -- Incrementing count for each new pixel in raster order (no reset on row boundaries). Count starts at frames count.
	constant TP_STATIC              : std_logic_vector(2 downto 0) := "100"; -- Use constant pixel value as pattern

	-- VERSION HISTORY

	type bus_vector is array (natural range <>) of std_logic_vector(g_bits_per_pixel -1 downto 0);

	signal s_pixel_data_out               : bus_vector(15 downto 0) := (others => (others => '0'));
	signal s_frame_index                  : unsigned(31 downto 0)                                  := (others => '0');
	signal s_timestamp                    : std_logic_vector(31 downto 0)                          := (others => '0');
	signal s_timestamp_slow               : std_logic_vector(31 downto 0)                          := (others => '0');
	signal s_pixel_format                 : std_logic_vector(31 downto 0)                          := x"010C0047"; --! 12 bit packed mono by default
	signal s_num_rows_csr                 : unsigned(13 downto 0)                                  := to_unsigned(g_number_rows, 14);
	signal s_num_rows_m                   : unsigned(13 downto 0)                                  := to_unsigned(g_number_rows, 14);
	signal s_num_rows                     : unsigned(13 downto 0)                                  := to_unsigned(g_number_rows, 14);
	signal s_num_cols_csr                 : unsigned(13 downto 0)                                  := to_unsigned(g_number_cols, 14);
	signal s_num_cols_m                   : unsigned(13 downto 0)                                  := to_unsigned(g_number_cols, 14);
	signal s_num_cols                     : unsigned(13 downto 0)                                  := to_unsigned(g_number_cols, 14);
	signal s_roi_offset_x, s_roi_offset_y : std_logic_vector(13 downto 0)                          := (others => '0');
	signal s_tp_cnt : unsigned(g_bits_per_pixel-1 downto 0) := (others => '0');

	signal s_srst_csr, s_srst_m, s_srst     : std_logic := '1';
	signal s_en_tp_csr, s_en_tp_m, s_en_tp : std_logic := '0';

	signal s_frame_sync  : std_logic := '0';
	signal s_pixel_out_v : std_logic := '0';

	signal s_passthru      : std_logic := '1';
	signal s_passthru_m    : std_logic := '1';
	signal s_passthru_dclk : std_logic := '1';

	signal s_pixel_data_out_pass               : std_logic_vector(g_packed_pixels_per_clk*g_bits_per_pixel - 1 downto 0); --  pixel_data_out.data
	signal s_pixel_data_out_valid_pass         : std_logic; --                .valid
	signal s_pixel_data_out_endofpacket_pass   : std_logic; --                .endofpacket
	signal s_pixel_data_out_startofpacket_pass : std_logic; --                .startofpacket
	signal s_pixel_data_out_test               : std_logic_vector(g_packed_pixels_per_clk*g_bits_per_pixel - 1 downto 0); --  pixel_data_out.data
	signal s_pixel_data_out_valid_test         : std_logic; --                .valid
	signal s_pixel_data_out_endofpacket_test   : std_logic; --                .endofpacket
	signal s_pixel_data_out_startofpacket_test : std_logic; --                .startofpacket

	signal s_row : unsigned(13 downto 0) := (others => '0');
	signal s_col : unsigned(13 downto 0) := (others => '0');

	type t_state is (IDLE, FRONT_PORCH_STATE, LINE_PORCH_STATE, DATA_STATE);
	signal s_tp_state      : t_state               := IDLE;
	signal s_porch_cnt     : unsigned(31 downto 0) := (others => '0');
	signal s_porch_max_csr : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(50000000, 32));
	signal s_porch_max_m   : unsigned(31 downto 0) := to_unsigned(50000000, 32);
	signal s_porch_max     : unsigned(31 downto 0) := to_unsigned(50000000, 32);
	signal s_frame_cnt, s_frame_cnt_m : unsigned(31 downto 0) := (others=>'0');
	signal s_frame_cnt_csr : std_logic_vector(31 downto 0) := (others=>'0');
	signal s_tp_type, s_tp_type_m, s_tp_type_csr : std_logic_vector(2 downto 0) := g_tp_type;
	signal s_static_val, s_static_val_m, s_static_val_csr : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(g_static_val, 32));
	signal s_line_porch, s_line_porch_m : unsigned(31 downto 0) := to_unsigned(g_line_porch, 32);
	signal s_line_porch_csr : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(g_line_porch, 32));
	signal s_line_porch_cnt : unsigned(31 downto 0) := to_unsigned(0, 32);
	signal s_data_out_div_cnt     : unsigned(31 downto 0) := (others => '0');
	signal s_data_div_max_csr : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(1, 32));
	signal s_data_div_max_m   : unsigned(31 downto 0) := to_unsigned(1, 32);
	signal s_data_div_max     : unsigned(31 downto 0) := to_unsigned(1, 32);

	signal s_version_reg : std_logic_vector(15 downto 0);
	signal s_ver_rd : std_logic := '0';

	-- attribute mark_debug : string;
	-- attribute mark_debug of o_pixel_data_out : signal is "true";
	-- attribute mark_debug of o_pixel_data_out_valid : signal is "true";
	-- attribute mark_debug of o_pixel_data_out_endofpacket : signal is "true";
	-- attribute mark_debug of o_pixel_data_out_startofpacket : signal is "true";

begin

	o_pixel_data_out               <= s_pixel_data_out_pass when s_passthru_dclk = '1' else s_pixel_data_out_test;
	o_pixel_data_out_valid         <= s_pixel_data_out_valid_pass when s_passthru_dclk = '1' else s_pixel_data_out_valid_test;
	o_pixel_data_out_endofpacket   <= s_pixel_data_out_endofpacket_pass when s_passthru_dclk = '1' else s_pixel_data_out_endofpacket_test;
	o_pixel_data_out_startofpacket <= s_pixel_data_out_startofpacket_pass when s_passthru_dclk = '1' else s_pixel_data_out_startofpacket_test;

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

	--! Process to handle register writes by the HPS.
	REG_WRITE_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			if (i_reg_wr = '1' and i_reg_cs = '1') then
				case i_reg_addr is
					when CTRL_REG_OFFSET =>
						s_srst_csr <= i_reg_data(0);
						s_en_tp_csr <= i_reg_data(1);
						s_passthru  <= i_reg_data(2);
						s_tp_type_csr <= i_reg_data(5 downto 3);

					when PORCH_REG_OFFSET_LOW =>
						s_porch_max_csr(15 downto 0) <= i_reg_data;
					when PORCH_REG_OFFSET_HIGH =>
						s_porch_max_csr(31 downto 16) <= i_reg_data;

					when ROWS_REG_OFFSET =>
						s_num_rows_csr <= unsigned(i_reg_data(13 downto 0));
					when COLS_REG_OFFSET =>
						s_num_cols_csr <= unsigned(i_reg_data(13 downto 0));

					when STATIC_VAL_REGS_OFFSET_LOW =>
						s_static_val_csr(15 downto 0) <= i_reg_data;
					when STATIC_VAL_REGS_OFFSET_HIGH =>
						s_static_val_csr(31 downto 16) <= i_reg_data;

					when LINE_PORCH_REGS_OFFSET_LOW =>
						s_line_porch_csr(15 downto 0) <= i_reg_data;
					when LINE_PORCH_REGS_OFFSET_HIGH =>
						s_line_porch_csr(31 downto 16) <= i_reg_data;

					when DATA_DIV_REGS_OFFSET_LOW =>
						s_data_div_max_csr(15 downto 0) <= i_reg_data;
					when DATA_DIV_REGS_OFFSET_HIGH =>
						s_data_div_max_csr(31 downto 16) <= i_reg_data;

					when others =>
						null;
				end case;
			end if;
		end if;
	end process REG_WRITE_PROC;

	--! Process to handle register reads by the HPS.
	REG_READ_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			o_reg_data <= (others => '0');
			s_frame_cnt_m <= s_frame_cnt;
			s_frame_cnt_csr <= std_logic_vector(s_frame_cnt_m);
			s_ver_rd <= '0';

			if (i_reg_cs = '1') then
				case i_reg_addr is
					when VERS_REG_OFFSET =>
						o_reg_data <= s_version_reg;
						s_ver_rd <= i_reg_rd;

					when CTRL_REG_OFFSET =>
						o_reg_data(0) <= s_srst_csr;
						o_reg_data(1) <= s_en_tp_csr;
						o_reg_data(2) <= s_passthru;
						o_reg_data(5 downto 3) <= s_tp_type_csr;

					when PORCH_REG_OFFSET_LOW =>
						o_reg_data <= s_porch_max_csr(15 downto 0);
					when PORCH_REG_OFFSET_HIGH =>
						o_reg_data <= s_porch_max_csr(31 downto 16);

					when ROWS_REG_OFFSET =>
						o_reg_data(13 downto 0) <= std_logic_vector(s_num_rows_csr);
					when COLS_REG_OFFSET =>
						o_reg_data(13 downto 0) <= std_logic_vector(s_num_cols_csr);
					
					when FRAME_CNT_REGS_OFFSET_LOW =>
						o_reg_data <= s_frame_cnt_csr(15 downto 0);
					when FRAME_CNT_REGS_OFFSET_HIGH =>
						o_reg_data <= s_frame_cnt_csr(31 downto 16);
					
					when STATIC_VAL_REGS_OFFSET_LOW =>
						o_reg_data <= s_static_val_csr(15 downto 0);
					when STATIC_VAL_REGS_OFFSET_HIGH =>
						o_reg_data <= s_static_val_csr(31 downto 16);
					
					when LINE_PORCH_REGS_OFFSET_LOW =>
						o_reg_data <= s_line_porch_csr(15 downto 0);
					when LINE_PORCH_REGS_OFFSET_HIGH =>
						o_reg_data <= s_line_porch_csr(31 downto 16);

					when DATA_DIV_REGS_OFFSET_LOW =>
						o_reg_data <= s_data_div_max_csr(15 downto 0);
					when DATA_DIV_REGS_OFFSET_HIGH =>
						o_reg_data <= s_data_div_max_csr(31 downto 16);

					when others => NULL;
				end case;
			end if;
		end if;
	end process REG_READ_PROC;

	debug_proc: process(i_data_clk)
	begin
		if s_srst = '1' then
			s_frame_cnt <= (others=>'0');
		elsif rising_edge(i_data_clk) then
			if (s_frame_sync = '1' and s_passthru_dclk = '0') 
		   		or (s_pixel_data_out_startofpacket_pass = '1' and s_passthru_dclk = '1')	then
				s_frame_cnt <= s_frame_cnt + 1;
			end if;
		end if;
	end process;

	test_gen_proc : process(i_data_clk)
	begin
		if rising_edge(i_data_clk) then
			-- Register inputs, incease pass thru mode is activated
			s_passthru_m                        <= s_passthru;
			s_passthru_dclk                     <= s_passthru_m;
			s_pixel_data_out_pass               <= i_pixel_data_in;
			s_pixel_data_out_valid_pass         <= i_pixel_data_in_valid;
			s_pixel_data_out_endofpacket_pass   <= i_pixel_data_in_endofpacket;
			s_pixel_data_out_startofpacket_pass <= i_pixel_data_in_startofpacket;

			-- clock cross from csr
			s_en_tp_m     <= s_en_tp_csr;
			s_en_tp       <= s_en_tp_m;
			s_porch_max_m <= unsigned(s_porch_max_csr);
			s_porch_max   <= s_porch_max_m;
			s_num_rows_m  <= s_num_rows_csr;
			s_num_rows    <= s_num_rows_m;
			s_num_cols_m  <= s_num_cols_csr;
			s_num_cols    <= s_num_cols_m;
			s_srst_m <= s_srst_csr;
			s_srst <= s_srst_m;
			s_tp_type_m <= s_tp_type_csr;
			s_tp_type <= s_tp_type_m;
			s_static_val_m <= s_static_val_csr;
			s_static_val <= s_static_val_m;
			s_line_porch_m <= unsigned(s_line_porch_csr);
			s_line_porch <= s_line_porch_m;
			s_data_div_max_m <= unsigned(s_data_div_max_csr);
			s_data_div_max <= s_data_div_max_m;

			s_frame_sync  <= '0';
			s_pixel_out_v <= '0';
			case s_tp_state is
				when IDLE =>
					if s_en_tp = '1' then
						s_tp_state  <= FRONT_PORCH_STATE;
						s_porch_cnt <= (others => '0');
					end if;
				when FRONT_PORCH_STATE =>
					if s_porch_cnt < s_porch_max then
						s_porch_cnt <= s_porch_cnt + 1;
					else
						s_tp_state <= DATA_STATE;
						s_frame_sync  <= '1';
						s_data_out_div_cnt <= (others=>'0');
					end if;
				when DATA_STATE =>
					if s_data_out_div_cnt >= s_data_div_max then
						s_data_out_div_cnt <= (others=>'0');
						s_pixel_out_v <= '1';
						for pix in 0 to g_packed_pixels_per_clk-1 loop
							case s_tp_type is
								when TP_H_GRADIENT =>
									s_pixel_data_out(pix) <= std_logic_vector(resize(s_col + TO_UNSIGNED(pix, 12), g_bits_per_pixel));

								when TP_V_GRADIENT =>
									s_pixel_data_out(pix) <= std_logic_vector(resize(s_row, g_bits_per_pixel));
								when TP_COUNT_STATIC =>
									s_pixel_data_out(pix) <= std_logic_vector(resize(s_tp_cnt + TO_UNSIGNED(pix, 14), g_bits_per_pixel));
								when TP_COUNT_FRAME_NUM =>
									s_pixel_data_out(pix) <= std_logic_vector(resize(s_tp_cnt + TO_UNSIGNED(pix, 14), g_bits_per_pixel));
								when TP_STATIC => 
									s_pixel_data_out(pix) <= s_static_val(s_pixel_data_out(pix)'length-1 downto 0);
								when others =>
									s_pixel_data_out(pix) <= (others => '0');
									s_pixel_data_out(pix)(15 downto 0) <= x"DEAD";
							end case;
						end loop;
						s_tp_cnt <= s_tp_cnt + g_packed_pixels_per_clk;
						s_col <= s_col + g_packed_pixels_per_clk;
						if s_col = s_num_cols - g_packed_pixels_per_clk then
							-- End of a row, move on to the line porch state
							s_col <= (others => '0');
							s_line_porch_cnt <= (others=>'0');
							s_tp_state <= LINE_PORCH_STATE;
						end if;
					else
						s_data_out_div_cnt <= s_data_out_div_cnt + 1;
					end if;
				when LINE_PORCH_STATE =>
					if s_line_porch_cnt < s_line_porch then
						s_line_porch_cnt <= s_line_porch_cnt + 1;
					else
						-- End of line porch, go to idle or back to data state
						s_row <= s_row + 1;
						s_line_porch_cnt <= (others=>'0');
						if s_row = s_num_rows - 1 then
							s_row         <= (others => '0');
							s_frame_index <= s_frame_index + 1;
							if (s_tp_type = TP_COUNT_FRAME_NUM) then
								s_tp_cnt <= s_frame_index(s_tp_cnt'length-1 downto 0);
							else
								s_tp_cnt <= UNSIGNED(s_static_val(s_tp_cnt'length-1 downto 0));
							end if;
							s_tp_state <= IDLE;
						else
							s_tp_state <= DATA_STATE;
						end if;
					end if;
			end case;
		end if;
	end process;

	--! Pack the frame data properly so we play nice with other units.
	HEADER_CREATE_INST : header_create
		generic map(
			g_pixels_per_clk => g_packed_pixels_per_clk,
			g_bits_per_pixel => g_bits_per_pixel,
			g_dim_size_bits  => 14
		)
		port map(
			i_clk                       => i_data_clk,
			i_srst                      => s_srst,
			i_num_cols                  => std_logic_vector(s_num_cols),
			i_num_rows                  => std_logic_vector(s_num_rows),
			i_roi_offset_x              => s_roi_offset_x,
			i_roi_offset_y              => s_roi_offset_y,
			i_frame_index               => std_logic_vector(s_frame_index),
			i_timestamp                 => s_timestamp,
			i_timestamp_slow            => s_timestamp_slow,
			i_frame_sync                => s_frame_sync,
			i_ready                     => '1', -- No back pressure support.

			i_pair0_even_pixel          => s_pixel_data_out(0),
			i_pair0_odd_pixel           => s_pixel_data_out(1),
			i_pair1_even_pixel          => s_pixel_data_out(2),
			i_pair1_odd_pixel           => s_pixel_data_out(3),
			i_pair2_even_pixel          => s_pixel_data_out(4),
			i_pair2_odd_pixel           => s_pixel_data_out(5),
			i_pair3_even_pixel          => s_pixel_data_out(6),
			i_pair3_odd_pixel           => s_pixel_data_out(7),
			i_pair4_even_pixel          => s_pixel_data_out(8),
			i_pair4_odd_pixel           => s_pixel_data_out(9),
			i_pair5_even_pixel          => s_pixel_data_out(10),
			i_pair5_odd_pixel           => s_pixel_data_out(11),
			i_pair6_even_pixel          => s_pixel_data_out(12),
			i_pair6_odd_pixel           => s_pixel_data_out(13),
			i_pair7_even_pixel          => s_pixel_data_out(14),
			i_pair7_odd_pixel           => s_pixel_data_out(15),
			i_pixel_v                   => s_pixel_out_v,
			o_packet_data               => s_pixel_data_out_test,
			o_packet_data_startofpacket => s_pixel_data_out_startofpacket_test,
			o_packet_data_v             => s_pixel_data_out_valid_test,
			o_packet_data_endofpacket   => s_pixel_data_out_endofpacket_test
		);

end architecture rtl;
