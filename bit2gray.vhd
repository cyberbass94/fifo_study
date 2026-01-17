----------------------------------------------------------------------------------
-- Company: Personal
-- Engineer: Berk Erbas
-- 
-- Create Date: 01/10/2026 02:01:21 PM
-- Design Name: bit2gray
-- Module Name: bit2gray - Dataflow
-- Project Name: homemade_fifo
-- Target Devices: KR260
-- Tool Versions: Vivado 2024.2.1
-- 
-- Description: 
-- This module implements a parameterized binary to Gray code converter.
-- It uses a concurrent for-generate loop to XOR each bit with its 
-- more significant neighbor to produce the Gray code output.
--
-- Configuration Settings & Rationale:
-- 1. Parameterization: 
--    - BIT_SIZE: Generic width for the input and output vectors.
-- 2. Logic Implementation:
--    - gray_out(i) = bit_in(i) XOR bit_in(i+1) for i in 0 to BIT_SIZE-2.
--    - gray_out(BIT_SIZE-1) = bit_in(BIT_SIZE-1).
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity bit2gray is
  generic (
    BIT_SIZE : integer := 8
  );
  port (
    bit_in   : in std_logic_vector(BIT_SIZE - 1 downto 0);
    gray_out : out std_logic_vector(BIT_SIZE - 1 downto 0)
  );
end bit2gray;

architecture Dataflow of bit2gray is

begin
  bit2gray_loop : for i in 0 to BIT_SIZE - 2 generate
    gray_out(i) <= bit_in(i) xor bit_in(i + 1);
  end generate;
  
  gray_out(BIT_SIZE - 1) <= bit_in(BIT_SIZE - 1);
end Dataflow;
