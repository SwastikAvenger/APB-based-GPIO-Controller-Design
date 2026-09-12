`timescale 1ns / 1ps

module tb_gpio_topmod();

    reg PCLK;
    reg rst_n;
    reg [7:0] PADDR;
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire PREADY;
    wire [31:0] xpins;

    reg  [31:0] ext_drive;
    wire [31:0] gpio_dir_probe = dut.gpio_dir;
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : EXT_DRV
            assign xpins[gi] = (gpio_dir_probe[gi] == 1'b0) ? ext_drive[gi] : 1'bz;
        end
    endgenerate

    localparam ADDR_DATAOUT = 8'h00;
    localparam ADDR_DIR     = 8'h04;
    localparam ADDR_DATAIN  = 8'h08;

    integer pass_count = 0;
    integer fail_count = 0;

    //DUT instantiation
    gpio_topmod dut(
        .PCLK(PCLK),
        .rst_n(rst_n),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .xpins(xpins)
    );

    //INITIAL VALUES
    initial begin
        PCLK      = 1'b0;
        rst_n     = 1'b1;
        PADDR     = 8'b0;
        PSEL      = 1'b0;
        PENABLE   = 1'b0;
        PWRITE    = 1'b0;
        PWDATA    = 32'h0;
        ext_drive = 32'h0000_00AA;
    end

    //CLOCK
    always #5 PCLK = ~PCLK;

    //RESET OPERATION
    task reset;
        begin
            rst_n = 1'b0;
            repeat(4) @(negedge PCLK);
            rst_n = 1'b1;
            @(negedge PCLK);
        end
    endtask

    //WRITE OPERATION
    task apb_write(input [7:0] addr, input [31:0] data);
        begin
            @(negedge PCLK) begin
                PADDR   = addr;
                PWDATA  = data;
                PENABLE = 1'b0;     //ADDRESS Phase
                PSEL    = 1'b1;     //Assert the Slave
                PWRITE  = 1'b1;     //Write Operation Underway
            end

            @(negedge PCLK)
                PENABLE = 1'b1;     //DATA Phase

            repeat(2) @(negedge PCLK);

            PSEL    = 1'b0;         //Deassert the Slave
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
        end
    endtask

    //READ OPERATION
    task apb_read(input [7:0] addr, output [31:0] data);
        begin
            @(negedge PCLK) begin
                PADDR   = addr;
                PENABLE = 1'b0;     //ADDRESS Phase
                PSEL    = 1'b1;     //Assert the Slave
                PWRITE  = 1'b0;
            end

            @(negedge PCLK)
                PENABLE = 1'b1;     //DATA Phase

            @(posedge PCLK);
            #2;
            data = PRDATA;

            @(negedge PCLK);
            PSEL    = 1'b0;         //Deassert the Slave
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

    always @(posedge PCLK) begin
        #1;
        $display("t=%0t | rst_n=%b PSEL=%b PENABLE=%b PWRITE=%b PADDR=%h PWDATA=%h PRDATA=%h | xpins=%h | dir_reg=%h dataout_reg=%h",
            $time, rst_n, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, xpins,
            dut.uut_gpio_ctrl.gpio_dir_reg, dut.uut_gpio_ctrl.gpio_data_out_reg);
    end

    reg [31:0] rdata;

    //STIMULUS
    initial begin
        reset;

        apb_write(ADDR_DIR, 32'h0000_00FF);     //DIRECTION REGISTER
        apb_read(ADDR_DIR, rdata);
        check32("DIR readback", 32'h0000_00FF, rdata);

        apb_write(ADDR_DATAOUT, 32'h0000_000A); //DATAOUT REGISTER
        apb_read(ADDR_DATAOUT, rdata);
        check32("DATAOUT readback", 32'h0000_000A, rdata);

        apb_read(ADDR_DIR, rdata);              //Reading the Data
        check32("DIR unchanged by read-back", 32'h0000_00FF, rdata);

        apb_read(ADDR_DATAIN, rdata);
        $display("[INFO] DATAIN read = 0x%08h", rdata);

        #20;
        $display("--------------------------------------------------");
        $display("TESTS PASSED: %0d", pass_count);
        $display("TESTS FAILED: %0d", fail_count);
        $display("--------------------------------------------------");
        #500 $finish();
    end

//Safety Timeout block
//    initial begin
//        #10000;
//        $finish;
//    end

endmodule        