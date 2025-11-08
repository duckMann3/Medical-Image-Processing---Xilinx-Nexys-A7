`timescale 1ns / 1ps
// ============================
// sd_spi_init.v
// SD power-up in SPI mode; produces 'ready' and 'is_sdhc'.
// Depends on spi_master_byte; controls CS and byte sequencing.
// ============================
module sd_spi_init
#(
  parameter DUMMY_BYTES   = 10,      // 80 clocks with CS high
  parameter INIT_DIV      = 16'd250  // choose to meet <=400 kHz given your sysclk
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

  // SPI pins control
  output reg         sd_cs_n,

  // Status
  output reg         ready,
  output reg         is_sdhc,
  output reg         error
);

  // Assign slow divider during init
  assign spi_div = INIT_DIV;

  // Commands
  localparam CMD0  = 8'h40; // GO_IDLE_STATE
  localparam CMD8  = 8'h48; // SEND_IF_COND
  localparam CMD55 = 8'h77; // APP_CMD
  localparam ACMD41= 8'h69; // SD_SEND_OP_COND (App)
  localparam CMD58 = 8'h7A; // READ_OCR
  localparam CMD16 = 8'h50; // SET_BLOCKLEN

  // Simple timeout counters (sized generously)
  reg [23:0] timeout;
  reg [7:0]  byte_cnt;

  // R1 & R7/R3 staging
  reg [7:0]  r1;
  reg [31:0] r_long;

  // state machine
  localparam S_RST         = 0,
             S_DUMMY_CS1   = 1,
             S_DUMMY_SEND  = 2,
             S_CMD0_SEND   = 3,
             S_CMD0_R1     = 4,
             S_CMD8_SEND   = 5,
             S_CMD8_R1     = 6,
             S_CMD8_READ   = 7,
             S_ACMD_LOOP   = 8,
             S_CMD55_SEND  = 9,
             S_CMD55_R1    = 10,
             S_ACMD41_SEND = 11,
             S_ACMD41_R1   = 12,
             S_CMD58_SEND  = 13,
             S_CMD58_R1    = 14,
             S_CMD58_READ  = 15,
             S_CMD16_SEND  = 16,
             S_CMD16_R1    = 17,
             S_DONE        = 18,
             S_ERR         = 19;

  reg [4:0] state, next;

  // Helper: start a byte if SPI idle
  task send_byte;
  begin
    if (!spi_busy && !spi_done) begin
      spi_start <= 1'b1;
    end
  end
  endtask

  // FSM
  always @(posedge clk) begin
    if (rst) begin
      state     <= S_RST;
      sd_cs_n   <= 1'b1;
      spi_start <= 1'b0;
      spi_mosi  <= 8'hFF;
      ready     <= 1'b0;
      is_sdhc   <= 1'b0;
      error     <= 1'b0;
      timeout   <= 24'd0;
      byte_cnt  <= 8'd0;
      r1        <= 8'hFF;
      r_long    <= 32'h0;
    end else begin
      spi_start <= 1'b0; // default

      case (state)
        S_RST: begin
          sd_cs_n  <= 1'b1;
          ready    <= 1'b0;
          is_sdhc  <= 1'b0;
          error    <= 1'b0;
          timeout  <= 24'd0;
          byte_cnt <= 8'd0;
          state    <= S_DUMMY_CS1;
        end

        // Send >=80 dummy clocks with CS high
        S_DUMMY_CS1: begin
          sd_cs_n  <= 1'b1;
          if (byte_cnt < DUMMY_BYTES) begin
            spi_mosi <= 8'hFF;
            send_byte();
            if (spi_done) byte_cnt <= byte_cnt + 8'd1;
          end else begin
            byte_cnt <= 8'd0;
            state    <= S_CMD0_SEND;
          end
        end

        // CMD0 (CRC 0x95), expect R1=0x01
        S_CMD0_SEND: begin
          sd_cs_n  <= 1'b0;
          timeout  <= 24'hFFFFFF;
          // CMD packet: [cmd][arg(4)][crc]
          if (!spi_busy && !spi_done) begin spi_mosi<=CMD0;  send_byte(); end
          if (spi_done) begin state<=S_CMD0_R1; byte_cnt<=8'd0; end
        end
        S_CMD0_R1: begin
          if (timeout==0) begin error<=1'b1; state<=S_ERR; end
          else begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); timeout<=timeout-1; end
            if (spi_done) begin
              r1 <= spi_miso;
              if (spi_miso==8'h01) begin state<=S_CMD8_SEND; end
              else if (spi_miso!=8'hFF) begin error<=1'b1; state<=S_ERR; end
            end
          end
        end

        // CMD8 (0x000001AA, CRC 0x87), read R7
        S_CMD8_SEND: begin
          if (!spi_busy && !spi_done) begin
            case (byte_cnt)
              8'd0: begin spi_mosi<=CMD8;          send_byte(); byte_cnt<=1; end
              8'd1: begin spi_mosi<=8'h00;         send_byte(); byte_cnt<=2; end
              8'd2: begin spi_mosi<=8'h00;         send_byte(); byte_cnt<=3; end
              8'd3: begin spi_mosi<=8'h01;         send_byte(); byte_cnt<=4; end
              8'd4: begin spi_mosi<=8'hAA;         send_byte(); byte_cnt<=5; end
              8'd5: begin spi_mosi<=8'h87;         send_byte(); byte_cnt<=6; end
              default: begin byte_cnt<=0; state<=S_CMD8_R1; timeout<=24'hFFFFFF; end
            endcase
          end
        end
        S_CMD8_R1: begin
          if (timeout==0) begin error<=1'b1; state<=S_ERR; end
          else begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); timeout<=timeout-1; end
            if (spi_done) begin
              r1 <= spi_miso;
              if (spi_miso==8'h01 || spi_miso==8'h05) begin // some legacy cards return illegal cmd
                byte_cnt<=0; state<=S_CMD8_READ;
              end else if (spi_miso!=8'hFF) begin error<=1'b1; state<=S_ERR; end
            end
          end
        end
        S_CMD8_READ: begin
          // Read 4 bytes of R7 (or 0xFFs for legacy)
          if (byte_cnt<4) begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); end
            if (spi_done) begin
              r_long <= {r_long[23:0], spi_miso};
              byte_cnt <= byte_cnt + 1;
            end
          end else begin
            // proceed to ACMD41 loop (HCS=1)
            byte_cnt <= 0;
            state    <= S_ACMD_LOOP;
          end
        end

        S_ACMD_LOOP: begin
          state <= S_CMD55_SEND;
        end

        // CMD55
        S_CMD55_SEND: begin
          if (!spi_busy && !spi_done) begin
            case (byte_cnt)
              8'd0: begin spi_mosi<=CMD55; send_byte(); byte_cnt<=1; end
              8'd1: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=2; end
              8'd2: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=3; end
              8'd3: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=4; end
              8'd4: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=5; end
              8'd5: begin spi_mosi<=8'h65; send_byte(); byte_cnt<=6; end // dummy CRC
              default: begin byte_cnt<=0; state<=S_CMD55_R1; timeout<=24'h7FFFFF; end
            endcase
          end
        end
        S_CMD55_R1: begin
          if (timeout==0) begin error<=1'b1; state<=S_ERR; end
          else begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); timeout<=timeout-1; end
            if (spi_done) begin
              r1 <= spi_miso;
              if (spi_miso!=8'hFF) begin state<=S_ACMD41_SEND; byte_cnt<=0; end
            end
          end
        end

        // ACMD41 with HCS=1 (arg=0x40000000)
        S_ACMD41_SEND: begin
          if (!spi_busy && !spi_done) begin
            case (byte_cnt)
              8'd0: begin spi_mosi<=ACMD41; send_byte(); byte_cnt<=1; end
              8'd1: begin spi_mosi<=8'h40;  send_byte(); byte_cnt<=2; end
              8'd2: begin spi_mosi<=8'h00;  send_byte(); byte_cnt<=3; end
              8'd3: begin spi_mosi<=8'h00;  send_byte(); byte_cnt<=4; end
              8'd4: begin spi_mosi<=8'h00;  send_byte(); byte_cnt<=5; end
              8'd5: begin spi_mosi<=8'h77;  send_byte(); byte_cnt<=6; end // dummy CRC
              default: begin byte_cnt<=0; state<=S_ACMD41_R1; timeout<=24'hFFFFFF; end
            endcase
          end
        end
        S_ACMD41_R1: begin
          if (timeout==0) begin error<=1'b1; state<=S_ERR; end
          else begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); timeout<=timeout-1; end
            if (spi_done) begin
              r1 <= spi_miso;
              if (spi_miso==8'h00) begin state<=S_CMD58_SEND; byte_cnt<=0; end
              else if (spi_miso!=8'hFF) begin state<=S_ACMD_LOOP; end // keep looping
            end
          end
        end

        // CMD58 (READ_OCR), read R3
        S_CMD58_SEND: begin
          if (!spi_busy && !spi_done) begin
            case (byte_cnt)
              8'd0: begin spi_mosi<=CMD58; send_byte(); byte_cnt<=1; end
              8'd1: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=2; end
              8'd2: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=3; end
              8'd3: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=4; end
              8'd4: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=5; end
              8'd5: begin spi_mosi<=8'hFD; send_byte(); byte_cnt<=6; end // dummy CRC
              default: begin byte_cnt<=0; state<=S_CMD58_R1; timeout<=24'h7FFFFF; end
            endcase
          end
        end
        S_CMD58_R1: begin
          if (timeout==0) begin error<=1'b1; state<=S_ERR; end
          else begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); timeout<=timeout-1; end
            if (spi_done) begin
              r1 <= spi_miso;
              if (spi_miso==8'h00) begin byte_cnt<=0; r_long<=32'h0; state<=S_CMD58_READ; end
              else if (spi_miso!=8'hFF) begin error<=1'b1; state<=S_ERR; end
            end
          end
        end
        S_CMD58_READ: begin
          if (byte_cnt<4) begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); end
            if (spi_done) begin
              r_long <= {r_long[23:0], spi_miso};
              byte_cnt <= byte_cnt + 1;
            end
          end else begin
            // OCR[30] = CCS -> SDHC/SDXC block addressing
            is_sdhc <= r_long[30];
            if (!r_long[30]) state <= S_CMD16_SEND; // set 512 bytes
            else             state <= S_DONE;
            byte_cnt <= 0;
          end
        end

        // CMD16(512)
        S_CMD16_SEND: begin
          if (!spi_busy && !spi_done) begin
            case (byte_cnt)
              8'd0: begin spi_mosi<=CMD16; send_byte(); byte_cnt<=1; end
              8'd1: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=2; end
              8'd2: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=3; end
              8'd3: begin spi_mosi<=8'h02; send_byte(); byte_cnt<=4; end
              8'd4: begin spi_mosi<=8'h00; send_byte(); byte_cnt<=5; end
              8'd5: begin spi_mosi<=8'h15; send_byte(); byte_cnt<=6; end // dummy CRC
              default: begin byte_cnt<=0; state<=S_CMD16_R1; timeout<=24'h7FFFFF; end
            endcase
          end
        end
        S_CMD16_R1: begin
          if (timeout==0) begin error<=1'b1; state<=S_ERR; end
          else begin
            if (!spi_busy && !spi_done) begin spi_mosi<=8'hFF; send_byte(); timeout<=timeout-1; end
            if (spi_done) begin
              if (spi_miso==8'h00) state<=S_DONE;
              else if (spi_miso!=8'hFF) begin error<=1'b1; state<=S_ERR; end
            end
          end
        end

        S_DONE: begin
          sd_cs_n <= 1'b1; // idle with CS high
          ready   <= 1'b1;
        end

        S_ERR: begin
          sd_cs_n <= 1'b1;
          ready   <= 1'b0;
        end

        default: state <= S_ERR;
      endcase
    end
  end
endmodule

