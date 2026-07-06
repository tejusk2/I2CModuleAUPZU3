`timescale 1ns / 1ps

module MultiplyAndShift (
    input logic [15:0] in_data,
    output logic [15:0] out_data
);
    logic [17:0] intermediate_out;
    
    //Do addition in combination logic
    always_comb begin
        intermediate_out = in_data * 2'b11;
        out_data = intermediate_out[17:2];
    end



endmodule