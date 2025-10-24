`timescale 1ns / 1ps

module clock_divider(
  input clk_in,    // 100 MHz
  input reset,
  output clk_out   // 25 MHz
);

  reg [1:0] div = 2'b00;

  always@(posedge clk_in or posedge reset) begin
    if(reset)
      div <=  2'b00;
    else
      div <= div + 1'b1;
  end

  assign clk_out = div[1]; // 100 / 4 = 25 MHz
   
endmodule