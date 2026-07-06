`timescale 1ns / 1ps

module I2Controller(output SCL, inout SDA, input reset_n, output logic error, input logic master_clock, output logic done, output logic [7:0]instr);
    //inout is a tri state buffer, we want to leave it undriven to output 1 because the pullup network will connect it to vcc
    //Vars
    localparam int NUM_INSTRUCTIONS = 60;
    typedef enum {IDLE, START, WRITING, ACKNOWLEDGE, STOP, INCREMENT, READACK, RESTART, EXECUTE_STOP, DONE, DELAY} controller_state; //state encoding
    controller_state state, next;
    logic [2:0] write_counter = 3'b000; //To count the number of bits sent during the write state
    logic [7:0]instruction_counter = 0; //index for byte in byte array
    logic drive_sda_high = 1'b1; //boolean logic bit to drive SDA
    logic drive_scl_high = 1'b1; //boolean logic bit to drive SCL

    logic [8:0] counter = 9'd0; //clock divider counter
    logic stop_issued = 0; //issue a stop during write state for after acknowledge state
    logic [1:0]data_cycle = 2'b00;

    logic reset_flag;
    logic delay_flag;
    logic [32:0] reset_counter;

    (* mark_debug = "true" *) logic debug_drive_sda;
    (* mark_debug = "true" *) logic debug_drive_scl;
    (* mark_debug = "true" *) logic debug_error;
    (* mark_debug = "true" *) logic [3:0] debug_state;
    (* mark_debug = "true" *) logic [7:0] debug_inst_counter;
    (* mark_debug = "true" *) logic [2:0] debug_write_counter;

    assign debug_drive_sda    = drive_sda_high;
    assign debug_drive_scl    = drive_scl_high;
    assign debug_state        = state;
    assign debug_inst_counter = instruction_counter;
    assign debug_write_counter = write_counter;
    assign instr = instruction_counter;
    //---------------------Block ROM Init-------------------
    logic [7:0] byte_rom [0: NUM_INSTRUCTIONS-1];//Static read only memory to configure I2C
        initial begin
            //Page Select
            byte_rom[0]   = 8'h30;
            byte_rom[1]   = 8'h00;
            byte_rom[2]   = 8'h00;
            //Reset
            byte_rom[3]   = 8'h30;
            byte_rom[4]   = 8'h01;
            byte_rom[5]   = 8'h80;
            //Enable the PLL, set P to 4, Q to doesn't matter
            byte_rom[6]   = 8'h30;
            byte_rom[7]   = 8'h03;
            byte_rom[8]   = 8'h04;
            //Set J = to 7
            byte_rom[9]   = 8'h30;
            byte_rom[10]  = 8'h04;
            byte_rom[11]  = 8'h1d;
            //D needs to be 00100011001110 in 14 bits of binary
            //Write the first 8 bits of D: 00100011
            byte_rom[12]  = 8'h30;
            byte_rom[13]  = 8'h05;
            byte_rom[14]  = 8'h23;
            //Write the next 6 bits of D: 001110 - 00
            byte_rom[15]  = 8'h30;
            byte_rom[16]  = 8'h06;
            byte_rom[17]  = 8'h38;
            //Configure I2S to master mode, power down lines when codec powered down, 
            byte_rom[18]  = 8'h30;
            byte_rom[19]  = 8'h08;
            byte_rom[20]  = 8'hd0;
            //DAC and ADC Resyncs
            byte_rom[21]  = 8'h30;
            byte_rom[22]  = 8'h09;
            byte_rom[23]  = 8'h06;
            //Power up Left ADC
            byte_rom[24]  = 8'h30;
            byte_rom[25]  = 8'h13;
            byte_rom[26]  = 8'h04;
            //Power up right ADC
            byte_rom[27]  = 8'h30;
            byte_rom[28]  = 8'h16;
            byte_rom[29]  = 8'h04;
            //Unmute left PGA
            byte_rom[30]  = 8'h30;
            byte_rom[31]  = 8'h0f;
            byte_rom[32]  = 8'h00;
            //Unmute right PGA
            byte_rom[33]  = 8'h30;
            byte_rom[34]  = 8'h10;
            byte_rom[35]  = 8'h00;
            //Left data to left DAC, right data to right DAC
            byte_rom[36]  = 8'h30;
            byte_rom[37]  = 8'h07;
            byte_rom[38]  = 8'h0a;
            //Power up DACs
            byte_rom[39]  = 8'h30;
            byte_rom[40]  = 8'h25;
            byte_rom[41]  = 8'hc0;
            //Unmute left digital volume
            byte_rom[42]  = 8'h30;
            byte_rom[43]  = 8'h2b;
            byte_rom[44]  = 8'h00;
            //Unmute right digital volume
            byte_rom[45]  = 8'h30;
            byte_rom[46]  = 8'h2c;
            byte_rom[47]  = 8'h00;
            //Left DAC to left line out
            byte_rom[48]  = 8'h30;
            byte_rom[49]  = 8'h52;
            byte_rom[50]  = 8'h80;
            //right DAC to right line out
            byte_rom[51]  = 8'h30;
            byte_rom[52]  = 8'h5c;
            byte_rom[53]  = 8'h80;
            //Power up and unmute left line out
            byte_rom[54]  = 8'h30;
            byte_rom[55]  = 8'h56;
            byte_rom[56]  = 8'h09;
            //Power up and unmute right line out
            byte_rom[57]  = 8'h30;
            byte_rom[58]  = 8'h5d;
            byte_rom[59]  = 8'h09;
        end


    //State Machine to handle bit sending data
    always_ff @(posedge master_clock)begin
        //reset conditions
        if(!reset_n)begin
            error <= 0; //no errors
            state <= IDLE; //IDLE state
            drive_sda_high <= 1; //leave SDA undriven to start
            write_counter <= 3'b000; //Write counter is 0
            instruction_counter <= 0; //Instruction Counter is 0
            drive_scl_high <= 1; //SCL HIGH to START
            reset_counter <= 0;
            reset_flag <= 0;
            delay_flag <= 1;
            data_cycle <= 2'b00;
            stop_issued <= 0;
        end else begin
            //After hardware reset, give the codec time to power up before sending data on the I2C line
            if(delay_flag)begin
                if(reset_counter >= 9999)begin//99999999
                    reset_counter <= 0;
                    delay_flag <= 0;
                end else begin
                    reset_counter <= reset_counter + 1;
                end
            end else begin
                //one full period every 1000 clock cycles
                //100Mhz input, 100Khz output
                if(counter == 9'd499)begin
                    //release SDA for readack
                    if(state == ACKNOWLEDGE)drive_sda_high<=1;
                    //Keep SCL high during start state
                    if(state == IDLE)begin
                        drive_scl_high <= 1;
                    end else if(state == EXECUTE_STOP)begin
                        drive_scl_high <= 1;
                    end else begin
                        drive_scl_high <= ~drive_scl_high;
                    end
                    counter <= 9'd0; //reset counter
                    state <= next;
                end else begin
                    //change during the middle of the clock cycle
                    if(counter== 9'd249)begin
                        //--------------------------------STATE MACHINE IMPLEMENTATION----------------------------
                        case(state)
                            IDLE: drive_sda_high <= 1;
                            START: drive_sda_high <= 0; //pull SDA low to start
                            WRITING: begin
                                if(data_cycle == 2)begin
                                    stop_issued <= 1;
                                end else begin
                                    stop_issued <= 0;
                                end
                                drive_sda_high <= byte_rom[instruction_counter][7-write_counter]; 
                            end
                            INCREMENT: begin
                                write_counter <= write_counter + 1;
                            end
                            STOP:begin
                                //If passed the 5th instruction(software reset) - flag the reset
                                if(instruction_counter == 6)begin
                                    reset_flag <= 1;
                                end
                                drive_sda_high <= 0; //drive low to stop
                            end 
                            READACK: begin
                                drive_sda_high <= 1;
                            end
                            RESTART:begin
                                drive_sda_high <= 1;
                                error <= (SDA) ? 1 : 0;
                                if(instruction_counter != NUM_INSTRUCTIONS - 1)begin
                                    instruction_counter <= instruction_counter + 1; //increment if not at end
                                    if(data_cycle == 2)begin
                                        data_cycle <= 0;
                                    end else begin
                                        data_cycle <= data_cycle + 1;
                                    end
                                    write_counter <= 0;
                                end
                            end 
                            EXECUTE_STOP:begin
                                drive_sda_high <= 1;
                                //before sending more data after software reset, wait for some time
                                if(reset_flag)begin
                                    if(reset_counter >= 999)begin//99999
                                        reset_flag <= 0;
                                    end else begin
                                        reset_counter <= reset_counter + 1;
                                    end
                                end
                            end 
                        endcase
                    end
                    counter <= counter + 1;
                end
            end      
        end
    end
    //drive SDA
    assign SDA = (drive_sda_high) ? 1'bz : 1'b0; //tri state buffer for SDA
    assign SCL = drive_scl_high;
    //next state logic
    always_comb begin
        next = state; //default to avoid latches
        done = 0;
        case(state)
            IDLE: next = START;
            START: next = WRITING;
            WRITING:begin
                if(write_counter == 3'b111)begin
                    next = ACKNOWLEDGE;
                end else begin
                    next = INCREMENT;
                end
            end
            INCREMENT: next = WRITING;
            ACKNOWLEDGE: next = READACK;
            READACK:begin
                next = RESTART; 
            end
            RESTART:begin
                if(error)begin
                    next = DONE;
                end else begin
                    if(stop_issued)begin
                        next = STOP;
                    end else begin
                        next = WRITING;
                    end
                end
            end 
            STOP: next = EXECUTE_STOP;
            EXECUTE_STOP:begin
                if(instruction_counter == NUM_INSTRUCTIONS - 1)begin
                    next = DONE; 
                end else begin
                    if(reset_flag)begin
                        next = EXECUTE_STOP;
                    end else begin
                        next = IDLE;
                    end
                end
            end 
            DONE: done = 1;
        endcase
    end
endmodule