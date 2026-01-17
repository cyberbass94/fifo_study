----------------------------------------------------------------------------------
-- Company: Personal
-- Engineer: Berk Erbas
-- 
-- Create Date: 01/06/2026 11:07:41 PM
-- Design Name: dual_port_ram_w32_d2048
-- Module Name: dual_port_ram_w32_d2048 - Structural
-- Project Name: homemade_fifo
-- Target Devices: KR260
-- Tool Versions: Vivado 2024.2.1
-- 
-- Description: 
-- This module implements a 2048x32-bit dual-port RAM by combining four 
-- RAMB18E2 blocks (via the ramb18e2_fifo_standard wrapper). 
-- It uses both width and depth expansion:
-- 1. Width Expansion: Two 16-bit blocks are used in parallel to achieve a 32-bit 
--    data width (LSB and MSB halves).
-- 2. Depth Expansion: Each 16-bit half uses two RAMB18E2 blocks cascaded 
--    vertically to increase depth from 1024 to 2048 entries.
--
-- Configuration Settings & Rationale:
-- 1. Memory Organization:
--    - Total Capacity: 2048 words of 32 bits each.
--    - Physical Implementation: 4x RAMB18E2 configured in 18-bit mode (16 bits used).
-- 2. Addressing:
--    - Address width: 11 bits (ADDR[10:0]).
--    - ADDR[10]: Used as a bank select signal (via rd_en/wr_en and cascade mux).
--    - ADDR[9:0]: Passed to the individual RAM blocks for internal indexing.
-- 3. Data Flow:
--    - Read Port: Asynchronous reading from cascaded blocks. Output is selected 
--      based on the cascade chain.
--    - Write Port: Selective writing to the appropriate bank based on ADDR[10].
-- 4. Cascading:
--    - Vertical cascading is used to minimize logic outside the BRAMs for depth expansion.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity dual_port_ram_w32_d2048 is
  port (
    -- Read Port (Port A)
    rd_clk_i  : in std_logic;
    rd_en_i   : in std_logic;
    rd_rst_i  : in std_logic;
    rd_addr_i : in std_logic_vector(10 downto 0);
    rd_data_o : out std_logic_vector(31 downto 0);

    -- Write Port (Port B)
    wr_clk_i  : in std_logic;
    wr_en_i   : in std_logic;
    wr_rst_i  : in std_logic;
    wr_addr_i : in std_logic_vector(10 downto 0);
    wr_data_i : in std_logic_vector(31 downto 0)
  );
end dual_port_ram_w32_d2048;

architecture Structural of dual_port_ram_w32_d2048 is
  signal casdout_1_lsb              : std_logic_vector(15 downto 0);
  signal casdout_1_msb              : std_logic_vector(15 downto 0);
  signal wr_en_1, wr_en_2           : std_logic;
  signal rd_en_1, rd_en_2           : std_logic;
  signal casdomux_2                 : std_logic;
  signal data_out_lsb, data_out_msb : std_logic_vector(15 downto 0);

  component ramb18e2_fifo_standard is
    generic (
      CASCADE_ORDER : string := "FIRST"
    );
    port (
      rd_clk_i   : in std_logic;
      rd_en_i    : in std_logic;
      rd_rst_i   : in std_logic;
      rd_addr_i  : in std_logic_vector(9 downto 0);
      rd_data_o  : out std_logic_vector(15 downto 0);
      wr_clk_i   : in std_logic;
      wr_en_i    : in std_logic;
      wr_rst_i   : in std_logic;
      wr_addr_i  : in std_logic_vector(9 downto 0);
      wr_data_i  : in std_logic_vector(15 downto 0);
      casdomux_i : in std_logic;
      casdin_i   : in std_logic_vector(15 downto 0);
      casdout_o  : out std_logic_vector(15 downto 0)
    );
  end component;

begin
  -- Logic gates for bank selection
  wr_en_1    <= (wr_en_i and (not wr_addr_i(10)));
  wr_en_2    <= wr_en_i and wr_addr_i(10);
  rd_en_1    <= (rd_en_i and (not rd_addr_i(10)));
  rd_en_2    <= rd_en_i and rd_addr_i(10);
  casdomux_2 <= (not rd_addr_i(10));

  -- Final 32-bit word assembly
  rd_data_o <= data_out_msb & data_out_lsb;

  ---------------------------------------------------------
  -- LSB COLUMN (Bits 15:0)
  ---------------------------------------------------------
  BRAM_1_lsb : ramb18e2_fifo_standard
  generic map(CASCADE_ORDER => "FIRST")
  port map
  (
    rd_clk_i   => rd_clk_i,
    rd_en_i    => rd_en_1,
    rd_rst_i   => rd_rst_i,
    rd_addr_i  => rd_addr_i(9 downto 0),
    rd_data_o  => open,
    wr_clk_i   => wr_clk_i,
    wr_en_i    => wr_en_1,
    wr_rst_i   => wr_rst_i,
    wr_addr_i  => wr_addr_i(9 downto 0),
    wr_data_i  => wr_data_i(15 downto 0),
    casdomux_i => '0',
    casdin_i => (others => '0'),
    casdout_o  => casdout_1_lsb
  );

  BRAM_2_lsb : ramb18e2_fifo_standard
  generic map(CASCADE_ORDER => "LAST")
  port map
  (
    rd_clk_i   => rd_clk_i,
    rd_en_i    => rd_en_2,
    rd_rst_i   => rd_rst_i,
    rd_addr_i  => rd_addr_i(9 downto 0),
    rd_data_o  => data_out_lsb,
    wr_clk_i   => wr_clk_i,
    wr_en_i    => wr_en_2,
    wr_rst_i   => wr_rst_i,
    wr_addr_i  => wr_addr_i(9 downto 0),
    wr_data_i  => wr_data_i(15 downto 0),
    casdomux_i => casdomux_2,
    casdin_i   => casdout_1_lsb,
    casdout_o  => open
  );

  ---------------------------------------------------------
  -- MSB COLUMN (Bits 31:16)
  ---------------------------------------------------------
  BRAM_1_msb : ramb18e2_fifo_standard
  generic map(CASCADE_ORDER => "FIRST")
  port map
  (
    rd_clk_i   => rd_clk_i,
    rd_en_i    => rd_en_1,
    rd_rst_i   => rd_rst_i,
    rd_addr_i  => rd_addr_i(9 downto 0),
    rd_data_o  => open,
    wr_clk_i   => wr_clk_i,
    wr_en_i    => wr_en_1,
    wr_rst_i   => wr_rst_i,
    wr_addr_i  => wr_addr_i(9 downto 0),
    wr_data_i  => wr_data_i(31 downto 16),
    casdomux_i => '0',
    casdin_i => (others => '0'),
    casdout_o  => casdout_1_msb
  );

  BRAM_2_msb : ramb18e2_fifo_standard
  generic map(CASCADE_ORDER => "LAST")
  port map
  (
    rd_clk_i   => rd_clk_i,
    rd_en_i    => rd_en_2,
    rd_rst_i   => rd_rst_i,
    rd_addr_i  => rd_addr_i(9 downto 0),
    rd_data_o  => data_out_msb,
    wr_clk_i   => wr_clk_i,
    wr_en_i    => wr_en_2,
    wr_rst_i   => wr_rst_i,
    wr_addr_i  => wr_addr_i(9 downto 0),
    wr_data_i  => wr_data_i(31 downto 16),
    casdomux_i => casdomux_2,
    casdin_i   => casdout_1_msb,
    casdout_o  => open
  );

end Structural;
