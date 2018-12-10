--
-- VHDL Architecture LDA_lib.debouncer.rtl
--
-- Created:
--          by - kvas.UNKNOWN (FLCKVASWL)
--          at - 11:22:03 22.07.2014
--
-- using Mentor Graphics HDL Designer(TM) 2012.2b (Build 5)
-- --version 0.1, not tested
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
   generic(
      width        : integer   := 20;   --width of the counter
      resetdefault : std_logic := '0'
      );
   port(
      clk       : in  std_logic;
      reset     : in  std_logic;
      pin       : in  std_logic;
      debounced : out std_logic
      );

   -- Declarations
end entity debouncer;

--
architecture rtl of debouncer is
   type states is (
      zero, up, one, down
      );
   signal CS, ns             : states;  --current and next state
   signal count              : std_logic;
--   signal reached : std_logic;
   signal counter            : unsigned(width-1 downto 0);
   signal debounced_int      : std_logic;
   signal pin_reg1, pin_reg2 : std_logic;
   
begin
   
   clk_proc : process(clk)
   begin
      if clk'event and clk = '1' then
         if reset = '1' then
            debounced <= resetdefault;
            pin_reg1  <= resetdefault;
            pin_reg2  <= resetdefault;
            if resetdefault = '1' then
               cs <= one;
            else
               cs <= zero;
            end if;
         else
            debounced <= debounced_int;
            pin_reg2  <= pin_reg1;
            pin_reg1  <= pin;
            CS        <= ns;
         end if;
      end if;
   end process;

   counter_proc : process(clk)
   begin
      if clk'event and clk = '1' then
         if reset = '1' then
            counter <= (others => '0');
         else
            if count = '1' then
               counter <= counter + 1;
            else
               counter <= (others => '0');
            end if;  --count
         end if;  --reset
      end if;  --clk
   end process;


   ns_proc : process(pin_reg2, cs, counter)
   begin
      case cs is
         when zero =>
            if pin_reg2 = '1' then
               ns <= up;
            else
               ns <= zero;
            end if;
         when up =>
            if pin_reg2 = '0' then
               ns <= zero;
            elsif counter = (counter'range => '1') then
               ns <= one;
            else
               ns <= up;
            end if;
         when one =>
            if pin_reg2 = '0' then
               ns <= down;
            else
               ns <= one;
            end if;
         when down =>
            if pin_reg2 = '1' then
               ns <= one;
            elsif counter = (counter'range => '1') then
               ns <= zero;
            else
               ns <= down;
            end if;
         when others =>
            if resetdefault = '1' then
               ns <= one;
            else
               ns <= zero;
            end if;
      end case;
   end process;

   out_proc : process(pin_reg2, cs, counter)
   begin
      count <= '0';
      case cs is
         when zero =>
            debounced_int <= '0';
            if pin_reg2 = '1' then
               count <= '1';
            end if;
         when up =>
            debounced_int <= '0';
            if counter = (counter'range => '1') then
            elsif pin_reg2 = '1' then
               count <= '1';
            end if;
         when one =>
            debounced_int <= '1';
            if pin_reg2 = '0' then
               count <= '1';
            end if;
         when down =>
            debounced_int <= '1';
            if counter = (counter'range => '1') then
            elsif pin_reg2 = '0' then
               count <= '1';
            end if;
         when others =>
            if resetdefault = '1' then
               debounced_int <= '1';
            else
               debounced_int <= '0';
            end if;
      end case;
   end process;
   
end architecture rtl;
