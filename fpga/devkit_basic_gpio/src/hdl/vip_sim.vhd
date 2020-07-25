--- Title: vip_sim.vhd
--- Description: Simulates a simple RGB colorbar pattern at 1920 x 1080p
---              with 24 bit RGB and embedded SYNCs for the AM57x. This is
---              strictly following the ITU-R BT.1120-9 spec for sync codes and
---              line timing.  The goal of this code is to test and demonstrate
---              the MitySOM-AM57x / FPGA PORT A 24 bit VIP.
---
---     o  0
---     | /       Copyright (c) 2020
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.
--- Date: 7/13/2020
--- Version: 1.00
--- Revisions: 
---   1.00 - Initial release.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;
use WORK.MitySOM_AM57_pkg.ALL;

-- for ODDR primitive
Library UNISIM;
use UNISIM.vcomponents.all;

entity vip_sim is
	generic (
		H_PORCH_ADJ  : integer := 0;
		V_PORCH_ADJ  : integer := 0
	);
	port (
		i_clk         : in std_logic; -- reference clock, 148.5 MHz for 60 Hz timing with no adjustments
		-- VIN4A interface (MUST USE EMBEDDED SYNC MODES)
		o_vin_d       : out std_logic_vector(23 downto 0);
		o_vin_clk     : out std_logic
	);
end entity vip_sim;

architecture rtl of vip_sim is

	constant   OUT_WIDTH     : integer   := 1920;
	constant   OUT_HEIGHT    : integer   := 1080;
	constant   H_PORCH       : integer   := 280 + H_PORCH_ADJ;
	constant   LINE_WIDTH    : integer   := OUT_WIDTH + H_PORCH;
	constant   V_PORCH_FRONT : integer   := 40 + V_PORCH_ADJ;
	constant   v_PORCH_BACK  : integer   := 4;

	signal s_data        : std_logic_vector(23 downto 0)  := x"000000";
	signal s_line_cnt    : unsigned(11 downto 0)          := x"001";
	signal s_col_cnt     : unsigned(11 downto 0)          := x"001";
	signal s_video_col   : unsigned(11 downto 0)          := x"001";     -- counts the pixels within a color bar
	signal s_SAV         : std_logic_vector(7 downto 0)   := x"AB";      -- H=0, V=1, H=0 plus protection bits
	signal s_EAV         : std_logic_vector(7 downto 0)   := x"B6";      -- H=0, V=1, H=1 plus protection bits

	type color_rom is array(0 to 7) of std_logic_vector(7 downto 0);
	-- SMTPE 100% white, yellow, cyan, green, Magenta, red, blue, black 
	signal s_rom_r : color_rom := (0 => x"EB", 1 => x"EB", 2 => x"10", 3 => x"10",
	                               4 => x"EB", 5 => x"EB", 6 => x"10", 7 => x"10");
	signal s_rom_g : color_rom := (0 => x"EB", 1 => x"EB", 2 => x"EB", 3 => x"EB",
	                               4 => x"10", 5 => x"10", 6 => x"10", 7 => x"10");
	signal s_rom_b : color_rom := (0 => x"EB", 1 => x"10", 2 => x"EB", 3 => x"10",
								   4 => x"EB", 5 => x"10", 6 => x"EB", 7 => x"10");
	signal s_color_lookup : unsigned(2 downto 0) := "000";

	type line_state is (VBLANK_FRONT, ACTIVE, VBLANK_BACK);
	signal s_line_state : line_state := VBLANK_FRONT;

begin

	-- use DDR IO blocks to control output timing and clock edge, etc.

	gen_data_ddr : for i in 0 to 23 generate
	begin
		data_ddr : ODDR
			generic map(
				DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
				INIT         => '0', -- Initial value for Q port ('1' or '0')
				SRTYPE       => "SYNC" ) -- Reset Type ("ASYNC" or "SYNC")
			port map (
				Q   => o_vin_d(i), -- 1-bit DDR output
				C   => i_clk,  -- 1-bit clock input
				CE  => '1', -- 1-bit clock enable input
				D1  => s_data(i), -- 1-bit data input (positive edge)
				D2  => s_data(i), -- 1-bit data input (negative edge)
				R   => '0', -- 1-bit reset input
				S   => '0'  -- 1-bit set input
			);
	end generate gen_data_ddr;

	clock_ddr : ODDR
	generic map(
		DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
		INIT         => '0', -- Initial value for Q port ('1' or '0')
		SRTYPE       => "SYNC" ) -- Reset Type ("ASYNC" or "SYNC")
	port map (
		Q   => o_vin_clk, -- 1-bit DDR output
		C   => i_clk,  -- 1-bit clock input
		CE  => '1', -- 1-bit clock enable input
		D1  => '0', -- 1-bit data input (positive edge)
		D2  => '1', -- 1-bit data input (negative edge)
		R   => '0', -- 1-bit reset input
		S   => '0'  -- 1-bit set input
	);

	-- just run the timing continuously
	drive_timing : process(i_clk)
	begin
		if rising_edge(i_clk) then
			-- line/row and column counters
			if s_col_cnt = LINE_WIDTH then 
				s_col_cnt <= to_unsigned(1, s_col_cnt'length);
				-- new line logic
				if s_line_cnt = OUT_HEIGHT + V_PORCH_FRONT + V_PORCH_BACK then
					s_line_cnt <= to_unsigned(1, s_line_cnt'length);
				else
					s_line_cnt <= s_line_cnt + 1;
				end if;
			else
				s_col_cnt <= s_col_cnt + 1;
			end if;

			-- color lookup counter
			if s_col_cnt <= H_PORCH then
				s_color_lookup <= to_unsigned(0, s_color_lookup'length);
				s_video_col <= to_unsigned(1, s_video_col'length);
			elsif s_video_col = OUT_WIDTH/8 then
				s_color_lookup <= s_color_lookup + 1;
				s_video_col <= to_unsigned(1, s_video_col'length);
			else
				s_video_col <= s_video_col + 1;
			end if;


			case s_line_state is
				when VBLANK_FRONT =>
					if s_line_cnt = V_PORCH_FRONT then
						s_line_state <= ACTIVE;
						s_SAV <= x"80"; -- H=0, V=0, H=0 plus protection bits
						s_EAV <= x"9D"; -- F=1, V=0, H=1 plus protection bits
					end if;
				when ACTIVE =>
					if s_line_cnt = V_PORCH_FRONT + OUT_HEIGHT then
						s_SAV <= x"AB"; -- H=0, V=1, H=0 plus protection bits
						s_EAV <= x"B6"; -- H=0, V=1, H=1 plus protection bits
						s_line_state <= VBLANK_BACK;
					end if;
				when VBLANK_BACK =>
					if s_line_cnt = V_PORCH_FRONT + OUT_HEIGHT + V_PORCH_BACK then
						s_line_state <= VBLANK_FRONT;
						s_SAV <= x"AB"; -- H=0, V=1, H=0 plus protection bits
						s_EAV <= x"B6"; -- H=0, V=1, H=1 plus protection bits
					end if;
				when others =>
						s_SAV <= x"AB"; -- H=0, V=1, H=0 plus protection bits
						s_EAV <= x"B6"; -- H=0, V=1, H=1 plus protection bits
						s_line_state <= VBLANK_FRONT;
			end case;

			-- generate codes
			-- First word in SAV or EAV SYNC CODE
			if s_col_cnt = 1 or s_col_cnt = (H_PORCH-3) then
				s_data <= x"FF" & x"FF" & x"FF";
			-- Second word in SAV or EAV SYNC CODE
			elsif s_col_cnt = 2 or s_col_cnt = (H_PORCH-2) then
				s_data <= x"00" & x"00" & x"00";
			-- Third word in SAV or EAV SYNC CODE
			elsif s_col_cnt = 3 or s_col_cnt = (H_PORCH-1) then 
				s_data <= x"00" & x"00" & x"00";
			-- Fourth word in EAV SYNC CODE
			elsif s_col_cnt = 4 then
				s_data <= s_EAV & s_EAV & s_EAV;
			-- Fourth word in SAV SYNC CODE
			elsif s_col_cnt = (H_PORCH-0) then
				s_data <= s_SAV & s_SAV & s_SAV;
			-- Blanking data
			elsif s_col_cnt < H_PORCH then
				s_data <= x"01" & x"01" & x"01";
			-- video data
			else
				s_data <= s_rom_r(to_integer(s_color_lookup)) & s_rom_g(to_integer(s_color_lookup)) & s_rom_b(to_integer(s_color_lookup));
			end if;
		end if;
	end process drive_timing;

end architecture rtl;