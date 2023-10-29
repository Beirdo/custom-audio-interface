library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity adat_interface is
port(
  m_clk : in std_logic;
  adat0_bitclk_in : in std_logic;
  adat1_bitclk_in : in std_logic;

  adat0_in : in std_logic;
  adat0_user : out std_logic_vector(3 downto 0);
  adat0_bitclk_out : out std_logic;

  adat1_in : in std_logic;
  adat1_user : out std_logic_vector(3 downto 0);
  adat1_bitclk_out : out std_logic;

  bclk : out std_logic := '0';
  fsync : out std_logic := '0';
  tdm_data : out std_logic := '0'
 );
end adat_interface;

architecture behavioral of adat_interface is
 component ADAT_receiver
  port (
   m_clk : in std_logic;
   adat_in : in std_logic;

   adat_bitclk : out std_logic;
   adat_latch : out std_logic;
   adat_user : out std_logic_vector(3 downto 0); -- adat user bits
   adat_data_out : out std_logic_vector(191 downto 0)
  );
 end component;

 component pll
  PORT (
   areset	: IN STD_LOGIC  := '0';
   clkswitch	: IN STD_LOGIC  := '0';
   inclk0	: IN STD_LOGIC  := '0';
   inclk1	: IN STD_LOGIC  := '0';
   c0		: OUT STD_LOGIC ;
   locked	: OUT STD_LOGIC 
  );
 end component;

 signal pll_reset : std_logic := '0';
 signal pll_clkswitch : std_logic := '0';
 signal pll_locked : std_logic := '0';
 signal pll_clk_out : std_logic := '0';

 signal tdm_bitclk : std_logic := '0';
 signal tdm_bitcount : std_logic_vector(8 downto 0) := (others => '0');  -- goes from 0 to 383
 signal tdm_sr_latch : std_logic := '0';
 signal tdm_shift_reg : std_logic_vector(383 downto 0) := (others => '0');
 signal tdm_stage_reg : std_logic_vector(383 downto 0) := (others => '0');

 signal adat0_latch : std_logic := '0';
 signal adat0_data_out : std_logic_vector(191 downto 0) := (others => '0');

 signal adat1_latch : std_logic := '0';
 signal adat1_data_out : std_logic_vector(191 downto 0) := (others => '0');

begin

 tdm_pll : pll
  PORT MAP (
   areset	 => pll_reset,
   clkswitch	 => pll_clkswitch,
   inclk0	 => adat0_bitclk_in,
   inclk1	 => adat1_bitclk_in,
   c0	 	 => pll_clk_out,
   locked	 => pll_locked
  );

 tdm_bitclk <= pll_clk_out and pll_locked;
 bclk <= tdm_bitclk;
 
 adat0_receiver : ADAT_receiver
  port map (
   m_clk => m_clk,
   adat_in => adat0_in,

   adat_bitclk => adat0_bitclk_out,
   adat_latch => adat0_latch,
   adat_user => adat0_user,
   adat_data_out => adat0_data_out
  );

 latch_adat0 : process (adat0_latch, tdm_sr_latch)
 begin
  if adat0_latch'event and adat0_latch = '1' then
   tdm_stage_reg(383 downto 192) <= adat0_data_out;
  end if;
  if tdm_sr_latch = '1' then
   tdm_stage_reg(383 downto 192) <= (others => '0');
  end if;
 end process latch_adat0;


 adat1_receiver : ADAT_receiver
  port map (
   m_clk => m_clk,
   adat_in => adat1_in,

   adat_bitclk => adat1_bitclk_out,
   adat_latch => adat1_latch,
   adat_user => adat1_user,
   adat_data_out => adat1_data_out
  );

 latch_adat1 : process (adat1_latch, tdm_sr_latch)
 begin
  if adat1_latch'event and adat1_latch = '1' then
   tdm_stage_reg(191 downto 0) <= adat1_data_out;
  end if;
  if tdm_sr_latch = '1' then
   tdm_stage_reg(191 downto 0) <= (others => '0');
  end if;
 end process latch_adat1;
 
 tdm_bit_counter : process (tdm_bitclk, pll_locked)
 begin
  if tdm_bitclk'event and tdm_bitclk = '1' then
   if tdm_bitcount = "101111111" then -- 383
    tdm_sr_latch <= '1';
    tdm_bitcount <= (others => '0');
   else      
    tdm_sr_latch <= '0';
    tdm_bitcount <= tdm_bitcount + 1;
   end if;
  end if;
  if pll_locked = '0' then
   tdm_sr_latch <= '0';
	tdm_bitcount <= (others => '0');
  end if;
 end process tdm_bit_counter;
 
 fsync <= tdm_sr_latch and pll_locked;

 shift_tdm_data : process (tdm_bitclk)
 begin
  if tdm_bitclk'event and tdm_bitclk = '1' then
   tdm_data <= tdm_shift_reg(383);
   if tdm_sr_latch = '1' then
    tdm_shift_reg <= tdm_stage_reg;
   else
    tdm_shift_reg <= tdm_shift_reg(382 downto 0) & '0';
   end if;
  end if;
 end process shift_tdm_data;

end behavioral;

