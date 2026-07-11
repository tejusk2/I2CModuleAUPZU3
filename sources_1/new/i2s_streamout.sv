`timescale 1ns / 1ps

module i2s_streamout (input logic wclk, input logic sclk, input logic [15:0] input_data, 
                    input logic rst_n, input logic ready, input logic read_done,
                    output logic data_out_bit);
    logic [15:0]serial_word;
    assign data_out_bit = serial_word[15];
    always_ff @(negedge sclk) begin
        if(~rst_n)begin
            serial_word <= 16'd0;
        end else begin
            //ready is a flag from the I2C Controller when its done writing
            if(ready)begin
                if(read_done)begin
                    serial_word <= input_data;
                end else begin
                    serial_word <= serial_word<<1;
                end
            end
        end
    end


endmodule