`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 10:54:51 PM
// Design Name: 
// Module Name: vertical_counter_tb
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

module vertical_counter_tb;
  // Use a small V_TOTAL so we can exhaustively cover many wraps quickly.
  parameter integer V_TOTAL_TB = 5;

  reg  clk_25MHz        = 1'b0;
  reg  reset            = 1'b1;
  reg  enable_V_counter = 1'b0;
  wire [9:0] V_count_value;

  vertical_counter #(.V_TOTAL(V_TOTAL_TB)) dut (
    .clk_25MHz(clk_25MHz),
    .reset(reset),
    .enable_V_counter(enable_V_counter),
    .V_count_value(V_count_value)
  );

  always #10 clk_25MHz = ~clk_25MHz;

  integer cycles, errors;
  reg [9:0] expected_V;

  task check_outputs;
    begin
      if (V_count_value !== expected_V) begin
        $display("[%0t] ERROR: V_count=%0d expected=%0d (en=%0b, rst=%0b)",
                 $time, V_count_value, expected_V, enable_V_counter, reset);
        errors = errors + 1;
      end
    end
  endtask

  task step_reference;
    begin
      if (reset) begin
        expected_V <= 10'd0;
      end else if (enable_V_counter) begin
        if (expected_V == V_TOTAL_TB - 1)
          expected_V <= 10'd0;
        else
          expected_V <= expected_V + 10'd1;
      end else begin
        expected_V <= expected_V; // hold
      end
    end
  endtask

  task drive_enable_sequence;
    integer k;
    begin
      // 1) Hold low
      enable_V_counter = 1'b0;
      repeat (4) @(posedge clk_25MHz) begin
        step_reference(); #1 check_outputs(); cycles = cycles + 1;
      end

      // 2) Spaced single pulses (increment one per pulse)
      repeat (3) begin
        enable_V_counter = 1'b1; @(posedge clk_25MHz);
        step_reference(); #1 check_outputs(); cycles = cycles + 1;

        enable_V_counter = 1'b0; @(posedge clk_25MHz);
        step_reference(); #1 check_outputs(); cycles = cycles + 1;
      end

      // 3) **Solid-high burst**: MUST count 0?1?2?3?4?0...
      enable_V_counter = 1'b1;
      repeat (V_TOTAL_TB + 2) @(posedge clk_25MHz) begin
        step_reference(); #1 check_outputs(); cycles = cycles + 1;
      end
      enable_V_counter = 1'b0;

      // 4) Mid-run reset
      reset = 1'b1; @(posedge clk_25MHz);
      step_reference(); #1 check_outputs(); cycles = cycles + 1;

      reset = 1'b0; @(posedge clk_25MHz);
      step_reference(); #1 check_outputs(); cycles = cycles + 1;

      // 5) Alternating pattern
      enable_V_counter = 1'b0; @(posedge clk_25MHz);
      step_reference(); #1 check_outputs(); cycles = cycles + 1;
      enable_V_counter = 1'b1; @(posedge clk_25MHz);
      step_reference(); #1 check_outputs(); cycles = cycles + 1;
      enable_V_counter = 1'b0; @(posedge clk_25MHz);
      step_reference(); #1 check_outputs(); cycles = cycles + 1;
      enable_V_counter = 1'b1; @(posedge clk_25MHz);
      step_reference(); #1 check_outputs(); cycles = cycles + 1;

      // 6) Final wrap-length burst
      enable_V_counter = 1'b1;
      repeat (V_TOTAL_TB) @(posedge clk_25MHz) begin
        step_reference(); #1 check_outputs(); cycles = cycles + 1;
      end
      enable_V_counter = 1'b0;
    end
  endtask

  initial begin
    errors      = 0;
    cycles      = 0;
    expected_V  = 10'd0;

    // Reset for a few clocks
    repeat (3) @(posedge clk_25MHz);
    reset = 1'b0;

    drive_enable_sequence();

    if (errors == 0)
      $display("PASS: tb_vertical_counter completed %0d cycles with no mismatches.", cycles);
    else
      $display("FAIL: tb_vertical_counter found %0d mismatches over %0d cycles.", errors, cycles);

    $finish;
  end
endmodule