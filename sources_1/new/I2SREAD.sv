`timescale 1ns / 1ps

module I2SREAD(input logic wclk, input logic sclk, input logic datain, input logic rst_n, input logic ready,
                output logic [15:0] dataout, output logic read_done

    );
    logic align;
    logic delay;
    logic [3:0] counter;
    //Will trigger on first bit clock posedge after word clock toggle
    assign read_done = (counter == 4'b0000) ? 1 : 0;

    always_ff @ (posedge sclk)begin
        if(!rst_n)begin
            dataout <= 16'b0;
            delay <= 1'b0;
            counter <= 4'b000;
        end else begin
            //apply a 1 bit delay after reset to align data
            if(ready)begin
                if(delay)begin
                    dataout[15-counter] = datain;
                    counter <= counter + 1;
                end else begin
                    //only set delay once
                    delay <= (align) ? 1 : 0;
                end  
            end
        end
    end
    //basically a delay signal to tell the buffer to only start collection when wclk goes down
    always_ff @ (negedge wclk)begin
        if(!rst_n)begin
            align <= 0;
        end else begin
            if(ready)begin
                align <= 1;
            end
        end
    end


endmodule
