`timescale 1ns / 1ps

module tb_combfilter;
    //refrence model
    logic signed [15:0] ref_bram [440:0];
    logic [8:0] bram_pointer = 0;
    logic [15:0] golden_output = 0;
    //Signal Initialization
    logic start_clocks = 0;
    logic master_clk;
    logic word_clk = 0;
    logic serial_clk = 0;
    logic data_in = 0; //data into read
    logic rst_n = 0;

    logic [15:0] read_data = 0;
    logic read_done;

    
    logic [15:0] filter_output = 0;
    logic output_ready;

    //testbench vars
    int fd;
    int line_counter = 0;
    string hex_in;
    logic [15:0] input_data; 
    integer bit_index = 0;

    logic [15:0] expected_queue [$];
    logic [15:0] current_expected; // Holds the frame currently being evaluated

    I2SREAD read_stage(
        .wclk(word_clk),
        .sclk(serial_clk),
        .datain(data_in),
        .dataout(read_data),
        .read_done(read_done),
        .rst_n(rst_n),
        .ready(1)
    );
    FilterController combfilter(
        .sclk(serial_clk),
        .wclk(word_clk),
        .in_data(read_data),
        .read_done(read_done),
        .rst_n(rst_n),
        .out_data(filter_output),
        .output_ready(output_ready),
        .ready(1)
    );

    
    
    //Clock generation
    localparam real SERIAL_CLOCK_HALF_PERIOD = (1000000000 / 1411200)/2;
    initial begin
        forever begin
            #(SERIAL_CLOCK_HALF_PERIOD) serial_clk = ~serial_clk;
        end  
    end

   
    logic [4:0] clk_div = 0; 

    always @(negedge serial_clk) begin
        clk_div <= clk_div + 1;
        if (clk_div == 5'd15 || clk_div == 5'd31) begin
            word_clk <= ~word_clk;
        end
    end
    //Set up test
    initial begin
        ref_bram = '{default: '0};
        fd = $fopen("stimulus.txt", "r");
        
        //I2S Writer to simulate the ADC
        @(posedge rst_n);
        @(posedge word_clk);
        while (line_counter <= 10000) begin
            if ($fgets(hex_in, fd)) begin
                input_data = hex_in.atohex();
                expected_queue.push_back(input_data);
                expected_queue.push_back(input_data);
            end else begin
                $display("failed reading a line");
            end
            repeat(2)begin //for both left and right channels
                bit_index = 0;
                while(bit_index <= 15)begin
                    //Shift data(delayed by 1 bit)
                    @(negedge serial_clk);
                    data_in = input_data[15-bit_index];
                    bit_index = bit_index+1;
                end
            end
            
            line_counter = line_counter + 1;
        end
        $display("Simulation Completed With No Errors");
        $finish;
    end
    initial begin
        @(posedge rst_n);
        forever begin
            repeat(2)begin
               @(posedge read_done);
                current_expected = expected_queue.pop_front();
                if(read_data !== current_expected)begin
                    $display("Current Input Data: %d", current_expected);
                    $display("DUT Data: %d", read_data);
                    $display("Current Line: %d", line_counter);
                    $display("Current Time: %t", $realtime);
                    $error("read data doesn't match input data");
                    $finish;
                end
                @(posedge output_ready);
                golden_ref_add();
                if(filter_output !== golden_output)begin
                    $display("Reference: %d", golden_output);
                    $display("DUT: %d", filter_output);
                    $display("Current Line: %d", line_counter);
                    $display("Current Time: %t", $realtime);
                    $error("filter output doesn't match golden reference model");
                    $finish;
                end         
            end
            ref_bram[bram_pointer] = golden_output;
            
        end
    end
    initial begin
        //increment bram pointer on negative edge of the world clock to align with DUT
        @(posedge rst_n);
        @(negedge word_clk);
        forever begin
            @(negedge word_clk);
            if(bram_pointer == 440)begin
                bram_pointer = 0;
            end else begin
                bram_pointer = bram_pointer + 1;
            end
        end
    end
    initial begin
        $display("--- Simulation Start ---");
        rst_n = 0; 
        #4000;
        rst_n = 1; 
    end
    task golden_ref_add();
        //safely read one behind the write pointer
        //models dut behavior, doesn't read from memory we just wrote in the earlier part of the cycle
        logic [8:0] read_pointer;
        logic signed [17:0]full_product;
        logic signed [15:0]shifted_product;
        if(bram_pointer == 9'd440)begin
            read_pointer = 9'd0;
        end else begin
            read_pointer = bram_pointer + 1;
        end
        full_product = 3'sd3*ref_bram[read_pointer];
        shifted_product = full_product >>> 2;
        golden_output = shifted_product + current_expected;
        //check for overflow
        //If inputs have same signs but output has different sign
        if(shifted_product[15] == current_expected[15] && golden_output[15] != current_expected[15])begin
            //saturate
            if(current_expected[15] == 1)begin
                golden_output = 16'h8000;
            end else begin
                golden_output = 16'h7fff;
            end
        end
    endtask

endmodule

