`timescale 1ns / 1ps

module top_audio_init (
    input  logic sys_clk_p,
    input  logic sys_clk_n,
    input  logic system_rst,
    
    inout  logic i2c_sda,
    output logic i2c_scl,
    output logic codec_rst_n,
    
    output logic init_error,
    output logic init_done,

    output logic i2s_master_clock,
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

    //12.5 Mhz clock
    logic [2:0] mclk_counter = 0;

    always_ff @(posedge sys_clk) begin
        mclk_counter <= mclk_counter + 1;
    end

    assign i2s_master_clock = mclk_counter[2];


    assign sys_rst_n = ~system_rst; 
    
    assign codec_rst_n = sys_rst_n;
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
endmodule