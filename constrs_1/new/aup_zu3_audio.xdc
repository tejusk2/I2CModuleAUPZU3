# -------------------------------------------------------------------------
# Clock Constraints (100MHz LVDS on PL)
# -------------------------------------------------------------------------
set_property IOSTANDARD LVDS [get_ports sys_clk_p]

set_property PACKAGE_PIN D7 [get_ports sys_clk_p]
set_property PACKAGE_PIN D6 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports sys_clk_p]

# -------------------------------------------------------------------------
# Reset Button (PL_USER_PB0)
# -------------------------------------------------------------------------
set_property PACKAGE_PIN AB6 [get_ports codec_rst]
set_property IOSTANDARD LVCMOS12 [get_ports codec_rst]

set_property PACKAGE_PIN AB7 [get_ports system_rst]
set_property IOSTANDARD LVCMOS12 [get_ports system_rst]

# -------------------------------------------------------------------------
# Audio Codec Interface (Bank LVCMOS18)
# -------------------------------------------------------------------------
set_property PACKAGE_PIN F5 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS18 [get_ports i2c_scl]
set_property PULLTYPE PULLUP [get_ports i2c_scl]

set_property PACKAGE_PIN G5 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS18 [get_ports i2c_sda]
set_property PULLTYPE PULLUP [get_ports i2c_sda]

# AIC_nRST pin
set_property PACKAGE_PIN E2 [get_ports codec_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports codec_rst_n]

# -------------------------------------------------------------------------
# Status LED (PL_USER_LED0)
# -------------------------------------------------------------------------
set_property PACKAGE_PIN AD7 [get_ports init_error]
set_property IOSTANDARD LVCMOS12 [get_ports init_error]

set_property PACKAGE_PIN AG9 [get_ports init_done]
set_property IOSTANDARD LVCMOS12 [get_ports init_done]

set_property PACKAGE_PIN AF7 [get_ports a_on]
set_property IOSTANDARD LVCMOS12 [get_ports a_on]

set_property PACKAGE_PIN AF6 [get_ports b_on]
set_property IOSTANDARD LVCMOS12 [get_ports b_on]

set_property PACKAGE_PIN AF5 [get_ports instruction_leds[0]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[0]]

set_property PACKAGE_PIN AE7 [get_ports instruction_leds[1]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[1]]

set_property PACKAGE_PIN AH2 [get_ports instruction_leds[2]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[2]]

set_property PACKAGE_PIN AE5 [get_ports instruction_leds[3]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[3]]

set_property PACKAGE_PIN AH1 [get_ports instruction_leds[4]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[4]]

set_property PACKAGE_PIN AE4 [get_ports instruction_leds[5]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[5]]

set_property PACKAGE_PIN AG1 [get_ports instruction_leds[6]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[6]]

set_property PACKAGE_PIN AF2 [get_ports instruction_leds[7]]
set_property IOSTANDARD LVCMOS12 [get_ports instruction_leds[7]]

#I2S Outputs

set_property PACKAGE_PIN F3 [get_ports i2s_master_clock]
set_property IOSTANDARD LVCMOS18 [get_ports i2s_master_clock]

set_property PACKAGE_PIN F2 [get_ports i2s_word_clk]
set_property IOSTANDARD LVCMOS18 [get_ports i2s_word_clk]

set_property PACKAGE_PIN G1 [get_ports i2s_bit_clk]
set_property IOSTANDARD LVCMOS18 [get_ports i2s_bit_clk]

set_property PACKAGE_PIN G4 [get_ports i2s_data]
set_property IOSTANDARD LVCMOS18 [get_ports i2s_data]



#Switch
set_property PACKAGE_PIN AB1 [get_ports tone_switch_in]
set_property IOSTANDARD LVCMOS12 [get_ports tone_switch_in]


