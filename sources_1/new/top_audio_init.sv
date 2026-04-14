`timescale 1ns / 1ps
module top_audio_init (
    input  logic  sys_clk_p,
    input  logic  sys_clk_n,
    input  logic  pb_rst,
    input logic tone_switch_in,
    
    inout  logic  i2c_sda,
    output logic  i2c_scl,
    output logic codec_rst_n,
    
    output logic init_error,
    output logic init_done,

    output logic i2s_master_clock,
    output logic i2s_word_clk,
    output logic i2s_bit_clk,
    output logic i2s_data,

    output logic a_on,
    output logic b_on

);

    logic sys_clk;
    logic sys_rst_n;
    logic clk_locked;
    logic mhz24_clk;
    // Convert Differential 100MHz clock to Single-Ended
    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("TRUE")
    ) ibufds_sys_clk (
        .O(sys_clk),
        .I(sys_clk_p),
        .IB(sys_clk_n)
    );

    clk_wiz_0 audio_clock_gen (
        .clk_in1(sys_clk),       // Feed it the 100MHz system clock
        .reset(~sys_rst_n),      // Default Vivado IP reset is active-high
        .clk_out1(mhz24_clk),    // Our new 24.576 MHz clock
        .locked(clk_locked)      // Goes HIGH when 24.576 MHz is stable
    );

    assign sys_rst_n = ~pb_rst; 
    assign codec_rst_n = sys_rst_n & clk_locked;
    assign i2s_master_clock = mhz24_clk & clk_locked;

    assign b_on = ~tone_switch_in;
    assign a_on = tone_switch_in;

    I2Controller i2c_mac (
        .master_clock(sys_clk),
        .reset_n(codec_rst_n),
        .SDA(i2c_sda),
        .SCL(i2c_scl),
        .error(init_error),
        .done(init_done)
    );

    logic i2c_init_done_meta;
    (* mark_debug = "true" *) logic i2c_init_done_sync;

    always_ff @(posedge mhz24_clk) begin
        if (!sys_rst_n) begin
            i2c_init_done_meta <= 0;
            i2c_init_done_sync <= 0;
        end else begin
            i2c_init_done_meta <= init_done;        
            i2c_init_done_sync <= i2c_init_done_meta;   
        end
    end
    i2s_streamout i2s_controller (
        .master(i2s_master_clock),
        .lr_clk(i2s_word_clk),
        .s_clk(i2s_bit_clk),
        .s_data(i2s_data),
        .ready(i2c_init_done_sync & clk_locked),
        .tone_switch(tone_switch_in)
    );

endmodule