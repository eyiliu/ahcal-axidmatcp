----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/06/2018 04:56:09 PM
-- Design Name: 
-- Module Name: test - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity test is
   generic(BYTES : integer := 8);
--  Port ( );
end test;

architecture Behavioral of test is


   component axis_desparse is
      generic (
         BYTES : integer range 2 to 256);
      port (
         srst                : in  std_logic;
         axis_sparse_clk     : in  std_logic;
         axis_sparse_tdata   : in  std_logic_vector (8*BYTES-1 downto 0);
         axis_sparse_tkeep   : in  std_logic_vector (BYTES-1 downto 0);
         axis_sparse_tlast   : in  std_logic;
         axis_sparse_tready  : out std_logic;
         axis_sparse_tvalid  : in  std_logic;
         axis_compact_clk    : in  std_logic;
         axis_compact_tdata  : out std_logic_vector (8*BYTES-1 downto 0);
         axis_compact_tkeep  : out std_logic_vector (BYTES-1 downto 0);
         axis_compact_tlast  : out std_logic;
         axis_compact_tready : in  std_logic;
         axis_compact_tvalid : out std_logic);
   end component axis_desparse;
   signal clk                 : std_logic;
   signal srst                : std_logic;
   signal axis_sparse_clk     : std_logic;
   signal axis_sparse_tdata   : std_logic_vector (8*BYTES-1 downto 0);
   signal axis_sparse_tkeep   : std_logic_vector (BYTES-1 downto 0);
   signal axis_sparse_tlast   : std_logic;
   signal axis_sparse_tready  : std_logic;
   signal axis_sparse_tvalid  : std_logic;
   signal axis_compact_clk    : std_logic;
   signal axis_compact_tdata  : std_logic_vector (8*BYTES-1 downto 0);
   signal axis_compact_tkeep  : std_logic_vector (BYTES-1 downto 0);
   signal axis_compact_tlast  : std_logic;
   signal axis_compact_tready : std_logic;
   signal axis_compact_tvalid : std_logic;

   signal result_tready_probability : real := 0.4;
   signal generator_density : real := 0.6;
                                              

begin
   axis_desparse_1 : axis_desparse
      generic map (
         BYTES => BYTES)
      port map (
         srst                => srst,
         axis_sparse_clk     => axis_sparse_clk,
         axis_sparse_tdata   => axis_sparse_tdata,
         axis_sparse_tkeep   => axis_sparse_tkeep,
         axis_sparse_tlast   => axis_sparse_tlast,
         axis_sparse_tready  => axis_sparse_tready,
         axis_sparse_tvalid  => axis_sparse_tvalid,
         axis_compact_clk    => axis_compact_clk,
         axis_compact_tdata  => axis_compact_tdata,
         axis_compact_tkeep  => axis_compact_tkeep,
         axis_compact_tlast  => axis_compact_tlast,
         axis_compact_tready => axis_compact_tready,
         axis_compact_tvalid => axis_compact_tvalid);

   clk_proc : process
   begin
      clk <= '0';
      wait for 12.5 ns;
      clk <= '1';
      wait for 12.5 ns;
   end process;

   axis_sparse_clk <= clk;

   probability_steering : process
        variable seed1, seed2 : positive;  -- Seed values for the random generator
      variable rand         : real;      -- Random value (0 to 1.0 range)
   begin
      generator_density <= 0.6;
      result_tready_probability <= 0.3;
      wait for 5 ns;
      result_tready_probability <= 0.8;
      wait for 5 ns;
      for i in 0 to 9 loop
            UNIFORM(seed1, seed2, rand);
            result_tready_probability <= rand;
            UNIFORM(seed1, seed2, rand);
            generator_density <= rand;
            wait for 500*1000 ns;
      end loop;
   end process;

   rst_proc : process
      variable seed1, seed2 : positive;  -- Seed values for the random generator
      variable rand         : real;      -- Random value (0 to 1.0 range)

   begin
      axis_compact_tready <= '0';
      srst                <= '1';
      wait for 500 ns;
      srst                <= '0';
      wait for 500 ns;
      loop
         UNIFORM(seed1, seed2, rand);
         wait until falling_edge(clk);
         if rand < result_tready_probability then
            axis_compact_tready <= '1';
         else
            axis_compact_tready <= '0';
         end if;
      end loop;
      wait;
   end process;

   checker_process : process
      variable seed1, seed2 : positive;  -- Seed values for the random generator
      variable rand         : real;      -- Random value (0 to 1.0 range)
      variable cnt          : unsigned(7 downto 0) := (others => '0');
   begin
      report "watching for errors in the counter continuity";
      loop
         wait until rising_edge(clk);
         if axis_compact_tready = '1' and axis_compact_tvalid = '1' then
            case axis_compact_tkeep is
               when "00000000" => report "empty tkeep" severity error;
               when "00000001" => null;  --ok
               when "00000011" => null;  --ok
               when "00000111" => null;  --ok
               when "00001111" => null;  --ok
               when "00011111" => null;  --ok
               when "00111111" => null;  --ok
               when "01111111" => null;  --ok
               when "11111111" => null;  --ok
               when others     => report "TKEEP violates specs: (dec) " & integer'image(to_integer(unsigned(axis_compact_tkeep))) severity failure;
            end case;
            for i in 0 to 7 loop
               if axis_compact_tkeep(i) = '1' then
                  if axis_compact_tdata(8*i+7 downto 8*i) /= std_logic_vector(cnt) then
                     report "Unexpected data. Expected " & integer'image(to_integer(cnt)) & ", received " & integer'image(to_integer(unsigned(axis_compact_tdata(8*i+7 downto 8*i)))) severity error;
                     cnt := unsigned(axis_compact_tdata(8*i+7 downto 8*i));
                  end if;
                  cnt := cnt + 1;
               end if;
            end loop;
         end if;
      end loop;
      
   end process;

   data_proc : process

      variable seed1, seed2 : positive;  -- Seed values for the random generator
      variable rand         : real;      -- Random value (0 to 1.0 range)

      variable cnt : unsigned(7 downto 0) := (others => '0');

      procedure fillrnd is
         variable has_data : std_logic;
      begin  -- procedure fillrnd
         UNIFORM(seed1, seed2, rand);
         if axis_sparse_tready = '1' then
            if rand < 0.95 then
               has_data := '0';
               for i in 0 to 7 loop
                  UNIFORM(seed1, seed2, rand);
                  if rand < generator_density then
                     axis_sparse_tkeep(i)                <= '1';
                     axis_sparse_tdata(8*i+7 downto 8*i) <= std_logic_vector(cnt);
                     cnt                                 := cnt + 1;
                     has_data                            := '1';
                  else
                     axis_sparse_tkeep(i)                <= '0';
                     axis_sparse_tdata(8*i+7 downto 8*i) <= (others => '0');
                  end if;
               end loop;
               UNIFORM(seed1, seed2, rand);
               if rand < 0.01 then
                  axis_sparse_tlast <= '1';
               else
                  axis_sparse_tlast <= '0';
               end if;
               axis_sparse_tvalid <= has_data;
            else
               axis_sparse_tvalid <= '0';
            end if;
         end if;
      end procedure fillrnd;
      
   begin
      axis_sparse_tdata  <= X"0000000000000000";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00000000";
      axis_sparse_tvalid <= '0';
      wait for 1000 ns;
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0400000300020100";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "10010110";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0000000000000000";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00000000";
      axis_sparse_tvalid <= '0';
      wait until falling_edge(clk);
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0600000000000500";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "10000010";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0900000008000700";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "10001010";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0000000000000000";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00000000";
      axis_sparse_tvalid <= '0';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"100F0E0D0C0B0A00";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "11111110";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0000000000000000";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00000000";
      axis_sparse_tvalid <= '0';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0017161514131211";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "01111111";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"001E1D1C1B1A1918";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "01111111";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"002524232221201F";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "01111111";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"FF2C2B2A29282726";
      axis_sparse_tlast  <= '1';
      axis_sparse_tkeep  <= "11111111";
      axis_sparse_tvalid <= '1';

      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"00000000302F2E2D";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00001111";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0000003534333231";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00011111";
      axis_sparse_tvalid <= '1';
      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0000000000383736";
      axis_sparse_tlast  <= '1';
      axis_sparse_tkeep  <= "00000111";
      axis_sparse_tvalid <= '1';

      wait until falling_edge(clk);
      axis_sparse_tdata  <= X"0000000000000000";
      axis_sparse_tlast  <= '0';
      axis_sparse_tkeep  <= "00000000";
      axis_sparse_tvalid <= '0';

      wait for 1000ns;
      loop
         for i in 0 to 50000 loop      -- 0.5 ms of data
            wait until falling_edge(clk);
            fillrnd;
         end loop;
         wait until falling_edge(clk);
         axis_sparse_tdata  <= X"0000000000000000";
         axis_sparse_tlast  <= '0';
         axis_sparse_tkeep  <= "00000000";
         axis_sparse_tvalid <= '0';
         wait for 200000 ns;            -- no data for 0.2 ms
      end loop;
   end process;

end Behavioral;
