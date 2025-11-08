`timescale 1ns / 1ps
// ============================
// sd_frame_reader_top.v
// Auto-initialize then stream N contiguous 512B blocks to a simple write port.
// Pin mapping for Nexys A7 microSD SPI mode:
//   sd_mosi -> SD_CMD
//   sd_miso -> SD_DAT0
//   sd_cs_n -> SD_DAT3
//   sd_sck  -> SD_SCK
// ============================
module sd_frame_reader_top
#(
  parameter SYSCLK_HZ      = 100_000_000,
  parameter INIT_DIV       = 16'd250,  // ~200 kHz @100 MHz
  parameter DATA_DIV       = 16'd2,    // ~25 MHz @100 MHz
  parameter LBA_START      = 32'd2048, // first block to read
  parameter BLOCKS_TO_READ = 32'd600   // e.g., 640x480x8 / 512
)
(
  input  wire        clk,
  input  wire        rst,

  // SD SPI pins
  output wire        sd_sck,
  output wire        sd_mosi,
  input  wire        sd_miso,
  output wire        sd_cs_n,

  // Write port for downstream BRAM/DDR (byte-wide stream)
  output reg  [31:0] waddr,
  output reg  [7:0]  wdata,
  output reg         we,
  output reg         frame_done,

  // Debug/status
  output wire        init_ready,
  output wire        init_is_sdhc,
  output wire        any_error
);

  // -------------------------
  // Shared SPI byte engine
  // -------------------------
  wire [15:0] spi_div_sel;
  wire        spi_start;
  wire [7:0]  spi_mosi_b;
  wire        spi_busy;
  wire        spi_done;
  wire [7:0]  spi_miso_b;

  wire        sck_net, mosi_net;
  wire        cs_from_init, cs_from_rd;
  wire [15:0] div_from_init, div_from_rd;
  wire        start_from_init, start_from_rd;
  wire [7:0]  mosi_from_init,  mosi_from_rd;
    

// Which owner drives the SPI?
reg         use_init;

// Mux between init and reader
assign spi_div_sel  = use_init ? div_from_init   : div_from_rd;
assign spi_start_sel= use_init ? start_from_init : start_from_rd;
assign spi_mosi_sel = use_init ? mosi_from_init  : mosi_from_rd;
assign sd_cs_n      = use_init ? cs_from_init    : cs_from_rd;

// SPI core
spi_master_byte spi0 (
  .clk       (clk),
  .rst       (rst),
  .clk_div   (spi_div_sel),   // <-- use the muxed wire
  .start     (spi_start_sel), // <-- use the muxed wire
  .mosi_byte (spi_mosi_sel),  // <-- use the muxed wire
  .miso_byte (spi_miso_b),
  .busy      (spi_busy),
  .done      (spi_done),
  .sck       (sck_net),
  .mosi      (mosi_net),
  .miso      (sd_miso)
);

assign sd_sck  = sck_net;
assign sd_mosi = mosi_net;

  // -------------------------
  // Init block
  // -------------------------
  wire init_ready_w;
  wire init_is_sdhc_w;
  wire init_err;
  sd_spi_init #(
    .DUMMY_BYTES (10),
    .INIT_DIV    (INIT_DIV)
  ) init0 (
    .clk        (clk),
    .rst        (rst),
    .spi_div    (div_from_init),
    .spi_start  (start_from_init),
    .spi_mosi   (mosi_from_init),
    .spi_busy   (spi_busy),
    .spi_done   (spi_done),
    .spi_miso   (spi_miso_b),
    .sd_cs_n    (cs_from_init),
    .ready      (init_ready_w),
    .is_sdhc    (init_is_sdhc_w),
    .error      (init_err)
  );

  assign init_ready   = init_ready_w;
  assign init_is_sdhc = init_is_sdhc_w;

  // -------------------------
  // Block reader
  // -------------------------
  reg         rd_start;
  reg         rd_multi;
  reg  [31:0] rd_lba;
  reg  [31:0] rd_blocks;
  reg         rd_stop;

  wire [15:0] div_from_rd_w;
  assign div_from_rd = div_from_rd_w;

  wire rd_data_valid;
  wire [7:0] rd_data_byte;
  wire rd_block_done, rd_all_done, rd_err;
  sd_block_reader #(
    .DATA_DIV   (DATA_DIV),
    .WAIT_BYTES (24'd2_000_000) // generous while staying synthesizable
  ) reader0 (
    .clk        (clk),
    .rst        (rst),
    .spi_div    (div_from_rd_w),
    .spi_start  (start_from_rd),
    .spi_mosi   (mosi_from_rd),
    .spi_busy   (spi_busy),
    .spi_done   (spi_done),
    .spi_miso   (spi_miso_b),
    .sd_cs_n    (cs_from_rd),
    .start      (rd_start),
    .multi      (rd_multi),
    .lba_start  (rd_lba),
    .blocks     (rd_blocks),
    .stop_multi (rd_stop),
    .data_valid (rd_data_valid),
    .data_byte  (rd_data_byte),
    .block_done (rd_block_done),
    .all_done   (rd_all_done),
    .error      (rd_err)
  );

  // -------------------------
  // Top-level control & writer
  // -------------------------
  localparam T_INIT    = 0,
             T_WAIT    = 1,
             T_READ    = 2,
             T_FINISH  = 3;

  reg [1:0] tstate;

  assign any_error = init_err | rd_err;

  // Address & write strobe
  always @(posedge clk) begin
    if (rst) begin
      use_init    <= 1'b1;
      waddr       <= 32'd0;
      wdata       <= 8'd0;
      we          <= 1'b0;
      frame_done  <= 1'b0;
      rd_start    <= 1'b0;
      rd_multi    <= 1'b0;
      rd_lba      <= 32'd0;
      rd_blocks   <= 32'd0;
      rd_stop     <= 1'b0;
      tstate      <= T_INIT;
    end else begin
      we         <= 1'b0;
      frame_done <= 1'b0;
      rd_start   <= 1'b0;
      rd_stop    <= 1'b0;

      case (tstate)
        T_INIT: begin
          // Give init ownership of SPI
          use_init <= 1'b1;
          if (init_ready_w) begin
            tstate <= T_WAIT;
          end
          // if error, stay; user can reset externally
        end

        T_WAIT: begin
          // Switch to reader (fast clock)
          use_init <= 1'b0;

          // Compute addressing: SDHC uses block addressing; SDSC needs byte addressing (LBA*512).
          if (init_is_sdhc_w)
            rd_lba <= LBA_START;
          else
            rd_lba <= LBA_START << 9;

          rd_blocks <= BLOCKS_TO_READ;
          rd_multi  <= 1'b1; // continuous multi-block read
          rd_start  <= 1'b1;
          tstate    <= T_READ;
        end

        T_READ: begin
          // Stream data into write port
          if (rd_data_valid) begin
            wdata <= rd_data_byte;
            we    <= 1'b1;
            waddr <= waddr + 32'd1;
          end

          // Stop after requested block count completes
          if (rd_block_done && (rd_blocks==32'd1)) begin
            rd_stop   <= 1'b1;   // trigger CMD12
          end
          // track remaining blocks
          if (rd_block_done && rd_blocks!=0) begin
            rd_blocks <= rd_blocks - 32'd1;
          end

          if (rd_all_done) begin
            frame_done <= 1'b1;
            tstate     <= T_FINISH;
          end
        end

        T_FINISH: begin
          // Stay here (or re-trigger another frame if desired).
          // For continuous operation, you can automatically go back to T_WAIT.
        end

        default: tstate <= T_INIT;
      endcase
    end
  end

endmodule
