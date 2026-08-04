// decodes 32 byte internal protocol message

module internal_protocol_decoder (
    input logic clk,
    input logic rst,

    input logic [255:0] message_data,
    input logic message_valid,
    input logic message_packet_start,
    input logic message_packet_end,
    input logic message_packet_abort,

    output logic decoded_valid,
    output logic [7:0] decoded_message_type,
    output logic [7:0] decoded_flags,
    output logic [31:0] decoded_sequence_number,
    output logic [15:0] decoded_symbol_id,
    output logic [47:0] decoded_timestamp,
    output logic [31:0] decoded_payload_0,
    output logic [31:0] decoded_payload_1,
    output logic [31:0] decoded_payload_2,
    output logic [31:0] decoded_payload_3,

    output logic decoded_packet_start,
    output logic decoded_packet_end,
    output logic decoded_packet_abort,
    output logic protocol_error
);

  localparam logic [7:0] SESSION_STATUS = 8'h01;
  localparam logic [7:0] TOB_UPDATE = 8'h02;
  localparam logic [7:0] SYMBOL_STATUS = 8'h03;
  localparam logic [7:0] ORDER_INTENT = 8'h04;
  localparam logic [7:0] CONFIG_CONTROL = 8'h05;

  localparam logic [31:0] CONFIG_NOP = 32'h00;
  localparam logic [31:0] CONFIG_RESET_ALL = 32'h1;
  localparam logic [31:0] CONFIG_RESET_SYMBOL = 32'h2;
  localparam logic [31:0] CONFIG_SET_SYMBOL_ENABLED = 32'h3;
  localparam logic [31:0] CONFIG_SET_MAX_ORDER_QTY = 32'h4;
  localparam logic [31:0] CONFIG_SET_MAX_NOTIONAL = 32'h5;
  localparam logic [31:0] CONFIG_SET_PRICE_BAND_TICKS = 32'h6;


  logic [7:0] message_type_candidate;
  logic [7:0] flags_candidate;
  logic [15:0] reserved_candidate;
  logic [31:0] sequence_number_candidate;
  logic [15:0] symbol_id_candidate;
  logic [47:0] timestamp_candidate;
  logic [31:0] payload_0_candidate;
  logic [31:0] payload_1_candidate;
  logic [31:0] payload_2_candidate;
  logic [31:0] payload_3_candidate;

  logic message_format_valid;
  logic type_fields_valid;


  always_ff @(posedge clk) begin
    if (rst) begin
      decoded_valid <= 1'b0;
      decoded_packet_start <= 1'b0;
      decoded_packet_end <= 1'b0;
      decoded_packet_abort <= 1'b0;
      protocol_error <= 1'b0;
    end
    else begin
      decoded_valid <= 1'b0;
      decoded_packet_start <= 1'b0;
      decoded_packet_end <= 1'b0;
      decoded_packet_abort <= 1'b0;
      protocol_error <= 1'b0;

      if (message_packet_abort) begin
        decoded_packet_abort <= 1'b1;
      end
      else if (message_valid) begin
        decoded_message_type <= message_type_candidate;
        decoded_flags <= flags_candidate;
        decoded_sequence_number <= sequence_number_candidate;
        decoded_symbol_id <= symbol_id_candidate;
        decoded_timestamp <= timestamp_candidate;
        decoded_payload_0 <= payload_0_candidate;
        decoded_payload_1 <= payload_1_candidate;
        decoded_payload_2 <= payload_2_candidate;
        decoded_payload_3 <= payload_3_candidate;

        if (message_format_valid || (message_type_candidate == ORDER_INTENT)) begin
          decoded_valid <= 1'b1;
          decoded_packet_start <= message_packet_start;
          decoded_packet_end <= message_packet_end;
        end

        if (!message_format_valid) begin
          protocol_error <= 1'b1;
          decoded_packet_abort <= 1'b1;
        end
      end
    end
  end


  always_comb begin
    message_type_candidate = message_data[7:0];
    flags_candidate = message_data[15:8];
    reserved_candidate = {message_data[23:16], message_data[31:24]};
    sequence_number_candidate = {message_data[39:32], message_data[47:40], message_data[55:48], message_data[63:56]};
    symbol_id_candidate = {message_data[71:64], message_data[79:72]};
    timestamp_candidate = {message_data[87:80], message_data[95:88], message_data[103:96], message_data[111:104], message_data[119:112], message_data[127:120]};
    payload_0_candidate = {message_data[135:128], message_data[143:136], message_data[151:144], message_data[159:152]};
    payload_1_candidate = {message_data[167:160], message_data[175:168], message_data[183:176], message_data[191:184]};
    payload_2_candidate = {message_data[199:192], message_data[207:200], message_data[215:208], message_data[223:216]};
    payload_3_candidate = {message_data[231:224], message_data[239:232], message_data[247:240], message_data[255:248]};
  end

  always_comb begin
    case (message_type_candidate)
      SESSION_STATUS: begin
        type_fields_valid = (flags_candidate == 8'h0) && (symbol_id_candidate == 16'h0) && (payload_0_candidate <= 32'd6) && (payload_1_candidate == 32'h0) && (payload_2_candidate == 32'h0) && (payload_3_candidate == 32'h0);
      end

      TOB_UPDATE: begin
        type_fields_valid = (flags_candidate[7:2] == 6'b0) && (symbol_id_candidate != 16'h0) &&

        // An invalid bid must carry zero bid fields.
        (flags_candidate[0] || ((payload_0_candidate == 32'h0) && (payload_1_candidate == 32'h0))) &&

        // An invalid ask must carry zero ask fields.
        (flags_candidate[1] || ((payload_2_candidate == 32'h0) && (payload_3_candidate == 32'h0)));
      end

      SYMBOL_STATUS: begin
        type_fields_valid = (flags_candidate == 8'h0) && (symbol_id_candidate != 16'h0) && (payload_0_candidate <= 32'd4) && (payload_1_candidate == 32'h0) && (payload_2_candidate == 32'h0) && (payload_3_candidate == 32'h0);
      end

      ORDER_INTENT: begin
        type_fields_valid = (flags_candidate == 8'h0) && (symbol_id_candidate != 16'h0) && (payload_0_candidate <= 32'd2) && message_packet_end;
      end

      CONFIG_CONTROL: begin
        type_fields_valid = 1'b0;

        if (flags_candidate == 8'h00) begin
          case (payload_0_candidate)

            CONFIG_NOP: begin
              type_fields_valid = (symbol_id_candidate == 16'h0) && (payload_1_candidate == 32'h0) && (payload_2_candidate == 32'h0);
            end
            CONFIG_RESET_ALL: begin
              type_fields_valid = (symbol_id_candidate == 16'h0) && (payload_1_candidate[31:4] == 28'b0) && (payload_2_candidate == 32'h0);
            end
            CONFIG_RESET_SYMBOL: begin
              type_fields_valid = (symbol_id_candidate != 16'h0) && (payload_1_candidate[31:4] == 28'b0) && (payload_2_candidate == 32'h0);
            end
            CONFIG_SET_SYMBOL_ENABLED: begin
              type_fields_valid = (symbol_id_candidate != 16'h0) && (payload_1_candidate <= 32'd1) && (payload_2_candidate == 32'h0);
            end
            CONFIG_SET_MAX_ORDER_QTY: begin
              type_fields_valid = (symbol_id_candidate != 16'h0) && (payload_2_candidate == 32'h0);
            end
            CONFIG_SET_MAX_NOTIONAL: begin
              type_fields_valid = (symbol_id_candidate != 16'h0);
            end
            CONFIG_SET_PRICE_BAND_TICKS: begin
              type_fields_valid = (symbol_id_candidate != 16'h0) && (payload_2_candidate == 32'h0);
            end
            default: begin
              type_fields_valid = 1'b0;
            end
          endcase
        end
      end

      default: begin
        type_fields_valid = 1'b0;
      end
    endcase

    message_format_valid = (reserved_candidate == 16'h0000) && type_fields_valid;
  end


endmodule
