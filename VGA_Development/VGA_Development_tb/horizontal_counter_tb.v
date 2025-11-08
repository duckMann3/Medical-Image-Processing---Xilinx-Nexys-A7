`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 10:54:51 PM
// Design Name: 
// Module Name: horizontal_counter_tb
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


module horizontal_counter_tb;
localparam integer H_TOTAL_TB = 8;

  reg  clk_25MHz = 1'b0;
  reg  reset = 1'b1;
  wire [9:0] H_count_value;
  wire enable_V_counter;

  horizontal_counter #(.H_TOTAL(H_TOTAL_TB)) dut (.clk_25MHz(clk_25MHz), .reset(reset),
    .enable_V_counter(enable_V_counter), .H_count_value(H_count_value)
  );

  always #10 clk_25MHz = ~clk_25MHz;

  initial $timeformat(-9, 0, " ns", 7);

  integer errors = 0;
  integer checks = 0;
  reg have_prev = 0;
  reg [9:0] prev_H  = 10'd0;
  reg prev_en = 1'b0;

  // Pulse mode
  // 0 = unknown, 1 = pulse on WRAP (when current H==0),
  // 2 = pulse on PRE-WRAP (when previous H==H_TOTAL-1).
  reg [1:0] pulse_mode = 2'd0;

  // prints the first N cycles so you always see live output
  // use run -all on the console to see the rest of the cases
  integer heartbeat_left = 50;

  always @(posedge clk_25MHz) begin
    if (reset) begin
      have_prev   <= 1'b0;
      prev_H      <= 10'd0;
      prev_en     <= 1'b0;
      pulse_mode  <= 2'd0;   // re-learn after reset
    end else begin
      if (!have_prev) begin
        have_prev <= 1'b1;
        prev_H    <= H_count_value;
        prev_en   <= enable_V_counter;
      end else begin
        // Heartbeat (for the first few cycles)
        if (heartbeat_left > 0) begin
          $display("[%0t] INFO: H=%0d en=%0b (prev_H=%0d prev_en=%0b, mode=%0d)",
                   $time, H_count_value, enable_V_counter, prev_H, prev_en, pulse_mode);
          heartbeat_left = heartbeat_left - 1;
        end

        if (prev_H == (H_TOTAL_TB - 1)) begin
          // This must wrap to 0
          if (H_count_value !== 10'd0) begin
            $display("[%0t] ERROR: wrap expected: prev_H=%0d, got H=%0d",
                     $time, prev_H, H_count_value);
            errors = errors + 1;
          end

          // check enable pulse placement
          if (pulse_mode == 2'd0) begin
            if (enable_V_counter && !prev_en)      pulse_mode <= 2'd1; // on wrap
            else if (!enable_V_counter && prev_en) pulse_mode <= 2'd2; // pre-wrap
            else begin
              $display("[%0t] ERROR: couldn't learn enable pulse around first wrap (prev_en=%0b curr_en=%0b)",
                       $time, prev_en, enable_V_counter);
              errors = errors + 1;
            end
          end else if (pulse_mode == 2'd1) begin
            if (enable_V_counter !== 1'b1) begin
              $display("[%0t] ERROR: en should be 1 on WRAP (H==0). Got %0b", $time, enable_V_counter);
              errors = errors + 1;
            end
          end else if (pulse_mode == 2'd2) begin
            if (enable_V_counter !== 1'b0) begin
              $display("[%0t] ERROR: en should be 0 on WRAP when pulse is PRE-WRAP. Got %0b",
                       $time, enable_V_counter);
              errors = errors + 1;
            end
            if (prev_en !== 1'b1) begin
              $display("[%0t] ERROR: en should have been 1 on PRE-WRAP (prev_H==H_TOTAL-1). prev_en=%0b",
                       $time, prev_en);
              errors = errors + 1;
            end
          end
        end else begin
          // must increment by +1
          if (H_count_value !== (prev_H + 10'd1)) begin
            $display("[%0t] ERROR: increment expected: prev_H=%0d, got H=%0d (expected %0d)",
                     $time, prev_H, H_count_value, prev_H + 10'd1);
            errors = errors + 1;
          end
          // On non-wrap cycles, en must be 0 (except for pre-wrap mode when CURRENT H==H_TOTAL-1)
          if (enable_V_counter !== 1'b0) begin
            if (!(pulse_mode==2'd2 && (H_count_value==(H_TOTAL_TB-1)))) begin
              $display("[%0t] ERROR: en should be 0 on non-wrap cycles. Got %0b (prev_H=%0d H=%0d)",
                       $time, enable_V_counter, prev_H, H_count_value);
              errors = errors + 1;
            end
          end
        end

        checks = checks + 1;

        prev_H  <= H_count_value;
        prev_en <= enable_V_counter;
      end
    end
  end

  initial begin
    $display("=== horizontal_counter_tb (H_TOTAL_TB=%0d) ===", H_TOTAL_TB);

    // Reset for 3 cycles
    repeat (3) @(posedge clk_25MHz);
    reset = 1'b0;
    $display("[%0t] INFO: reset deasserted", $time);

    // Run through several wraps
    repeat (H_TOTAL_TB * 6) @(posedge clk_25MHz);

    // Mid-run reset & re-learn
    reset = 1'b1; @(posedge clk_25MHz);
    $display("[%0t] INFO: mid-run reset asserted", $time);
    reset = 1'b0; @(posedge clk_25MHz);
    $display("[%0t] INFO: mid-run reset released", $time);

    // Run again
    repeat (H_TOTAL_TB * 6) @(posedge clk_25MHz);

    // Summary
    $display("------------------------------------------------");
    if (errors == 0)
      $display("PASS: horizontal_counter_tb %0d checks, no mismatches. (pulse_mode=%0d)", checks, pulse_mode);
    else
      $display("FAIL: horizontal_counter_tb found %0d mismatches over %0d checks. (pulse_mode=%0d)",
               errors, checks, pulse_mode);
    $display("------------------------------------------------");

    $finish;
  end

endmodule