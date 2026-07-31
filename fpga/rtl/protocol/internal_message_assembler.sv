// Takes in four 64-bit udp payload workds and produces one 256-bit internal protocol message

module internal_message_assembler (
    input logic clk,
    input logic rst,

    input logic [63:0] udp_payload_data,
    input logic udp_payload_start,
    input logic udp_payload_end,
    input logic udp_payload_valid,
    input logic udp_packet_abort,

    output logic [255:0] message_data,
    output logic message_valid,
    output logic message_packet_start,
    output logic message_packet_end,
    output logic message_packet_abort
);

  logic [191:0] message_prefix;  // store incoming 64 bit payload for 3 cycles
  logic [1:0] word_index;  // emit on word 3
  logic current_message_is_packet_start;

  assign message_data = {udp_payload_data, message_prefix};
  assign message_packet_start = message_valid && current_message_is_packet_start;
  assign message_packet_end = message_valid && udp_payload_end;
  assign message_packet_abort = udp_packet_abort;
  assign message_valid = udp_payload_valid && !udp_packet_abort && (word_index == 2'd3);

  always_ff @(posedge clk) begin
    if (rst) begin
      word_index <= '0;
      current_message_is_packet_start <= 1'b0;
    end
    else if (udp_packet_abort) begin
      word_index <= '0;
      current_message_is_packet_start <= 1'b0;
    end

    else if (udp_payload_valid) begin
      case (word_index)
        2'd0: begin
          message_prefix[63:0] <= udp_payload_data;
          current_message_is_packet_start <= udp_payload_start;
          word_index <= 2'd1;
        end

        2'd1: begin
          message_prefix[127:64] <= udp_payload_data;
          word_index <= 2'd2;
        end

        2'd2: begin
          message_prefix[191:128] <= udp_payload_data;
          word_index <= 2'd3;
        end

        2'd3: begin
          word_index <= 2'd0;
          current_message_is_packet_start <= 1'b0;
        end
      endcase
    end
  end

endmodule
