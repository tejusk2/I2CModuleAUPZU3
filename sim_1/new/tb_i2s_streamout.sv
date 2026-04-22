`timescale 1ns / 1ps

module tb_i2s_streamout;
    logic master_clk;
    logic ready;
    logic tone_switch;

    logic lr_clk;
    logic s_clk;
    logic s_data;

    i2s_streamout uut (
        .master      (master_clk),
        .ready       (ready),
        .tone_switch (tone_switch),
        .lr_clk      (lr_clk),
        .s_clk       (s_clk),
        .s_data      (s_data)
    );

    initial begin
        master_clk = 0;
        forever #20.345 master_clk = ~master_clk;
    end

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

        #50_000;

        $display("=================================================");
        $display("[%0t] Switching tone_switch to SINE WAVE", $time);
        $display("=================================================");
        tone_switch = 1;

        #600_000;

        $display("=================================================");
        $display("[%0t] Test Complete.", $time);
        $display("=================================================");
        $finish;
    end

    
    logic [31:0] frame_rx;
    logic        lr_clk_d1 = 1;
    logic        lr_clk_d2 = 1;

    always @(posedge s_clk) begin
        // Continuously shift data in on every rising edge
        frame_rx <= {frame_rx[30:0], s_data};
        
        // Track the history of lr_clk to detect frame boundaries
        lr_clk_d1 <= lr_clk;
        lr_clk_d2 <= lr_clk_d1;
        
    
        if (lr_clk_d1 == 0 && lr_clk_d2 == 1) begin
            $display("[%0t] LEFT  Channel: 16'h%0h | RIGHT Channel: 16'h%0h", 
                     $time, frame_rx[31:16], frame_rx[15:0]);
        end
    end

endmodule