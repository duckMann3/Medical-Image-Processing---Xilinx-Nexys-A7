`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CECS 361
// Engineer: Jonathan Fuentes
// 
// Create Date: 10/18/2025 11:52:20 PM
// Design Name: 
// Module Name: spi_master_byte
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi_master_byte(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] din, // 8-bit transmission on MOSI
    input wire [7:0] dout, // last received byte from MISO
    output reg sck,
    output reg busy,
    output reg mosi,
    input wire miso
    );
   
   localparam IDLE = 0;
   localparam RUN = 1;
   reg state; // 
    
    reg [7:0] shreg_out;
    reg [7:0] shreg_in;
    reg [8:0] bitcnt; 
    reg [15:0] clk_div;
    
    always@(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            busy <= 1'b0;
            sck <= 1'b0;
            mosi <= 1'b1;
            dout <= 8'b0000_0000;
            
        end
        else begin
            case (state)
                IDLE: begin 
                    sck <= 0;
                        if (start) begin
endmodule
