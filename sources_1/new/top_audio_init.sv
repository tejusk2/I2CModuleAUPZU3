`timescale 1ns / 1ps

module top_audio_init (
    input  logic sys_clk_p,
    input  logic sys_clk_n,
    input  logic codec_rst,
    input  logic system_rst,
    input  logic tone_switch_in,
    
    inout  logic i2c_sda,
    output logic i2c_scl,
    output logic codec_rst_n,
    
    output logic init_error,
    output logic init_done,

    output logic i2s_master_clock,
    output logic i2s_word_clk,
    output logic i2s_bit_clk,
    output logic i2s_data,

    output logic a_on,
    output logic b_on,

    output logic [7:0]instruction_leds
);

    logic sys_clk;
    logic sys_rst_n;
    logic clk_locked;
    logic mhz24_clk;
    logic i2s_delay_done;
    
    // Convert Differential 100MHz clock to Single-Ended
    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("TRUE")
    ) ibufds_sys_clk (
        .O(sys_clk),
        .I(sys_clk_p),
        .IB(sys_clk_n)
    );

    logic [2:0] mclk_counter = 0;

    always_ff @(posedge sys_clk) begin
        mclk_counter <= mclk_counter + 1;
    end

    assign i2s_master_clock = mclk_counter[2];

    /*
    // Generate 24.576 MHz Audio Clock
    clk_wiz_0 audio_clock_gen (
        .clk_in1(sys_clk),       
        .reset(~sys_rst_n),      
        .clk_out1(mhz24_clk),    
        .locked(clk_locked)      
    );

    ODDRE1 #(
        .SRVAL(1'b0)
    ) mclk_forward_inst (
        .Q(i2s_master_clock),  // Drives the top-level output port directly
        .C(mhz24_clk),         
        .D1(1'b1),
        .D2(1'b0),
        .SR(~clk_locked)
    );
    */

    assign sys_rst_n = ~system_rst; 
    
    // Hold the codec in reset until the clock wizard is stable
    assign codec_rst_n = sys_rst_n;

    assign b_on = i2s_delay_done;
    assign a_on = tone_switch_in;

    // I2C Controller running on the 100MHz system clock
    I2Controller i2c_mac (
        .master_clock(sys_clk),
        .reset_n(sys_rst_n),
        .SDA(i2c_sda),
        .SCL(i2c_scl),
        .error(init_error),
        .done(init_done),
        .instr(instruction_leds)
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
        .master(mhz24_clk),                      
        .lr_clk(i2s_word_clk),
        .s_clk(i2s_bit_clk),
        .s_data(i2s_data),
        .ready(1'b0), // Only start after I2C is finished
        .tone_switch(tone_switch_in),
        .delay_over(i2s_delay_done)
    );

endmodule