`timescale 1ns / 1ps

module vertical_counter#(
  parameter integer V_TOTAL = 525
)(
  input  wire       clk_25MHz,
  input  wire       reset,               // async high
  input  wire       enable_V_counter,    // 1 when we should increment
  output reg  [9:0] V_count_value = 10'd0
);
always @(posedge clk_25MHz or posedge reset) begin
  if (reset) begin
    V_count_value <= 10'd0;
  end else if (enable_V_counter) begin
    if (V_count_value == V_TOTAL - 1)
      V_count_value <= 10'd0;
    else
      V_count_value <= V_count_value + 10'd1;
  end
  // else: hold
end
endmodule