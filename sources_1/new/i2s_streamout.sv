`timescale 1ns / 1ps

module i2s_streamout (
    input  logic        master,
    input  logic        ready,
    input  logic        tone_switch,

    output logic        lr_clk,
    output logic        s_clk,
    output logic        s_data
);

    // =====================================================
    // Sine ROM
    // =====================================================
    logic [15:0] sine_amps [0:26];
    logic [4:0]  sample_idx;

    initial begin
        sine_amps[0]  = 16'h0000; sine_amps[1]  = 16'h1D85; sine_amps[2]  = 16'h3977;
        sine_amps[3]  = 16'h5246; sine_amps[4]  = 16'h66FC; sine_amps[5]  = 16'h759F;
        sine_amps[6]  = 16'h7E0D; sine_amps[7]  = 16'h7FD2; sine_amps[8]  = 16'h7AB2;
        sine_amps[9]  = 16'h6ED9; sine_amps[10] = 16'h5D22; sine_amps[11] = 16'h469D;
        sine_amps[12] = 16'h2BC7; sine_amps[13] = 16'h0EDC; sine_amps[14] = 16'hF124;
        sine_amps[15] = 16'hD439; sine_amps[16] = 16'hB963; sine_amps[17] = 16'hA2DE;
        sine_amps[18] = 16'h9127; sine_amps[19] = 16'h854E; sine_amps[20] = 16'h802E;
        sine_amps[21] = 16'h81F3; sine_amps[22] = 16'h8A61; sine_amps[23] = 16'h9904;
        sine_amps[24] = 16'hADBA; sine_amps[25] = 16'hC689; sine_amps[26] = 16'hE27B;
    end

    // =====================================================
    // Registers & Counters
    // =====================================================
    logic [3:0]  mclk_div;   // Generates S_CLK 
    logic [4:0]  bclk_cnt;   // Tracks the 32 bits of the I2S frame (0-31)
    logic [15:0] shift_reg;  // Holds the current sample being shifted out

    // =====================================================
    // Logic
    // =====================================================
    always_ff @(posedge master) begin
        if (!ready) begin
            mclk_div   <= 0;
            bclk_cnt   <= 5'd31; // Start at 31 so the first increment sets it to 0
            lr_clk     <= 1;     // Start high so it transitions low on cycle 0
            s_clk      <= 0;
            s_data     <= 0;
            sample_idx <= 0;
            shift_reg  <= 0;
        end else begin
            
            // Divide master clock by 16 for full S_CLK period
            mclk_div <= mclk_div + 1;

            // ---------------------------------------------------------
            // FALLING EDGE OF S_CLK: Shift data and WS
            // ---------------------------------------------------------
            if (mclk_div == 4'd7) begin
                logic [4:0]  next_bclk;
                logic [15:0] next_shift_reg;

                s_clk <= 0;
                
                // Calculate next bit index (0 to 31)
                next_bclk = bclk_cnt + 1;
                bclk_cnt <= next_bclk;

                // Manage WS / LR_CLK 
                // Transitions 1 cycle before the MSB is loaded to satisfy the 1-bit delay
                if (next_bclk == 0)       lr_clk <= 0; // Left channel
                else if (next_bclk == 16) lr_clk <= 1; // Right channel

                // Manage Shift Register
                if (next_bclk == 1) begin
                    // Load Left channel exactly 1 cycle after lr_clk went low
                    next_shift_reg = tone_switch ? sine_amps[sample_idx] : 16'd1;
                end else if (next_bclk == 17) begin
                    // Load Right channel exactly 1 cycle after lr_clk went high
                    next_shift_reg = tone_switch ? sine_amps[sample_idx] : 16'd1;
                    // Advance ROM pointer for the next frame
                    sample_idx <= (sample_idx == 26) ? 0 : sample_idx + 1;
                end else begin
                    // Shift out the next bit
                    next_shift_reg = {shift_reg[14:0], 1'b0};
                end

                shift_reg <= next_shift_reg;
                s_data    <= next_shift_reg[15]; // Drive MSB of the shift register
            end

            // ---------------------------------------------------------
            // RISING EDGE OF S_CLK: Hold data stable for DAC to sample
            // ---------------------------------------------------------
            else if (mclk_div == 4'd15) begin
                s_clk <= 1;
            end
        end
    end

endmodule