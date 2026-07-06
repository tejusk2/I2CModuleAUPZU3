`timescale 1ns / 1ps

(* ram_style = "block" *)
module xilinx_simple_dual_port_bram #(
    parameter int DATA_WIDTH = 16,
    parameter int ADDR_WIDTH = 9
)(
    input  logic                    clk,
    input  logic                    en_a,
    input  logic                    en_b,
    input  logic                    we_a,
    input  logic [ADDR_WIDTH-1:0]   addr_a,
    input  logic [ADDR_WIDTH-1:0]   addr_b,
    input  logic [DATA_WIDTH-1:0]   din_a,
    output logic [DATA_WIDTH-1:0]   dout_b
);

    localparam int RAM_DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] ram [RAM_DEPTH-1:0];

    logic [ADDR_WIDTH-1:0] addr_b_reg;
    initial begin
        ram = '{default: 0};
    end

    // Port A: Write Interface
    always_ff @(posedge clk) begin
        if (en_a) begin
            if (we_a) begin
                ram[addr_a] <= din_a;
            end
        end
    end

    // Port B: Read Interface
    always_ff @(posedge clk) begin
        if (en_b) begin
            addr_b_reg <= addr_b;
        end
    end

    assign dout_b = ram[addr_b_reg];

endmodule
