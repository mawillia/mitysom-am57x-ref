--- Title: gpio.vhd
--- Description: 
---
---     o  0
---     | /       Copyright (c) 2010
---    (CL)---o   Critical Link, LLC
---      \
---       O
---
--- Company: Critical Link, LLC.
--- Date: 11/11/2010
--- Version: 1.01
--- Revisions: 
---   1.00 - Initial release.
---   1.01 - Connected interrupt output signal and fixed a bug with version reads.
---   1.02 - Rework interrupt logic
---   1.03 - Total rewrite for efficiency....

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library work;
use work.MitySOM_AM57_pkg.all;

entity gpio is
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
end gpio;

architecture rtl of gpio is

constant CORE_VERSION_MAJOR:  std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 01, 4));
constant CORE_VERSION_MINOR:  std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 03, 4));
constant CORE_ID:             std_logic_vector(7 downto 0) := std_logic_vector( to_unsigned( 04, 8));
constant CORE_YEAR:           std_logic_vector(4 downto 0) := std_logic_vector( to_unsigned( 11, 5));
constant CORE_MONTH:          std_logic_vector(3 downto 0) := std_logic_vector( to_unsigned( 06, 4));
constant CORE_DAY:            std_logic_vector(4 downto 0) := std_logic_vector( to_unsigned( 08, 5));

constant BANK_OFFSET : integer := 2;
constant BANK_SIZE   : integer := 5;
constant IOVAL_OFFSET: integer := 0;
constant IODIR_OFFSET: integer := 1;
constant IRE_OFFSET  : integer := 2;
constant IFE_OFFSET  : integer := 3;
constant IP_OFFSET   : integer := 4;

signal version_reg : std_logic_vector(15 downto 0);
signal ver_rd      : std_logic;

signal ind_m  : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal ind    : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal ind_r1 : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal outd   : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := i_initoutval;
signal ire    : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal ip     : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal ic     : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal ife    : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := (others=>'0');
signal dir    : std_logic_vector(NUM_BANKS*NUM_IO_PER_BANK-1 downto 0) := i_initdir;

begin

version : core_version
   port map(
      clk           => clk,                  -- system clock
      rd            => ver_rd,               -- read enable
      ID            => CORE_ID,              -- assigned ID number, 0xFF if unassigned
      version_major => CORE_VERSION_MAJOR,   -- major version number 1-15
      version_minor => CORE_VERSION_MINOR,   -- minor version number 0-15
      year          => CORE_YEAR,            -- year since 2000
      month         => CORE_MONTH,           -- month (1-12)
      day           => CORE_DAY,             -- day (1-31)
      ilevel        => i_ilevel,
      ivector       => i_ivector,
      o_data        => version_reg
      );

interrupt_gen : for i in 0 to NUM_BANKS*NUM_IO_PER_BANK-1 generate
begin

process(clk) 
begin
    if rising_edge(clk) then    
        -- meta stable the I/O and then latch for edge detection.
        ind_m(i)  <= i_io(i);
        ind(i)    <= ind_m(i);
        ind_r1(i) <= ind(i);
        if ic(i)='1' then
           ip(i) <= '0';
        elsif (ind(i)='1' and ind_r1(i)='0' and ire(i)='1') or
              (ind(i)='0' and ind_r1(i)='1' and ife(i)='1') then
           ip(i) <= '1';
        end if;
    end if;
end process;

end generate interrupt_gen;

o_irq <= '0' when ip = std_logic_vector(to_unsigned(0, NUM_BANKS*NUM_IO_PER_BANK)) else '1';

reg_read : process(clk)
begin
   if rising_edge(clk) then

       ver_rd <= '0';

       if i_cs='1' then
           case i_ABus is
           
           when "000000" =>
               o_DBus <= version_reg;
               ver_rd <= i_rd_en;
           
           when "000001" =>
               o_DBus <= x"0" & std_logic_vector(to_unsigned(NUM_BANKS,4)) & std_logic_vector(to_unsigned(NUM_IO_PER_BANK,8));
               
           when "000010" =>
               o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ind(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK);
           when "000011" =>
               o_DBus(NUM_IO_PER_BANK-1 downto 0) <= dir(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK);
           when "000100" =>
               o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ire(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK);
           when "000101" =>
               o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ife(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK);
           when "000110" =>
               o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ip(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK);
               
           -- TODO - this block fails to simulate using ghdl.  It will compile, but we get a bounds exception
           --        if NUM_BANKS = 1.
           when "000111" =>
               if NUM_BANKS > 1 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ind(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK);
               end if;
           when "001000" =>
               if NUM_BANKS > 1 then
                  o_DBus(NUM_IO_PER_BANK-1 downto 0) <= dir(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK);
               end if;
           when "001001" =>
               if NUM_BANKS > 1 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ire(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK);
               end if;
           when "001010" =>
               if NUM_BANKS > 1 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ife(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK);
               end if;
           when "001011" =>
               if NUM_BANKS > 1 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ip(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK);
               end if;

           when "001100" =>
               if NUM_BANKS > 2 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ind(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK);
               end if;
           when "001101" =>
               if NUM_BANKS > 2 then
                  o_DBus(NUM_IO_PER_BANK-1 downto 0) <= dir(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK);
               end if;
           when "001110" =>
               if NUM_BANKS > 2 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ire(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK);
               end if;
           when "001111" =>
               if NUM_BANKS > 2 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ife(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK);
               end if;
           when "010000" =>
               if NUM_BANKS > 2 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ip(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK);
               end if;

           when "010001" =>
               if NUM_BANKS > 3 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ind(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK);
               end if;
           when "010010" =>
               if NUM_BANKS > 3 then
                  o_DBus(NUM_IO_PER_BANK-1 downto 0) <= dir(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK);
               end if;
           when "010011" =>
               if NUM_BANKS > 3 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ire(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK);
               end if;
           when "010100" =>
               if NUM_BANKS > 3 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ife(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK);
               end if;
           when "010101" =>
               if NUM_BANKS > 3 then
                   o_DBus(NUM_IO_PER_BANK-1 downto 0) <= ip(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK);
               end if;
           
           when others => NULL;
           
           end case;
       else
           o_DBus <= (others=>'0');
       end if;   
   end if;
end process reg_read;

reg_write : process(clk, i_initdir, i_initoutval)
begin
   if rising_edge(clk) then
      
       if i_cs='1' and i_wr_en='1' then
           case i_ABus is
           
           when "000010" =>
               outd(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
           when "000011" =>
               dir(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
           when "000100" =>
               ire(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
           when "000101" =>
               ife(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
           when "000110" =>
               ic(1*NUM_IO_PER_BANK-1 downto (1-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);

           when "000111" =>
               if NUM_BANKS > 1 then
                   outd(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001000" =>
               if NUM_BANKS > 1 then
                   dir(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001001" =>
               if NUM_BANKS > 1 then
                   ire(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001010" =>
               if NUM_BANKS > 1 then
                   ife(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001011" =>
               if NUM_BANKS > 1 then
                   ic(2*NUM_IO_PER_BANK-1 downto (2-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 

           when "001100"  =>
               if NUM_BANKS > 2 then
                   outd(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001101" =>
               if NUM_BANKS > 2 then
                   dir(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001110" =>
               if NUM_BANKS > 2 then
                   ire(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "001111" =>
               if NUM_BANKS > 2 then
                   ife(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "010000" =>
               if NUM_BANKS > 2 then
                   ic(3*NUM_IO_PER_BANK-1 downto (3-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 

           when "010001" =>
               if NUM_BANKS > 3 then
                   outd(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "010010" =>
               if NUM_BANKS > 3 then
                   dir(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "010011" =>
               if NUM_BANKS > 3 then
                   ire(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "010100" =>
               if NUM_BANKS > 3 then
                   ife(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
           when "010101" =>
               if NUM_BANKS > 3 then
                   ic(4*NUM_IO_PER_BANK-1 downto (4-1)*NUM_IO_PER_BANK) <= i_DBus(NUM_IO_PER_BANK-1 downto 0);
               end if; 
                         
           when others=>NULL;
           
           end case;
       elsif i_wr_en='0' then
           ic <= (others=>'0');
       end if;   
   end if;
end process reg_write;      

o_io <= outd;
t_io <= not dir;

end rtl;
