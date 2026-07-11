`timescale 1ns / 1ps

module I2SREAD(input logic wclk, input logic sclk, input logic datain, input logic rst_n, input logic ready,
                output logic [15:0] dataout, output logic read_done

    );
    logic align;
    logic wclk_bit_delayed;
    logic delay;
    logic [3:0] counter;
    //Will trigger on first bit clock posedge after word clock toggle
    assign read_done = (counter == 4'b0000) ? 1 : 0;

    always_ff @ (posedge sclk)begin
        if(!rst_n)begin
            dataout <= 16'b0;
            delay <= 1'b0;
            counter <= 4'b0000;
            wclk_bit_delayed <= 1'b0;
        end else begin
            //apply a 1 bit delay after reset to align data
            if(ready)begin
                wclk_bit_delayed <= wclk;
                //Word clock transitions, we are sampling previous LSB
                if(wclk != wclk_bit_delayed)begin
                    delay <= 1;//delay goes high for next cycle
                    dataout[0] <= datain;
                    counter <= 0; //reset counter to 0 for next cycle
                end
                if(delay)begin
                    dataout[15-counter] <= datain;
                    counter <= counter + 1;
                    if(counter == 4'b1110)begin//reset delay if at 15
                        delay <= 0; //for first clock cycle after the edge
                    end
                end
            end
        end
    end
    
    


endmodule
