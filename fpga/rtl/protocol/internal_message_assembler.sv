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
    output logic message_packet_abort,
    output logic assembler_error
);

  logic [255:0] message_buffer;
  logic [1:0] word_index;  // emit on word 3
  logic packet_active;
  logic current_message_is_packet_start;

  logic framing_error;


  always_ff @(posedge clk) begin
    if (rst) begin
      message_data <= '0;
      message_valid <= 1'b0;
      message_packet_start <= 1'b0;
      message_packet_end <= 1'b0;
      message_packet_abort <= 1'b0;
      assembler_error <= 1'b0;

      message_buffer <= '0;
      word_index <= '0;
      packet_active <= 1'b0;
      current_message_is_packet_start <= 1'b0;
    end
    else begin
      message_valid <= 1'b0;
      message_packet_start <= 1'b0;
      message_packet_end <= 1'b0;
      message_packet_abort <= 1'b0;
      assembler_error <= 1'b0;

      if (udp_packet_abort) begin
        message_buffer <= '0;
        word_index <= '0;
        packet_active <= 1'b0;
        current_message_is_packet_start <= 1'b0;
        message_packet_abort <= 1'b1;
      end

      else if (udp_payload_valid) begin
        if (framing_error) begin
          assembler_error <= 1'b1;
          message_packet_abort <= 1'b1;
          message_buffer <= '0;
          word_index <= '0;
          packet_active <= 1'b0;
          current_message_is_packet_start <= 1'b0;
        end

        else begin
          case (word_index)
            2'd0: begin
              message_buffer[63:0] <= udp_payload_data;
              packet_active <= 1'b1;
              current_message_is_packet_start <= udp_payload_start;
              word_index <= 2'd1;
            end
            2'd1: begin
              message_buffer[127:64] <= udp_payload_data;
              word_index <= 2'd2;
            end
            2'd2: begin
              message_buffer[191:128] <= udp_payload_data;
              word_index <= 2'd3;
            end
            2'd3: begin
              message_data <= {udp_payload_data, message_buffer[191:0]};
              message_valid <= 1'b1;
              message_packet_start <= current_message_is_packet_start;
              message_packet_end <= udp_payload_end;
              word_index <= 2'b0;
              current_message_is_packet_start <= 1'b0;
              if (udp_payload_end) begin
                packet_active <= 1'b0;
              end
            end
            default: begin
              assembler_error <= 1'b1;
              message_packet_abort <= 1'b1;
              message_buffer <= '0;
              word_index <= '0;
              packet_active <= 1'b0;
              current_message_is_packet_start <= 1'b0;
            end
          endcase
        end
      end
    end
  end


  always_comb begin
    framing_error = (udp_payload_start && packet_active)  // error: unexpected second packet start
    || (!packet_active && !udp_payload_start)  // error: data arrived outside a packet
    || (udp_payload_end && word_index != 2'd3);  // error: packet ended halfway through one 32 byte message
  end

endmodule
