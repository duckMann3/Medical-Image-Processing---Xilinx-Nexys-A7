`timescale 1ns / 1ps

module horizontal_counter#(
  parameter H_TOTAL = 800
)(
  input wire clk_25MHz, 
  input wire reset,
  output reg enable_V_counter = 10'b0,
  output reg [9:0] H_count_value = 10'b0
);

always@(posedge clk_25MHz or posedge reset) begin
  if(reset)
    H_count_value <= 10'd0;
  else if(H_count_value < (H_TOTAL - 1)) begin
      H_count_value <= H_count_value + 10'd1;
      enable_V_counter <= 10'b0;
  end
  else begin
    H_count_value <= 10'b0;
    enable_V_counter <= 10'b1;
  end
end

endmodule
