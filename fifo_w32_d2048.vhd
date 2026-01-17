----------------------------------------------------------------------------------
-- Company: Personal
-- Engineer: Berk Erbas
-- 
-- Create Date: 01/10/2026 03:02:22 PM
-- Design Name: fifo_w32_d2048
-- Module Name: fifo_w32_d2048 - Behavioral
-- Project Name: homemade_fifo
-- Target Devices: KR260
-- Tool Versions: Vivado 2024.2.1
-- 
-- Description: 
-- This module implements a 2048x32-bit asynchronous FIFO using Gray code 
-- pointers for safe clock domain crossing (CDC). It utilizes a structural 
-- dual-port RAM instantiation and a binary-to-gray converter.
--
-- Configuration Settings & Rationale:
-- 1. Pointer Logic:
--    - Uses 12-bit pointers (2048 depth + 1 extra bit) for Gray code conversion.
--    - Pointers are registered before CDC to ensure glitch-free synchronization.
-- 2. CDC Synchronization:
--    - 2-stage flip-flop synchronizers with ASYNC_REG attributes for metastability safety.
-- 3. Full/Empty Logic:
--    - Fast combinatorial detection for immediate status updates.
--    - Empty: Read Gray pointer matches the synchronized Write Gray pointer.
--    - Full: MSD and Second-MSD of Gray pointers differ, while LSBs match.
-- 4. Safety:
--    - Gated RAM enable signals (rd_en_gated, wr_en_gated) to prevent overflows.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity fifo_w32_d2048 is
  port (
    clk_rd_i  : in std_logic;
    clk_wr_i  : in std_logic;
    rst_i     : in std_logic;
    wr_en_i   : in std_logic;
    rd_en_i   : in std_logic;
    wr_data_i : in std_logic_vector(31 downto 0);
    rd_data_o : out std_logic_vector(31 downto 0);
    full_o    : out std_logic;
    empty_o   : out std_logic
  );
end fifo_w32_d2048;

architecture Behavioral of fifo_w32_d2048 is
  -- 12-bit pointers (Bit 11 is the lap bit, 10 downto 0 is the RAM address)
  signal wr_ptr_bin, rd_ptr_bin           : unsigned(11 downto 0) := (others => '0');
  signal wr_ptr_gray, rd_ptr_gray         : std_logic_vector(11 downto 0);
  signal wr_ptr_gray_reg, rd_ptr_gray_reg : std_logic_vector(11 downto 0);

  -- CDC Signals with Vivado attributes
  attribute ASYNC_REG                                       : string;
  signal wr_ptr_gray_cdc1, wr_ptr_gray_cdc2                 : std_logic_vector(11 downto 0);
  signal rd_ptr_gray_cdc1, rd_ptr_gray_cdc2                 : std_logic_vector(11 downto 0);
  signal rst_bridge_wr, rst_bridge_rd                       : std_logic;
  signal rst_wr, rst_rd                                     : std_logic;
  attribute ASYNC_REG of wr_ptr_gray_cdc1, wr_ptr_gray_cdc2 : signal is "TRUE";
  attribute ASYNC_REG of rd_ptr_gray_cdc1, rd_ptr_gray_cdc2 : signal is "TRUE";
  attribute ASYNC_REG of rst_bridge_wr, rst_wr              : signal is "TRUE";
  attribute ASYNC_REG of rst_bridge_rd, rst_rd              : signal is "TRUE";

  -- Internal signals for type conversion
  signal rd_addr_v                : std_logic_vector(10 downto 0);
  signal wr_addr_v                : std_logic_vector(10 downto 0);
  signal full, empty              : std_logic := '0';
  signal wr_en_gated, rd_en_gated : std_logic := '0';

  component bit2gray is
    generic (
      BIT_SIZE : integer := 8
    );
    port (
      bit_in   : in std_logic_vector(BIT_SIZE - 1 downto 0);
      gray_out : out std_logic_vector(BIT_SIZE - 1 downto 0)
    );
  end component;

  component dual_port_ram_w32_d2048 is
    port (
      rd_clk_i  : in std_logic;
      rd_en_i   : in std_logic;
      rd_rst_i  : in std_logic;
      rd_addr_i : in std_logic_vector(10 downto 0);
      rd_data_o : out std_logic_vector(31 downto 0);

      wr_clk_i  : in std_logic;
      wr_en_i   : in std_logic;
      wr_rst_i  : in std_logic;
      wr_addr_i : in std_logic_vector(10 downto 0);
      wr_data_i : in std_logic_vector(31 downto 0)
    );
  end component;

begin

  -- Address Mapping: Use the lower 11 bits for the RAM
  rd_addr_v <= std_logic_vector(rd_ptr_bin(10 downto 0));
  wr_addr_v <= std_logic_vector(wr_ptr_bin(10 downto 0));

  ---------------------------------------------------------
  -- READ DOMAIN
  ---------------------------------------------------------
  empty <= '1' when rd_ptr_gray = wr_ptr_gray_cdc2 else
    '0';
  empty_o     <= empty;
  rd_en_gated <= (rd_en_i = '1') and (empty = '0');

  read_process : process (clk_rd_i, rst_rd)
  begin
    if rst_rd = '1' then
      rd_ptr_bin <= (others => '0');
    elsif rising_edge(clk_rd_i) then
      -- Increment pointer only if enabled AND not empty
      if rd_en_gated = '1' then
        rd_ptr_bin <= rd_ptr_bin + 1;
      end if;
    end if;
  end process;

  ---------------------------------------------------------
  -- WRITE DOMAIN
  ---------------------------------------------------------
  -- Full logic for 12-bit Gray Code: 
  -- Top bit is inverted, remaining 10 bits match.
  full <= '1' when (wr_ptr_gray(11) /= rd_ptr_gray_cdc2(11)) and
    (wr_ptr_gray(10) /= rd_ptr_gray_cdc2(10)) and
    (wr_ptr_gray(9 downto 0) = rd_ptr_gray_cdc2(9 downto 0))
    else
    '0';
  full_o      <= full;
  wr_en_gated <= (wr_en_i = '1') and (full = '0');

  write_process : process (clk_wr_i, rst_wr)
  begin
    if rst_wr = '1' then
      wr_ptr_bin <= (others => '0');
    elsif rising_edge(clk_wr_i) then
      if wr_en_gated = '1' then -- Check internal full status
        wr_ptr_bin <= wr_ptr_bin + 1;
      end if;
    end if;
  end process;

  ---------------------------------------------------------
  -- CDC PROCESSES
  ---------------------------------------------------------
  write2read_cdc_process : process (clk_rd_i, rst_rd)
  begin
    if rst_rd = '1' then
      wr_ptr_gray_cdc1 <= (others => '0');
      wr_ptr_gray_cdc2 <= (others => '0');
    elsif rising_edge(clk_rd_i) then
      wr_ptr_gray_cdc1 <= wr_ptr_gray_reg;
      wr_ptr_gray_cdc2 <= wr_ptr_gray_cdc1;
    end if;
  end process;

  read2write_cdc_process : process (clk_wr_i, rst_wr)
  begin
    if rst_wr = '1' then
      rd_ptr_gray_cdc1 <= (others => '0');
      rd_ptr_gray_cdc2 <= (others => '0');
    elsif rising_edge(clk_wr_i) then
      rd_ptr_gray_cdc1 <= rd_ptr_gray_reg;
      rd_ptr_gray_cdc2 <= rd_ptr_gray_cdc1;
    end if;
  end process;

  reset_bridge_write : process (clk_wr_i, rst_i)
  begin
    if rst_i = '1' then
      rst_bridge_wr <= '1'; -- Async assertion
      rst_wr        <= '1';
    elsif rising_edge(clk_wr_i) then
      rst_bridge_wr <= '0'; -- Sync de-assertion
      rst_wr        <= rst_bridge_wr;
    end if;
  end process;
  reset_bridge_read : process (clk_rd_i, rst_i)
  begin
    if rst_i = '1' then
      rst_bridge_rd <= '1'; -- Async assertion
      rst_rd        <= '1';
    elsif rising_edge(clk_rd_i) then
      rst_bridge_rd <= '0'; -- Sync de-assertion
      rst_rd        <= rst_bridge_rd;
    end if;
  end process;

  ---------------------------------------------------------
  -- BIT TO GRAY CONVERTER INSTANCES
  ---------------------------------------------------------
  register_rd_ptr_gray : process (clk_rd_i, rst_i)
  begin
    if rst_i = '1' then
      rd_ptr_gray_reg <= (others => '0');
    elsif rising_edge(clk_rd_i) then
      rd_ptr_gray_reg <= rd_ptr_gray;
    end if;
  end process;

  register_wr_ptr_gray : process (clk_wr_i, rst_i)
  begin
    if rst_i = '1' then
      wr_ptr_gray_reg <= (others => '0');
    elsif rising_edge(clk_wr_i) then
      wr_ptr_gray_reg <= wr_ptr_gray;
    end if;
  end process;

  bit2gray_rd_ptr_inst : bit2gray
  generic map(
    BIT_SIZE => 12
  )
  port map
  (
    bit_in   => std_logic_vector(rd_ptr_bin),
    gray_out => rd_ptr_gray
  );

  bit2gray_wr_ptr_inst : bit2gray
  generic map(
    BIT_SIZE => 12
  )
  port map
  (
    bit_in   => std_logic_vector(wr_ptr_bin),
    gray_out => wr_ptr_gray
  );

  ---------------------------------------------------------
  -- RAM INSTANCE
  ---------------------------------------------------------
  dual_port_ram_inst : dual_port_ram_w32_d2048
  port map
  (
    rd_clk_i  => clk_rd_i,
    rd_en_i   => rd_en_gated,
    rd_rst_i  => rst_rd,
    rd_addr_i => rd_addr_v,
    rd_data_o => rd_data_o,

    wr_clk_i  => clk_wr_i,
    wr_en_i   => wr_en_gated,
    wr_rst_i  => rst_wr,
    wr_addr_i => wr_addr_v,
    wr_data_i => wr_data_i
  );
end Behavioral;
