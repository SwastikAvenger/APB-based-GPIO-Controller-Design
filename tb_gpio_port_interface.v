//`timescale 1ns/1ps

//module tb_gpio_port_interface();
//    reg PCLK;   
//    reg [31:0] gpio_data_out;
//    reg [31:0] gpio_dir;
//    wire [31:0] gpio_data_in;
//    wire [31:0] xpins;
    
//    reg [31:0] temp_xpins;
    
//    // Drive xpins ONLY when configured as inputs (gpio_dir == 0)
//    assign xpins = (gpio_dir == 32'h0) ? temp_xpins : 32'bz;
    
//    // Initial Values
//    initial begin
//        PCLK = 1'b0;
//        gpio_data_out = 32'b0;
//        gpio_dir = 32'b0;
//        temp_xpins = 32'bz;
//    end
    
//    // Clock Generation
//    always #5 PCLK = ~PCLK;
    
//    // DUT Instantiation
//    gpio_port_interface dut(
//        .PCLK(PCLK),
//        .gpio_data_out(gpio_data_out),
//        .gpio_data_in(gpio_data_in),
//        .xpins(xpins),
//        .gpio_dir(gpio_dir)
//    );
    
//    // WRITE TASK
//    task automatic write;
//        begin
//            gpio_dir = 32'hFFFF_FFFF; // WRITE OPERATION - configured as outputs
//            gpio_data_out = {$random};      //random data, driving to the peripherals
//            temp_xpins = 32'bz;         //During Write, temp_xpins will be high impedance, 
//                                        //since, xpins will have the data of gpio_data_out
//        end
//    endtask
    
//    // READ TASK
//    task automatic read;
//        begin
//            gpio_dir   = 32'h0000_0000;    // READ OPERATION - configured as inputs
//            temp_xpins = {$random};        //During Read, the xpins will have random data from 
//                                           //the peripherals. That's why temp_xpins have random value
//        end
//    endtask
    
//    // STIMULUS 
//    initial begin
//        //Write Operation
//        repeat(5) @(negedge PCLK) write;
        
//        //Read Operation
//        repeat(5) @(negedge PCLK) read;
        
//        #100 $finish();  
//    end
//endmodule

`timescale 1ns/1ps
 
module tb_gpio_port_interface();
    reg         PCLK;
    reg         rst_n;
    reg  [31:0] gpio_data_out;
    reg  [31:0] gpio_dir;
    wire [31:0] gpio_data_in;
    wire [31:0] xpins;
    reg  [31:0] temp_xpins;
 
    assign xpins = (gpio_dir == 32'h0) ? temp_xpins : 32'bz;
 
    // Initial Values
    initial begin
        PCLK          = 1'b0;
        rst_n         = 1'b0;
        gpio_data_out = 32'b0;
        gpio_dir      = 32'b0;
        temp_xpins    = 32'bz;
    end
 
    // Clock Generation
    always #5 PCLK = ~PCLK;
 
    // DUT Instantiation
    gpio_port_interface dut(
        .PCLK(PCLK),
        .rst_n(rst_n),
        .gpio_data_out(gpio_data_out),
        .gpio_data_in(gpio_data_in),
        .xpins(xpins),
        .gpio_dir(gpio_dir)
    );

    reg [31:0] ref_ff1, ref_ff2, ref_data_in;
    always @(posedge PCLK or negedge rst_n) begin
        if (!rst_n) begin
            ref_ff1     <= 32'h0;
            ref_ff2     <= 32'h0;
            ref_data_in <= 32'h0;
        end else begin
            ref_ff1     <= xpins;
            ref_ff2     <= ref_ff1;
            ref_data_in <= ref_ff2;
        end
    end
 
    integer pass_count = 0;
    integer fail_count = 0;
 
    task check_data_in;
        begin
            if (gpio_data_in === ref_data_in) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] t=%0t gpio_data_in mismatch: dut=%h expected=%h",
                          $time, gpio_data_in, ref_data_in);
            end
        end
    endtask
 
    task check_write_loopback;
        begin
            if (gpio_dir == 32'hFFFF_FFFF) begin
                #1; // Combinational tri-state drivers settle
                if (xpins === gpio_data_out) begin
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                    $display("[FAIL] t=%0t xpins does not match gpio_data_out: xpins=%h gpio_data_out=%h",
                              $time, xpins, gpio_data_out);
                end
            end
        end
    endtask
 
    // Per-cycle debug display
    always @(posedge PCLK) begin
        #2;
        $display("t=%0t | rst_n=%b | gpio_dir=%h | gpio_data_out=%h | temp_xpins=%h | xpins=%h | gpio_data_in=%h | ref_data_in=%h",
                   $time, rst_n, gpio_dir, gpio_data_out, temp_xpins, xpins, gpio_data_in, ref_data_in);
    end
 
    // WRITE TASK
    task automatic write;
        begin
            gpio_dir      = 32'hFFFF_FFFF; // WRITE OPERATION - configured as outputs
            gpio_data_out = {$random};     // random data, driving to the peripherals
            temp_xpins    = 32'bz;         // hi-Z during write: DUT drives xpins instead
            check_write_loopback;
        end
    endtask
 
    // READ TASK
    task automatic read;
        begin
            gpio_dir   = 32'h0000_0000;    // READ OPERATION - configured as inputs
            temp_xpins = {$random};        // random data emulating an external peripheral
        end
    endtask
 
    // STIMULUS
    initial begin
        //Reset check
        repeat (3) @(negedge PCLK);
        if (gpio_data_in === 32'h0) begin
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] t=%0t gpio_data_in not reset to 0: %h", $time, gpio_data_in);
        end
        @(negedge PCLK);
        rst_n = 1'b1;
 
        //Write Operation
        repeat(5) @(negedge PCLK) write;
 
        //Read Operation
        repeat(5) @(negedge PCLK) read;

        repeat(3) @(negedge PCLK);
 
        #20;
        $display("TESTS PASSED: %0d", pass_count);
        $display("TESTS FAILED: %0d", fail_count);
        $finish();
    end

    always @(posedge PCLK) begin
        #3;
        if (rst_n === 1'b1) check_data_in;
    end
 
endmodule