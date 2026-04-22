connect_debug_port u_ila_0/probe1 [get_nets [list {i2c_mac/write_counter[0]} {i2c_mac/write_counter[1]} {i2c_mac/write_counter[2]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list i2c_mac/drive_scl_high]]


connect_debug_port u_ila_0/probe0 [get_nets [list i2s_data_OBUF]]
connect_debug_port u_ila_0/probe1 [get_nets [list i2s_word_clk_OBUF]]
connect_debug_port u_ila_0/probe2 [get_nets [list i2s_bit_clk_OBUF]]

