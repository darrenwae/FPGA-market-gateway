/*
Parses the fixed v0 Ethernet II / IPv4 / UDP receive format.
Consumes Ethernet frame bytes from the PCS block decoder, and emits
only the UDP payload
*/

module eth_ipv4_udp_rx (
    input logic clk,
    input logic rst,

    input logic [63:0] frame_data,
    input logic [7:0] frame_keep,
    input logic frame_start,
    input logic frame_end,
    input logic frame_valid,
    input logic frame_abort,

    output logic [63:0] udp_payload_data,
    output logic udp_payload_start,
    output logic udp_payload_end,
    output logic udp_payload_valid,
    output logic udp_packet_abort,

    output logic parser_error
);

  typedef enum logic [1:0] {
    IDLE,
    HEADER,
    PAYLOAD,
    DRAIN
  } state_t;

  typedef enum logic {
    START_0_ALIGNMENT,
    START_4_ALIGNMENT
  } alignment_t;

  state_t state;
  alignment_t payload_alignment;

  logic [5:0] header_bytes_discarded;  // need to discard 49 header bytes: Preamble{7} + Ethernet{14} + IPv4{20} + UDP{8};
  logic [63:0] previous_frame_data;

  logic [63:0] aligned_payload_data;
  logic payload_started;
  logic [7:0] payload_words_remaining;  // 4 64-bit words form a full 32 byte internal protocol message

  logic udp_length_present;
  logic [15:0] udp_length_candidate;
  logic udp_length_invalid;
  logic udp_length_candidate_valid;
  logic final_payload_input_valid;

  always_comb begin
    udp_length_present = 1'b0;
    udp_length_candidate = '0;

    case (payload_alignment)
      START_0_ALIGNMENT: begin
        // Current word contains frame bytes 39–46
        if (header_bytes_discarded == 6'd39) begin
          udp_length_present = 1'b1;
          udp_length_candidate = {frame_data[55:48], frame_data[63:56]};
        end
      end

      START_4_ALIGNMENT: begin
        // Current word contains frame bytes 43–50
        if (header_bytes_discarded == 6'd43) begin
          udp_length_present = 1'b1;
          udp_length_candidate = {frame_data[23:16], frame_data[31:24]};
        end
      end

      default: begin
        udp_length_present = 1'b0;
        udp_length_candidate = '0;
      end
    endcase
  end

  // frame must contain one full message(32 bytes) but no more than 46 full messages(1472 bytes)
  assign udp_length_candidate_valid = (udp_length_candidate >= 16'd40) && (udp_length_candidate <= 16'd1480) && (udp_length_candidate[4:0] == 5'd8);

  always_comb begin
    case (payload_alignment)
      // Two final payload bytes followed by all four FCS bytes.
      START_0_ALIGNMENT: final_payload_input_valid = frame_end && (frame_keep == 8'h3F);
      // Six final payload bytes followed by the first two FCS bytes.
      START_4_ALIGNMENT: final_payload_input_valid = !frame_end && (frame_keep == 8'hFF);

      default: final_payload_input_valid = 1'b0;
    endcase
  end


  always_ff @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      payload_alignment <= START_0_ALIGNMENT;
      header_bytes_discarded <= '0;
      previous_frame_data <= '0;
      payload_started <= 1'b0;
      payload_words_remaining <= '0;
      udp_payload_data <= '0;
      udp_payload_start <= 1'b0;
      udp_payload_end <= 1'b0;
      udp_payload_valid <= 1'b0;
      udp_packet_abort <= 1'b0;
      udp_length_invalid <= 1'b0;
      parser_error <= 1'b0;
    end
    else begin
      udp_payload_start <= 1'b0;
      udp_payload_end <= 1'b0;
      udp_payload_valid <= 1'b0;
      udp_packet_abort <= 1'b0;
      parser_error <= 1'b0;

      if (frame_abort) begin
        state <= IDLE;
        header_bytes_discarded <= '0;
        previous_frame_data <= '0;
        payload_started <= 1'b0;
        payload_words_remaining <= '0;
        udp_length_invalid <= 1'b0;

        if (payload_started) begin
          udp_packet_abort <= 1'b1;
        end
      end
      else begin
        case (state)
          IDLE: begin
            if (frame_valid && frame_start) begin

              previous_frame_data <= '0;
              payload_started <= 1'b0;
              payload_words_remaining <= '0;
              udp_length_invalid <= 1'b0;

              if (frame_keep == 8'h7F) begin
                payload_alignment <= START_0_ALIGNMENT;
                header_bytes_discarded <= 6'd7;
              end
              else begin
                payload_alignment <= START_4_ALIGNMENT;
                header_bytes_discarded <= 6'd3;
              end

              state <= HEADER;
            end
          end

          HEADER: begin
            if (frame_valid) begin
              if (frame_keep != 8'hFF || frame_end) begin
                parser_error <= 1'b1;
                payload_words_remaining <= '0;
                payload_started <= 1'b0;

                if (frame_end) begin
                  state <= IDLE;
                  header_bytes_discarded <= '0;
                end
                else begin
                  state <= DRAIN;
                end
              end
              else begin
                if (udp_length_present) begin
                  payload_words_remaining <= udp_length_candidate[10:3] - 8'd1;
                  udp_length_invalid <= !udp_length_candidate_valid;
                end

                if (header_bytes_discarded + 6'd8 >= 6'd49) begin
                  previous_frame_data <= frame_data;
                  header_bytes_discarded <= 6'd49;
                  state <= PAYLOAD;
                end
                else begin
                  header_bytes_discarded <= header_bytes_discarded + 6'd8;
                end
              end
            end
          end

          PAYLOAD: begin
            if (frame_valid) begin
              if (udp_length_invalid) begin
                parser_error <= 1'b1;
                udp_packet_abort <= payload_started;
                payload_started <= 1'b0;
                if (frame_end) begin
                  state <= IDLE;
                end
                else begin
                  state <= DRAIN;
                end
              end
              else if ((payload_words_remaining > 8'd1) && ((frame_keep != 8'hFF) || frame_end)) begin
                // Frame ended before the declared UDP payload was complete.
                parser_error <= 1'b1;
                udp_packet_abort <= payload_started;
                payload_started <= 1'b0;
                payload_words_remaining <= '0;

                if (frame_end) begin
                  state <= IDLE;
                end
                else begin
                  state <= DRAIN;
                end
              end
              else if ((payload_words_remaining == 8'd1) && !final_payload_input_valid) begin
                // Final input word does not contain enough bytes to complete the final aligned UDP payload word
                parser_error <= 1'b1;
                udp_packet_abort <= payload_started;
                payload_started <= 1'b0;
                payload_words_remaining <= '0;

                if (frame_end) begin
                  state <= IDLE;
                end
                else begin
                  state <= DRAIN;
                end
              end
              else begin
                udp_payload_data <= aligned_payload_data;
                udp_payload_valid <= 1'b1;
                udp_payload_start <= !payload_started;

                if (payload_words_remaining == 8'd1) begin
                  udp_payload_end <= 1'b1;
                  payload_words_remaining <= '0;

                  case (payload_alignment)
                    START_0_ALIGNMENT: begin
                      // The same input contains the remaining payload and complete FCS
                      state <= IDLE;
                      payload_started <= 1'b0;
                    end

                    START_4_ALIGNMENT: begin
                      // Two FCS bytes remain for the following termination beat
                      state <= DRAIN;
                      payload_started <= 1'b1;
                    end

                    default: begin
                      state <= IDLE;
                      payload_started <= 1'b0;
                    end
                  endcase
                end
                else begin
                  payload_words_remaining <= payload_words_remaining - 1'b1;

                  payload_started <= 1'b1;
                  previous_frame_data <= frame_data;
                end
              end
            end
          end

          DRAIN: begin
            if (frame_valid) begin
              if (payload_started) begin
                // A successfully completed START_4 payload must be followed by exactly the two remaining FCS bytes.
                if (frame_end && (frame_keep == 8'h03)) begin
                  state <= IDLE;
                  header_bytes_discarded <= '0;
                  previous_frame_data <= '0;
                  payload_started <= 1'b0;
                  payload_words_remaining <= '0;
                end
                else begin
                  parser_error <= 1'b1;
                  udp_packet_abort <= 1'b1;
                  payload_started <= 1'b0;
                  payload_words_remaining <= '0;

                  if (frame_end) begin
                    state <= IDLE;
                    header_bytes_discarded <= '0;
                    previous_frame_data <= '0;
                  end
                end
              end
              else if (frame_end) begin
                // Finish draining a frame that was already rejected
                state <= IDLE;
                header_bytes_discarded <= '0;
                previous_frame_data <= '0;
                payload_words_remaining <= '0;
              end
            end
          end

          default: begin
            state <= IDLE;
            header_bytes_discarded <= '0;
            previous_frame_data <= '0;
            payload_started <= 1'b0;
            payload_words_remaining <= '0;
          end
        endcase
      end
    end
  end

  always_comb begin
    case (payload_alignment)
      START_0_ALIGNMENT: begin
        aligned_payload_data = {frame_data[15:0], previous_frame_data[63:16]};
      end

      START_4_ALIGNMENT: begin
        aligned_payload_data = {frame_data[47:0], previous_frame_data[63:48]};
      end

      default: begin
        aligned_payload_data = '0;
      end
    endcase
  end

endmodule
