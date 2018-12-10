----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/13/2016 06:25:27 PM
-- Design Name: 
-- Module Name: dma_tester_top - rtl
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity dma_tester_top is
   port (
      DDR_addr          : inout std_logic_vector (14 downto 0);
      DDR_ba            : inout std_logic_vector (2 downto 0);
      DDR_cas_n         : inout std_logic;
      DDR_ck_n          : inout std_logic;
      DDR_ck_p          : inout std_logic;
      DDR_cke           : inout std_logic;
      DDR_cs_n          : inout std_logic;
      DDR_dm            : inout std_logic_vector (3 downto 0);
      DDR_dq            : inout std_logic_vector (31 downto 0);
      DDR_dqs_n         : inout std_logic_vector (3 downto 0);
      DDR_dqs_p         : inout std_logic_vector (3 downto 0);
      DDR_odt           : inout std_logic;
      DDR_ras_n         : inout std_logic;
      DDR_reset_n       : inout std_logic;
      DDR_we_n          : inout std_logic;
      FIXED_IO_ddr_vrn  : inout std_logic;
      FIXED_IO_ddr_vrp  : inout std_logic;
      FIXED_IO_mio      : inout std_logic_vector (53 downto 0);
      FIXED_IO_ps_clk   : inout std_logic;
      FIXED_IO_ps_porb  : inout std_logic;
      FIXED_IO_ps_srstb : inout std_logic;
      LED               : out   std_logic_vector(7 downto 0);
      SW                : in    std_logic_vector(7 downto 0);
      BTNL              : in    std_logic;
      BTNR              : in    std_logic;
      BTND              : in    std_logic;
      BTNC              : in    std_logic;
      BTNU              : in    std_logic
      );
end dma_tester_top;

architecture rtl of dma_tester_top is
   component debouncer is
      generic (
         width        : integer;
         resetdefault : std_logic);
      port (
         clk       : in  std_logic;
         reset     : in  std_logic;
         pin       : in  std_logic;
         debounced : out std_logic);
   end component debouncer;

   component design_1 is
      port (
         DDR_addr             : inout std_logic_vector (14 downto 0);
         DDR_ba               : inout std_logic_vector (2 downto 0);
         DDR_cas_n            : inout std_logic;
         DDR_ck_n             : inout std_logic;
         DDR_ck_p             : inout std_logic;
         DDR_cke              : inout std_logic;
         DDR_cs_n             : inout std_logic;
         DDR_dm               : inout std_logic_vector (3 downto 0);
         DDR_dq               : inout std_logic_vector (31 downto 0);
         DDR_dqs_n            : inout std_logic_vector (3 downto 0);
         DDR_dqs_p            : inout std_logic_vector (3 downto 0);
         DDR_odt              : inout std_logic;
         DDR_ras_n            : inout std_logic;
         DDR_reset_n          : inout std_logic;
         DDR_we_n             : inout std_logic;
         DMA_AXIS_MM2S_tdata  : out   std_logic_vector (31 downto 0);
         DMA_AXIS_MM2S_tkeep  : out   std_logic_vector (3 downto 0);
         DMA_AXIS_MM2S_tlast  : out   std_logic;
         DMA_AXIS_MM2S_tready : in    std_logic;
         DMA_AXIS_MM2S_tvalid : out   std_logic;
         DMA_AXIS_S2MM_tdata  : in    std_logic_vector (63 downto 0);
         DMA_AXIS_S2MM_tkeep  : in    std_logic_vector (7 downto 0);
         DMA_AXIS_S2MM_tlast  : in    std_logic;
         DMA_AXIS_S2MM_tready : out   std_logic;
         DMA_AXIS_S2MM_tvalid : in    std_logic;
         FIXED_IO_ddr_vrn     : inout std_logic;
         FIXED_IO_ddr_vrp     : inout std_logic;
         FIXED_IO_mio         : inout std_logic_vector (53 downto 0);
         FIXED_IO_ps_clk      : inout std_logic;
         FIXED_IO_ps_porb     : inout std_logic;
         FIXED_IO_ps_srstb    : inout std_logic;
         fclk_clk0            : out   std_logic
         );
   end component design_1;

   component saxi_generator_counter is
      generic (
         AXI_WIDTH : integer);
      port (
         clk          : in  std_logic;
         srst         : in  std_logic;
         control_run  : in  std_logic;
         control_size : in  std_logic_vector(3 downto 0);
         AXIS_tdata   : out std_logic_vector (AXI_WIDTH*8-1 downto 0);
         AXIS_tkeep   : out std_logic_vector (AXI_WIDTH-1 downto 0);
         AXIS_tlast   : out std_logic;
         AXIS_tready  : in  std_logic;
         AXIS_tvalid  : out std_logic);
   end component saxi_generator_counter;

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
         axis_compact_tdata  : out std_logic_vector (8*BYTES-1 downto 0);
         axis_compact_tkeep  : out std_logic_vector (BYTES-1 downto 0);
         axis_compact_tlast  : out std_logic;
         axis_compact_tready : in  std_logic;
         axis_compact_tvalid : out std_logic);
   end component axis_desparse;
   signal axis_sparse_clk     : std_logic;
   signal axis_sparse_tdata   : std_logic_vector (8*8-1 downto 0);
   signal axis_sparse_tkeep   : std_logic_vector (8-1 downto 0);
   signal axis_sparse_tlast   : std_logic;
   signal axis_sparse_tready  : std_logic;
   signal axis_sparse_tvalid  : std_logic;
   signal axis_compact_tdata  : std_logic_vector (8*8-1 downto 0);
   signal axis_compact_tkeep  : std_logic_vector (8-1 downto 0);
   signal axis_compact_tlast  : std_logic;
   signal axis_compact_tready : std_logic;
   signal axis_compact_tvalid : std_logic;

   signal SW_debounced   : std_logic_vector(SW'range) := (sw'range => '0');
   signal btnc_debounced : std_logic                  := '1';

   signal DMA_AXIS_MM2S_tdata  : std_logic_vector (31 downto 0);
   signal DMA_AXIS_MM2S_tkeep  : std_logic_vector (3 downto 0);
   signal DMA_AXIS_MM2S_tlast  : std_logic;
   signal DMA_AXIS_MM2S_tready : std_logic;
   signal DMA_AXIS_MM2S_tvalid : std_logic;

   signal DMA_AXIS_S2MM_tdata  : std_logic_vector (63 downto 0);
   signal DMA_AXIS_S2MM_tkeep  : std_logic_vector (7 downto 0);
   signal DMA_AXIS_S2MM_tlast  : std_logic;
   signal DMA_AXIS_S2MM_tready : std_logic;
   signal DMA_AXIS_S2MM_tvalid : std_logic;

   signal S00_AXIS_tvalid : std_logic;
   signal S00_AXIS_tready : std_logic;
   signal S00_AXIS_tdata  : std_logic_vector (63 downto 0);
   signal S00_AXIS_tstrb  : std_logic_vector (7 downto 0);
   signal S00_AXIS_tkeep  : std_logic_vector (7 downto 0);
   signal S00_AXIS_tlast  : std_logic;
   signal fclk_clk0       : std_logic;
begin
   design_1_2 : design_1
      port map (
         DDR_addr             => DDR_addr,
         DDR_ba               => DDR_ba,
         DDR_cas_n            => DDR_cas_n,
         DDR_ck_n             => DDR_ck_n,
         DDR_ck_p             => DDR_ck_p,
         DDR_cke              => DDR_cke,
         DDR_cs_n             => DDR_cs_n,
         DDR_dm               => DDR_dm,
         DDR_dq               => DDR_dq,
         DDR_dqs_n            => DDR_dqs_n,
         DDR_dqs_p            => DDR_dqs_p,
         DDR_odt              => DDR_odt,
         DDR_ras_n            => DDR_ras_n,
         DDR_reset_n          => DDR_reset_n,
         DDR_we_n             => DDR_we_n,
         DMA_AXIS_MM2S_tdata  => DMA_AXIS_MM2S_tdata,
         DMA_AXIS_MM2S_tkeep  => DMA_AXIS_MM2S_tkeep,
         DMA_AXIS_MM2S_tlast  => DMA_AXIS_MM2S_tlast,
         DMA_AXIS_MM2S_tready => DMA_AXIS_MM2S_tready,
         DMA_AXIS_MM2S_tvalid => DMA_AXIS_MM2S_tvalid,
         DMA_AXIS_S2MM_tdata  => DMA_AXIS_S2MM_tdata,
         DMA_AXIS_S2MM_tkeep  => DMA_AXIS_S2MM_tkeep,
         DMA_AXIS_S2MM_tlast  => DMA_AXIS_S2MM_tlast,
         DMA_AXIS_S2MM_tready => DMA_AXIS_S2MM_tready,
         DMA_AXIS_S2MM_tvalid => DMA_AXIS_S2MM_tvalid,
         FIXED_IO_ddr_vrn     => FIXED_IO_ddr_vrn,
         FIXED_IO_ddr_vrp     => FIXED_IO_ddr_vrp,
         FIXED_IO_mio         => FIXED_IO_mio,
         FIXED_IO_ps_clk      => FIXED_IO_ps_clk,
         FIXED_IO_ps_porb     => FIXED_IO_ps_porb,
         FIXED_IO_ps_srstb    => FIXED_IO_ps_srstb,
         fclk_clk0            => fclk_clk0);

   saxi_generator_counter_1 : saxi_generator_counter
      generic map (
         AXI_WIDTH => 8)
      port map (
         clk          => fclk_clk0,
         srst         => btnc_debounced,
         control_run  => SW_debounced(0),
         control_size => SW_debounced(4 downto 1),
         AXIS_tdata   => S00_AXIS_tdata,
         AXIS_tkeep   => S00_AXIS_tkeep,
         AXIS_tlast   => S00_AXIS_tlast,
         AXIS_tready  => S00_AXIS_tready,
         AXIS_tvalid  => S00_AXIS_tvalid
         );
   S00_AXIS_tstrb <= S00_AXIS_tkeep;

   axis_desparse_1 : entity work.axis_desparse
      generic map (
         BYTES => 8)
      port map (
         srst                => btnc_debounced,
         axis_sparse_clk     => fclk_clk0,
         axis_sparse_tdata   => axis_sparse_tdata,
         axis_sparse_tkeep   => axis_sparse_tkeep,
         axis_sparse_tlast   => axis_sparse_tlast,
         axis_sparse_tready  => axis_sparse_tready,
         axis_sparse_tvalid  => axis_sparse_tvalid,
         axis_compact_tdata  => axis_compact_tdata,
         axis_compact_tkeep  => axis_compact_tkeep,
         axis_compact_tlast  => axis_compact_tlast,
         axis_compact_tready => axis_compact_tready,
         axis_compact_tvalid => axis_compact_tvalid);

   axi_switch_proc : process (DMA_AXIS_MM2S_tdata, DMA_AXIS_MM2S_tkeep, DMA_AXIS_MM2S_tlast, DMA_AXIS_MM2S_tvalid, S00_AXIS_tdata, S00_AXIS_tkeep, S00_AXIS_tlast, S00_AXIS_tvalid, SW_debounced(5),
                              axis_sparse_tready)
   begin
      if SW_debounced(5) = '1' then     --use the counter
         axis_sparse_tdata    <= S00_AXIS_tdata;
         axis_sparse_tvalid   <= S00_AXIS_tvalid;
         axis_sparse_tlast    <= S00_AXIS_tlast;
         axis_sparse_tkeep    <= S00_AXIS_tkeep;
         S00_AXIS_tready      <= axis_sparse_tready;
         DMA_AXIS_MM2S_tready <= '1';   --eat everything that comes from DMA
      else                              --use loopback data
         axis_sparse_tdata    <= (31 downto 0 => '0') & DMA_AXIS_MM2S_tdata;
         axis_sparse_tvalid   <= DMA_AXIS_MM2S_tvalid;
         axis_sparse_tlast    <= DMA_AXIS_MM2S_tlast;
         axis_sparse_tkeep    <= "0000" & DMA_AXIS_MM2S_tkeep;
         DMA_AXIS_MM2S_tready <= axis_sparse_tready;
         S00_AXIS_tready      <= '0';   -- don't count
      end if;  --sw
   end process;

   DMA_AXIS_S2MM_tvalid <= axis_compact_tvalid;
   DMA_AXIS_S2MM_tdata  <= axis_compact_tdata;
   DMA_AXIS_S2MM_tkeep  <= axis_compact_tkeep;
   DMA_AXIS_S2MM_tlast  <= axis_compact_tlast;
   axis_compact_tready  <= DMA_AXIS_S2MM_tready;

   LET_Proc : process(fclk_clk0)
   begin
      if rising_edge(fclk_clk0) then
         case SW(7 downto 6) is
            when "00" =>
               LED(0) <= DMA_AXIS_S2MM_tvalid;
               LED(1) <= DMA_AXIS_S2MM_tready;
               LED(2) <= DMA_AXIS_S2MM_tlast;
               LED(3) <= '0';
               LED(4) <= '0';
               LED(5) <= '0';
               LED(6) <= '0';
               LED(7) <= '0';
            when "01" =>
               LED(0) <= S00_AXIS_tdata(0) or S00_AXIS_tdata(1);
               LED(1) <= S00_AXIS_tdata(2) or S00_AXIS_tdata(3);
               LED(2) <= S00_AXIS_tdata(4) or S00_AXIS_tdata(5);
               LED(3) <= S00_AXIS_tdata(6) or S00_AXIS_tdata(7);
               LED(4) <= S00_AXIS_tdata(8) or S00_AXIS_tdata(9);
               LED(5) <= S00_AXIS_tdata(10) or S00_AXIS_tdata(11);
               LED(6) <= S00_AXIS_tdata(12) or S00_AXIS_tdata(13);
               LED(7) <= S00_AXIS_tdata(14) or S00_AXIS_tdata(15);
            when "10" =>
               LED(0) <= S00_AXIS_tdata(16);
               LED(1) <= S00_AXIS_tdata(17);
               LED(2) <= S00_AXIS_tdata(18);
               LED(3) <= S00_AXIS_tdata(19);
               LED(4) <= S00_AXIS_tdata(20);
               LED(5) <= S00_AXIS_tdata(21);
               LED(6) <= S00_AXIS_tdata(22);
               LED(7) <= S00_AXIS_tdata(23);
            when "11" =>
               LED(0) <= S00_AXIS_tdata(24);
               LED(1) <= S00_AXIS_tdata(25);
               LED(2) <= S00_AXIS_tdata(26);
               LED(3) <= S00_AXIS_tdata(27);
               LED(4) <= S00_AXIS_tdata(28);
               LED(5) <= S00_AXIS_tdata(29);
               LED(6) <= S00_AXIS_tdata(30);
               LED(7) <= S00_AXIS_tdata(31);
            when others =>
               LED <= (others => '0');
         end case;
      end if;  --fclk
   end process;

   debounce_gen : for i in 0 to 7 generate
      debouncer_i : debouncer
         generic map (
            width        => 23,
            resetdefault => '0')
         port map (
            clk       => fclk_clk0,
            reset     => '0',
            pin       => SW(i),
            debounced => SW_debounced(i));
   end generate;

   debouncer_btnc : debouncer
      generic map (
         width        => 20,
         resetdefault => '0')
      port map (
         clk       => fclk_clk0,
         reset     => '0',
         pin       => BTNC,
         debounced => btnc_debounced);
end rtl;
