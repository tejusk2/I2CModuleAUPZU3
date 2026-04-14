`timescale 1ns / 1ps

module i2s_streamout (
    input  logic master,        // 24.576 MHz clock
    input  logic ready,         // start signal (from I2C init)
    input  logic tone_switch,   // enable tone
    
    output logic lr_clk,        // word select (LRCLK)
    output logic s_clk,         // bit clock (BCLK)
    output logic s_data         // serial data
);

    // ================================
    // Parameters
    // ================================
    localparam int SCLK_DIV = 8;   // 24.576MHz / (2*8) = 1.536 MHz
    localparam int FRAME_BITS = 32;

    // ================================
    // Clock + Counters
    // ================================
    logic [2:0] sclk_div_cnt = 0;
    logic [5:0] bit_index = 0; // 0–31

    // ================================
    // Sine Wave ROM (same as yours)
    // ================================
    logic [4:0] sample_index = 0;
    logic [15:0] sine_amps [0:26];

    initial begin
        sine_amps[0]  = 16'h0000;
        sine_amps[1]  = 16'h1D85;
        sine_amps[2]  = 16'h3977;
        sine_amps[3]  = 16'h5246;
        sine_amps[4]  = 16'h66FC;
        sine_amps[5]  = 16'h759F;
        sine_amps[6]  = 16'h7E0D;
        sine_amps[7]  = 16'h7FD2;
        sine_amps[8]  = 16'h7AB2;
        sine_amps[9]  = 16'h6ED9;
        sine_amps[10] = 16'h5D22;
        sine_amps[11] = 16'h469D;
        sine_amps[12] = 16'h2BC7;
        sine_amps[13] = 16'h0EDC;
        sine_amps[14] = 16'hF124;
        sine_amps[15] = 16'hD439;
        sine_amps[16] = 16'hB963;
        sine_amps[17] = 16'hA2DE;
        sine_amps[18] = 16'h9127;
        sine_amps[19] = 16'h854E;
        sine_amps[20] = 16'h802E;
        sine_amps[21] = 16'h81F3;
        sine_amps[22] = 16'h8A61;
        sine_amps[23] = 16'h9904;
        sine_amps[24] = 16'hADBA;
        sine_amps[25] = 16'hC689;
        sine_amps[26] = 16'hE27B;
    end

    // ================================
    // Main I2S Logic
    // ================================
    always_ff @(posedge master) begin
        if (!ready) begin
            s_clk        <= 0;
            lr_clk       <= 0;
            s_data       <= 0;
            sclk_div_cnt <= 0;
            bit_index    <= 0;
            sample_index <= 0;
        end else begin
            // ----------------------------
            // Generate SCLK
            // ----------------------------
            sclk_div_cnt <= sclk_div_cnt + 1;

            if (sclk_div_cnt == SCLK_DIV-1) begin
                sclk_div_cnt <= 0;
                s_clk <= ~s_clk;

                // ----------------------------
                // Rising edge of SCLK
                // (receiver samples here)
                // ----------------------------
                if (s_clk == 0) begin
                    bit_index <= bit_index + 1;

                    if (bit_index == FRAME_BITS-1) begin
                        bit_index <= 0;

                        // advance sine wave each frame
                        sample_index <= (sample_index == 26) ? 0 : sample_index + 1;
                    end
                end

                // ----------------------------
                // Falling edge of SCLK
                // (we update data here)
                // ----------------------------
                else begin
                    if (tone_switch) begin
                        // I2S: MSB starts at bit_index = 1
                        if (bit_index >= 1 && bit_index <= 16) begin
                            // LEFT channel
                            s_data <= sine_amps[sample_index][16 - bit_index];
                        end
                        else if (bit_index >= 17 && bit_index <= 32) begin
                            // RIGHT channel (duplicate)
                            s_data <= sine_amps[sample_index][32 - bit_index];
                        end
                        else begin
                            s_data <= 0;
                        end
                    end else begin
                        s_data <= 0;
                    end
                end
            end

            // ----------------------------
            // LRCLK generation
            // ----------------------------
            // I2S standard:
            // LRCLK changes one bit BEFORE MSB
            lr_clk <= (bit_index < 16) ? 0 : 1;
        end
    end

endmodule