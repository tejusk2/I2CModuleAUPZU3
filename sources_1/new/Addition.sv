`timescale 1ns / 1ps

module Addition (
    input logic [15:0] in_data,
    input logic [15:0] rd_data,
    output logic [15:0] out_data
);
    logic [15:0] intermediate_out;
    
    //Do addition in combination logic
    always_comb begin
        //check for overflow
        intermediate_out = in_data + rd_data;
        if(in_data[15] == rd_data[15] && intermediate_out[15] != in_data[15])begin
            //overflow(sign mismatch)
            if(in_data[15] == 1)begin
                //negative overflow
                out_data = 16'h8000;
            end else begin
                //positive overflow
                out_data = 16'h7FFF;
            end
        end else begin
            //no overflow
            out_data = intermediate_out;
        end
    end



endmodule