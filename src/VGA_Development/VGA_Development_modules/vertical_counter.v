`timescale 1ns / 1ps

module vertical_counter#(
  parameter V_TOTAL = 525
)(
  input clk_25MHz, 
  input reset,
  input enable_V_counter,
  output reg [9:0] V_count_value = 10'd0
);

always@(posedge clk_25MHz or posedge reset) begin
  // Keep counting until 525
  if(reset)
    V_count_value <= 10'd0;

  else if(enable_V_counter == 10'b1) begin
      if(V_count_value == (V_TOTAL - 1))
        V_count_value <= V_count_value + 10'd1;
      else
        V_count_value <= 10'd0;
  end
end

endmodule