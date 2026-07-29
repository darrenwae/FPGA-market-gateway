// Interprets data and control block types, identifies frame boundaries,
// and flags malformed blocks or invalid START/TERMINATE sequencing

module pcs_rx_block_decoder (
    input logic clk,
    input logic rst,

    input logic [63:0] descrambled_payload,
    input logic [1:0] descrambled_header,
    input logic descrambled_valid,

    output logic [63:0] frame_data,  // frame_data[7:0] is the earliest byte
    output logic [7:0] frame_keep,  // bitset for valid data frame byte
    output logic frame_start,
    output logic frame_end,
    output logic frame_valid,
    output logic frame_abort,

    output logic bad_block,
    output logic sequence_error
);

  localparam logic [1:0] SYNC_DATA = 2'b01;
  localparam logic [1:0] SYNC_CTRL = 2'b10;

  localparam logic [7:0] BLOCK_TYPE_CTRL = 8'h1E;  // will only accept all idle here
  localparam logic [7:0] BLOCK_TYPE_START_0 = 8'h78;
  localparam logic [7:0] BLOCK_TYPE_START_4 = 8'h33;

  localparam logic [7:0] BLOCK_TYPE_TERM_0 = 8'h87;
  localparam logic [7:0] BLOCK_TYPE_TERM_1 = 8'h99;
  localparam logic [7:0] BLOCK_TYPE_TERM_2 = 8'hAA;
  localparam logic [7:0] BLOCK_TYPE_TERM_3 = 8'hB4;
  localparam logic [7:0] BLOCK_TYPE_TERM_4 = 8'hCC;
  localparam logic [7:0] BLOCK_TYPE_TERM_5 = 8'hD2;
  localparam logic [7:0] BLOCK_TYPE_TERM_6 = 8'hE1;
  localparam logic [7:0] BLOCK_TYPE_TERM_7 = 8'hFF;

  logic [63:0] normalized_data;
  logic [7:0] block_type;

  logic inside_frame;
  logic inside_frame_next;

  logic [7:0] term_keep;
  logic term_format_valid;

  always_ff @(posedge clk) begin
    if (rst) begin
      inside_frame <= 1'b0;
    end
    else begin
      inside_frame <= inside_frame_next;
    end
  end

  always_comb begin
    for (int i = 0; i < 64; i++) begin
      normalized_data[i] = descrambled_payload[63-i];
    end
  end
  assign block_type = normalized_data[7:0];

  always_comb begin
    term_keep = 8'h00;
    term_format_valid = 1'b0;

    case (block_type)
      BLOCK_TYPE_TERM_0: begin
        term_keep = 8'h00;
        term_format_valid = (normalized_data[63:8] == '0);
      end

      BLOCK_TYPE_TERM_1: begin
        term_keep = 8'h01;
        term_format_valid = (normalized_data[63:16] == '0);
      end

      BLOCK_TYPE_TERM_2: begin
        term_keep = 8'h03;
        term_format_valid = (normalized_data[63:24] == '0);
      end

      BLOCK_TYPE_TERM_3: begin
        term_keep = 8'h07;
        term_format_valid = (normalized_data[63:32] == '0);
      end

      BLOCK_TYPE_TERM_4: begin
        term_keep = 8'h0F;
        term_format_valid = (normalized_data[63:40] == '0);
      end

      BLOCK_TYPE_TERM_5: begin
        term_keep = 8'h1F;
        term_format_valid = (normalized_data[63:48] == '0);
      end

      BLOCK_TYPE_TERM_6: begin
        term_keep = 8'h3F;
        term_format_valid = (normalized_data[63:56] == '0);
      end

      BLOCK_TYPE_TERM_7: begin
        term_keep = 8'h7F;
        term_format_valid = 1'b1;
      end

      default: begin
        term_keep = 8'h00;
        term_format_valid = 1'b0;
      end
    endcase
  end

  always_comb begin
    inside_frame_next = inside_frame;
    frame_data = '0;
    frame_keep = '0;
    frame_start = 1'b0;
    frame_end = 1'b0;
    frame_valid = 1'b0;
    frame_abort = 1'b0;
    bad_block = 1'b0;
    sequence_error = 1'b0;

    if (descrambled_valid) begin
      case (descrambled_header)
        SYNC_DATA: begin
          if (inside_frame) begin
            frame_data = normalized_data;
            frame_keep = 8'hFF;
            frame_valid = 1'b1;
          end
          else begin
            sequence_error = 1'b1;
          end
        end
        SYNC_CTRL: begin
          case (block_type)
            // Idle block
            BLOCK_TYPE_CTRL: begin
              if (normalized_data[63:8] != 56'b0) begin
                bad_block = 1'b1;
              end

              // if idle frame appear in frame, current frame ended abnormally
              if (inside_frame) begin
                sequence_error = 1'b1;
              end
            end

            BLOCK_TYPE_START_0: begin
              if (inside_frame) begin
                // START appear before termination is sequence error
                sequence_error = 1'b1;
              end
              else begin
                frame_data[55:0] = normalized_data[63:8];  // first byte occupied by START
                frame_keep = 8'h7F;
                frame_start = 1'b1;
                frame_valid = 1'b1;
                inside_frame_next = 1'b1;
              end
            end

            BLOCK_TYPE_START_4: begin
              if (normalized_data[39:8] != 32'b0) begin
                // lane 0 to 3 contains IDLE bytes
                bad_block = 1'b1;
              end
              else if (inside_frame) begin
                sequence_error = 1'b1;
              end
              else begin
                frame_data[23:0] = normalized_data[63:40];  // START occupies PCS lane 4 and is removed here, PCS lanes 5 to 7 become output byte lanes 0 to 2
                frame_keep = 8'h07;
                frame_start = 1'b1;
                frame_valid = 1'b1;
                inside_frame_next = 1'b1;
              end
            end

            BLOCK_TYPE_TERM_0, BLOCK_TYPE_TERM_1, BLOCK_TYPE_TERM_2, BLOCK_TYPE_TERM_3, BLOCK_TYPE_TERM_4, BLOCK_TYPE_TERM_5, BLOCK_TYPE_TERM_6, BLOCK_TYPE_TERM_7: begin
              if (!term_format_valid) begin
                bad_block = 1'b1;
                inside_frame_next = 1'b0;
              end
              else if (!inside_frame) begin
                sequence_error = 1'b1;
              end
              else begin
                // Final data bytes always begin immediately after block_type
                frame_data = normalized_data >> 8;
                frame_keep = term_keep;
                frame_end = 1'b1;
                frame_valid = 1'b1;
                inside_frame_next = 1'b0;
              end
            end
            default: begin
              bad_block = 1'b1;
            end
          endcase
        end
        default: begin
          bad_block = 1'b1;
          if (inside_frame) begin
            inside_frame_next = 1'b0;
            sequence_error = 1'b1;
          end
        end
      endcase
    end

    // Any decoder error during an active frame invalidates that frame
    // Suppress the offending block and return to the idle frame state
    if ((bad_block || sequence_error) && inside_frame) begin
      inside_frame_next = 1'b0;
      frame_abort = 1'b1;
    end
  end

endmodule
