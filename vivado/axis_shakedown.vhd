-------------------------------------------------------------------------------
-- Title      : AXI4-stream shakedown
-- Project    : 
-------------------------------------------------------------------------------
-- File       : axis_shakedown.vhd
-- Author     : Jiri Kvasnicka (jiri.kvasnicka@desy.de), (kvas@fzu.cz)
-- Company    : DESY / Institute of Physics ASCR
-- Created    : 2018-12-06
-- Last update: 2018-12-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: pipeline stage, that shift bytes down in order to form
-- a compact vector without any gaps inside.
-- 
-- DFFs: ~590
-- LUTs: ~460
-------------------------------------------------------------------------------
-- Copyright (c) 2018 DESY / Institute of Physics ASCR
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-12-06  1.0      kvas    Created
-------------------------------------------------------------------------------

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

entity axis_shakedown is
   generic (
      BYTES : integer range 2 to 256 := 8);
   port (
      clk                : in  std_logic;
      srst               : in  std_logic;
      ce                 : in  std_logic;  --count enable
      --axis input
      axis_sparse_tdata  : in  std_logic_vector (8*BYTES-1 downto 0);
      axis_sparse_tkeep  : in  std_logic_vector (BYTES-1 downto 0);
      axis_sparse_tlast  : in  std_logic;
      axis_sparse_tvalid : in  std_logic;
      --axis output
      axis_shaked_tdata  : out std_logic_vector (8*BYTES-1 downto 0);
      axis_shaked_tkeep  : out std_logic_vector (BYTES-1 downto 0);
      axis_shaked_tlast  : out std_logic;
      axis_shaked_tvalid : out std_logic
      );
end entity axis_shakedown;

architecture RTL of axis_shakedown is
   type T_AXIS_IN is record
      tdata  : std_logic_vector (axis_sparse_tdata'range);
      tkeep  : std_logic_vector (axis_sparse_tkeep'range);
      tlast  : std_logic;
      tvalid : std_logic;
   end record T_AXIS_IN;

   type T_PIPELINE is array (0 to BYTES-1) of T_AXIS_IN;
   signal SHAKEDOWN_PIPE : T_PIPELINE;
   
begin  -- architecture RTL

   pipegen : for i in 1 to BYTES-1 generate  --pipe stages
      shakedown_proc : process(clk)
      begin
         if rising_edge(clk) then
            if srst = '1' then
               SHAKEDOWN_PIPE(i).tdata  <= (others => '0');
               SHAKEDOWN_PIPE(i).tkeep  <= (others => '0');
               SHAKEDOWN_PIPE(i).tlast  <= '0';
               SHAKEDOWN_PIPE(i).tvalid <= '0';
            elsif ce = '1' then              --rst
               SHAKEDOWN_PIPE(i).tvalid <= SHAKEDOWN_PIPE(i-1).tvalid;
               SHAKEDOWN_PIPE(i).tlast  <= SHAKEDOWN_PIPE(i-1).tlast;
               for b in 0 to BYTES-1 loop    --individual bytes from the stage
                  if SHAKEDOWN_PIPE(i-1).tkeep(b downto 0) = (b downto 0 => '1') then
                     --there is no tkeep gap below. Just copy 
                     SHAKEDOWN_PIPE(i).tkeep(b)                <= SHAKEDOWN_PIPE(i-1).tkeep(b);
                     SHAKEDOWN_PIPE(i).tdata(b*8+7 downto b*8) <= SHAKEDOWN_PIPE(i-1).tdata(b*8+7 downto b*8);
                  else
                     --there is somewhere a gap of tkeep 0
                     if (b = (BYTES - 1)) then
                        --special treatment of the last byte: filled with 0s
                        SHAKEDOWN_PIPE(i).tkeep(b)                <= '0';
                        SHAKEDOWN_PIPE(i).tdata(b*8+7 downto b*8) <= (others => '0');
                     else
                        --take the upper bit/byte
                        SHAKEDOWN_PIPE(i).tkeep(b)                <= SHAKEDOWN_PIPE(i-1).tkeep(b+1);
                        SHAKEDOWN_PIPE(i).tdata(b*8+7 downto b*8) <= SHAKEDOWN_PIPE(i-1).tdata(b*8+7+8 downto b*8+8);
                     end if;  --highest byte
                  end if;  --gap below exist
               end loop;  --bytes
            end if;  --rst            
         end if;  --clk
      end process;
   end generate;

   shakedown_first_proc : process(clk)
   begin
      if rising_edge(clk) then
         if srst = '1' then
            SHAKEDOWN_PIPE(0).tdata  <= (others => '0');
            SHAKEDOWN_PIPE(0).tkeep  <= (others => '0');
            SHAKEDOWN_PIPE(0).tlast  <= '0';
            SHAKEDOWN_PIPE(0).tvalid <= '0';
         elsif ce = '1' then
            SHAKEDOWN_PIPE(0).tvalid <= axis_sparse_tvalid;
            if axis_sparse_tvalid = '1' then
               SHAKEDOWN_PIPE(0).tkeep <= axis_sparse_tkeep;
               SHAKEDOWN_PIPE(0).tdata <= axis_sparse_tdata;
               SHAKEDOWN_PIPE(0).tlast <= axis_sparse_tlast;
            else
               SHAKEDOWN_PIPE(0).tdata <= (others => '0');
               SHAKEDOWN_PIPE(0).tkeep <= (others => '0');
               SHAKEDOWN_PIPE(0).tlast <= '0';
            end if;
         end if;  --rst            
      end if;  --clk
   end process;
   axis_shaked_tdata  <= SHAKEDOWN_PIPE(BYTES-1).tdata;
   axis_shaked_tkeep  <= SHAKEDOWN_PIPE(BYTES-1).tkeep;
   axis_shaked_tvalid <= SHAKEDOWN_PIPE(BYTES-1).tvalid;
   axis_shaked_tlast  <= SHAKEDOWN_PIPE(BYTES-1).tlast;

   

end architecture RTL;
