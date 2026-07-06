`timescale 1ns / 1ps

module top_audio_init (
    input  logic sys_clk_p,
    input  logic sys_clk_n,
    input  logic system_rst,
    input  logic serial_clk,
    input  logic word_clk,
    
    inout  logic i2c_sda,
    output logic i2c_scl,
    output logic codec_rst_n,
    
    output logic init_error,
    output logic init_done,

    output logic i2s_master_clock,
    output logic [7:0]instruction_leds,
    output logic serial_i2s_in,
    output logic serial_i2s_out
);

    logic sys_clk;
    logic sys_rst_n;
    logic clk_locked;
    logic mhz24_clk;
    logic i2c_write_done;

    logic [15:0] read_data;
    logic [15:0] filter_output;
    logic output_ready;
    logic read_done;
    
    // Convert Differential 100MHz clock to Single-Ended
    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("TRUE")
    ) ibufds_sys_clk (
        .O(sys_clk),
        .I(sys_clk_p),
        .IB(sys_clk_n)
    );
    //50 Mhz clock for I2S
    logic [1:0] mclk_counter = 0;

    always_ff @(posedge sys_clk) begin
        mclk_counter <= mclk_counter + 1;
    end

    assign i2s_master_clock = mclk_counter[1];
    assign sys_rst_n = ~system_rst; 
    assign codec_rst_n = sys_rst_n;
    assign init_done = i2c_write_done;
    // I2C Controller running on the 100MHz system clock
    I2Controller i2c_mac (
        .master_clock(sys_clk),
        .reset_n(sys_rst_n),
        .SDA(i2c_sda),
        .SCL(i2c_scl),
        .error(init_error),
        .done(i2c_write_done),
        .instr(instruction_leds)
    );
    FilterController combfilter(
        .sclk(serial_clk),
        .wclk(word_clk),
        .in_data(read_data),
        .read_done(read_done),
        .rst_n(sys_rst_n),
        .out_data(filter_output),
        .output_ready(output_ready),
        .ready(i2c_write_done)
    );
    I2SREAD read_stage(
        .wclk(word_clk),
        .sclk(serial_clk),
        .datain(serial_i2s_out),
        .dataout(read_data),
        .read_done(read_done),
        .rst_n(sys_rst_n),
        .ready(i2c_write_done)
    );
    i2s_streamout write_stage(
        .wclk(word_clk),
        .sclk(serial_clk),
        .input_data(filter_output),
        .rst_n(sys_rst_n),
        .ready(i2c_write_done),
        .read_done(read_done),
        .data_out_bit(serial_i2s_in)
    );
endmodule