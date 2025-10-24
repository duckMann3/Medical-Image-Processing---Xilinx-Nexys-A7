`timescale 1ns / 1ps

module clock_divider_tb();
reg clk;
reg reset_tb;
wire clk_out;

clock_divider uut(.clk_in(clk), .reset(reset_tb), .clk_out(clk_out));

always #5 clk = ~clk;

initial begin
    clk=0;
    #50;
    reset_tb = 1;
    #50;
    reset_tb = 0;
    #50;
end

endmodule
