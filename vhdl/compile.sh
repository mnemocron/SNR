#!/usr/bin/bash

ghdl --version | head -n 1

# delete
rm -rf *.vcd &
rm -rf *.cf &

# analyze
ghdl -a -fsynopsys tb_export_sinewave.vhd
ghdl -a axis_sample_viewer.vhd

# elaborate
ghdl -e -fsynopsys tb_export_sinewave

# run
ghdl -r -fsynopsys tb_export_sinewave --vcd=wave.vcd --stop-time=100us
gtkwave wave.vcd waveform.gtkw

# delete
rm -rf *.vcd &
rm -rf *.cf &
