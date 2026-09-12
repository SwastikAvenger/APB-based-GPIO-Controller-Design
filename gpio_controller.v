
/*
The GPIO Controller has the inbuilt registers which are configured by the APB interface.
*/

`timescale 1ns/1ps

module gpio_controller(

    //APB Signals
        input wire PCLK,
        input wire rst_n,
        input wire [7:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [31:0] PWDATA,   
        output reg [31:0] PRDATA,
        output PREADY,  
        
    //Port Interface Signals
        input wire [31:0] gpio_data_in,     //Received from the Port Interface, the data sent by peripheral
        output wire [31:0] gpio_data_out,   //Sent to the Port Interface, the data sent by master
        output wire [31:0] gpio_dir         //Sent to the Port Interface, the direction of the XPINS
       
    );
        reg [31:0] gpio_dir_reg;        //temporary direction register  
        reg [31:0] gpio_data_out_reg;   //temporary WRITE data register
        
    assign gpio_data_out = gpio_data_out_reg;
    assign gpio_dir = gpio_dir_reg;
    
    assign PREADY = 1'b1;   //hard-coding the PREADY signal to high value, to avoid the WAIT State
    
    //Defining the Address of each register
    localparam ADDR_DATAOUT = 8'h00;        //TO DRIVE THE GPIO PINS, WRITE TO GPIO PINS
    localparam ADDR_DIR = 8'h04;            //WRITE TO PINS or READ FROM PINS
    localparam ADDR_DATAIN = 8'h08;         //TO READ THE GPIO PINS, READ FROM GPIO PINS
    
    //FSM states for the APB Transaction
    parameter IDLE = 2'b00;
    parameter SETUP = 2'b01;
    parameter ACCESS = 2'b10;
    
    reg [1:0] state, next;      //state for PRESENT State, next for NEXT State of the APB FSM.
    
    //PRESENT STATE LOGIC of the FSM
    always@(posedge PCLK or negedge rst_n)begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next;
    end
    
    //NEXT STATE LOGIC of the FSM
    always@(*)begin
        case(state)
            IDLE: 
                    if(PSEL) next = SETUP;
                    else next = IDLE;
            SETUP: 
                    if(PENABLE) next = ACCESS;
                    else next = SETUP;
            ACCESS:
                    next = IDLE;
                    
            default: next = IDLE;
        endcase
    end
    
    //OUTPUT WRITE LOGIC
    always@(posedge PCLK or negedge rst_n)begin
        if(!rst_n)begin
            //Internal registers are reset to zero
             gpio_dir_reg <= 0;     
             gpio_data_out_reg <= 0;  
        end
        else if(state==ACCESS && PWRITE)begin       //Peripherals will sample data from the master in the Access State, only if PWRITE is high
            case(PADDR)     //WRITE TO THE REGISTERS VIA THEIR ADDRESSES || ALL DATA FOR THESE REGISTERS WILL COME FROM PWDATA BUS
                ADDR_DATAOUT:
                    gpio_data_out_reg <= PWDATA;
                ADDR_DIR:
                    gpio_dir_reg <= PWDATA;     //Here, there are 32 seperare pins. The data can be any combination of 0(low) and/or F(high)
                                                /*
                                                    bit 0 --> 0/F   XPIN-0 direction (Input/Output)
                                                    bit 1 --> 0/F   XPIN-1 direction (Input/Output)
                                                    bit 2 --> 0/F   XPIN-2 direction (Input/Output)
                                                      .  .     .
                                                      .  .     .
                                                   bit 31 --> 0/F   XPIN-31 direction (Input/Output)
                                                */
                default: ;      //Hold Current Value
            endcase
        end
    end  
    
    //INPUT READ LOGIC
    always@(*)begin         //read logic is combinational in nature
        case(PADDR)
            ADDR_DATAOUT:               //What content is written to the output register by MASTER, NOT THE CONTENT OF THE PERIPHERAL
                PRDATA = gpio_data_out_reg;
            ADDR_DIR:                       //read the content of the direction register (whether read operation or write operation? )
                PRDATA = gpio_dir_reg;
            ADDR_DATAIN:                    //Reading the contents sent by the Peripheral to the master
                PRDATA = gpio_data_in;      //XPINS are connected to this bus. When direction is READ(0), the contents of this bus is read
            default: 
                PRDATA = 32'b0;
        endcase
    end
endmodule
                /*
                    The PWDATA bus is used to write to all the registers. It can be either the content of direction or the actual data
                    to be written to the peripheral. 
                    
                    Likewise, PRDATA bus is used to read the contents of all the registers. It can be the content of the direction register,
                    the output register, which holds the output value to be written to the peripheral unit (what is being written),
                    or the input register, which has the value provided by the peripheral unit for the master.
                    
                    In all the cases, these registers are chosen by using the PADDR line. The value in the PADDR line is the address
                    and can be either 0x00, 0x04 or 0x08. The registers are 32 bit, hence the gap of 4units hex value.
                */