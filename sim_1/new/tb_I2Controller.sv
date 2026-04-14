`timescale 1ns / 1ps

module tb_I2C_Controller;

    logic sys_clk;
    logic reset_n;
    
    // The I2C lines
    tri1 sda;
    tri1 scl;
    
    logic error;

    // Testbench internal control for driving SDA
    logic tb_drive_sda_low;

    I2Controller dut (
        .master_clock(sys_clk),
        .reset_n(reset_n),
        .SDA(sda),
        .SCL(scl),
        .error(error)
    );
    
    // SIMULATE THE PULL-UP

    // TESTBENCH SDA DRIVER
    assign sda = (tb_drive_sda_low) ? 1'b0 : 1'bz;

    initial begin
        sys_clk = 0;
        forever #20 sys_clk = ~sys_clk; // Toggle every 20ns = 40ns period = 25MHz
    end

    // --------------------------------------------------------
    // The TLV320AIC3204 Slave Model
    // --------------------------------------------------------
    initial begin
        logic [7:0] current_byte;
        logic [6:0] dev_addr;
        logic rw_bit;

        tb_drive_sda_low = 0;
        
        forever begin
            // A. Wait for START Condition (SDA goes low while SCL is high)
            @(negedge sda iff scl == 1'b1);
            
            $display("\n--------------------------------------------------");
            $display("Time %t: [Slave] START condition detected", $time);
            
            // B. Read the first byte (Device Address + R/W)
            read_byte(current_byte);
            dev_addr = current_byte[7:1];
            rw_bit   = current_byte[0];
            
            // C. Evaluate the Address Byte
            // TLV320AIC3204 address is 7'h18. Write bit is 1'b0.
            if (dev_addr == 7'h18 && rw_bit == 1'b0) begin
                $display("Time %t: [Slave] Valid Address (7'h18) & Write Bit. Sending ACK.", $time);
                send_ack();

                // D. Inner loop for Register Address and Data bytes
                forever begin
                    fork
                        begin : read_next_byte
                            // Wait for the next 8 clock cycles
                            read_byte(current_byte);
                            $display("Time %t: [Slave] Data Byte Received: 8'h%h", $time, current_byte);
                            send_ack();
                        end
                        begin : wait_for_stop
                            // A STOP is SDA going high while SCL is already high
                            @(posedge sda iff scl === 1'b1);
                        end
                    join_any
                    
                    // Immediately terminate whichever thread did not trigger
                    disable fork; 

                    // Check if the STOP thread was the one that triggered
                    if (scl === 1'b1 && sda === 1'b1) begin
                        $display("Time %t: [Slave] STOP condition detected. Transaction End.", $time);
                        break; // Break out of the inner loop, go back to waiting for START
                    end
                end

            end else begin
                $display("Time %t: [Slave] Invalid Address (7'b%b) or R/W bit. NACKing.", $time, dev_addr);
                // Do not pull SDA low. Wait for the master to issue a STOP condition.
                @(posedge sda iff scl === 1'b1);
                $display("Time %t: [Slave] STOP condition detected after NACK.", $time);
            end
        end
    end

    // Task to read 8 bits from the Master
    // Added 'output' port so the calling block can evaluate the data
    task read_byte(output logic [7:0] received_byte);
        int i;
        for (i = 7; i >= 0; i--) begin
            @(posedge scl);
            received_byte[i] = sda;
        end
    endtask

    // Task to generate the Acknowledge
    task send_ack();
        // Wait for SCL to go low (Master finished sending bit 0)
        @(negedge scl);
        
        // Drive SDA LOW (ACK)
        tb_drive_sda_low = 1;
        
        // Wait for the Master to clock the ACK (Low -> High -> Low)
        @(posedge scl); 
        @(negedge scl); 
        
        // Release SDA
        tb_drive_sda_low = 0;
    endtask

    // --------------------------------------------------------
    // Main Stimulus
    // --------------------------------------------------------
    initial begin
        $display("--- Simulation Start ---");
        reset_n = 0; 
        #100;
        reset_n = 1; 
        
        #200000000; 
        
        $display("--- Simulation End ---");
        $stop;
    end

endmodule