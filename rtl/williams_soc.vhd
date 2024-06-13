-----------------------------------------------------------------------
--
-- A SOC-like top-level for robotron-fpga
-- (C) 2020 Slingshot
--
-- MC6809 Cycle-Accurate 6809 Core
-- (c) 2016, Greg Miller
--
-- Defender sound board by Dar (darfpga@aol.fr)
--
-- robotron-fpga is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- robotron-fpga is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- You should have received a copy of the GNU General
-- Public License along with robotron-fpga. If not, see
-- <http://www.gnu.org/licenses/>.
--
-----------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity williams_soc is
port (
	clock            : in    std_logic; -- 12MHz

	-- Cellular RAM / StrataFlash
	MemWR            : out   std_logic;

	RamCS            : out   std_logic;
	RamLB            : out   std_logic;
	RamUB            : out   std_logic;

	MemAdr           : out   std_logic_vector(15 downto 0);
	MemDin           : out   std_logic_vector(7 downto 0);
	MemDout          : in    std_logic_vector(7 downto 0);

	blitter_sc2      : in    std_logic;
	sinistar         : in    std_logic;
	sg_state         : out   std_logic;

	-- Switches
	SW               : in    std_logic_vector(7 downto 0);

	-- Buttons
	BTN              : in    std_logic_vector(3 downto 0);
	SIN_FIRE         : in    std_logic;
	SIN_BOMB         : in    std_logic;

	-- VGA connector
	vgaRed           : out   std_logic_vector(2 downto 0);
	vgaGreen         : out   std_logic_vector(2 downto 0);
	vgaBlue          : out   std_logic_vector(1 downto 0);
	Hsync            : out   std_logic;
	Vsync            : out   std_logic;

	-- Audio
	audio_out        : out   std_logic_vector(7 downto 0);
	speech_out       : out   std_logic_vector(15 downto 0);

	-- 12-pin connectors
	JA               : in    std_logic_vector(7 downto 0);
	JB               : in    std_logic_vector(7 downto 0);
	
	pause            : in    std_logic;
	
	dl_clock         : in    std_logic;
	dl_addr          : in    std_logic_vector(16 downto 0);
	dl_data          : in    std_logic_vector(7 downto 0);
	dl_wr            : in    std_logic;
	dl_upload        : in    std_logic
);
end williams_soc;

architecture Behavioral of williams_soc is

component mc6809is is
port (
	clk      : in  std_logic;
	D        : in  std_logic_vector( 7 downto 0);
	Dout     : out std_logic_vector( 7 downto 0);
	ADDR     : out std_logic_vector(15 downto 0);
	RnW      : out std_logic;
	E        : in  std_logic;
	Q        : in  std_logic;
	BS       : out std_logic;
	BA       : out std_logic;
	nIRQ     : in  std_logic := '1';
	nFIRQ    : in  std_logic := '1';
	nNMI     : in  std_logic := '1';
	AVMA     : out std_logic;
	BUSY     : out std_logic;
	LIC      : out std_logic;
	nHALT    : in  std_logic := '1';
	nRESET   : in  std_logic := '1';
	nDMABREQ : in  std_logic := '1'
);
end component mc6809is;

signal  cpu_a        : std_logic_vector(15 downto 0);
signal  cpu_dout     : std_logic_vector( 7 downto 0);
signal  cpu_din      : std_logic_vector( 7 downto 0);
signal  cpu_reset_n  : std_logic;
signal  cpu_nmi_n    : std_logic;
signal  cpu_firq_n   : std_logic;
signal  cpu_irq_n    : std_logic;
signal  cpu_lic      : std_logic;
signal  cpu_avma     : std_logic;
signal  cpu_rwn      : std_logic;
signal  cpu_halt_n   : std_logic;
signal  cpu_ba       : std_logic;
signal  cpu_bs       : std_logic;
signal  cpu_busy     : std_logic;
signal  cpu_e        : std_logic;
signal  cpu_q        : std_logic;

signal  hand         : std_logic;
signal  select_sound : std_logic_vector( 5 downto 0);

signal  snd_addr     : std_logic_vector(13 downto 0);
signal  snd_do       : std_logic_vector( 7 downto 0);
signal  spch_do      : std_logic_vector( 7 downto 0);
signal  snd_rom_we   : std_logic;
signal  spch_rom_we  : std_logic;

begin

mc6809: mc6809is
port map (
	clk              => not clock,
	ADDR             => cpu_a,
	Dout             => cpu_dout,
	D                => cpu_din,
	nReset           => cpu_reset_n,
	nNMI             => cpu_nmi_n,
	nFIRQ            => cpu_firq_n,
	nIRQ             => cpu_irq_n,
	LIC              => cpu_lic,
	AVMA             => cpu_avma,
	RnW              => cpu_rwn,
	nHALT            => cpu_halt_n and (not dl_upload) and (not pause),
	BA               => cpu_ba,
	BS               => cpu_bs,
	BUSY             => cpu_busy,
	E                => cpu_e,
	Q                => cpu_q
);

process (clock) 
begin
	if rising_edge(clock) then 
		if cpu_rwn = '0' and cpu_a = x"9C92" then
			if cpu_dout = X"FD" then
				sg_state <= '1';
			else
				sg_state <= '0';
			end if;
		end if;
	end if;
end process;

cpu_board: entity work.williams_cpu
port map (
	clock            => clock,
	blitter_sc2      => blitter_sc2,
	sinistar         => sinistar,

	A                => cpu_a,
	Dout             => cpu_dout,
	Din              => cpu_din,
	RESET_N          => cpu_reset_n,
	NMI_N            => cpu_nmi_n,
	FIRQ_N           => cpu_firq_n,
	IRQ_N            => cpu_irq_n,
	LIC              => cpu_lic,
	AVMA             => cpu_avma,
	R_W_N            => cpu_rwn,
	TSC              => open,
	HALT_N           => cpu_halt_n,
	BA               => cpu_ba,
	BS               => cpu_bs,
	BUSY             => cpu_busy,
	E                => cpu_e,
	Q                => cpu_q,

	-- Cellular RAM / StrataFlash
	MemWR            => MemWR,

	RamCS            => RamCS,
	RamLB            => RamLB,
	RamUB            => RamUB,

	MemAdr           => MemAdr,
	MemDin           => MemDin,
	MemDout          => MemDout,

        -- 7-segment display
--	SEG              => SEG,
--	DP               => DP,
--	AN               => AN,

	-- LEDs
--	LED              => LED,

	-- Switches
	SW               => SW,

	-- Buttons
	BTN              => BTN,
	SIN_FIRE         => SIN_FIRE,
	SIN_BOMB         => SIN_BOMB,

	-- VGA connector
	vgaRed           => vgaRed,
	vgaGreen         => vgaGreen,
	vgaBlue          => vgaBlue,
	Hsync            => Hsync,
	Vsync            => Vsync,

	-- 12-pin connectors
	JA               => JA,
	JB               => JB,
	
	-- Sound board
	PB               => select_sound,
	HAND             => hand,

	dl_clock         => dl_clock,
	dl_addr          => dl_addr,
	dl_data          => dl_data,
	dl_wr            => dl_wr
);

snd_rom : entity work.dualport_2clk_ram  --work.dpram generic map( dWidth => 8, aWidth => 12)
generic map 
(       
    FALLING_B    => TRUE,
    ADDR_WIDTH   => 12,
    DATA_WIDTH   => 8
)
port map(
	clock_a    => clock,
	address_a  => snd_addr(11 downto 0),
	q_a        => snd_do,
	
	clock_b    => dl_clock,
	wren_b     => snd_rom_we,
	address_b  => dl_addr(11 downto 0),
	data_b     => dl_data
);

spch_rom : entity work.dualport_2clk_ram -- work.dpram generic map( dWidth => 8, aWidth => 14)
generic map 
(       
    FALLING_B    => TRUE,
    ADDR_WIDTH   => 14,
    DATA_WIDTH   => 8
)
port map(
	clock_a    => clock,
	address_a  => snd_addr,
	q_a        => spch_do,
	
	clock_b    => dl_clock,
	wren_b     => spch_rom_we,
	address_b  => (dl_addr(13 downto 12) - "10") & dl_addr(11 downto 0),
	data_b     => dl_data
);

snd_rom_we  <= '1' when dl_wr = '1' and dl_addr(16 downto 12)  = x"C" else '0'; -- 0C000-0CFFF
spch_rom_we <= '1' when dl_wr = '1' and dl_addr(16 downto 12) >= x"E" else '0'; -- 0E000-11FFF

-- sound board
sound_board : entity work.williams_sound_board
port map(
	clock         => clock,
	reset         => not cpu_reset_n,
	hand          => hand,
	select_sound  => select_sound,
	audio_out     => audio_out,
	speech_out    => speech_out,
	rom_addr      => snd_addr,
	rom_do        => snd_do,
	spch_do		  => spch_do
);

end Behavioral;
