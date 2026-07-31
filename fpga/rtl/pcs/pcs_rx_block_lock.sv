// Monitors 64b/66b sync headers produced by the GTY synchronous gearbox.
// Requests gearbox slips until the receiver is aligned to valid block boundaries
// Acquires and maintains block lock
// Forwards payload and header data only when the gearbox output is valid and locked

module pcs_rx_block_lock (
    input logic clk,  // rx_pcs_clk from gty wrapper
    input logic rst,

    input logic [63:0] rx_data,  // 64 bit scarmbled payload
    input logic [1:0] rx_header,  // 2 bit header
    input logic rx_data_valid,  // payload validity this cycle
    input logic rx_header_valid,  // header validity this cycle

    output logic rx_gearbox_slip,

    output logic [63:0] block_payload,
    output logic [1:0] block_header,
    output logic block_valid,
    output logic block_lock
);

  typedef enum logic [1:0] {
    ACQUIRE,
    SLIP_WAIT,
    LOCKED
  } state_t;

  localparam logic [5:0] ACQUIRE_LAST = 6'd63;
  localparam logic [5:0] MONITOR_LAST = 6'd63;
  localparam logic [4:0] INVALID_LIMIT = 5'd16;
  localparam logic [4:0] SLIP_WAIT_LAST = 5'd31;

  state_t state;
  logic [5:0] acquire_count;  // 0 to 63 valid header count
  logic [5:0] monitor_count;  // 0 to 63 blocks in lock window
  logic [4:0] invalid_count;  // 16 invalid headers to lose lock
  logic [4:0] slip_wait_count;  // 0 to 31 clock cycles before recheck

  logic sample_valid;
  logic header_legal;

  assign sample_valid = rx_data_valid && rx_header_valid;
  assign header_legal = rx_header[0] ^ rx_header[1];  // only 2'b10 or 2'b01 are valid header

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= ACQUIRE;
      acquire_count <= '0;
      monitor_count <= '0;
      invalid_count <= '0;
      slip_wait_count <= '0;
      rx_gearbox_slip <= 1'b0;
      block_lock <= 1'b0;
    end
    else begin
      rx_gearbox_slip <= 1'b0;

      case (state)
        ACQUIRE: begin
          block_lock <= 1'b0;
          if (sample_valid) begin
            if (header_legal) begin
              if (acquire_count == ACQUIRE_LAST) begin
                // 64 consecutive legal headers acquired
                monitor_count <= '0;
                invalid_count <= '0;
                block_lock <= 1'b1;
                state <= LOCKED;
              end
              else begin
                acquire_count <= acquire_count + 1'b1;
              end
            end
            else begin
              // header position is not correct
              acquire_count <= '0;
              monitor_count <= '0;
              invalid_count <= '0;
              slip_wait_count <= '0;
              rx_gearbox_slip <= 1'b1;
              state <= SLIP_WAIT;
            end
          end
        end

        SLIP_WAIT: begin
          if (slip_wait_count == SLIP_WAIT_LAST) begin
            slip_wait_count <= '0;
            acquire_count <= '0;
            monitor_count <= '0;
            invalid_count <= '0;
            state <= ACQUIRE;
          end
          else begin
            slip_wait_count <= slip_wait_count + 1'b1;
          end
        end

        LOCKED: begin
          if (sample_valid) begin
            if (!header_legal && (invalid_count == INVALID_LIMIT - 1'b1)) begin
              // Lose lock after 16 illegal header
              block_lock <= 1'b0;
              acquire_count <= '0;
              monitor_count <= '0;
              slip_wait_count <= '0;
              invalid_count <= '0;
              rx_gearbox_slip <= 1'b1;
              state <= SLIP_WAIT;
            end
            else if (monitor_count == MONITOR_LAST) begin
              // start new monitoring window
              monitor_count <= '0;
              invalid_count <= '0;
            end
            else begin
              monitor_count <= monitor_count + 1'b1;
              if (!header_legal) begin
                invalid_count <= invalid_count + 1'b1;
              end
            end
          end
        end

        default: begin
          state <= ACQUIRE;
          acquire_count <= '0;
          monitor_count <= '0;
          invalid_count <= '0;
          slip_wait_count <= '0;
          rx_gearbox_slip <= 1'b0;
          block_lock <= 1'b0;
        end
      endcase
    end
  end

  assign block_payload = rx_data;
  assign block_header = rx_header;
  assign block_valid = block_lock && sample_valid;

endmodule
