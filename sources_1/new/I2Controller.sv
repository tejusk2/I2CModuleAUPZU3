`timescale 1ns / 1ps

module I2Controller(output SCL, inout SDA, input reset_n, output logic error, input logic master_clock, output logic done, output logic [7:0]instr);
    //inout is a tri state buffer, we want to leave it undriven to output 1 because the pullup network will connect it to vcc
    //Vars
    localparam int NUM_INSTRUCTIONS = 30;
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
            //select page 0 - reg 0
            byte_rom[0]  = 8'h30;
            byte_rom[1]  = 8'h00;
            byte_rom[2]  = 8'h00;
            //Software reset - reg 1
            byte_rom[3]  = 8'h30;
            byte_rom[4]  = 8'h01;
            byte_rom[5]  = 8'h80;
            //Power up left ADC - reg 19
            byte_rom[6]  = 8'h30;
            byte_rom[7]  = 8'h13;
            byte_rom[8]  = 8'h04;
            //Power up right ADC - reg 22
            byte_rom[9]  = 8'h30;
            byte_rom[10] = 8'h16; 
            byte_rom[11] = 8'h04;
            //Unmute the left PGA, Volume gain at 0db - reg 15
            byte_rom[12] = 8'h30;
            byte_rom[13] = 8'h0F; 
            byte_rom[14] = 8'h00; 
            //Unmute the right PGA, Volume gain at 0db - reg 16
            byte_rom[15] = 8'h30;
            byte_rom[16] = 8'h10; 
            byte_rom[17] = 8'h00; 
            //Route PGA_L to left LOP - reg 81
            byte_rom[18] = 8'h30;
            byte_rom[19] = 8'h51; 
            byte_rom[20] = 8'h80; 
            //Unmute and power up the left LOP - reg 86
            byte_rom[21] = 8'h30;
            byte_rom[22] = 8'h56; 
            byte_rom[23] = 8'h09;
            //Route PGA_R to right LOP - reg 91
            byte_rom[24] = 8'h30;
            byte_rom[25] = 8'h5B; 
            byte_rom[26] = 8'h80; 
            //Unmute and power up the right LOP - reg 93
            byte_rom[27] = 8'h30;
            byte_rom[28] = 8'h5D;
            byte_rom[29] = 8'h09; 
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
                if(reset_counter >= 99999999)begin
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
                                    if(reset_counter >= 99999)begin
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