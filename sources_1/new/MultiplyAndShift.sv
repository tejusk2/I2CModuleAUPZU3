`timescale 1ns / 1ps

module MultiplyAndShift (
    input logic signed [15:0] in_data,
    output logic signed [15:0] out_data
);
    logic signed [17:0] intermediate_out;
    
    //Do addition in combination logic
    always_comb begin
        intermediate_out = in_data * 3'sd3;
        out_data = intermediate_out >>> 2;
    end



endmodule