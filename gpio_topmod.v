
`timescale 1ns/1ps

module gpio_topmod(
    input wire PCLK,
    input wire rst_n,
    input wire [7:0] PADDR,
    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [31:0] PWDATA,
    output wire [31:0] PRDATA,
    output wire PREADY,
    inout wire [31:0] xpins
);
        //Interconnection Wires
        wire [31:0] gpio_dir;
        wire [31:0] gpio_data_in;
        wire [31:0] gpio_data_out;
        
    //Module Instantiation
    gpio_controller uut_gpio_ctrl(
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
        .gpio_dir(gpio_dir),
        .gpio_data_out(gpio_data_out)
    ); 
    
     gpio_port_interface uut_gpio_prt_inf(
        .PCLK(PCLK),
        .rst_n(rst_n),
        .gpio_data_out(gpio_data_out),
        .gpio_data_in(gpio_data_in),
        .gpio_dir(gpio_dir),
        .xpins(xpins) 
    );
endmodule