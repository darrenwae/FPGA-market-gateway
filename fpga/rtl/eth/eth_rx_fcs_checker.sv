// Checks the Ethernet FCS of each received frame
// The late verdict is used by the TX path to commit or poison a speculative ORDER_DECISION response.

module eth_rx_fcs_checker (
    input logic clk,
    input logic rst,

    input logic [63:0] frame_data,  // [7:0] is the earliest byte
    input logic [7:0] frame_keep,
    input logic frame_start,
    input logic frame_end,
    input logic frame_valid,

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


  logic [2:0] skip_remaining;  // Remaining preamble/SFD bytes to skip
  logic [31:0] crc_state;  // running CRC value from dest MAC through to received FCS

  logic [31:0] crc_after_word;
  logic [2:0] skip_after_word;

  logic [63:0] frame_data_pipe;  // Registered FCS frame data
  logic [7:0] frame_keep_pipe;  // Registered valid-byte mask
  logic frame_start_pipe;  // Registered frame start
  logic frame_end_pipe;  // Registered frame end
  logic frame_valid_pipe;  // Registered frame valid


  // Isolates the CRC path from combinational PCS decoding.
  always_ff @(posedge clk) begin
    if (rst) begin
      frame_data_pipe <= '0;
      frame_keep_pipe <= '0;
      frame_start_pipe <= 1'b0;
      frame_end_pipe <= 1'b0;
      frame_valid_pipe <= 1'b0;

    end
    else begin
      frame_data_pipe <= frame_data;
      frame_keep_pipe <= frame_keep;
      frame_start_pipe <= frame_start;
      frame_end_pipe <= frame_end;
      frame_valid_pipe <= frame_valid;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      skip_remaining <= '0;
      crc_state <= '0;
      fcs_result_valid <= 1'b0;
      fcs_ok <= 1'b0;
    end
    else begin
      fcs_result_valid <= 1'b0;

      if (frame_valid_pipe) begin
        crc_state <= crc_after_word;
        skip_remaining <= skip_after_word;

        if (frame_start_pipe) begin
          fcs_ok <= 1'b0;
        end

        if (frame_end_pipe) begin
          fcs_result_valid <= 1'b1;
          fcs_ok <= (skip_after_word == 3'd0) && (crc_after_word == CRC32_RESIDUE);
        end
      end
    end
  end

  // Calculates the CRC state after the registered frame word.
  always_comb begin
    if (frame_start_pipe) begin
      crc_after_word = 32'hFFFF_FFFF;
      skip_after_word = 3'd7;
    end
    else begin
      crc_after_word = crc_state;
      skip_after_word = skip_remaining;
    end

    if (frame_valid_pipe) begin
      for (int i = 0; i < 8; i++) begin
        if (frame_keep_pipe[i]) begin
          if (skip_after_word != 3'd0) begin
            skip_after_word = skip_after_word - 3'd1;
          end
          else begin
            crc_after_word = crc32_update_byte(crc_after_word, frame_data_pipe[i*8+:8]);
          end
        end
      end
    end
  end

endmodule
