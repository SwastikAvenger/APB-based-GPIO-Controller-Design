
/*
GPIO Port Interface will be responsible for the communication of the GPIO Controller with the external hardware GPIO Pins.
The Port Interface will allow transfer of data either to the master from the Pins, or from the master to the peripherals connected.
*/

`timescale 1ns / 1ps

module gpio_port_interface(
        input wire PCLK,        //ref. clock
        input wire rst_n,       //reset
        input wire [31:0] gpio_data_out,    //this is the data to be WRITTEN to the peripherals. This data comes from the master
        output reg [31:0] gpio_data_in,     //this is the data to be READ by the master. This data is coming from the peripherals
        inout [31:0] xpins,                 //the actual pins which will communicate with the external pins
        input [31:0] gpio_dir       //direction for each xpin - whether xpin will read or write 
    );
    
    //WRITE OPERATION
    genvar i;
    generate
        for(i=0;i<32;i=i+1)begin
            assign xpins[i] = gpio_dir[i] ? gpio_data_out[i] : 1'bz;
        end
    endgenerate
    
    //READ OPERATION
    //Implement a two flip-flop synchronizer to avoid metastability state
    //The peripheral might NOT have the idea of PCLK, hence it might be asynchronoys in nature
     
    reg [31:0] sync_ff1;
    reg [31:0] sync_ff2;
    always@(posedge PCLK or negedge rst_n)begin
        if(!rst_n)begin
            gpio_data_in <= 32'h0;
            sync_ff1 <= 32'h0;
            sync_ff2 <= 32'h0;
        end
        else begin
            sync_ff1 <= xpins;      //XPINS send data to first flipflop
            sync_ff2 <= sync_ff1;   //Second Flip Flop synchronization eliminates metastability
            gpio_data_in <= sync_ff2;      //read data from the 2nd FF and pass it to the master
        end
    end
        
        //Using a 2 flipflop synchronizer removes metastability
        //But it might add a one clock cycle latency.
        
    /*
    always@(posedge PCLK or negedge rst_n)begin
        if(!rst_n)begin
            xpins <= 32'bz;
            gpio_data_in <= 32'b0;
            gpio_data_out <= 32'b0;
        end
        else begin
            if(gpio_dir)
                xpins <= gpio_data_out;
            else gpio_data_in <= xpins;
        end
    end
    */
endmodule
