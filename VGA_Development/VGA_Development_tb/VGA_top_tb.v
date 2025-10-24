`timescale 1ns / 1ps

module VGA_top_tb();

reg clk;
reg reset_tb;
wire h_sync;
wire v_sync;
wire [3:0] vga_r;
wire [3:0] vga_g;
wire [3:0] vga_b;

VGA_top uut(.clock(clk), .reset_n(reset_tb), .h_sync(h_sync), .v_sync(v_sync), .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b));

always #10 clk = ~clk;

initial begin
    clk = 0;
    // Reset pulse
    reset_tb = 0;
    #200;
    reset_tb = 1;
    #100;
end

endmodule
