----------------------------------------------------------------------------------
-- company: 
-- engineer: 
-- 
-- create date: 
-- design name: 
-- module name: 
-- project name: 
-- target devices: 
-- tool versions: 
-- description: 
-- 
-- dependencies: 
-- 
-- revision:
-- revision 0.01 - file created
-- additional comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package axis_sample_viewer_pkg is
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
end axis_sample_viewer_pkg;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_sample_viewer is
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
end axis_sample_viewer;

architecture behavioral of axis_sample_viewer is
    signal value : signed(SAMPLE_WIDTH - 1 downto 0) := (others => '0');
begin
    process
        variable data : std_logic_vector(s_axis_tdata'range) := (others => '0');
    begin
        wait until rising_edge(aclk);
        if s_axis_tvalid = '1' then
            data := s_axis_tdata;
            for ii in 0 to N_SAMPLES - 1 loop
                value <= signed(data(ii * PADDED_SAMPLE_WIDTH + BIT_OFFSET + SAMPLE_WIDTH - 1 downto ii * PADDED_SAMPLE_WIDTH + BIT_OFFSET));
                wait for VIRTUAL_PERIOD;
            end loop;
        end if;
    end process;

    sample <= std_logic_vector(value);
end behavioral;
