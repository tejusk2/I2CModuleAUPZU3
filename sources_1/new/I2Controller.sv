`timescale 1ns / 1ps

module I2Controller(output SCL, inout SDA, input reset_n, output logic error, input logic master_clock, output logic done);
    //inout is a tri state buffer, we want to leave it undriven to output 1 because the pullup network will connect it to vcc
    //Vars
    localparam int NUM_INSTRUCTIONS = 42;
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
    logic [20:0] reset_counter;

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
    //---------------------Block ROM Init-------------------
    logic [7:0] byte_rom [0: NUM_INSTRUCTIONS-1];//Static read only memory to configure I2C
        initial begin
            // Select Page 0
            byte_rom[0]  = 8'h30; byte_rom[1]  = 8'h00; byte_rom[2]  = 8'h00;
            // Software Reset
            byte_rom[3]  = 8'h30; byte_rom[4]  = 8'h01; byte_rom[5]  = 8'h80;

            //delay
            // Reg 101: CODEC_CLKIN = CLKDIV_OUT
            byte_rom[6]  = 8'h30; byte_rom[7]  = 8'h65; byte_rom[8]  = 8'h01;
            // Reg 102: CLKDIV_IN = MCLK, PLLCLK_IN = MCLK, reserved=0010
            byte_rom[9]  = 8'h30; byte_rom[10] = 8'h66; byte_rom[11] = 8'h02;
            // Reg 2: N(* mark_debug = "true" *)CODEC=1, ADC and DAC fs = fs_ref/1
            byte_rom[12] = 8'h30; byte_rom[13] = 8'h02; byte_rom[14] = 8'h00;
            // Reg 9: I2S mode, 16-bit, slave
            byte_rom[15] = 8'h30; byte_rom[16] = 8'h09; byte_rom[17] = 8'h00;
            
            // Reg 7: Left DAC = left channel, Right DAC = right channel
            byte_rom[18] = 8'h30; byte_rom[19] = 8'h07; byte_rom[20] = 8'h0A;
            // Reg 37: Power up Left and Right DACs
            byte_rom[21] = 8'h30; byte_rom[22] = 8'h25; byte_rom[23] = 8'hC0;

            // Reg 41: DAC_L1 path left, DAC_R1 path right, independent vol ctrl
            byte_rom[24] = 8'h30; byte_rom[25] = 8'h2B; byte_rom[26] = 8'h00;
            // Reg 82: Route DAC_L1 to LEFT_LOP/M, 0dB
            byte_rom[27] = 8'h30; byte_rom[28] = 8'h2C; byte_rom[29] = 8'h00;

            // Reg 92: Route DAC_R1 to RIGHT_LOP/M, 0dB
            byte_rom[30] = 8'h30; byte_rom[31] = 8'h52; byte_rom[32] = 8'h80;
            // Reg 86: LEFT_LOP/M unmute (D3=1) + power up (D0=1)
            byte_rom[33] = 8'h30; byte_rom[34] = 8'h5C; byte_rom[35] = 8'h80;

            // Reg 93: RIGHT_LOP/M unmute (D3=1) + power up (D0=1)
            byte_rom[36] = 8'h30; byte_rom[37] = 8'h56; byte_rom[38] = 8'h09;
            // Reg 43: Left DAC unmute, 0dB
            byte_rom[39] = 8'h30; byte_rom[40] = 8'h5D; byte_rom[41] = 8'h09;
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
        end else begin
            if(counter == 9'd499)begin
                //release SDA for readack
                if(state == ACKNOWLEDGE)drive_sda_high<=1;
                //Keep SCL high during start state
                if(state == IDLE)begin
                    drive_scl_high <= 1;
                end else begin
                    drive_scl_high <= ~drive_scl_high;
                end
                counter <= 9'd0; //reset counter
                state <= next;
            end else begin
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
                            drive_sda_high <= byte_rom[instruction_counter][7-write_counter];
                        end
                        ACKNOWLEDGE: drive_sda_high <= byte_rom[instruction_counter][7-write_counter];
                        STOP: drive_sda_high <= 0; //drive low to stop
                        READACK: begin
                            drive_sda_high <= 1;
                            error <= (SDA) ? 1 : 0;
                        end
                        RESTART:begin
                            drive_sda_high <= 1;
                            if(instruction_counter != NUM_INSTRUCTIONS - 1)begin
                                if(instruction_counter == 5)begin
                                    reset_flag <= 1;
                                end
                                if(reset_flag)begin
                                    if(reset_counter >= 99999)begin
                                        reset_flag <= 0;
                                        reset_counter <= 0;
                                        data_cycle <= 0;
                                    end else begin
                                        reset_counter <= reset_counter + 1;
                                    end
                                end else begin
                                    instruction_counter <= instruction_counter + 1; //increment if not at end
                                    if(data_cycle == 2)begin
                                        data_cycle <= 0;
                                    end else begin
                                        data_cycle <= data_cycle + 1;
                                    end
                                    write_counter <= 0;
                                end
                            end
                            
                        end 
                        EXECUTE_STOP: drive_sda_high <= 1;

                    endcase
                end
                counter <= counter + 1;
            end
        end      
    end
    //drive SDA
    assign SDA = (drive_sda_high) ? 1'bz : 1'b0; //tri state buffer for SDA
    assign SCL = (drive_scl_high) ? 1'bz : 1'b0;
    //next state logic
    always_comb begin
        //TODO: Create Logic For moving through bytes, receiving acknowledgements...
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
                if(error)begin
                    next = DONE;
                end else begin
                    next = RESTART;
                end   
            end
            RESTART:begin
                if(stop_issued)begin
                    if(reset_flag)begin
                        next = RESTART;
                    end else begin
                        next = STOP;
                    end
                end else begin
                    next = WRITING;
                end
            end 
            STOP: next = EXECUTE_STOP;
            EXECUTE_STOP:begin
                if(instruction_counter == NUM_INSTRUCTIONS - 1)begin
                    next = DONE; 
                end else begin
                    next = IDLE;
                end
            end 
            DONE: done = 1;
        endcase

    end
    //Write to Registers
    //Confirm Success or Error
endmodule