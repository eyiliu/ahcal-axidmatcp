----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/14/2016 10:03:37 AM
-- Design Name: 
-- Module Name: saxi_generator_counter - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;

use ieee.math_real.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity saxi_generator_counter is
   generic (
      AXI_WIDTH : integer := 8                         --number of bytes in the axi stream.
    --must be of the power of 2!
    --valid: 1,2,4,8,16
      );
   port (
      clk          : in std_logic;
      srst         : in std_logic;
      control_run  : in std_logic;                     -- generates the data when '1', otherwise waits
      control_size : in std_logic_vector(3 downto 0);  -- packet size: 256bytes * 2^size
                                                       -- '1111'=>8MB, '1110'=>4MB, '1100'=>1MB
                                                       -- '1000'=>64kB, '0100'=>4kB, '0010'=>1kB, '0001'=>512bytes,
                                                       -- '0000' = >split packet into random <4kB packets.

      AXIS_tdata  : out std_logic_vector (AXI_WIDTH*8-1 downto 0);
      AXIS_tkeep  : out std_logic_vector (AXI_WIDTH-1 downto 0);
      AXIS_tlast  : out std_logic;
      AXIS_tready : in  std_logic;
      AXIS_tvalid : out std_logic

      );
end saxi_generator_counter;

architecture rtl of saxi_generator_counter is
   --constant subparts     : integer := (AXI_WIDTH-1) / 4 + 1;                                          --number of subparts of 32bits
   --constant cnt_log2     : integer := integer(floor(log2(real(i))));                                  --log2 of the axiwidth
   --constant cnt_subindex : integer := integer(realmax(real(0.0), floor(log2(real(i))) - real(2.0)));  --log2 of splitting factor
   --constant cnt_size     : integer := integer(real(8) * (real(2.0)**RealMin(2.0, real(integer(floor(log2(real(AXI_WIDTH-1))))))));

   signal vector_cnt : std_logic_vector(31 downto 0) := (others => '0');
   signal data       : std_logic_vector(AXI_WIDTH*8-1 downto 0);
--   signal data_reg   : std_logic_vector((AXI_WIDTH)*8-1 downto 0);

   signal length_cnt          : unsigned(22 downto 0);  --bookkeeping of how much data was sent in the burst (23 bits are maximum
   signal length_random_limit : unsigned(11 downto 0);  --pseudorandom length limit for small packet generation (12-bit)

   signal generate_new_vector : std_logic;  --conditions are OK for creating a new test vector
   signal last_reached        : std_logic;  --the length of the data burst reached the limit
   signal length_clear        : std_logic;  --conditions are ok for setting a new burst length
begin
   vector_cnt_proc : process(clk)
   begin
      if rising_edge(clk) then
         if (srst = '1') then
            vector_cnt <= (others => '0');
         else
            if (generate_new_vector = '1') then
               vector_cnt <= std_logic_vector(unsigned(vector_cnt) + 1);
            else
               vector_cnt <= vector_cnt;
            end if;
         end if;  --reset
      end if;  --clk
   end process;

   generate_new_vector <= AXIS_tready and control_run;
   length_clear        <= last_reached and AXIS_tready and control_run;

   length_cnt_proc : process(clk)
   begin
      if rising_edge(clk) then
         if (srst = '1') or (length_clear = '1') then
            length_cnt <= to_unsigned(AXI_WIDTH, length_cnt'length);
         else
            if (generate_new_vector = '1') then
               length_cnt <= length_cnt + AXI_WIDTH;
            end if;
         end if;  --srst
      end if;  --clk
   end process;

   last_reached_proc : process(control_size, length_cnt, length_random_limit)
      variable comparison : std_logic_vector(15 downto 0) := (others => '0');
   begin
      for i in 15 downto 1 loop
         comparison(i) := length_cnt(length_cnt'high - 15 + i);
      --if (length_cnt = (length_cnt'high downto length_cnt'high-i+1 => '0', length_cnt'high-i downto 0 => '1')) then
      --   comparison(i) := '1';
      --else
      --   comparison(i) := '0';
      --end if;
      end loop;
      if (length_cnt(length_random_limit'high+1 downto 0) >= unsigned("0"&length_random_limit)) then
         comparison(0) := '1';
      else
         comparison(0) := '0';
      end if;
      last_reached <= comparison(to_integer(unsigned(control_size)));
   end process;

   length_random_generator : process(clk)   --pseudorandom LSFR generator
   begin
      if rising_edge(clk) then
         if ((srst = '1') or (length_random_limit = (length_random_limit'high downto 0 => '0'))) then
            length_random_limit <= X"CA0";  --don't start with 1, it creates troubles with tlast directly with first tdata vector.
                                            -- (length_random_limit'high downto 1 => '0', 0 => '1');
         else
            if (length_clear = '1') then
                                            --implementation of galios LSFR for 12 bits: x^12+x^11+x^8+x^6
               if (length_random_limit(0) = '1') then
                  length_random_limit(length_random_limit'high downto 0) <= ('0' & length_random_limit(length_random_limit'high downto 1)) xor "110010100000";
               else
                  length_random_limit(length_random_limit'high downto 0) <= '0' & length_random_limit(length_random_limit'high downto 1);
               end if;
            end if;  --length clear
         end if;  --reset
      end if;  --clk
   end process;

   cnt_1_gen : if AXI_WIDTH = 1 generate
      data(7 downto 0) <= vector_cnt(7 downto 0);
   end generate;
   cnt_2_gen : if AXI_WIDTH = 2 generate
      data(15 downto 0) <= vector_cnt(15 downto 0);
   end generate;
   cnt_4_gen : if AXI_WIDTH = 4 generate
      data(31 downto 0) <= vector_cnt(31 downto 0);
   end generate;
   cnt_8_gen : if AXI_WIDTH = 8 generate
      data(31 downto 1)  <= vector_cnt(30 downto 0);
      data(63 downto 33) <= vector_cnt(30 downto 0);
      data(0)            <= '0';
      data(32)           <= '1';
   end generate;
   cnt_16_gen : if AXI_WIDTH = 16 generate
      data(31 downto 2)   <= vector_cnt(29 downto 0);
      data(63 downto 34)  <= vector_cnt(29 downto 0);
      data(95 downto 66)  <= vector_cnt(29 downto 0);
      data(127 downto 98) <= vector_cnt(29 downto 0);
      data(1 downto 0)    <= "00";
      data(33 downto 32)  <= "01";
      data(65 downto 64)  <= "10";
      data(97 downto 96)  <= "11";
   end generate;


   AXIS_tdata  <= data;
   AXIS_tkeep  <= (others => '1');
   AXIS_tlast  <= last_reached and control_run;
   AXIS_tvalid <= control_run;
        
--   AXIS_proc : process(clk)
--   begin
--      if rising_edge(clk) then
--         if (control_run = '1') then
--            if (AXIS_tready = '1') then
--               AXIS_tdata  <= data;
--               AXIS_tkeep  <= (others => '1');
--               AXIS_tlast  <= last_reached;
--               AXIS_tvalid <= '1';
--            end if;
--         else
--            AXIS_tdata  <= (others => '0');
--            AXIS_tkeep  <= (others => '0');
--            AXIS_tlast  <= '0';
--            AXIS_tvalid <= '0';
--         end if;
--      end if;
--   end process;
   

end rtl;
