`timescale 1ns / 1ps
// ============================
// sd_block_reader.v
// After init, read one or more contiguous 512-byte blocks.
// Argument is LBA for SDHC; for SDSC, caller must pre-scale by 512 (byte address).
// Streams bytes out at 'clk' via data_valid/data_byte.
// ============================
module sd_block_reader
#(
  parameter DATA_DIV    = 16'd4,     // example: with 100 MHz -> 100e6/(2*4)=12.5 MHz
  parameter WAIT_BYTES  = 24'd800000 // timeout while waiting for token/response
)
(
  input  wire        clk,
  input  wire        rst,

  // SPI byte engine
  output wire [15:0] spi_div,
  output reg         spi_start,
  output reg  [7:0]  spi_mosi,
  input  wire        spi_busy,
  input  wire        spi_done,
  input  wire [7:0]  spi_miso,

  // SPI CS control
  output reg         sd_cs_n,

  // Control
  input  wire        start,       // pulse to start a transfer
  input  wire        multi,       // 0: CMD17 single, 1: CMD18 multi
  input  wire [31:0] lba_start,
  input  wire [31:0] blocks,      // number of blocks to read (ignored if multi=1 and stop external)
  input  wire        stop_multi,  // pulse to stop CMD18 via CMD12 when desired

  // Stream out
  output reg         data_valid,
  output reg  [7:0]  data_byte,
  output reg         block_done,  // pulses after each 512-byte block
  output reg         all_done,    // pulses when all requested blocks done (or after CMD12)
  output reg         error
);

  assign spi_div = DATA_DIV;

  localparam CMD17 = 8'h51;
  localparam CMD18 = 8'h52;
  localparam CMD12 = 8'h4C;

  reg [23:0] waitcnt;
  reg [8:0]  bcnt;        // 0..511
  reg [31:0] cur_lba;
  reg [31:0] blocks_left;

  reg [7:0]  r1;
  reg [7:0]  token;

  // states
  localparam R_IDLE       = 0,
             R_CMD_SEND   = 1,
             R_CMD_R1     = 2,
             R_WAIT_TOK   = 3,
             R_STREAM     = 4,
             R_DROP_CRC   = 5,
             R_BLK_DONE   = 6,
             R_NEXT_BLK   = 7,
             R_SEND_STOP  = 8,
             R_STOP_R1    = 9,
             R_DONE       = 10,
             R_ERR        = 11;

  reg [3:0] state;
  reg [2:0] ph; // packet byte phase 0..5

  // Helpers
  task start_byte;
  begin
    if (!spi_busy && !spi_done) spi_start <= 1'b1;
  end
  endtask

  always @(posedge clk) begin
    if (rst) begin
      sd_cs_n     <= 1'b1;
      spi_start   <= 1'b0;
      spi_mosi    <= 8'hFF;
      data_valid  <= 1'b0;
      data_byte   <= 8'h00;
      block_done  <= 1'b0;
      all_done    <= 1'b0;
      error       <= 1'b0;
      state       <= R_IDLE;
      waitcnt     <= 24'd0;
      bcnt        <= 9'd0;
      cur_lba     <= 32'd0;
      blocks_left <= 32'd0;
      r1          <= 8'hFF;
      token       <= 8'hFF;
      ph          <= 3'd0;
    end else begin
      spi_start  <= 1'b0;
      data_valid <= 1'b0;
      block_done <= 1'b0;
      all_done   <= 1'b0;

      case (state)
        R_IDLE: begin
          sd_cs_n     <= 1'b1;
          if (start) begin
            sd_cs_n     <= 1'b0;
            cur_lba     <= lba_start;
            blocks_left <= blocks;
            ph          <= 3'd0;
            state       <= R_CMD_SEND;
            error       <= 1'b0;
          end
        end

        // Send CMD17/CMD18 packet: [cmd][arg][crc]
        R_CMD_SEND: begin
          if (!spi_busy && !spi_done) begin
            case (ph)
              3'd0: begin spi_mosi <= multi ? CMD18 : CMD17; start_byte(); ph<=3'd1; end
              3'd1: begin spi_mosi <= cur_lba[31:24];         start_byte(); ph<=3'd2; end
              3'd2: begin spi_mosi <= cur_lba[23:16];         start_byte(); ph<=3'd3; end
              3'd3: begin spi_mosi <= cur_lba[15:8];          start_byte(); ph<=3'd4; end
              3'd4: begin spi_mosi <= cur_lba[7:0];           start_byte(); ph<=3'd5; end
              3'd5: begin spi_mosi <= 8'hFF;                  start_byte(); ph<=3'd6; end // dummy CRC ok in SPI
              default: begin ph<=3'd0; waitcnt<=WAIT_BYTES; state<=R_CMD_R1; end
            endcase
          end
        end

        // Read R1
        R_CMD_R1: begin
          if (waitcnt==0) begin error<=1'b1; state<=R_ERR; end
          else if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; start_byte(); waitcnt<=waitcnt-1; end
          if (spi_done) begin
            r1 <= spi_miso;
            if (spi_miso==8'h00) begin bcnt<=9'd0; state<=R_WAIT_TOK; waitcnt<=WAIT_BYTES; end
            else if (spi_miso!=8'hFF) begin error<=1'b1; state<=R_ERR; end
          end
        end

        // Wait for data token 0xFE
        R_WAIT_TOK: begin
          if (waitcnt==0) begin error<=1'b1; state<=R_ERR; end
          else if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; start_byte(); waitcnt<=waitcnt-1; end
          if (spi_done) begin
            token <= spi_miso;
            if (spi_miso==8'hFE) begin state<=R_STREAM; bcnt<=9'd0; end
          end
        end

        // Stream 512 bytes
        R_STREAM: begin
          if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; start_byte(); end
          if (spi_done) begin
            data_byte  <= spi_miso;
            data_valid <= 1'b1;
            bcnt       <= bcnt + 1;
            if (bcnt == 9'd511) state<=R_DROP_CRC;
          end
        end

        // Drop 2 CRC bytes
        R_DROP_CRC: begin
          if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; start_byte(); end
          if (spi_done) begin
            if (ph==0) begin ph<=1; end
            else begin ph<=0; state<=R_BLK_DONE; end
          end
        end

        R_BLK_DONE: begin
          block_done <= 1'b1;
          if (!multi) begin
            sd_cs_n  <= 1'b1; // release after single block
            all_done <= 1'b1;
            state    <= R_DONE;
          end else begin
            // In multi mode, either continue next block or stop when asked (or count reached if provided)
            if (stop_multi || (blocks_left==32'd1)) begin
              state <= R_SEND_STOP;
              ph    <= 0;
            end else begin
              // continue to next block
              cur_lba     <= cur_lba + 32'd1;
              if (blocks_left!=0) blocks_left <= blocks_left - 32'd1;
              state <= R_NEXT_BLK;
            end
          end
        end

        // Between blocks of CMD18, card keeps streaming; we just wait for next token
        R_NEXT_BLK: begin
          waitcnt <= WAIT_BYTES;
          state   <= R_WAIT_TOK;
        end

        // CMD12 to stop transmission
        R_SEND_STOP: begin
          // Following spec: send CMD12; a "stuff byte" may appear before R1.
          if (!spi_busy && !spi_done) begin
            case (ph)
              3'd0: begin spi_mosi<=CMD12; start_byte(); ph<=1; end
              3'd1: begin spi_mosi<=8'h00; start_byte(); ph<=2; end
              3'd2: begin spi_mosi<=8'h00; start_byte(); ph<=3; end
              3'd3: begin spi_mosi<=8'h00; start_byte(); ph<=4; end
              3'd4: begin spi_mosi<=8'h00; start_byte(); ph<=5; end
              3'd5: begin spi_mosi<=8'hFD; start_byte(); ph<=6; end
              default: begin ph<=0; waitcnt<=WAIT_BYTES; state<=R_STOP_R1; end
            endcase
          end
        end

        R_STOP_R1: begin
          if (waitcnt==0) begin error<=1'b1; state<=R_ERR; end
          else if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; start_byte(); waitcnt<=waitcnt-1; end
          if (spi_done) begin
            if (spi_miso!=8'hFF) begin
              sd_cs_n  <= 1'b1;
              all_done <= 1'b1;
              state    <= R_DONE;
            end
          end
        end

        R_DONE: begin
          // idle
        end

        R_ERR: begin
          sd_cs_n <= 1'b1;
        end

        default: state <= R_ERR;
      endcase
    end
  end
endmodule

