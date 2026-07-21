// Checks the Ethernet FCS of each received frame.
// The late verdict is used by the TX path to commit or poison a speculative ORDER_DECISION response.

module eth_rx_fcs_checker (
    input logic clk,
    input logic rst,

    input logic [63:0] frame_data,  // [7:0] is the earliest byte
    input logic [7:0] frame_keep,
    input logic frame_start,
    input logic frame_end,
    input logic frame_valid,
    input logic frame_abort,

    // fcs_result_valid = 1, fcs_ok = 1   : completed frame passed
    // fcs_result_valid = 1, fcs_ok = 0  : completed frame failed
    // fcs_result_valid = 0              : no new result this cycle
    output logic fcs_result_valid,
    output logic fcs_ok
);

  localparam logic [31:0] CRC32_POLY_REFLECTED = 32'hEDB8_8320;
  localparam logic [31:0] CRC32_RESIDUE = 32'hDEBB_20E3;

  /*
  Updates the reflected Ethernet CRC state with one byte
  Ethernet processes each byte least-significant bit first
  Each loop iteration performs one streaming polynomial-division step:
  1. Combine the next data bit with the active CRC bit
  2. Shift to the next reflected polynomial position
  3. XOR the reflected generator polynomial when cancellation is required
  */

  function automatic logic [31:0] crc32_update_byte(input logic [31:0] crc_in, input logic [7:0] data_byte);

    logic [31:0] crc;
    logic feedback;

    begin
      crc = crc_in;

      for (int i = 0; i < 8; i++) begin
        // A value of one means the generator polynomial must be applied
        // for this reflected polynomial-division step
        feedback = crc[0] ^ data_byte[i];
        crc >>= 1;  // Advance by one bit in the reflected, LSB-first orientation.

        if (feedback) begin
          crc ^= CRC32_POLY_REFLECTED;  // Cancel the active term using the lower 32 generator coefficients
        end
      end

      crc32_update_byte = crc;
    end

  endfunction


  logic inside_frame;
  logic [2:0] skip_remaining;  // Remaining preamble/SFD bytes to skip
  logic [31:0] crc_state;  // running CRC value from dest MAC through to received FCS

  logic [31:0] crc_after_word;
  logic [2:0] skip_after_word;

  always_ff @(posedge clk) begin
    if (rst) begin
      inside_frame <= 1'b0;
      skip_remaining <= '0;
      crc_state <= '0;
      fcs_result_valid <= 1'b0;
      fcs_ok <= 1'b0;
    end
    else begin
      fcs_result_valid <= 1'b0;
      if (frame_abort) begin
        inside_frame <= 1'b0;
        skip_remaining <= '0;
        crc_state <= '0;
        fcs_ok <= 1'b0;
      end
      else begin
        if (frame_valid && (inside_frame || frame_start)) begin
          crc_state <= crc_after_word;
          skip_remaining <= skip_after_word;
        end
        if (frame_valid && frame_start) begin
          inside_frame <= 1'b1;
          fcs_ok <= 1'b0;
        end

        // A valid frame_end is expected only while processing a frame.
        if (frame_valid && frame_end && inside_frame) begin
          inside_frame <= 1'b0;
          fcs_result_valid <= 1'b1;
          fcs_ok <= (skip_after_word == 3'd0) && (crc_after_word == CRC32_RESIDUE);
        end
      end
    end
  end

  // Calculates the CRC and preamble-skip state after the current word.
  // Blocking assignments are used because each chronological byte depends
  // on the result produced by the preceding byte.
  always_comb begin
    // A start word begins a new CRC calculation. Later words continue
    // from the registered state of the current frame.
    if (frame_start) begin
      crc_after_word = 32'hFFFF_FFFF;
      skip_after_word = 3'd7;
    end
    else begin
      crc_after_word = crc_state;
      skip_after_word = skip_remaining;
    end

    // The start word must be processed even though inside_frame has not
    // yet been updated by the sequential logic.
    if (frame_valid && (inside_frame || frame_start)) begin
      for (int i = 0; i < 8; i++) begin
        if (frame_keep[i]) begin
          // Skip the remaining preamble/SFD bytes before starting CRC.
          if (skip_after_word != 3'd0) begin
            skip_after_word = skip_after_word - 3'd1;
          end
          else begin
            // frame_data[7:0] is the earliest byte, so lanes are
            // processed from i = 0 through i = 7.
            crc_after_word = crc32_update_byte(crc_after_word, frame_data[i*8+:8]);
          end
        end
      end
    end
  end

endmodule
