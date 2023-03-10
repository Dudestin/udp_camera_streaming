# This file is generated by Anlogic Timing Wizard. 04 09 2022

#Created Clock
create_clock -name raw_clock -period 41.666 -waveform {0 20.833} [get_ports {clk}]
create_clock -name phy0_ref_clk -period 20 -waveform {0 10} [get_ports {PHY_REF_CLK}]
#create_clock -name phy1_ref_clk -period 20 -waveform {0 10} [get_ports {PHY_REF_CLK[1]}]
#create_clock -name phy2_ref_clk -period 20 -waveform {0 10} [get_ports {PHY_REF_CLK[2]}]
#create_clock -name phy3_ref_clk -period 20 -waveform {0 10} [get_ports {PHY_REF_CLK[3]}]

#Derive PLL Clocks
derive_pll_clocks -gen_basic_clock

#Set Input/Output Delay
set_input_delay -clock phy0_ref_clk -min 2 [get_ports {PHY_CRSDV} {PHY_RXD[0]} {PHY_RXD[1]}]
#set_input_delay -clock phy1_ref_clk -min 2 [get_ports {PHY_CRS_DV[1]} {PHY_RXD0[1]} {PHY_RXD1[1]}]
#set_input_delay -clock phy2_ref_clk -min 2 [get_ports {PHY_CRS_DV[2]} {PHY_RXD0[2]} {PHY_RXD1[2]}]
#set_input_delay -clock phy3_ref_clk -min 2 [get_ports {PHY_CRS_DV[3]} {PHY_RXD0[3]} {PHY_RXD1[3]}]
set_output_delay -clock phy0_ref_clk -min 2 [get_ports {PHY_TXD[0]} {PHY_TXD[1]} {PHY_TXEN}]
set_output_delay -clock phy0_ref_clk -max 16 [get_ports {PHY_TXD[0]} {PHY_TXD[1]} {PHY_TXEN}]
#set_output_delay -clock phy1_ref_clk -min 2 [get_ports {PHY_TXD0[1]} {PHY_TXD1[1]} {PHY_TXEN[1]}]
#set_output_delay -clock phy1_ref_clk -max 16 [get_ports {PHY_TXD0[1]} {PHY_TXD1[1]} {PHY_TXEN[1]}]
#set_output_delay -clock phy2_ref_clk -min 2 [get_ports {PHY_TXD0[2]} {PHY_TXD1[2]} {PHY_TXEN[2]}]
#set_output_delay -clock phy2_ref_clk -max 16 [get_ports {PHY_TXD0[2]} {PHY_TXD1[2]} {PHY_TXEN[2]}]
#set_output_delay -clock phy3_ref_clk -min 2 [get_ports {PHY_TXD0[3]} {PHY_TXD1[3]} {PHY_TXEN[3]}]
#set_output_delay -clock phy3_ref_clk -max 16 [get_ports {PHY_TXD0[3]} {PHY_TXD1[3]} {PHY_TXEN[3]}]

#Set Clock Groups
set_clock_groups -asynchronous -group [get_clocks {raw_clock}] -group [get_clocks {phy0_ref_clk}]

