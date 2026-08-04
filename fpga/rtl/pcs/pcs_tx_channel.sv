// Converts the fixed v0 response frame into scrambled 64b/66b blocks
// Once a frame starts, frame_valid must remain asserted through frame_end

module pcs_tx_channel (
    input logic clk,
    input logic rst,

    input logic [63:0] frame_data,
    input logic frame_start,
    input logic frame_end,
    input logic frame_valid,

    output logic frame_start_ready,
    output logic [63:0] tx_data,
    output logic [5:0] tx_header,
    output logic [6:0] tx_sequence
);

  localparam logic [1:0] SYNC_DATA = 2'b01;
  localparam logic [1:0] SYNC_CONTROL = 2'b10;

  localparam logic [7:0] BLOCK_TYPE_IDLE = 8'h1E;
  localparam logic [7:0] BLOCK_TYPE_START_0 = 8'h78;
  localparam logic [7:0] BLOCK_TYPE_TERMINATE_6 = 8'hE1;

  localparam logic [5:0] GEARBOX_PAUSE_SEQUENCE = 6'd32;


  typedef struct packed {
    logic frame_end;
    logic [1:0] header;
    logic [63:0] scrambler_payload;
  } transmit_block_t;

  // Reverse bits as per GT convention before entering scrambler
  function automatic logic [63:0] reverse_payload_bits(input logic [63:0] payload);
    begin
      for (int i = 0; i < 64; i++) begin
        reverse_payload_bits[i] = payload[63-i];
      end
    end
  endfunction


  function automatic logic [63:0] scramble_payload(input logic [63:0] payload, input logic [57:0] previous_scrambled_bits);
    logic [63:0] scrambled_payload;

    begin
      for (int i = 63; i >= 0; i--) begin
        scrambled_payload[i] = payload[i] ^ ((i <= 24) ? scrambled_payload[i+39] : previous_scrambled_bits[i-25]) ^ ((i <= 5) ? scrambled_payload[i+58] : previous_scrambled_bits[i-6]);
      end

      scramble_payload = scrambled_payload;
    end
  endfunction


  localparam logic [57:0] INITIAL_SCRAMBLER_STATE = {58{1'b1}};

  localparam logic [63:0] IDLE_SCRAMBLER_PAYLOAD = reverse_payload_bits(64'h0000_0000_0000_001E);

  localparam logic [63:0] INITIAL_TX_DATA = scramble_payload(IDLE_SCRAMBLER_PAYLOAD, INITIAL_SCRAMBLER_STATE);


  logic frame_active;
  logic [7:0] saved_frame_byte;

  logic [5:0] gearbox_sequence;
  logic [57:0] scrambler_state;

  transmit_block_t buffered_blocks[0:1];
  logic [1:0] buffered_block_count;

  transmit_block_t encoded_block;
  transmit_block_t next_transmit_block;

  logic encoded_block_valid;
  logic frame_start_accepted;

  logic advance_transmit_block;
  logic remove_buffered_block;

  logic [63:0] next_scrambled_payload;

  logic inter_frame_gap_pending;


  assign tx_sequence = {1'b0, gearbox_sequence};

  // Sequence 32 is ignored by the GT gearbox
  assign advance_transmit_block = gearbox_sequence != GEARBOX_PAUSE_SEQUENCE;
  assign frame_start_ready = !rst && !frame_active && (buffered_block_count == 2'd0) && !inter_frame_gap_pending && advance_transmit_block;
  assign frame_start_accepted = frame_valid && frame_start && frame_start_ready;
  assign remove_buffered_block = advance_transmit_block && (buffered_block_count != 2'd0);


  always_comb begin
    encoded_block = '0;
    encoded_block_valid = 1'b0;

    if (frame_start_accepted) begin
      encoded_block.header = SYNC_CONTROL;
      encoded_block.scrambler_payload = reverse_payload_bits({frame_data[55:0], BLOCK_TYPE_START_0});
      encoded_block_valid = 1'b1;
    end

    else if (frame_active && frame_valid) begin
      encoded_block_valid = 1'b1;

      if (frame_end) begin
        encoded_block.frame_end = 1'b1;
        encoded_block.header = SYNC_CONTROL;

        // The saved byte plus the five final input bytes form TERM_6
        encoded_block.scrambler_payload = reverse_payload_bits({8'h00, frame_data[39:0], saved_frame_byte, BLOCK_TYPE_TERMINATE_6});
      end
      else begin
        encoded_block.header = SYNC_DATA;
        encoded_block.scrambler_payload = reverse_payload_bits({frame_data[55:0], saved_frame_byte});
      end
    end
  end


  always_ff @(posedge clk) begin
    if (rst) begin
      frame_active <= 1'b0;
      saved_frame_byte <= '0;
    end
    else if (frame_start_accepted) begin
      frame_active <= 1'b1;
      saved_frame_byte <= frame_data[63:56];
    end
    else if (frame_active && frame_valid) begin
      if (frame_end) begin
        frame_active <= 1'b0;
      end
      else begin
        saved_frame_byte <= frame_data[63:56];
      end
    end
  end


  // Two entries absorb the single gearbox pause that can occur during this fixed eleven-block frame
  always_ff @(posedge clk) begin
    if (rst) begin
      buffered_block_count <= '0;
      buffered_blocks[0] <= '0;
      buffered_blocks[1] <= '0;
    end
    else begin
      case ({encoded_block_valid, remove_buffered_block})
        2'b10: begin
          if (buffered_block_count == 2'd0) begin
            buffered_blocks[0] <= encoded_block;
          end
          else begin
            buffered_blocks[1] <= encoded_block;
          end

          buffered_block_count <= buffered_block_count + 1'b1;
        end

        2'b01: begin
          if (buffered_block_count == 2'd2) begin
            buffered_blocks[0] <= buffered_blocks[1];
          end

          buffered_block_count <= buffered_block_count - 1'b1;
        end

        2'b11: begin
          if (buffered_block_count == 2'd1) begin
            buffered_blocks[0] <= encoded_block;
          end
          else begin
            buffered_blocks[0] <= buffered_blocks[1];
            buffered_blocks[1] <= encoded_block;
          end
        end

        default: begin
        end
      endcase
    end
  end


  always_comb begin
    if (buffered_block_count != 2'd0) begin
      next_transmit_block = buffered_blocks[0];
    end
    else begin
      next_transmit_block.frame_end = 1'b0;
      next_transmit_block.header = SYNC_CONTROL;
      next_transmit_block.scrambler_payload = IDLE_SCRAMBLER_PAYLOAD;
    end
  end


  assign next_scrambled_payload = scramble_payload(next_transmit_block.scrambler_payload, scrambler_state);


  always_ff @(posedge clk) begin
    if (rst) begin
      gearbox_sequence <= 6'd0;
      tx_data <= INITIAL_TX_DATA;
      tx_header <= {4'b0000, SYNC_CONTROL};
      scrambler_state <= INITIAL_TX_DATA[57:0];
      inter_frame_gap_pending <= 1'b0;
    end
    else begin
      if (gearbox_sequence == GEARBOX_PAUSE_SEQUENCE) begin
        gearbox_sequence <= 6'd0;
      end
      else begin
        gearbox_sequence <= gearbox_sequence + 1'b1;
      end

      if (advance_transmit_block) begin
        tx_data <= next_scrambled_payload;
        tx_header <= {4'b0000, next_transmit_block.header};
        scrambler_state <= next_scrambled_payload[57:0];
        if (remove_buffered_block && buffered_blocks[0].frame_end) begin
          inter_frame_gap_pending <= 1'b1;
        end
        else if (!remove_buffered_block && inter_frame_gap_pending) begin
          inter_frame_gap_pending <= 1'b0;
        end
      end
    end
  end

endmodule
