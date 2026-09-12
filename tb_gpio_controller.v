
`timescale 1ns/1ps

module tb_gpio_controller;

    // APB signals
    reg PCLK;
    reg rst_n;
    reg [7:0]PADDR;
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [31:0]PWDATA;
    wire [31:0]PRDATA;
    wire PREADY;

    reg  [31:0] gpio_data_in;
    wire [31:0] gpio_data_out;
    wire [31:0] gpio_dir;

    //REGISTER ADDRESSES
    localparam ADDR_DATAOUT = 8'h00;
    localparam ADDR_DIR     = 8'h04;
    localparam ADDR_DATAIN  = 8'h08;
    localparam ADDR_INVALID = 8'h0C;
    
    integer pass_count = 0;
    integer fail_count = 0;

    // DUT Instantiation
    gpio_controller dut(
        .PCLK(PCLK),
        .rst_n(rst_n),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .gpio_data_in(gpio_data_in),
        .gpio_data_out(gpio_data_out),
        .gpio_dir(gpio_dir)
    );

    // Clock generation
    initial PCLK = 1'b0;
    always #5 PCLK = ~PCLK;

    //INITIAL VALUES - SET THE INPUT VARIABLES TO SOME INITIAL VALUE
    initial begin
        PADDR = 8'b0;
        PSEL = 1'b0;
        PENABLE = 1'b0;
        PWRITE = 1'b0;
        PWDATA = 32'b0;

        gpio_data_in = 32'b0;
    end

    //RESET TASK
    task reset;
        begin
            @(negedge PCLK) rst_n = 1'b1;
            repeat(4) @(negedge PCLK) rst_n = 1'b0;
            @(negedge PCLK) rst_n = 1'b1;
        end
    endtask

    //APB WRITE TASK
    task apb_write(input [7:0] addr, input [31:0] data);
        begin
            @(negedge PCLK) begin
                PSEL = 1'b1;
                PENABLE = 1'b0;     // SETUP phase
                PWRITE = 1'b1;
                PADDR = addr;
                PWDATA = data;
            end

            @(negedge PCLK)
                PENABLE = 1'b1;     // ACCESS phase

            repeat(2) @(negedge PCLK);
            PSEL = 1'b0;
            PWRITE = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    //APB READ TASK
    task apb_read(input [7:0] addr, output [31:0] data);
        begin
            @(negedge PCLK) begin
                PSEL = 1'b1;
                PENABLE = 1'b0;     // SETUP phase
                PWRITE = 1'b0;
                PADDR = addr;
            end

            @(negedge PCLK)
                PENABLE = 1'b1;     // ACCESS phase

            @(posedge PCLK);
            #2;
            data = PRDATA;         

            @(negedge PCLK);
            PSEL = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    task check32(input [255:0] name, input [31:0] expected, input [31:0] actual);
        begin
            if (expected === actual) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s : expected=0x%08h actual=0x%08h", name, expected, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s : expected=0x%08h actual=0x%08h", name, expected, actual);
            end
        end
    endtask

    //self-checking comparator (for PREADY)
    task check1(input [255:0] name, input expected, input actual);
        begin
            if (expected === actual) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s : expected=%b actual=%b", name, expected, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s : expected=%b actual=%b", name, expected, actual);
            end
        end
    endtask

    // Readable state name for the debug display
    function [23:0] state_name(input [1:0] s);
        begin
            case(s)
                2'b00: state_name = "IDL";
                2'b01: state_name = "SET";
                2'b10: state_name = "ACC";
                default: state_name = "???";
            endcase
        end
    endfunction

    always @(posedge PCLK) begin
        #1;
        $display("t=%0t | state=%s | PSEL=%b PENABLE=%b PWRITE=%b PADDR=%h | PWDATA=%h PRDATA=%h PREADY=%b | dir_reg=%h dataout_reg=%h | gpio_data_in=%h",
                   $time, state_name(dut.state), PSEL, PENABLE, PWRITE, PADDR,
                   PWDATA, PRDATA, PREADY, dut.gpio_dir_reg, dut.gpio_data_out_reg, gpio_data_in);
    end

    reg [31:0] rdata;

    initial begin
        reset;
        check1("TEST_00 PREADY tied high after reset", 1'b1, PREADY);

        apb_read(ADDR_DIR, rdata);
        check32("TEST_01a reset DIR reg", 32'h0, rdata);
        apb_read(ADDR_DATAOUT, rdata);
        check32("TEST_01b reset DATAOUT reg", 32'h0, rdata);
        check1("TEST_01c PREADY tied high", 1'b1, PREADY);

        apb_write(ADDR_DIR, 32'hF0F0_F0F0);
        apb_read(ADDR_DIR, rdata);
        check32("TEST_02 DIR readback", 32'hF0F0_F0F0, rdata);

        apb_write(ADDR_DATAOUT, 32'hDEAD_BEEF);
        apb_read(ADDR_DATAOUT, rdata);
        check32("TEST_03 DATAOUT readback", 32'hDEAD_BEEF, rdata);

        gpio_data_in = 32'hCAFE_BABE;
        apb_read(ADDR_DATAIN, rdata);
        check32("TEST_04a DATAIN readback via APB", 32'hCAFE_BABE, rdata);

        PADDR = ADDR_DATAIN;
        PSEL = 1'b1; PENABLE = 1'b1; PWRITE = 1'b0;
        gpio_data_in = 32'h1111_2222;
        #1;
        check32("TEST_04b DATAIN tracks gpio_data_in combinationally", 32'h1111_2222, PRDATA);
        gpio_data_in = 32'h3333_4444;
        #1;
        check32("TEST_04c DATAIN tracks gpio_data_in combinationally (2nd change)", 32'h3333_4444, PRDATA);
        PSEL = 1'b0; PENABLE = 1'b0;
        @(negedge PCLK);

        apb_write(ADDR_DIR, 32'h0000_00FF);  
        @(negedge PCLK);
        PSEL = 1'b1; PENABLE = 1'b0; PWRITE = 1'b0; PADDR = ADDR_DIR; PWDATA = 32'hFFFF_FFFF;
        @(negedge PCLK);
        PENABLE = 1'b1;
        @(negedge PCLK);
        @(negedge PCLK);
        PSEL = 1'b0; PENABLE = 1'b0;
        @(negedge PCLK);
        apb_read(ADDR_DIR, rdata);
        check32("TEST_05 PWRITE=0 does not modify DIR reg", 32'h0000_00FF, rdata);

        apb_write(ADDR_DIR, 32'hAAAA_AAAA);
        apb_write(ADDR_DATAOUT, 32'h5555_5555);
        apb_write(ADDR_INVALID, 32'hFFFF_FFFF);
        apb_read(ADDR_DIR, rdata);
        check32("TEST_06a DIR unaffected by invalid-address write", 32'hAAAA_AAAA, rdata);
        apb_read(ADDR_DATAOUT, rdata);
        check32("TEST_06b DATAOUT unaffected by invalid-address write", 32'h5555_5555, rdata);

        apb_read(ADDR_INVALID, rdata);
        check32("TEST_07 invalid address read", 32'h0000_0000, rdata);

        @(negedge PCLK);
        PSEL = 1'b1; PENABLE = 1'b0; PWRITE = 1'b1; PADDR = ADDR_DIR; PWDATA = 32'h1234_5678;
        @(negedge PCLK);
        PENABLE = 1'b1;
        @(negedge PCLK);
        @(negedge PCLK);            
        
        PENABLE = 1'b0;
        PADDR = ADDR_DATAOUT; PWDATA = 32'h8765_4321;
        @(negedge PCLK);
        PENABLE = 1'b1;
        @(negedge PCLK);
        @(negedge PCLK);         
        PSEL = 1'b0; PENABLE = 1'b0; PWRITE = 1'b0;
        @(negedge PCLK);
        apb_read(ADDR_DIR, rdata);
        check32("TEST_08a back-to-back write 1 (DIR)", 32'h1234_5678, rdata);
        apb_read(ADDR_DATAOUT, rdata);
        check32("TEST_08b back-to-back write 2 (DATAOUT)", 32'h8765_4321, rdata);

        #20;
        $display("--------------------------------------------------");
        $display("TESTS PASSED: %0d", pass_count);
        $display("TESTS FAILED: %0d", fail_count);
        $display("--------------------------------------------------");
        $finish;
    end

    // Safety timeout
    initial begin
        #10000;
        $display("[TIMEOUT] Testbench did not finish in time.");
        $finish;
    end

endmodule