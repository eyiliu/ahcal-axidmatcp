-------------------------------------------------------------------------------
-- Title      : axi-stream de-sparser
-- Project    : 
-------------------------------------------------------------------------------
-- File       : axis_desparse.vhd
-- Author     : Jiri Kvasnicka (jiri.kvasnicka@desy.de), (kvas@fzu.cz)
-- Company    : DESY / Institute of Physics ASCR
-- Created    : 2018-12-05
-- Last update: 2018-12-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: converts sparse stream (stream, that contains tkeep==0
-- bytes) to a stream, that can be sparse only with the last vector,
-- when tlast is '1'.
--
-- Principle: the data travels through multiple stages:
--
-- a) shakedown of the inputs (external module) it will transform following
-- sparse vector to a new one:
--
-- tkeep          tdata
-- ----------  ----------        ----------  ----------
-- |11001011|  |abcdefgh|   ===> |11111000|  |abegh000| (result stage A)
-- ----------  ----------        ----------  ----------
--
-- b) shifting right by 0 ~ (BYTES-1) positions, depending on previously
-- accumulated number of bytes. for example if previously 6 bits were stored,
-- the whole vector will be shifted by 6 and filled with 0 from right:
--
-- tkeep         tdata
-- ----------  ----------         
-- |11111000|  |abegh000|   ===>  
-- ----------  ----------         
-- tkeep                 tdata
-- ------------------  ------------------
-- |00000011|1110000|  |000000ab|egh0000| (stage B result)
-- ------------------  ------------------
--
-- c) correct bytes will be cherrypicked from the extended vector from previous
-- step and stored to stage C or directly stage D. Depending on whether there is any entry in the extended part, the data
-- will be moved:
--   c1) if there is an antry: moved stage D (together with previously stored
--   data in stage C
--   c2) if there is no entry: only to stage C
-- The trick is in selecting proper input and use count enables for individual
-- bytes of stage C.
--
-- example for C2:
-- tkeep C      tdata C        tkeep D      tdata D  
-- ----------  ----------      ----------  ----------
-- |11100000|  |egh00000|      |00000011|  |_prev_ab|
-- ----------  ----------      ----------  ----------
-- 
-- There are some assumption: vector is valid, when there is at least 1 tkeep
-- byte in the vector. Stage A ensures, that tkeep is cleared when tvalid is
-- not set.
-- Stage B is also bookkeeping number of bytes stored (modulo BYTES)

-------------------------------------------------------------------------------
-- Copyright (c) 2018 DESY / Institute of Physics ASCR
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-12-05  1.0      kvas    Created
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

entity axis_desparse is
   generic (
      BYTES : integer range 2 to 256 := 8);  -- number of bytes in the axi stream
   port (
      srst                : in  std_logic;   -- sync reset
      --axis input
      axis_sparse_clk     : in  std_logic;
      axis_sparse_tdata   : in  std_logic_vector (8*BYTES-1 downto 0);
      axis_sparse_tkeep   : in  std_logic_vector (BYTES-1 downto 0);
      axis_sparse_tlast   : in  std_logic;
      axis_sparse_tready  : out std_logic;
      axis_sparse_tvalid  : in  std_logic;
      --axis output
      axis_compact_tdata  : out std_logic_vector (8*BYTES-1 downto 0);
      axis_compact_tkeep  : out std_logic_vector (BYTES-1 downto 0);
      axis_compact_tlast  : out std_logic;
      axis_compact_tready : in  std_logic;
      axis_compact_tvalid : out std_logic
      );                                -- data

end entity axis_desparse;

architecture Behavioral of axis_desparse is
   constant counter_bits : integer := integer(ceil(log2(real(BYTES))));  --for 8 BYTES returns 3, for 16 bytes return 4, ...
   type T_AXIS_IN is record
      tdata  : std_logic_vector (8*BYTES-1 downto 0);
      tkeep  : std_logic_vector (BYTES-1 downto 0);
      tlast  : std_logic;
      tvalid : std_logic;
   end record T_AXIS_IN;

   --shakedown stage A
   signal shaked_tdata  : std_logic_vector(8*BYTES-1 downto 0) := (others => '0');
   signal shaked_tkeep  : std_logic_vector(BYTES-1 downto 0)   := (others => '0');
   signal shaked_tlast  : std_logic                            := '0';
   signal shaked_tvalid : std_logic                            := '0';

   --shited stage B
   signal B_shift        : unsigned(counter_bits-1 downto 0)      := (others => '0');  --the shift can be only 0-7
   signal shifted_tdata  : std_logic_vector(2*8*BYTES-1 downto 0) := (others => '0');
   signal shifted_tkeep  : std_logic_vector(2*BYTES-1 downto 0)   := (others => '0');
   signal shifted_tlast  : std_logic                              := '0';
   signal shifted_tvalid : std_logic                              := '0';

   --collecting stage C
   signal collect_tdata  : std_logic_vector(8*BYTES-1 downto 0) := (others => '0');
   signal collect_tkeep  : std_logic_vector(BYTES-1 downto 0)   := (others => '0');
   signal collect_tlast  : std_logic                            := '0';
   signal collect_tvalid : std_logic                            := '0';

   --result output stage D
   signal result_tdata  : std_logic_vector(8*BYTES-1 downto 0) := (others => '0');
   signal result_tkeep  : std_logic_vector(BYTES-1 downto 0)   := (others => '0');
   signal result_tlast  : std_logic                            := '0';
   signal result_tvalid : std_logic                            := '0';

   --fifo stage
   signal fifo_full : std_logic;
   signal fifo_we   : std_logic;
   signal fifo_dout : std_logic_vector(9*BYTES downto 0);


   component axis_shakedown is
      generic (
         BYTES : integer range 2 to 256);
      port (
         clk                : in  std_logic;
         srst               : in  std_logic;
         ce                 : in  std_logic;
         axis_sparse_tdata  : in  std_logic_vector (8*BYTES-1 downto 0);
         axis_sparse_tkeep  : in  std_logic_vector (BYTES-1 downto 0);
         axis_sparse_tlast  : in  std_logic;
         axis_sparse_tvalid : in  std_logic;
         axis_shaked_tdata  : out std_logic_vector (8*BYTES-1 downto 0);
         axis_shaked_tkeep  : out std_logic_vector (BYTES-1 downto 0);
         axis_shaked_tlast  : out std_logic;
         axis_shaked_tvalid : out std_logic);
   end component axis_shakedown;

   component fifo_desparse is
      port (
         clk   : in  std_logic;
         rst   : in  std_logic;
         din   : in  std_logic_vector (72 downto 0);
         wr_en : in  std_logic;
         rd_en : in  std_logic;
         dout  : out std_logic_vector (72 downto 0);
         full  : out std_logic;
         empty : out std_logic;
         valid : out std_logic);
   end component fifo_desparse;

   --signal accumulated_shift : out integer range 0 to BYTES;
   function num_ones(X : std_logic_vector) return integer is
      variable count : integer := 0;
      variable i     : integer := 0;
   begin
      for i in X'range loop
         if (X(i) = '1') then
            count := count + 1;
         end if;
      end loop;
      return count;
   end num_ones;

   signal global_ce : std_logic := '0';
   signal clk       : std_logic;
begin
   clk                <= axis_sparse_clk;
   axis_sparse_tready <= global_ce;

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- stage A
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   axis_shakedown_1 : axis_shakedown
      generic map (
         BYTES => BYTES)
      port map (
         clk                => clk,
         srst               => srst,
         ce                 => global_ce,
         axis_sparse_tdata  => axis_sparse_tdata,
         axis_sparse_tkeep  => axis_sparse_tkeep,
         axis_sparse_tlast  => axis_sparse_tlast,
         axis_sparse_tvalid => axis_sparse_tvalid,
         axis_shaked_tdata  => shaked_tdata,
         axis_shaked_tkeep  => shaked_tkeep,
         axis_shaked_tlast  => shaked_tlast,
         axis_shaked_tvalid => shaked_tvalid);

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- stage B
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

   --calculates the necessary shift for the next data
   shift_cnt_proc : process(clk)
      variable one_count : unsigned(counter_bits-1 downto 0);  --we count modulo BYTES, therefore -1-1
   begin
      if rising_edge(clk) then
         if srst = '1' then
            B_shift <= (others => '0');
         elsif (global_ce = '1') then
            one_count := to_unsigned(num_ones(shaked_tkeep), counter_bits);
            if (shaked_tlast = '1') then                       --tlast will reset the counter
               B_shift <= (others => '0');
            else
               B_shift <= B_shift + one_count;
            end if;  --tlast
         else
            B_shift <= B_shift;
         --do not modify
         end if;  --global_ce
      end if;  --clk
   end process;

   shifted_proc : process(clk)
      variable shift_int : integer;
   begin
      if rising_edge(clk) then
         if srst = '1' then
            shifted_tkeep <= (others => '0');
            shifted_tdata <= (others => '0');
            shifted_tlast <= '0';
         elsif global_ce = '1' then
            shift_int                                               := to_integer(B_shift);
            shifted_tkeep                                           <= (others => '0');
            shifted_tkeep(shift_int+BYTES-1 downto shift_int)       <= shaked_tkeep;
            shifted_tdata                                           <= (others => '0');
            shifted_tdata(8*(shift_int+BYTES)-1 downto 8*shift_int) <= shaked_tdata;
            shifted_tlast                                           <= shaked_tlast;
         else
            shifted_tdata <= shifted_tdata;
            shifted_tlast <= shifted_tlast;
            shifted_tkeep <= shifted_tkeep;
         end if;  --ce, rst
      end if;  --clk
   end process;

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- STAGE C - merge and collect data in a single vector
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   collect_gen : for i in 0 to BYTES-1 generate
      collect_proc_i : process(clk)
      begin
         if rising_edge(clk) then
            if srst = '1' then
               collect_tkeep(i)                <= '0';
               collect_tdata(8*i+7 downto 8*i) <= (others => '0');
            elsif global_ce = '1' then
               if shifted_tkeep(BYTES) = '1'                                     --the shifted vector is larger than BYTES
                  or shifted_tkeep(i) = '1'                                      --there is data to be stored (might still use the i+bytes)
                  or collect_tlast = '1'                                         --the vector will be sent out and needs to be cleaned (either with 0 or new data)
                  or collect_tkeep(BYTES-1) = '1' then                           --the collection register is full and we must clear to 0
                  if shifted_tkeep(BYTES) = '1' then
                     collect_tkeep(i)                <= shifted_tkeep(i+BYTES);  --must use the higher part. The lower is automatically sent to stage D in the same clock tick
                     collect_tdata(8*i+7 downto 8*i) <= shifted_tdata(8*(i+BYTES)+7 downto 8*(i+BYTES));
                  else
                     collect_tkeep(i)                <= shifted_tkeep(i);
                     collect_tdata(8*i+7 downto 8*i) <= shifted_tdata(8*i+7 downto 8*i);
                  end if;  --overflow
               end if;  --local CE condition
            else
               collect_tkeep(i)                <= collect_tkeep(i);
               collect_tdata(8*i+7 downto 8*i) <= collect_tdata(8*i+7 downto 8*i);
            end if;  --ce, reset
         end if;  --clk
      end process;
   end generate;

   collect_tlast_proc : process(clk)
   begin
      if rising_edge(clk) then
         if srst = '1' then
            collect_tlast <= '0';
         elsif global_ce = '1' then
            collect_tlast <= shifted_tlast;
         else
            collect_tlast <= collect_tlast;
         end if;  --ce, reset
      end if;  --clk
   end process;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- STAGE D
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

   result_gen : for i in 0 to BYTES-1 generate
      result_proc_i : process(clk)
      begin
         if rising_edge(clk) then
            if srst = '1' then
               result_tkeep(i)                <= '0';
               result_tdata(8*i+7 downto 8*i) <= (others => '0');
            elsif global_ce = '1' then
               if shifted_tkeep(BYTES) = '1' and shifted_tkeep(i) = '1' then  --overflow. The vector has to be completed from shifted vector partially
                  result_tkeep(i)                <= shifted_tkeep(i);
                  result_tdata(8*i+7 downto 8*i) <= shifted_tdata(8*i+7 downto 8*i);
               else
                  result_tkeep(i)                <= collect_tkeep(i);
                  result_tdata(8*i+7 downto 8*i) <= collect_tdata(8*i+7 downto 8*i);
               end if;  --overflow
            else
               --keep the previous data
               result_tkeep(i)                 <= result_tkeep(i);
               result_tdata(8*i+7 downto 8*i) <= result_tdata(8*i+7 downto 8*i);
            end if;  --ce, reset
         end if;  --clk
      end process;
   end generate;

   result_tvalid_proc : process(clk)
   begin
      if rising_edge(clk) then
         if srst = '1' then
            result_tvalid <= '0';
            result_tlast  <= '0';
         elsif global_ce = '1' then
            result_tlast <= collect_tlast;
            if shifted_tkeep(BYTES) = '1'       --overflow => data always valid
               or collect_tlast = '1'           --will send "incomplete" last word
               or collect_tkeep(BYTES-1) = '1'  --the collect vector is full
            then
               result_tvalid <= '1';
            else
               result_tvalid <= '0';
            end if;
         else                                   --global_ce
            --result_tlast and result_tvalid are still kept high, but it is expected, that they are not stored.
            --results are therefore valit through the whole period of global_ce=='0'
            result_tvalid <= result_tvalid;
            result_tlast  <= result_tlast;
         --result_tlast  <= '0';
         --result_tvalid <= '0'
         end if;  --srst
      end if;  --clk
   end process;

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- FINAL FIFO stage
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   fifo_desparse_1 : fifo_desparse
      port map (
         clk   => clk,
         rst   => srst,
         din   => result_tdata & result_tkeep & result_tlast,
         wr_en => fifo_we,
         rd_en => axis_compact_tready,
         dout  => fifo_dout,
         full  => fifo_full,
         empty => open,
         valid => axis_compact_tvalid);
   axis_compact_tlast <= fifo_dout(0);
   axis_compact_tkeep <= fifo_dout(BYTES downto 1);
   axis_compact_tdata <= fifo_dout(BYTES*9 downto BYTES+1);

   fifo_we   <= result_tvalid and global_ce;
   global_ce <= not fifo_full;



end Behavioral;
