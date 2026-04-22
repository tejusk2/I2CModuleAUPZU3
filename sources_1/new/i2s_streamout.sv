`timescale 1ns / 1ps

module i2s_streamout (
    input  logic        master,
    input  logic        ready,
    input  logic        tone_switch,

    output logic        lr_clk,
    output logic        s_clk,
    output logic        s_data,
    output logic        delay_over
);

    localparam [23:0] DELAY_CYCLES = 24'd12_288_000; 
    
    logic [23:0] delay_cnt;
    logic        delay_done;

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

    
    logic [2:0]  mclk_div;   
    logic [5:0]  bclk_cnt;   
    logic [15:0] shift_reg;  

    assign delay_over = delay_done;

    
    always_ff @(posedge master) begin
        if (!ready) begin
            delay_cnt  <= 0;
            delay_done <= 0;
            mclk_div   <= 0;
            bclk_cnt   <= 6'd63; // Start at 63 to wrap to 0 on first cycle
            lr_clk     <= 1;     
            s_clk      <= 0;
            s_data     <= 0;
            sample_idx <= 0;
            shift_reg  <= 0;
        end else begin
            
            // Timer Logic
            if (!delay_done) begin
                if (delay_cnt == DELAY_CYCLES - 1) begin
                    delay_done <= 1;
                end else begin
                    delay_cnt <= delay_cnt + 1;
                end
            end
            
            mclk_div <= mclk_div + 1;

            // FALLING EDGE OF S_CLK: Shift data and WS
            if (mclk_div == 3'd3) begin
                logic [5:0]  next_bclk;
                logic [15:0] next_shift_reg;

                s_clk <= 0;
                
                next_bclk = bclk_cnt + 1;
                bclk_cnt <= next_bclk;

                // WCLK transitions exactly 32 BCLKs apart
                if (next_bclk == 0)       lr_clk <= 0; 
                else if (next_bclk == 32) lr_clk <= 1; 

                // Left Channel Data Load (Bit 1)
                if (next_bclk == 1) begin
                    next_shift_reg = delay_done ? (tone_switch ? sine_amps[sample_idx] : 16'd1) : 16'd0;
                end 
                // Right Channel Data Load (Bit 33)
                else if (next_bclk == 33) begin
                    next_shift_reg = delay_done ? (tone_switch ? sine_amps[sample_idx] : 16'd1) : 16'd0;
                    if (delay_done) begin
                        sample_idx <= (sample_idx == 26) ? 0 : sample_idx + 1;
                    end
                end 
                // Standard Shift or Zero-Pad
                else begin
                    // Shift out data for bits 2-16 and 34-48. Pad zeroes for everything else.
                    if ((next_bclk > 1 && next_bclk <= 16) || (next_bclk > 33 && next_bclk <= 48)) begin
                        next_shift_reg = {shift_reg[14:0], 1'b0};
                    end else begin
                        next_shift_reg = 16'd0; 
                    end
                end

                shift_reg <= next_shift_reg;
                s_data    <= next_shift_reg[15]; 
            end

            // RISING EDGE OF S_CLK: Hold data stable
            else if (mclk_div == 3'd7) begin
                s_clk <= 1;
            end
        end
    end

endmodule