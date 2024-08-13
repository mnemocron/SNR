----------------------------------------------------------------------------------
-- Company:        
-- Engineer:       simon.burkhardt
-- 
-- Create Date:    
-- Design Name:    
-- Module Name:    
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_export_sinewave is
  generic
  (
    SAMPLE_WIDTH             : natural := 8;
    N_SAMPLES_PER_TRANSATION : natural := 4;
    N_SAMPLES_IN_FILE        : natural := 10000
  );
end tb_export_sinewave;

architecture bh of tb_export_sinewave is
  constant S_AXIS_TDATA_WIDTH   : natural := N_SAMPLES_PER_TRANSATION * SAMPLE_WIDTH;
  constant CLK_PERIOD: TIME := 5 ns;

  component axis_sample_viewer is
    generic (
      N_SAMPLES           : integer;
      SAMPLE_WIDTH        : integer;
      PADDED_SAMPLE_WIDTH : integer;
      BIT_OFFSET          : integer;
      VIRTUAL_PERIOD      : time
    );
    port (
      s_axis_tdata  : in std_logic_vector((N_SAMPLES * PADDED_SAMPLE_WIDTH) - 1 downto 0);
      s_axis_tvalid : in std_logic;
      sample        : out std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
      aclk          : in std_logic
    );
  end component;

  signal clk_count : unsigned(31 downto 0) := (others => '0');
  signal aclk     : std_logic := '0';
  signal areset_n : std_logic := '0';

  signal s_axis_tdata : std_logic_vector(S_AXIS_TDATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_axis_tvalid : std_logic := '0';
  signal s_axis_tready : std_logic := '0';
  signal view_sample : std_logic_vector(SAMPLE_WIDTH - 1 downto 0) := (others => '0');

  signal valid_ready : std_logic := '0';
  signal write_en    : std_logic := '0';

  file output_sample_file : text;

begin

  -- clk generator
  p_clk_gen : process
  begin
   wait for (CLK_PERIOD / 2);
   aclk <= '1';
   wait for (CLK_PERIOD / 2);
   aclk <= '0';
   clk_count <= clk_count + 1;
  end process;

  -- initial reset
  p_reset_gen : process
  begin 
    areset_n <= '0';
    wait until rising_edge(aclk);
    wait for (CLK_PERIOD / 4);
    areset_n <= '1';
    wait;
  end process;

  p_flow_control : process(aclk)
  begin
    if rising_edge(aclk) then
      if clk_count = 10 then
        s_axis_tready <= '1';
      end if;
      if clk_count = (N_SAMPLES_IN_FILE/N_SAMPLES_PER_TRANSATION)+10 then
        s_axis_tready <= '0';
      end if;
    end if;
  end process;

  p_wave_stimuli : process
      variable t_pp : real := 0.0;
      variable f : real := 100000.0;
      variable a : real := 0.999;
      variable x : real := 0.0;
      variable sample : std_logic_vector(SAMPLE_WIDTH - 1 downto 0) := (others => '0');
  begin
      wait until areset_n = '1';
      wait until rising_edge(aclk);
      
      while true loop
          wait until rising_edge(aclk);
          for ii in 0 to N_SAMPLES_PER_TRANSATION - 1 loop
              x := a*sin(2.0 * math_pi * f * t_pp);
          
              sample := std_logic_vector(to_signed(integer(round(x * (2.0 ** real(SAMPLE_WIDTH - 1) - 1.0))), SAMPLE_WIDTH));
              s_axis_tdata(ii * SAMPLE_WIDTH + SAMPLE_WIDTH - 1 downto ii * SAMPLE_WIDTH) <= sample;

              if areset_n = '0' then
                  t_pp := 0.0;
              elsif s_axis_tready = '1' then
                  t_pp := t_pp + 5.0e-9;
              end if;
              s_axis_tvalid <= '1';
          end loop;
      end loop;
      wait;
  end process;

  valid_ready <= s_axis_tvalid AND s_axis_tready;

  sample_viewer : axis_sample_viewer
    generic map (
        N_SAMPLES           => N_SAMPLES_PER_TRANSATION,
        SAMPLE_WIDTH        => SAMPLE_WIDTH,
        PADDED_SAMPLE_WIDTH => SAMPLE_WIDTH,
        BIT_OFFSET          => 0,
        VIRTUAL_PERIOD      => CLK_PERIOD/N_SAMPLES_PER_TRANSATION
    )
    port map (
        s_axis_tdata  => s_axis_tdata,
        s_axis_tvalid => valid_ready,
        sample        => view_sample,
        aclk          => aclk
    );


  process(aclk) begin
    if rising_edge(aclk) then
      write_en <= s_axis_tready;
    end if;
  end process;

  p_file_writer : process
    variable output_line : line;
  begin
    wait until rising_edge(s_axis_tready);
    file_open(output_sample_file, "values.txt", write_mode);

    while write_en = '1' or s_axis_tready = '1' loop
      wait on view_sample;
      write(output_line, view_sample, right, SAMPLE_WIDTH);
      writeline(output_sample_file, output_line);
    end loop;

    file_close(output_sample_file);
  end process;

end bh;
