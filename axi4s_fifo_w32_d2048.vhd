----------------------------------------------------------------------------------
-- Company: Personal
-- Engineer: Berk Erbas
-- 
-- Create Date: 01/11/2026 10:09:38 PM
-- Design Name: axi4s_fifo_w32_d2048
-- Module Name: axi4s_fifo_w32_d2048 - Dataflow
-- Project Name: homemade_fifo
-- Target Devices: KR260
-- Tool Versions: Vivado 2024.2.1
-- 
-- Description: 
-- This module implements an AXI4-Stream wrapper for the 2048x32-bit 
-- asynchronous FIFO. It provides standard TREADY and TVALID handshaking 
-- on both slave (input) and master (output) interfaces.
--
-- Configuration Settings & Rationale:
-- 1. Handshake Logic:
--    - Slave Interface (Write): axi4s_wr_ready_o is high when the FIFO is NOT full.
--    - Master Interface (Read): axi4s_rd_valid_o is high when the FIFO is NOT empty.
-- 2. Data Transfer:
--    - Data is written to the FIFO on the rising edge of axi4s_wr_clk_i if 
--      axi4s_wr_valid_i and axi4s_wr_ready_o are both '1'.
--    - Data is read from the FIFO on the rising edge of axi4s_rd_clk_i if 
--      axi4s_rd_valid_o and axi4s_rd_ready_i are both '1'.
-- 3. Architecture:
--    - Wraps the fifo_w32_d2048 component using combinatorial logic for 
--      handshake status signals.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity axi4s_fifo_w32_d2048 is
  port (
    axi4s_wr_data_i  : in std_logic_vector (31 downto 0);
    axi4s_wr_valid_i : in std_logic;
    axi4s_wr_ready_o : out std_logic;
    axi4s_wr_clk_i   : in std_logic;
    axi4s_rd_data_o  : out std_logic_vector (31 downto 0);
    axi4s_rd_valid_o : out std_logic;
    axi4s_rd_ready_i : in std_logic;
    axi4s_rd_clk_i   : in std_logic;
    rst_i            : in std_logic
  );
end axi4s_fifo_w32_d2048;

architecture Behavioral of axi4s_fifo_w32_d2048 is
  signal wr_en, rd_en : std_logic;
  signal full, empty  : std_logic;
  signal data_out_reg : std_logic_vector(31 downto 0);
  signal wait_cnt     : integer range 0 to 3 := 0;

  type state_type is (EMPTY_BUFF, WAITING_FOR_DATA, WITH_DATA);
  signal state : state_type := EMPTY_BUFF;

  component fifo_w32_d2048 is
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
  end component;

begin
  wr_en            <= axi4s_wr_valid_i and (not full);
  axi4s_wr_ready_o <= not full;
  axi4s_rd_data_o  <= data_out_reg;
  axi4s_rd_valid_o <= '1' when state = WITH_DATA else
    '0';

  FWFT_process : process (axi4s_rd_clk_i, rst_i)
  begin
    if rst_i = '1' then
      state    <= EMPTY_BUFF;
      rd_en    <= '0';
      wait_cnt <= 0;
    elsif rising_edge(axi4s_rd_clk_i) then
      case state is
        when EMPTY_BUFF =>
          if empty = '0' then
            rd_en    <= '1'; -- Fire read to pre-fetch the first word
            wait_cnt <= 2; -- Wait 2 cycles for registered rd_en + BRAM latency
            state    <= WAITING_FOR_DATA;
          else
            rd_en    <= '0';
            state    <= EMPTY_BUFF;
            wait_cnt <= 0;
          end if;

        when WAITING_FOR_DATA =>
          rd_en <= '0';
          if wait_cnt > 1 then
            wait_cnt <= wait_cnt - 1;
            state    <= WAITING_FOR_DATA;
          else
            state    <= WITH_DATA;
            wait_cnt <= 2;
          end if;

          --TODO: FIX this mass from ai. Think about latency when read is initiated and add that. AI is shit here

        when WITH_DATA =>
          if axi4s_rd_ready_i = '1' then
            -- Slave took the current word. Can we pre-fetch the next one?
            if empty = '0' then
              rd_en    <= '1';
              wait_cnt <= 2; -- Wait 2 cycles for registered rd_en + BRAM latency
              state    <= WAITING_FOR_DATA;
            else
              rd_en <= '0';
              state <= EMPTY_BUFF;
            end if;
          else
            rd_en <= '0';
            state <= WITH_DATA;
          end if;
      end case;
    end if;
  end process;

  fifo_inst : fifo_w32_d2048
  port map
  (
    clk_rd_i  => axi4s_rd_clk_i,
    clk_wr_i  => axi4s_wr_clk_i,
    rst_i     => rst_i,
    wr_en_i   => wr_en,
    rd_en_i   => rd_en,
    wr_data_i => axi4s_wr_data_i,
    rd_data_o => data_out_reg,
    full_o    => full,
    empty_o   => empty
  );
end Behavioral;
