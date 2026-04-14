`timescale 1ns / 1ps

module tb_i2s_streamout;

    // =====================================================
    // UUT Signals
    // =====================================================
    logic master_clk;
    logic ready;
    logic tone_switch;

    logic lr_clk;
    logic s_clk;
    logic s_data;

    // =====================================================
    // Instantiate the Unit Under Test (UUT)
    // =====================================================
    i2s_streamout uut (
        .master      (master_clk),
        .ready       (ready),
        .tone_switch (tone_switch),
        .lr_clk      (lr_clk),
        .s_clk       (s_clk),
        .s_data      (s_data)
    );

    // =====================================================
    // Clock Generation
    // 24.576 MHz Master Clock => ~40.69 ns period
    // Half-period = 20.345 ns
    // =====================================================
    initial begin
        master_clk = 0;
        forever #20.345 master_clk = ~master_clk;
    end

    // =====================================================
    // Stimulus Generation
    // =====================================================
    initial begin
        // Setup waveform dumping for viewing in GTKWave/Vivado/ModelSim
        $dumpfile("tb_i2s_streamout.vcd");
        $dumpvars(0, tb_i2s_streamout);

        // Initialize inputs
        ready       = 0;
        tone_switch = 0;

        // Hold in reset for 100ns
        #100;

        $display("=================================================");
        $display("[%0t] Releasing reset, testing CONSTANT output", $time);
        $display("=================================================");
        ready = 1;
        tone_switch = 0; // Should output 16'd1

        // Wait ~50us to capture a few I2S frames
        #50_000;

        $display("=================================================");
        $display("[%0t] Switching tone_switch to SINE WAVE", $time);
        $display("=================================================");
        tone_switch = 1;

        // Wait ~600us to capture at least one full cycle of the 27-sample sine ROM
        #600_000;

        $display("=================================================");
        $display("[%0t] Test Complete.", $time);
        $display("=================================================");
        $finish;
    end

    // =====================================================
    // I²S Behavioral Receiver / Monitor
    // =====================================================
    // This block mimics an audio DAC receiving your I2S data.
    // Standard I2S shifts MSB first, with a 1-clock delay 
    // after the WS (lr_clk) transition.
    // =====================================================

    // =====================================================
    // I²S Behavioral Receiver / Monitor (CONTINUOUS SHIFT)
    // =====================================================
    logic [31:0] frame_rx;
    logic        lr_clk_d1 = 1;
    logic        lr_clk_d2 = 1;

    always @(posedge s_clk) begin
        // 1. Continuously shift data in on every rising edge
        frame_rx <= {frame_rx[30:0], s_data};
        
        // 2. Track the history of lr_clk to detect frame boundaries
        lr_clk_d1 <= lr_clk;
        lr_clk_d2 <= lr_clk_d1;
        
        // 3. I2S frames wrap when lr_clk transitions from 1 (Right) to 0 (Left).
        // Because of the 1-bit delay, the Right channel's LSB is sampled slightly after the transition.
        // Exactly one clock after the Right LSB is sampled, lr_clk_d1=0 and lr_clk_d2=1.
        // At this exact moment, frame_rx contains a perfectly aligned 32-bit I2S frame!
        if (lr_clk_d1 == 0 && lr_clk_d2 == 1) begin
            $display("[%0t] LEFT  Channel: 16'h%0h | RIGHT Channel: 16'h%0h", 
                     $time, frame_rx[31:16], frame_rx[15:0]);
        end
    end

endmodule