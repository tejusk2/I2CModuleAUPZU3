`timescale 1ns / 1ps

module FilterController(input logic sclk, input logic wclk, 
input logic [15:0] in_data, input logic read_done, input logic rst_n, input logic ready,
output logic [15:0] out_data, output logic output_ready);
    logic r_en;
    logic w_en;
    logic [15:0] bram_data_in;
    logic [15:0] bram_data_out;
    logic [15:0] read_data;

    logic [8:0] read_pointer;
    logic [8:0] write_pointer;

    logic first_read_happened;

    logic [8:0] write_addr;
    logic [15:0] write_data;
    logic [8:0] read_addr;

    xilinx_simple_dual_port_bram bramTen(
        .clk(sclk),
        .en_a(w_en),
        .en_b(r_en),
        .we_a(w_en),
        .addr_a(write_addr),
        .addr_b(read_addr),
        .din_a(bram_data_in),
        .dout_b(bram_data_out)
    );
    Addition adder(
        .rd_data(bram_data_out),
        .in_data(in_data),
        .out_data(out_data)
    );
    MultiplyAndShift mult(
        .in_data(out_data),
        .out_data(write_data)
    );
    //This clocked block handles pre fetching the data from BRAM for addition
    //fetch on negative edge of word clock
    //Assumes right and left channel audio are the same
    //BRAM read_data updates at the end on next sclk posedge
    //This means data can start being written on the first sclk negedge after that(0 delay)
    //Gives addition output time to settle
    //This does in fact change the pointer at the end of the clock edge, but so does the write block
    always_ff @ (negedge wclk)begin
        if(~rst_n)begin
            read_pointer <= 9'd0;
            r_en <= 0;
            first_read_happened <= 0;
            read_addr <= 9'd0;
        end else begin
            if(ready)begin
                r_en <= 1;
                first_read_happened <= 1;
                read_addr <= read_pointer;
                if(read_pointer == 9'd440)begin
                    read_pointer <= 9'd0;
                end else begin
                    read_pointer <= read_pointer + 1;
                end
            end
        end
    end
    //This clock blocked writes the current addition output to memory
    //Sends the data on the negedge of sclk when wclk is low and read_done is high, two cycles have passed
    always_ff @ (negedge sclk)begin
        if(~rst_n)begin
            write_pointer <= 9'd440;
            w_en <= 0;
            output_ready <= 0;
            write_addr <= 9'd440;
        end else begin
            //Mostly for the testbench to verify
            if(ready)begin
                if(read_done)begin
                    output_ready <= 1;
                end else begin
                    output_ready <= 0;
                end
                if(read_done && ~wclk && first_read_happened)begin
                    //perform write operation on BRAM
                    bram_data_in <= write_data;
                    write_addr <= write_pointer;
                    w_en <= 1;
                    if(write_pointer == 9'd440)begin
                        write_pointer <= 9'd0;
                    end else begin
                        write_pointer <= write_pointer + 1;
                    end
                end else begin
                    w_en <= 0;
                end
            end
        end
    end

endmodule