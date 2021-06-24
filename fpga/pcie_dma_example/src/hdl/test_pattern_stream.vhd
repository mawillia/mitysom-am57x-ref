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

		o_axis_tdata : out STD_LOGIC_VECTOR(63 DOWNTO 0); 
		o_axis_tlast : out STD_LOGIC; 
		o_axis_tvalid : out STD_LOGIC;
		i_axis_tready : in STD_LOGIC;
		o_axis_tkeep : out STD_LOGIC_VECTOR(7 DOWNTO 0) 
	);
end test_pattern_stream;

architecture rtl of test_pattern_stream is

	constant VER_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(0, 6));
	constant CTRL_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1, 6));

	constant PATTERN_START_VAL_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2, 6));
	constant PATTERN_START_VAL_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(3, 6));

	constant NUM_WORDS_LO_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(4, 6));
	constant NUM_WORDS_HI_REG_OFFSET : std_logic_vector(5 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(5, 6));


	signal s_srst_reg : std_logic := '1';
	signal s_srst_meta : std_logic := '1';
	signal s_srst : std_logic := '1';

	signal s_pattern_start_val_reg : std_logic_vector(31 downto 0) := (others => '0');
	signal s_pattern_start_val_meta : std_logic_vector(31 downto 0) := (others => '0');
	signal s_pattern_start_val : std_logic_vector(31 downto 0) := (others => '0');

	signal s_num_words_reg : std_logic_vector(31 downto 0) := (others => '0');
	signal s_num_words_meta : std_logic_vector(31 downto 0) := (others => '0');
	signal s_num_words : std_logic_vector(31 downto 0) := (others => '0');

	signal s_pattern_cntr : unsigned(31 downto 0) := (others => '0');
	signal s_pattern_cntr_plus1 : unsigned(31 downto 0) := (others => '0');


	signal s_o_axis_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0) := (others => '0'); 
	signal s_o_axis_tlast : STD_LOGIC := '0';
	signal s_o_axis_tvalid : STD_LOGIC := '0';
	signal s_o_axis_tkeep : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');

begin

	REG_WRITE_PROC : process(i_reg_clk)
	begin
		if rising_edge(i_reg_clk) then
			if (i_reg_cs = '1' and i_reg_wr = '1') then
				case i_reg_addr is
					when VER_REG_OFFSET =>
						null;

					when CTRL_REG_OFFSET =>
						s_srst_reg <= i_reg_data(0);


					when PATTERN_START_VAL_LO_REG_OFFSET =>
						s_pattern_start_val_reg(15 downto 0) <= i_reg_data(15 downto 0);

					when PATTERN_START_VAL_HI_REG_OFFSET =>
						s_pattern_start_val_reg(31 downto 16) <= i_reg_data(15 downto 0);


					when NUM_WORDS_LO_REG_OFFSET =>
						s_num_words_reg(15 downto 0) <= i_reg_data(15 downto 0);

					when NUM_WORDS_HI_REG_OFFSET =>
						s_num_words_reg(31 downto 16) <= i_reg_data(15 downto 0);

						
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
						o_reg_data <= x"B1B1";

					when CTRL_REG_OFFSET =>
						o_reg_data(0) <= s_srst_reg;


					when PATTERN_START_VAL_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_pattern_start_val_reg(15 downto 0);

					when PATTERN_START_VAL_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_pattern_start_val_reg(31 downto 16);


					when NUM_WORDS_LO_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_num_words_reg(15 downto 0);

					when NUM_WORDS_HI_REG_OFFSET =>
						o_reg_data(15 downto 0) <= s_num_words_reg(31 downto 16);


					when others =>
						o_reg_data <= x"DEAD";
				end case;
			end if;
		end if;
	end process REG_READ_PROC;


	PATTERN_GEN_PROC : process(i_axi_clk)
	begin
		if rising_edge(i_axi_clk) then
			s_srst_meta <= s_srst_reg;
			s_srst <= s_srst_meta;

			s_pattern_start_val_meta <= s_pattern_start_val_reg;
			s_pattern_start_val <= s_pattern_start_val_meta;

			s_pattern_start_val_meta <= s_pattern_start_val_reg;
			s_pattern_start_val <= s_pattern_start_val_meta;

			s_o_axis_tvalid <= '0';

			if (s_srst = '1') then
				s_pattern_cntr <= UNSIGNED(s_pattern_start_val);
				s_pattern_cntr_plus1 <= UNSIGNED(s_pattern_start_val) + 1;
			else
				s_o_axis_tvalid <= '1';

				if (s_o_axis_tvalid = '1' and i_axis_tready = '1') then
					s_pattern_cntr <= s_pattern_cntr + 2;
					s_pattern_cntr_plus1 <= s_pattern_cntr_plus1 + 2;

					if (s_pattern_cntr + 2 = UNSIGNED(s_num_words)) then
						s_pattern_cntr <= UNSIGNED(s_pattern_start_val);
						s_pattern_cntr_plus1 <= UNSIGNED(s_pattern_start_val) + 1;
					end if;
				end if;
			end if;
		end if;
	end process PATTERN_GEN_PROC;

	s_o_axis_tdata(63 downto 32) <= STD_LOGIC_VECTOR(s_pattern_cntr_plus1);
	s_o_axis_tdata(31 downto 0) <= STD_LOGIC_VECTOR(s_pattern_cntr);
	s_o_axis_tlast <= '1' when (s_pattern_cntr + 2 = UNSIGNED(s_num_words))  else '0';
	s_o_axis_tkeep <= "11111111";

	o_axis_tdata <= s_o_axis_tdata;
	o_axis_tlast <= s_o_axis_tlast;
	o_axis_tvalid <= s_o_axis_tvalid;
	o_axis_tkeep <= s_o_axis_tkeep;

end rtl;

