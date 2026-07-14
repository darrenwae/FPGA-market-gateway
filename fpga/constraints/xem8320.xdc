#############################################################################
## XEM8320 - Xilinx constraints file
##
## Pin mappings for the XEM8320.  Use this as a template and comment out 
## the pins that are not used in your design.  (By default, map will fail
## if this file contains constraints for signals not in your design).
##
## Copyright (c) 2004-2022 Opal Kelly Incorporated
#############################################################################

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS True [current_design]

#############################################################################
### FrontPanel Host Interface
#############################################################################
#set_property PACKAGE_PIN U20 [get_ports {okHU[0]}]
#set_property PACKAGE_PIN U26 [get_ports {okHU[1]}]
#set_property PACKAGE_PIN T22 [get_ports {okHU[2]}]
#set_property SLEW FAST [get_ports {okHU[*]}]
#set_property IOSTANDARD LVCMOS18 [get_ports {okHU[*]}]

#set_property PACKAGE_PIN V23 [get_ports {okUH[0]}]
#set_property PACKAGE_PIN T23 [get_ports {okUH[1]}]
#set_property PACKAGE_PIN U22 [get_ports {okUH[2]}]
#set_property PACKAGE_PIN U25 [get_ports {okUH[3]}]
#set_property PACKAGE_PIN U21 [get_ports {okUH[4]}]
#set_property IOSTANDARD LVCMOS18 [get_ports {okUH[*]}]

#set_property PACKAGE_PIN P26 [get_ports {okUHU[0]}]
#set_property PACKAGE_PIN P25 [get_ports {okUHU[1]}]
#set_property PACKAGE_PIN R26 [get_ports {okUHU[2]}]
#set_property PACKAGE_PIN R25 [get_ports {okUHU[3]}]
#set_property PACKAGE_PIN R23 [get_ports {okUHU[4]}]
#set_property PACKAGE_PIN R22 [get_ports {okUHU[5]}]
#set_property PACKAGE_PIN P21 [get_ports {okUHU[6]}]
#set_property PACKAGE_PIN P20 [get_ports {okUHU[7]}]
#set_property PACKAGE_PIN R21 [get_ports {okUHU[8]}]
#set_property PACKAGE_PIN R20 [get_ports {okUHU[9]}]
#set_property PACKAGE_PIN P23 [get_ports {okUHU[10]}]
#set_property PACKAGE_PIN N23 [get_ports {okUHU[11]}]
#set_property PACKAGE_PIN T25 [get_ports {okUHU[12]}]
#set_property PACKAGE_PIN N24 [get_ports {okUHU[13]}]
#set_property PACKAGE_PIN N22 [get_ports {okUHU[14]}]
#set_property PACKAGE_PIN V26 [get_ports {okUHU[15]}]
#set_property PACKAGE_PIN N19 [get_ports {okUHU[16]}]
#set_property PACKAGE_PIN V21 [get_ports {okUHU[17]}]
#set_property PACKAGE_PIN N21 [get_ports {okUHU[18]}]
#set_property PACKAGE_PIN W20 [get_ports {okUHU[19]}]
#set_property PACKAGE_PIN W26 [get_ports {okUHU[20]}]
#set_property PACKAGE_PIN W19 [get_ports {okUHU[21]}]
#set_property PACKAGE_PIN Y25 [get_ports {okUHU[22]}]
#set_property PACKAGE_PIN Y26 [get_ports {okUHU[23]}]
#set_property PACKAGE_PIN Y22 [get_ports {okUHU[24]}]
#set_property PACKAGE_PIN V22 [get_ports {okUHU[25]}]
#set_property PACKAGE_PIN W21 [get_ports {okUHU[26]}]
#set_property PACKAGE_PIN AA23 [get_ports {okUHU[27]}]
#set_property PACKAGE_PIN Y23 [get_ports {okUHU[28]}]
#set_property PACKAGE_PIN AA24 [get_ports {okUHU[29]}]
#set_property PACKAGE_PIN W25 [get_ports {okUHU[30]}]
#set_property PACKAGE_PIN AA25 [get_ports {okUHU[31]}]
#set_property SLEW FAST [get_ports {okUHU[*]}]
#set_property IOSTANDARD LVCMOS18 [get_ports {okUHU[*]}]

#set_property PACKAGE_PIN T19 [get_ports {okAA}]
#set_property IOSTANDARD LVCMOS18 [get_ports {okAA}]


#create_clock -name okUH0 -period 9.920 [get_ports {okUH[0]}]

#set_input_delay -add_delay -max -clock [get_clocks {okUH0}]  8.000 [get_ports {okUH[*]}]
#set_input_delay -add_delay -min -clock [get_clocks {okUH0}]  9.920 [get_ports {okUH[*]}]

#set_input_delay -add_delay -max -clock [get_clocks {okUH0}]  7.000 [get_ports {okUHU[*]}]
#set_input_delay -add_delay -min -clock [get_clocks {okUH0}]  2.000 [get_ports {okUHU[*]}]

#set_output_delay -add_delay -max -clock [get_clocks {okUH0}]  2.000 [get_ports {okHU[*]}]
#set_output_delay -add_delay -min -clock [get_clocks {okUH0}]  -0.500 [get_ports {okHU[*]}]

#set_output_delay -add_delay -max -clock [get_clocks {okUH0}]  2.000 [get_ports {okUHU[*]}]
#set_output_delay -add_delay -min -clock [get_clocks {okUH0}]  -0.500 [get_ports {okUHU[*]}]


#############################################################################
### System Clock (Fabric)
#############################################################################
set_property PACKAGE_PIN T24 [get_ports {sys_clk_p}]
set_property IOSTANDARD LVDS [get_ports {sys_clk_p}]

set_property PACKAGE_PIN U24 [get_ports {sys_clk_n}]
set_property IOSTANDARD LVDS [get_ports {sys_clk_n}]

set_property DIFF_TERM FALSE [get_ports {sys_clk_p}]

create_clock -name sys_clk -period 10.000 [get_ports sys_clk_p]
#set_clock_groups -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks {mmcm0_clk0 okUH0}]


############################################################################
## 156.25 MHz GTY Reference Clock — XEM8320 Rev CXX
############################################################################
set_property PACKAGE_PIN Y7 [get_ports {gt_refclk_p}]
set_property PACKAGE_PIN Y6 [get_ports {gt_refclk_n}]

create_clock -name gt_refclk -period 6.400 [get_ports {gt_refclk_p}]

#############################################################################
### DDR4 RefClk
#############################################################################
#set_property PACKAGE_PIN AD20 [get_ports {ddr4_refclkp}]
#set_property IOSTANDARD LVDS [get_ports {ddr4_refclkp}]

#set_property PACKAGE_PIN AE20 [get_ports {ddr4_refclkn}]
#set_property IOSTANDARD LVDS [get_ports {ddr4_refclkn}]

#set_property DIFF_TERM FALSE [get_ports {ddr4_refclkp}]

#create_clock -name ddr4_refclk -period 10 [get_ports ddr4_refclkp]
#set_clock_groups -asynchronous -group [get_clocks {ddr4_refclk}] -group [get_clocks {mmcm0_clk0 okUH0}]

#############################################################################
### BOARD_READY Signal
#############################################################################
#set_property PACKAGE_PIN P19 [get_ports {board_ready}]
#set_property IOSTANDARD LVCMOS18 [get_ports {board_ready}]
#set_property SLEW FAST [get_ports {board_ready}]


## PORTA-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-4 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-5 
#set_property PACKAGE_PIN L18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-6 
#set_property PACKAGE_PIN M25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-7 
#set_property PACKAGE_PIN K18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-8 
#set_property PACKAGE_PIN M26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-9 
#set_property PACKAGE_PIN M20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-10 
#set_property PACKAGE_PIN L24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-11 
#set_property PACKAGE_PIN M21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-12 
#set_property PACKAGE_PIN L25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-13 
#set_property PACKAGE_PIN J19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-14 
#set_property PACKAGE_PIN K25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-15 
#set_property PACKAGE_PIN J20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-16 
#set_property PACKAGE_PIN K26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-17 
#set_property PACKAGE_PIN L22 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-18 
#set_property PACKAGE_PIN K22 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-19 
#set_property PACKAGE_PIN L23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-20 
#set_property PACKAGE_PIN K23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-21 
#set_property PACKAGE_PIN H24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-22 
#set_property PACKAGE_PIN L19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-23 
#set_property PACKAGE_PIN J21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-24 
#set_property PACKAGE_PIN M19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-25 
#set_property PACKAGE_PIN H23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-26 
#set_property PACKAGE_PIN L20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-27 
#set_property PACKAGE_PIN K21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-28 
#set_property PACKAGE_PIN K20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-29 
#set_property PACKAGE_PIN F24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-30 
#set_property PACKAGE_PIN J26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-31 
#set_property PACKAGE_PIN F25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-32 
#set_property PACKAGE_PIN J25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-33 
#set_property PACKAGE_PIN J23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-34 
#set_property PACKAGE_PIN H26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-35 
#set_property PACKAGE_PIN J24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-36 
#set_property PACKAGE_PIN G26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-37 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-38 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-39 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTA-40 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-4 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-5 
#set_property PACKAGE_PIN A22 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-6 
#set_property PACKAGE_PIN A24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-7 
#set_property PACKAGE_PIN A23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-8 
#set_property PACKAGE_PIN A25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-9 
#set_property PACKAGE_PIN E21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-10 
#set_property PACKAGE_PIN D24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-11 
#set_property PACKAGE_PIN D21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-12 
#set_property PACKAGE_PIN D25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-13 
#set_property PACKAGE_PIN E25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-14 
#set_property PACKAGE_PIN C23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-15 
#set_property PACKAGE_PIN E26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-16 
#set_property PACKAGE_PIN B24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-17 
#set_property PACKAGE_PIN F23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-18 
#set_property PACKAGE_PIN C21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-19 
#set_property PACKAGE_PIN E23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-20 
#set_property PACKAGE_PIN B21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-21 
#set_property PACKAGE_PIN D26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-22 
#set_property PACKAGE_PIN C26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-23 
#set_property PACKAGE_PIN B26 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-24 
#set_property PACKAGE_PIN B25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-25 
#set_property PACKAGE_PIN D23 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-26 
#set_property PACKAGE_PIN C24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-27 
#set_property PACKAGE_PIN B20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-28 
#set_property PACKAGE_PIN C22 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-29 
#set_property PACKAGE_PIN B22 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-30 
#set_property PACKAGE_PIN A20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-31 
#set_property PACKAGE_PIN D20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-32 
#set_property PACKAGE_PIN G21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-33 
#set_property PACKAGE_PIN G24 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-34 
#set_property PACKAGE_PIN H21 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-35 
#set_property PACKAGE_PIN G25 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-36 
#set_property PACKAGE_PIN H22 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-37 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-38 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-39 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTB-40 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-4 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-5 
#set_property PACKAGE_PIN F20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-6 
#set_property PACKAGE_PIN C18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-7 
#set_property PACKAGE_PIN E20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-8 
#set_property PACKAGE_PIN C19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-9 
#set_property PACKAGE_PIN H18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-10 
#set_property PACKAGE_PIN H17 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-11 
#set_property PACKAGE_PIN H19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-12 
#set_property PACKAGE_PIN G17 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-13 
#set_property PACKAGE_PIN F18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-14 
#set_property PACKAGE_PIN A17 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-15 
#set_property PACKAGE_PIN F19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-16 
#set_property PACKAGE_PIN A18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-17 
#set_property PACKAGE_PIN E16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-18 
#set_property PACKAGE_PIN B15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-19 
#set_property PACKAGE_PIN E17 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-20 
#set_property PACKAGE_PIN A15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-21 
#set_property PACKAGE_PIN A19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-22 
#set_property PACKAGE_PIN B19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-23 
#set_property PACKAGE_PIN H16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-24 
#set_property PACKAGE_PIN D16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-25 
#set_property PACKAGE_PIN D19 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-26 
#set_property PACKAGE_PIN E15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-27 
#set_property PACKAGE_PIN G20 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-28 
#set_property PACKAGE_PIN C16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-29 
#set_property PACKAGE_PIN G16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-30 
#set_property PACKAGE_PIN F15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-31 
#set_property PACKAGE_PIN G15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-32 
#set_property PACKAGE_PIN D15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-33 
#set_property PACKAGE_PIN E18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-34 
#set_property PACKAGE_PIN C17 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-35 
#set_property PACKAGE_PIN D18 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-36 
#set_property PACKAGE_PIN B17 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-37 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-38 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-39 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTC-40 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-4 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-5 
#set_property PACKAGE_PIN J12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-6 
#set_property PACKAGE_PIN W12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-7 
#set_property PACKAGE_PIN H12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-8 
#set_property PACKAGE_PIN W13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-9 
#set_property PACKAGE_PIN Y13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-10 
#set_property PACKAGE_PIN H14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-11 
#set_property PACKAGE_PIN AA13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-12 
#set_property PACKAGE_PIN G14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-13 
#set_property PACKAGE_PIN J13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-14 
#set_property PACKAGE_PIN AF14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-15 
#set_property PACKAGE_PIN H13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-16 
#set_property PACKAGE_PIN AF15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-17 
#set_property PACKAGE_PIN AE13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-18 
#set_property PACKAGE_PIN AC13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-19 
#set_property PACKAGE_PIN AF13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-20 
#set_property PACKAGE_PIN AC14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-21 
#set_property PACKAGE_PIN J14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-22 
#set_property PACKAGE_PIN J15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-23 
#set_property PACKAGE_PIN W14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-24 
#set_property PACKAGE_PIN Y15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-25 
#set_property PACKAGE_PIN AB16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-26 
#set_property PACKAGE_PIN W15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-27 
#set_property PACKAGE_PIN AB15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-28 
#set_property PACKAGE_PIN AE15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-29 
#set_property PACKAGE_PIN AA15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-30 
#set_property PACKAGE_PIN AD15 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-31 
#set_property PACKAGE_PIN Y16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-32 
#set_property PACKAGE_PIN W16 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-33 
#set_property PACKAGE_PIN AA14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-34 
#set_property PACKAGE_PIN AD13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-35 
#set_property PACKAGE_PIN AB14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-36 
#set_property PACKAGE_PIN AD14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-37 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-38 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-39 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTD-40 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-4 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-5 
#set_property PACKAGE_PIN AF2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-6 
#set_property PACKAGE_PIN AF7 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-7 
#set_property PACKAGE_PIN AF1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-8 
#set_property PACKAGE_PIN AF6 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-9 
#set_property PACKAGE_PIN AE4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-10 
#set_property PACKAGE_PIN AE9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-11 
#set_property PACKAGE_PIN AE3 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-12 
#set_property PACKAGE_PIN AE8 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-13 
#set_property PACKAGE_PIN AB7 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-14 
#set_property PACKAGE_PIN H9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-15 
#set_property PACKAGE_PIN AB6 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-16 
#set_property PACKAGE_PIN J9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-17 
#set_property PACKAGE_PIN J10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-18 
#set_property PACKAGE_PIN H11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-19 
#set_property PACKAGE_PIN K9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-20 
#set_property PACKAGE_PIN G9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-21 
#set_property PACKAGE_PIN K10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-22 
#set_property PACKAGE_PIN G10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-23 
#set_property PACKAGE_PIN J11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-24 
#set_property PACKAGE_PIN G11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-25 
#set_property PACKAGE_PIN AB2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-26 
#set_property PACKAGE_PIN AC5 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-27 
#set_property PACKAGE_PIN AB1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-28 
#set_property PACKAGE_PIN AC4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-29 
#set_property PACKAGE_PIN AD2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-30 
#set_property PACKAGE_PIN AD7 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-31 
#set_property PACKAGE_PIN AD1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-32 
#set_property PACKAGE_PIN AD6 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-33 
#set_property PACKAGE_PIN E11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-34 
#set_property PACKAGE_PIN F10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-35 
#set_property PACKAGE_PIN E10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-36 
#set_property PACKAGE_PIN F9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-37 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-38 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-39 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTE-40 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-4 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-5 
#set_property PACKAGE_PIN Y2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-6 
#set_property PACKAGE_PIN AA5 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-7 
#set_property PACKAGE_PIN Y1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-8 
#set_property PACKAGE_PIN AA4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-9 
#set_property PACKAGE_PIN V2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-10 
#set_property PACKAGE_PIN W5 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-11 
#set_property PACKAGE_PIN V1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-12 
#set_property PACKAGE_PIN W4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-13 
#set_property PACKAGE_PIN V7 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-14 
#set_property PACKAGE_PIN B9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-15 
#set_property PACKAGE_PIN V6 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-16 
#set_property PACKAGE_PIN A10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-17 
#set_property PACKAGE_PIN B10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-18 
#set_property PACKAGE_PIN A9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-19 
#set_property PACKAGE_PIN D9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-20 
#set_property PACKAGE_PIN C9 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-21 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-22 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-23 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-24 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-25 
#set_property PACKAGE_PIN P2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-26 
#set_property PACKAGE_PIN R5 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-27 
#set_property PACKAGE_PIN P1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-28 
#set_property PACKAGE_PIN R4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-29 
#set_property PACKAGE_PIN T2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-30 
#set_property PACKAGE_PIN U5 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-31 
#set_property PACKAGE_PIN T1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-32 
#set_property PACKAGE_PIN U4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-33 
#set_property PACKAGE_PIN D11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-34 
#set_property PACKAGE_PIN C11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-35 
#set_property PACKAGE_PIN D10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-36 
#set_property PACKAGE_PIN B11 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-37 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-38 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-39 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## PORTF-40 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-1 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-2 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-3 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-4 
#set_property PACKAGE_PIN AB10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-5 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-6 
#set_property PACKAGE_PIN AE12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-7 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-8 
#set_property PACKAGE_PIN Y10 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-9 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-10 
#set_property PACKAGE_PIN AB12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-11 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-12 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-13 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J3-14 
#set_property PACKAGE_PIN  [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J13-2 
#set_property PACKAGE_PIN C14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J13-3 
set_property PACKAGE_PIN C13 [get_ports {sfp_tx_disable[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J13-4 
#set_property PACKAGE_PIN B12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J13-5 
#set_property PACKAGE_PIN C12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J13-6 
#set_property PACKAGE_PIN D14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J13-7 
set_property PACKAGE_PIN D13 [get_ports {sfp_rate_select_0[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J13-8 
#set_property PACKAGE_PIN E13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J13-9 
set_property PACKAGE_PIN E12 [get_ports {sfp_rate_select_1[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J13-12 
set_property PACKAGE_PIN M1 [get_ports {sfp_rx_n[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J13-13 
set_property PACKAGE_PIN M2 [get_ports {sfp_rx_p[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J13-18 
set_property PACKAGE_PIN N5 [get_ports {sfp_tx_p[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J13-19 
set_property PACKAGE_PIN N4 [get_ports {sfp_tx_n[0]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-2 
#set_property PACKAGE_PIN F14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J14-3 
set_property PACKAGE_PIN F13 [get_ports {sfp_tx_disable[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-4 
#set_property PACKAGE_PIN F12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J14-5 
#set_property PACKAGE_PIN G12 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J14-6 
#set_property PACKAGE_PIN A14 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J14-7 
set_property PACKAGE_PIN B14 [get_ports {sfp_rate_select_0[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-8 
#set_property PACKAGE_PIN A13 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J14-9 
set_property PACKAGE_PIN A12 [get_ports {sfp_rate_select_1[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-12 
set_property PACKAGE_PIN K1 [get_ports {sfp_rx_n[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-13 
set_property PACKAGE_PIN K2 [get_ports {sfp_rx_p[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-18 
set_property PACKAGE_PIN L5 [get_ports {sfp_tx_p[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J14-19 
set_property PACKAGE_PIN L4 [get_ports {sfp_tx_n[1]}]
#set_property IOSTANDARD  [get_ports {}]
## J15-1 
#set_property PACKAGE_PIN H2 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J16-1 
#set_property PACKAGE_PIN H1 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J17-1 
#set_property PACKAGE_PIN J5 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J18-1 
#set_property PACKAGE_PIN J4 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J19-1 
#set_property PACKAGE_PIN M7 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]
## J20-1 
#set_property PACKAGE_PIN M6 [get_ports {}]
#set_property IOSTANDARD  [get_ports {}]

set_property IOSTANDARD LVCMOS33 [get_ports {sfp_tx_disable[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp_rate_select_0[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp_rate_select_1[*]}]

## LEDs #####################################################################
#set_property PACKAGE_PIN G19 [get_ports {led[0]}]
#set_property PACKAGE_PIN B16 [get_ports {led[1]}]
#set_property PACKAGE_PIN F22 [get_ports {led[2]}]
#set_property PACKAGE_PIN E22 [get_ports {led[3]}]
#set_property PACKAGE_PIN M24 [get_ports {led[4]}]
#set_property PACKAGE_PIN G22 [get_ports {led[5]}]
#set_property IOSTANDARD LVCMOS12 [get_ports {led[*]}]

## Flash ####################################################################
## The STARTUPE3 (see UG570) primitive must be used to interface with the FPGA flash
## See the following for more information: https://docs.opalkelly.com/xem8320/flash-memory/

## DRAM #####################################################################
#set_property PACKAGE_PIN AF22 [ get_ports "ddr4_cs_n[0]" ]
#set_property PACKAGE_PIN AA20 [ get_ports "ddr4_cke[0]" ]
#set_property PACKAGE_PIN AB20 [ get_ports "ddr4_odt[0]" ]
#set_property PACKAGE_PIN AE26 [ get_ports "ddr4_reset_n" ]
#set_property PACKAGE_PIN Y18 [ get_ports "ddr4_act_n" ]
#set_property PACKAGE_PIN AB19 [ get_ports "ddr4_bg[0]" ]
#set_property PACKAGE_PIN Y20 [ get_ports "ddr4_ck_t[0]" ]
#set_property PACKAGE_PIN Y21 [ get_ports "ddr4_ck_c[0]" ]
#set_property PACKAGE_PIN AD26 [ get_ports "ddr4_dqs_c[0]" ]
#set_property PACKAGE_PIN AB22 [ get_ports "ddr4_dqs_c[1]" ]
#set_property PACKAGE_PIN AC26 [ get_ports "ddr4_dqs_t[0]" ]
#set_property PACKAGE_PIN AA22 [ get_ports "ddr4_dqs_t[1]" ]
#set_property PACKAGE_PIN AE25 [ get_ports "ddr4_dm[0]" ]
#set_property PACKAGE_PIN AE22 [ get_ports "ddr4_dm[1]" ]
#set_property PACKAGE_PIN AC18 [ get_ports "ddr4_ba[0]" ]
#set_property PACKAGE_PIN AF18 [ get_ports "ddr4_ba[1]" ]
#set_property PACKAGE_PIN AD18 [ get_ports "ddr4_addr[0]" ]
#set_property PACKAGE_PIN AE17 [ get_ports "ddr4_addr[1]" ]
#set_property PACKAGE_PIN AB17 [ get_ports "ddr4_addr[2]" ]
#set_property PACKAGE_PIN AE18 [ get_ports "ddr4_addr[3]" ]
#set_property PACKAGE_PIN AD19 [ get_ports "ddr4_addr[4]" ]
#set_property PACKAGE_PIN AF17 [ get_ports "ddr4_addr[5]" ]
#set_property PACKAGE_PIN Y17 [ get_ports "ddr4_addr[6]" ]
#set_property PACKAGE_PIN AE16 [ get_ports "ddr4_addr[7]" ]
#set_property PACKAGE_PIN AA17 [ get_ports "ddr4_addr[8]" ]
#set_property PACKAGE_PIN AC17 [ get_ports "ddr4_addr[9]" ]
#set_property PACKAGE_PIN AC19 [ get_ports "ddr4_addr[10]" ]
#set_property PACKAGE_PIN AC16 [ get_ports "ddr4_addr[11]" ]
#set_property PACKAGE_PIN AF20 [ get_ports "ddr4_addr[12]" ]
#set_property PACKAGE_PIN AD16 [ get_ports "ddr4_addr[13]" ]
#set_property PACKAGE_PIN AA19 [ get_ports "ddr4_addr[14]" ]
#set_property PACKAGE_PIN AF19 [ get_ports "ddr4_addr[15]" ]
#set_property PACKAGE_PIN AA18 [ get_ports "ddr4_addr[16]" ]
#set_property PACKAGE_PIN AF24 [ get_ports "ddr4_dq[0]" ]
#set_property PACKAGE_PIN AB25 [ get_ports "ddr4_dq[1]" ]
#set_property PACKAGE_PIN AB26 [ get_ports "ddr4_dq[2]" ]
#set_property PACKAGE_PIN AC24 [ get_ports "ddr4_dq[3]" ]
#set_property PACKAGE_PIN AF25 [ get_ports "ddr4_dq[4]" ]
#set_property PACKAGE_PIN AB24 [ get_ports "ddr4_dq[5]" ]
#set_property PACKAGE_PIN AD24 [ get_ports "ddr4_dq[6]" ]
#set_property PACKAGE_PIN AD25 [ get_ports "ddr4_dq[7]" ]
#set_property PACKAGE_PIN AB21 [ get_ports "ddr4_dq[8]" ]
#set_property PACKAGE_PIN AE21 [ get_ports "ddr4_dq[9]" ]
#set_property PACKAGE_PIN AE23 [ get_ports "ddr4_dq[10]" ]
#set_property PACKAGE_PIN AD23 [ get_ports "ddr4_dq[11]" ]
#set_property PACKAGE_PIN AC23 [ get_ports "ddr4_dq[12]" ]
#set_property PACKAGE_PIN AD21 [ get_ports "ddr4_dq[13]" ]
#set_property PACKAGE_PIN AC22 [ get_ports "ddr4_dq[14]" ]
#set_property PACKAGE_PIN AC21 [ get_ports "ddr4_dq[15]" ]
