`timescale 1ns / 1ps

module FilterController(input logic sclk, input logic wclk, 
input logic [15:0] in_data, input logic read_done, input logic rst_n, input logic ready,
output logic [15:0] out_data, output logic output_ready);

    localparam int FILTER_DELAY = 4410; 
    localparam int ADDR_SIZE = 11; //13 for 4410, 9 for 441

    localparam int MAXDELAY = 441;
    localparam int MINDELAY = 41;
    logic [10:0] flang_counter;
    logic [6:0] lfo_delay;
    logic count_up;

    logic r_en;
    logic w_en;
    logic [15:0] bram_data_in;
    logic [15:0] bram_data_out;
    logic [15:0] read_data;

    logic [ADDR_SIZE-1:0] read_pointer;
    logic [ADDR_SIZE-1:0] write_pointer;

    logic first_read_happened;

    logic [ADDR_SIZE-1:0] write_addr;
    logic [15:0] write_data;
    logic [ADDR_SIZE-1:0] read_addr;

    xilinx_simple_dual_port_bram #(
        .DATA_WIDTH(16),
        .ADDR_WIDTH(ADDR_SIZE)
    ) bramTen (
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
            read_pointer <= 0;
            r_en <= 0;
            first_read_happened <= 0;
        end else begin
            if(ready)begin
                r_en <= 1;
                first_read_happened <= 1;
                
                if(read_pointer == FILTER_DELAY-1)begin
                    read_pointer <= 9'd0;
                end else begin
                    read_pointer <= read_pointer + 1;
                end
            end
        end
    end
    always_comb begin
        //Handle flanger read address logic
        if(write_addr > flang_counter)begin
            read_addr = write_addr - flang_counter;
        end else begin
            read_addr = (MAXDELAY + write_addr) - flang_counter;
        end
    end
    //This clock blocked writes the current addition output to memory
    //Sends the data on the negedge of sclk when wclk is low and read_done is high, two cycles have passed
    always_ff @ (negedge sclk)begin
        if(~rst_n)begin
            write_pointer <= MAXDELAY-1;
            w_en <= 0;
            output_ready <= 0;
            write_addr <= MAXDELAY-1;
            flang_counter <= MAXDELAY-1;
            count_up <= 0;
            lfo_delay <= 0;
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
                    if(write_pointer == MAXDELAY-1)begin
                        write_pointer <= 0;
                    end else begin
                        write_pointer <= write_pointer + 1;
                    end
                    
                    if(lfo_delay == 7'd110)begin
                        lfo_delay <= 0;
                         //Flanger counter logic
                        if(count_up)begin
                            if(flang_counter != MAXDELAY-1)begin
                                flang_counter <= flang_counter + 1;
                            end else begin
                                count_up <= 0;
                            end
                        end else begin
                            if(flang_counter != MINDELAY - 1)begin
                                flang_counter <= flang_counter - 1;
                            end else begin
                                count_up <= 1;
                            end
                        end
                    end else begin
                        lfo_delay <= lfo_delay + 1;
                    end
                   
                end else begin
                    w_en <= 0;
                end
            end
        end
    end

endmodule