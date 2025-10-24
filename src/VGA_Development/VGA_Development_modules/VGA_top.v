`timescale 1ns / 1ps

module VGA_top(
  input clock,       // 100 MHz
  input reset_n,     // active-low reset
  output h_sync, 
  output v_sync,
  output [3:0] vga_r,
  output [3:0] vga_g,
  output [3:0] vga_b
);

wire clk_25Mhz;
wire rst_pixel = ~reset_n;

clock_divider VGA_clock_divider(.clk_in(clock), .reset(reset_n), .clk_out(clk_25MHz));

wire end_of_line;
wire [9:0] H_count_value;
wire [9:0] V_count_value;

horizontal_counter VGA_Horz(.clk_25MHz(clk_25MHz), .reset(reset_n), .enable_V_counter(enable_V_counter), .H_count_value(H_count_value));
vertical_counter VGA_Vert(.clk_25MHz(clk_25MHz), .reset(reset_n), .enable_V_counter(enable_V_counter), .V_count_value(V_count_value));

assign h_sync = (H_count_value < 10'd95) ? 1'b1:1'b0;
assign v_sync = (V_count_value >= 10'd0 && V_count_value <= 10'd1) ? 1'b0:1'b1;

wire video_on = (H_count_value < 784 && H_count_value > 143 && 
                V_count_value < 515 && V_count_value > 34);

assign vga_r = video_on ? 4'hf:4'h0;
assign vga_g = video_on ? 4'hf:4'h0;
assign vga_b = video_on ? 4'hf:4'h0;

endmodule