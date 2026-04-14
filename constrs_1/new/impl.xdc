set_clock_groups -asynchronous -group [get_clocks sys_clk_pin] -group [get_clocks clk_out1_clk_wiz_0]

connect_debug_port u_ila_0/probe1 [get_nets [list {i2c_mac/write_counter[0]} {i2c_mac/write_counter[1]} {i2c_mac/write_counter[2]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list i2c_mac/drive_scl_high]]

