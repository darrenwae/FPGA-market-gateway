// Builds one {Ethernet/IPv4/UDP + 32 byte ORDER_DECISION} response
// The matching DECISION FIFO entry must be available before frame beat 6

module order_decision_frame_generator #(
    parameter logic [47:0] SOURCE_MAC_ADDRESS = '0,
    parameter logic [47:0] DESTINATION_MAC_ADDRESS = '0,
    parameter logic [31:0] SOURCE_IP_ADDRESS = '0,
    parameter logic [31:0] DESTINATION_IP_ADDRESS = '0,
    parameter logic [15:0] SOURCE_UDP_PORT = '0,
    parameter logic [15:0] DESTINATION_UDP_PORT = '0
) (
    input logic clk,
    input logic rst,

    input  logic tx_response_start_valid,
    output logic tx_response_start_ready,

    input  logic tx_decision_valid,
    output logic tx_decision_ready,

    input logic [31:0] tx_decision_sequence_number,
    input logic [15:0] tx_decision_symbol_id,
    input logic [31:0] tx_decision_intent_id,
    input logic [31:0] tx_decision,
    input logic [31:0] tx_reject_reason,
    input logic tx_source_frame_ok,

    // The PCS may delay a new frame for inter-frame gap. Once a frame starts, it must accept one beat per clock until frame_end.
    input logic frame_start_ready,

    output logic [63:0] frame_data,
    output logic [7:0] frame_keep,
    output logic frame_start,
    output logic frame_end,
    output logic frame_valid
);

  localparam logic [7:0] ORDER_DECISION_MESSAGE_TYPE = 8'h81;

  localparam logic [15:0] ETHERTYPE_IPV4 = 16'h0800;
  localparam logic [15:0] IPV4_TOTAL_LENGTH = 16'd60;
  localparam logic [15:0] UDP_LENGTH = 16'd40;

  localparam logic [31:0] CRC32_POLY_REFLECTED = 32'hEDB8_8320;

  localparam logic [3:0] FINAL_FRAME_BEAT = 4'd10;


  function automatic logic [63:0] wire_order_to_frame_data(input logic [63:0] bytes_in_wire_order);
    begin
      wire_order_to_frame_data = {bytes_in_wire_order[7:0], bytes_in_wire_order[15:8], bytes_in_wire_order[23:16], bytes_in_wire_order[31:24], bytes_in_wire_order[39:32], bytes_in_wire_order[47:40], bytes_in_wire_order[55:48], bytes_in_wire_order[63:56]};
    end
  endfunction


  function automatic logic [15:0] calculate_ipv4_header_checksum(input logic [31:0] source_ip_address, input logic [31:0] destination_ip_address);
    logic [31:0] sum;

    begin
      sum = 32'h0000_4500 + {16'd0, IPV4_TOTAL_LENGTH} + 32'h0000_4000 + 32'h0000_4011 + {16'd0, source_ip_address[31:16]} + {16'd0, source_ip_address[15:0]} + {16'd0, destination_ip_address[31:16]} + {16'd0, destination_ip_address[15:0]};
      sum = {16'd0, sum[15:0]} + {16'd0, sum[31:16]};
      sum = {16'd0, sum[15:0]} + {16'd0, sum[31:16]};
      calculate_ipv4_header_checksum = ~sum[15:0];
    end
  endfunction


  function automatic logic [31:0] crc32_update_byte(input logic [31:0] crc_in, input logic [7:0] data_byte);
    logic [31:0] crc;

    begin
      crc = crc_in;

      for (int i = 0; i < 8; i++) begin
        if (crc[0] ^ data_byte[i]) begin
          crc = (crc >> 1) ^ CRC32_POLY_REFLECTED;
        end
        else begin
          crc >>= 1;
        end
      end

      crc32_update_byte = crc;
    end
  endfunction


  function automatic logic [31:0] crc32_update_word(input logic [31:0] crc_in, input logic [63:0] data_word);
    logic [31:0] crc;

    begin
      crc = crc_in;

      for (int i = 0; i < 8; i++) begin
        crc = crc32_update_byte(crc, data_word[i*8+:8]);
      end

      crc32_update_word = crc;
    end
  endfunction


  localparam logic [15:0] IPV4_HEADER_CHECKSUM = calculate_ipv4_header_checksum(SOURCE_IP_ADDRESS, DESTINATION_IP_ADDRESS);
  localparam logic [31:0] CRC_AFTER_FIRST_ETHERNET_BYTE = crc32_update_byte(32'hFFFF_FFFF, DESTINATION_MAC_ADDRESS[47:40]);

  logic [3:0] frame_beat_index;
  logic [31:0] crc_state;

  logic start_event_accepted;

  logic [31:0] correct_fcs;
  logic [31:0] transmitted_fcs;


  assign tx_response_start_ready = !rst && (frame_beat_index == 4'd0) && frame_start_ready;
  assign start_event_accepted = tx_response_start_valid && tx_response_start_ready;
  assign tx_decision_ready = !rst && (frame_beat_index == FINAL_FRAME_BEAT) && tx_decision_valid;
  assign correct_fcs = ~crc32_update_byte(crc_state, tx_decision_intent_id[7:0]);

  // A failed source frame deliberately receives an invalid response FCS
  assign transmitted_fcs = tx_source_frame_ok ? correct_fcs : (correct_fcs ^ 32'h0000_0001);


  always_comb begin
    frame_data = '0;
    frame_keep = '0;
    frame_start = 1'b0;
    frame_end = 1'b0;
    frame_valid = 1'b0;

    if (!rst) begin
      if (frame_beat_index == 4'd0) begin
        if (start_event_accepted) begin
          frame_data = wire_order_to_frame_data({48'h55_55_55_55_55_55, 8'hD5, DESTINATION_MAC_ADDRESS[47:40]});
          frame_keep = 8'hFF;
          frame_start = 1'b1;
          frame_valid = 1'b1;
        end
      end
      else begin
        frame_keep = 8'hFF;
        frame_valid = 1'b1;

        case (frame_beat_index)
          4'd1: begin
            frame_data = wire_order_to_frame_data({DESTINATION_MAC_ADDRESS[39:0], SOURCE_MAC_ADDRESS[47:24]});
          end

          4'd2: begin
            frame_data = wire_order_to_frame_data({SOURCE_MAC_ADDRESS[23:0], ETHERTYPE_IPV4, 16'h4500, IPV4_TOTAL_LENGTH[15:8]});
          end

          4'd3: begin
            frame_data = wire_order_to_frame_data({IPV4_TOTAL_LENGTH[7:0], 16'h0000, 16'h4000, 8'h40, 8'h11, IPV4_HEADER_CHECKSUM[15:8]});
          end

          4'd4: begin
            frame_data = wire_order_to_frame_data({IPV4_HEADER_CHECKSUM[7:0], SOURCE_IP_ADDRESS, DESTINATION_IP_ADDRESS[31:8]});
          end

          4'd5: begin
            frame_data = wire_order_to_frame_data({DESTINATION_IP_ADDRESS[7:0], SOURCE_UDP_PORT, DESTINATION_UDP_PORT, UDP_LENGTH, 8'h00});
          end

          4'd6: begin
            frame_data = wire_order_to_frame_data({8'h00, ORDER_DECISION_MESSAGE_TYPE, 8'h00, 16'h0000, tx_decision_sequence_number[31:8]});
          end

          4'd7: begin
            frame_data = wire_order_to_frame_data({tx_decision_sequence_number[7:0], tx_decision_symbol_id, 40'h0000_0000_00});
          end

          4'd8: begin
            frame_data = wire_order_to_frame_data({8'h00, tx_decision, tx_reject_reason[31:8]});
          end

          4'd9: begin
            frame_data = wire_order_to_frame_data({tx_reject_reason[7:0], 32'h0000_0000, tx_decision_intent_id[31:8]});
          end

          FINAL_FRAME_BEAT: begin
            frame_data[7:0] = tx_decision_intent_id[7:0];

            // Reflected Ethernet CRC is transmitted least-significant byte first
            frame_data[39:8] = transmitted_fcs;

            frame_keep = 8'h1F;
            frame_end = 1'b1;
          end

          default: begin
            frame_data = '0;
            frame_keep = '0;
            frame_valid = 1'b0;
          end
        endcase
      end
    end
  end


  always_ff @(posedge clk) begin
    if (rst) begin
      frame_beat_index <= '0;
      crc_state <= 32'hFFFF_FFFF;
    end
    else if (frame_beat_index == 4'd0) begin
      if (start_event_accepted) begin
        frame_beat_index <= 4'd1;
        crc_state <= CRC_AFTER_FIRST_ETHERNET_BYTE;
      end
    end
    else if (frame_beat_index == FINAL_FRAME_BEAT) begin
      frame_beat_index <= '0;
    end
    else begin
      frame_beat_index <= frame_beat_index + 1'b1;
      crc_state <= crc32_update_word(crc_state, frame_data);
    end
  end

endmodule
