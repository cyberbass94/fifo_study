----------------------------------------------------------------------------------
-- Company: Personal
-- Engineer: Berk Erbas
-- 
-- Create Date: 12/28/2025 04:54:05 PM
-- Design Name: ramb18e2_fifo_standard
-- Module Name: ramb18e2_fifo_standard - Structural
-- Project Name: homemade_fifo
-- Target Devices: KR260
-- Tool Versions: Vivado 2024.2.1
-- 
-- Description: 
-- This module is a wrapper for the RAMB18E2 primitive, specifically configured 
-- for use in a FIFO. It supports vertical cascading using the Standard Data 
-- Output Cascade Mode for an 18-bit data width as per UG573.
--
-- Configuration Settings & Rationale:
-- 1. Port Usage: 
--    - Port A: Dedicated for Read operations.
--    - Port B: Dedicated for Write operations.
-- 2. Data Width: 18 bits (Standard Cascade Mode). 
--    - READ_WIDTH_A = 18, WRITE_WIDTH_B = 18.
--    - Input/Output data vectors are 16 bits, parity/CRC pins are tied off as 
--      they are not used. Actual BRAM width is 18 bits.
-- 3. Cascading:
--    - Enabled via CASCADE_ORDER generic ("FIRST", "MIDDLE", "LAST").
--    - Allows multiple RAMB18E2 blocks to be stacked to increase depth.
-- 4. Clocking:
--    - CLOCK_DOMAINS = "INDEPENDENT" to support asynchronous FIFO operation 
--      with separate read and write clocks.
-- 5. Latency:
--    - DOA_REG = 0, DOB_REG = 0 to minimize read latency.
-- 6. Addressing:
--    - For 18-bit width, addresses are mapped to ADDR[13:4].
--    - Inputs are shifted 4 bits (e.g., rd_addr_i & "0000").
-- 7. Write Mode:
--    - WRITE_MODE_A = "READ_FIRST" (Read Port).
--    - WRITE_MODE_B = "NO_CHANGE" (Write Port, power efficient).
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

library UNISIM;
use UNISIM.VComponents.all;

entity ramb18e2_fifo_standard is
  generic (
    CASCADE_ORDER : string := "FIRST"
  );
  port (
    -- Read Port (Port A)
    rd_clk_i  : in std_logic;
    rd_en_i   : in std_logic;
    rd_rst_i  : in std_logic;
    rd_addr_i : in std_logic_vector(9 downto 0);
    rd_data_o : out std_logic_vector(15 downto 0);

    -- Write Port (Port B)
    wr_clk_i  : in std_logic;
    wr_en_i   : in std_logic;
    wr_rst_i  : in std_logic;
    wr_addr_i : in std_logic_vector(9 downto 0);
    wr_data_i : in std_logic_vector(15 downto 0);

    -- Cascade Signals
    casdomux_i : in std_logic;
    casdin_i   : in std_logic_vector(15 downto 0);
    casdout_o  : out std_logic_vector(15 downto 0)
  );
end ramb18e2_fifo_standard;

architecture Structural of ramb18e2_fifo_standard is
  signal rd_addr_padded : std_logic_vector(13 downto 0);
  signal wr_addr_padded : std_logic_vector(13 downto 0);

begin
  rd_addr_padded <= rd_addr_i & "0000";
  wr_addr_padded <= wr_addr_i & "0000";

  BRAM_INST : RAMB18E2
  generic map(
    CASCADE_ORDER_A     => CASCADE_ORDER,
    CASCADE_ORDER_B     => "NONE",
    CLOCK_DOMAINS       => "INDEPENDENT",
    SIM_COLLISION_CHECK => "ALL",
    DOA_REG             => 0,
    DOB_REG             => 0,
    ENADDRENA           => "TRUE",
    ENADDRENB           => "TRUE",

    -- Data Width Settings (18-bit mode)
    READ_WIDTH_A  => 18,
    WRITE_WIDTH_A => 0,
    READ_WIDTH_B  => 0,
    WRITE_WIDTH_B => 18,

    -- Reset and Write Modes
    RSTREG_PRIORITY_A => "RSTREG",
    RSTREG_PRIORITY_B => "RSTREG",
    WRITE_MODE_A      => "READ_FIRST",
    WRITE_MODE_B      => "NO_CHANGE",

    -- Initialization (All zeros)
    INIT_A    => X"00000",
    INIT_B    => X"00000",
    SRVAL_A   => X"00000",
    SRVAL_B   => X"00000",
    INIT_FILE => "NONE",

    -- Programmable Inversion Attributes
    IS_CLKARDCLK_INVERTED     => '0',
    IS_CLKBWRCLK_INVERTED     => '0',
    IS_ENARDEN_INVERTED       => '0',
    IS_ENBWREN_INVERTED       => '0',
    IS_RSTRAMARSTRAM_INVERTED => '0',
    IS_RSTRAMB_INVERTED       => '0',
    IS_RSTREGARSTREG_INVERTED => '0',
    IS_RSTREGB_INVERTED       => '0',

    RDADDRCHANGEA => "FALSE",
    RDADDRCHANGEB => "FALSE",
    SLEEP_ASYNC   => "FALSE"
  )
  port map
  (
    -- Registered/Unregistered Cascade Outputs
    CASDOUTA  => casdout_o,
    CASDOUTB  => open,
    CASDOUTPA => open,
    CASDOUTPB => open,

    -- Data Outputs
    DOUTADOUT   => rd_data_o,
    DOUTPADOUTP => open,
    DOUTBDOUT   => open,
    DOUTPBDOUTP => open,

    -- Cascade Inputs
    CASDIMUXA => '0',
    CASDIMUXB => '0',
    CASDINA   => casdin_i,
    CASDINB => (others => '0'),
    CASDINPA => (others => '0'),
    CASDINPB => (others => '0'),

    -- Cascade Mux Control
    CASDOMUXA       => casdomux_i,
    CASDOMUXB       => '0',
    CASDOMUXEN_A    => '1',
    CASDOMUXEN_B    => '1',
    CASOREGIMUXA    => '0',
    CASOREGIMUXB    => '0',
    CASOREGIMUXEN_A => '0',
    CASOREGIMUXEN_B => '0',

    -- Port A: Read Interface
    ADDRARDADDR   => rd_addr_padded,
    ADDRENA       => '1',
    CLKARDCLK     => rd_clk_i,
    ENARDEN       => rd_en_i,
    REGCEAREGCE   => '0',
    RSTRAMARSTRAM => rd_rst_i,
    RSTREGARSTREG => '0',
    WEA           => "00",
    DINADIN => (others => '0'),
    DINPADINP => (others => '0'),

    -- Port B: Write Interface
    ADDRBWRADDR => wr_addr_padded,
    ADDRENB     => '1',
    CLKBWRCLK   => wr_clk_i,
    ENBWREN     => wr_en_i,
    REGCEB      => '0',
    RSTRAMB     => wr_rst_i,
    RSTREGB     => '0',
    WEBWE       => "1111",
    DINBDIN     => wr_data_i,
    DINPBDINP => (others => '0'),

    SLEEP => '0'
  );

end Structural;