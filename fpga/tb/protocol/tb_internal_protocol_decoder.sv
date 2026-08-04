`timescale 1ns / 1ps

module tb_internal_protocol_decoder;

  // ==========================================================================
  // Constants
  // ==========================================================================

  localparam time CLK_PERIOD = 6.206ns;

  localparam logic [7:0] SESSION_STATUS = 8'h01;
  localparam logic [7:0] TOB_UPDATE = 8'h02;
  localparam logic [7:0] SYMBOL_STATUS = 8'h03;
  localparam logic [7:0] ORDER_INTENT = 8'h04;
  localparam logic [7:0] CONFIG_CONTROL = 8'h05;

  localparam logic [31:0] CONFIG_NOP = 32'h0000_0000;
  localparam logic [31:0] CONFIG_RESET_ALL = 32'h0000_0001;
  localparam logic [31:0] CONFIG_RESET_SYMBOL = 32'h0000_0002;
  localparam logic [31:0] CONFIG_SET_SYMBOL_ENABLED = 32'h0000_0003;
  localparam logic [31:0] CONFIG_SET_MAX_ORDER_QTY = 32'h0000_0004;
  localparam logic [31:0] CONFIG_SET_MAX_NOTIONAL = 32'h0000_0005;
  localparam logic [31:0] CONFIG_SET_PRICE_BAND_TICKS = 32'h0000_0006;


  // ==========================================================================
  // DUT inputs
  // ==========================================================================

  logic clk;
  logic rst;

  logic [255:0] message_data;
  logic message_valid;
  logic message_packet_start;
  logic message_packet_end;
  logic message_packet_abort;


  // ==========================================================================
  // DUT outputs
  // ==========================================================================

  logic decoded_valid;
  logic [7:0] decoded_message_type;
  logic [7:0] decoded_flags;
  logic [31:0] decoded_sequence_number;
  logic [15:0] decoded_symbol_id;
  logic [47:0] decoded_timestamp;
  logic [31:0] decoded_payload_0;
  logic [31:0] decoded_payload_1;
  logic [31:0] decoded_payload_2;
  logic [31:0] decoded_payload_3;

  logic decoded_packet_start;
  logic decoded_packet_end;
  logic decoded_packet_abort;
  logic protocol_error;

  int unsigned error_count;


  // ==========================================================================
  // DUT instantiation
  // ==========================================================================

  internal_protocol_decoder dut (
      .clk(clk),
      .rst(rst),
      .message_data(message_data),
      .message_valid(message_valid),
      .message_packet_start(message_packet_start),
      .message_packet_end(message_packet_end),
      .message_packet_abort(message_packet_abort),
      .decoded_valid(decoded_valid),
      .decoded_message_type(decoded_message_type),
      .decoded_flags(decoded_flags),
      .decoded_sequence_number(decoded_sequence_number),
      .decoded_symbol_id(decoded_symbol_id),
      .decoded_timestamp(decoded_timestamp),
      .decoded_payload_0(decoded_payload_0),
      .decoded_payload_1(decoded_payload_1),
      .decoded_payload_2(decoded_payload_2),
      .decoded_payload_3(decoded_payload_3),
      .decoded_packet_start(decoded_packet_start),
      .decoded_packet_end(decoded_packet_end),
      .decoded_packet_abort(decoded_packet_abort),
      .protocol_error(protocol_error)
  );


  // ==========================================================================
  // Clock generation
  // ==========================================================================

  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;


  // ==========================================================================
  // Message construction helpers
  // ==========================================================================

  function automatic logic [255:0] pack_message(input logic [7:0] message_type, input logic [7:0] flags, input logic [15:0] reserved, input logic [31:0] sequence_number, input logic [15:0] symbol_id, input logic [47:0] timestamp, input logic [31:0] payload_0, input logic [31:0] payload_1, input logic [31:0] payload_2, input logic [31:0] payload_3);

    logic [255:0] packed_message;

    begin
      packed_message = '0;

      packed_message[7:0] = message_type;
      packed_message[15:8] = flags;
      packed_message[23:16] = reserved[15:8];
      packed_message[31:24] = reserved[7:0];

      packed_message[39:32] = sequence_number[31:24];
      packed_message[47:40] = sequence_number[23:16];
      packed_message[55:48] = sequence_number[15:8];
      packed_message[63:56] = sequence_number[7:0];

      packed_message[71:64] = symbol_id[15:8];
      packed_message[79:72] = symbol_id[7:0];

      packed_message[87:80] = timestamp[47:40];
      packed_message[95:88] = timestamp[39:32];
      packed_message[103:96] = timestamp[31:24];
      packed_message[111:104] = timestamp[23:16];
      packed_message[119:112] = timestamp[15:8];
      packed_message[127:120] = timestamp[7:0];

      packed_message[135:128] = payload_0[31:24];
      packed_message[143:136] = payload_0[23:16];
      packed_message[151:144] = payload_0[15:8];
      packed_message[159:152] = payload_0[7:0];

      packed_message[167:160] = payload_1[31:24];
      packed_message[175:168] = payload_1[23:16];
      packed_message[183:176] = payload_1[15:8];
      packed_message[191:184] = payload_1[7:0];

      packed_message[199:192] = payload_2[31:24];
      packed_message[207:200] = payload_2[23:16];
      packed_message[215:208] = payload_2[15:8];
      packed_message[223:216] = payload_2[7:0];

      packed_message[231:224] = payload_3[31:24];
      packed_message[239:232] = payload_3[23:16];
      packed_message[247:240] = payload_3[15:8];
      packed_message[255:248] = payload_3[7:0];

      pack_message = packed_message;
    end
  endfunction


  // ==========================================================================
  // Input-driving helpers
  // ==========================================================================

  task automatic initialize_inputs;
    begin
      rst = 1'b0;
      message_data = '0;
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      message_packet_abort = 1'b0;
      error_count = 0;
    end
  endtask

  task automatic reset_dut;
    begin
      @(negedge clk);
      message_data = '0;
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      message_packet_abort = 1'b0;
      rst = 1'b1;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic drive_idle;
    begin
      @(negedge clk);

      message_data = '0;
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      message_packet_abort = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic drive_message(input logic [255:0] data, input logic packet_start, input logic packet_end);
    begin
      @(negedge clk);
      message_data = data;
      message_valid = 1'b1;
      message_packet_start = packet_start;
      message_packet_end = packet_end;
      message_packet_abort = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic drive_abort(input logic [255:0] data, input logic valid, input logic packet_start, input logic packet_end);
    begin
      @(negedge clk);
      message_data = data;
      message_valid = valid;
      message_packet_start = packet_start;
      message_packet_end = packet_end;
      message_packet_abort = 1'b1;

      @(posedge clk);
      #1ps;
    end
  endtask


  // ==========================================================================
  // Checking helpers
  // ==========================================================================

  task automatic check_condition(input logic condition, input string failure_message);
    begin
      if (condition !== 1'b1) begin
        error_count++;
        $error("%s", failure_message);
      end
    end
  endtask


  task automatic check_no_output_pulses(input string check_label);
    begin
      check_condition(decoded_valid === 1'b0, $sformatf("%s: decoded_valid unexpectedly asserted", check_label));
      check_condition(decoded_packet_start === 1'b0, $sformatf("%s: decoded_packet_start unexpectedly asserted", check_label));
      check_condition(decoded_packet_end === 1'b0, $sformatf("%s: decoded_packet_end unexpectedly asserted", check_label));
      check_condition(decoded_packet_abort === 1'b0, $sformatf("%s: decoded_packet_abort unexpectedly asserted", check_label));
      check_condition(protocol_error === 1'b0, $sformatf("%s: protocol_error unexpectedly asserted", check_label));
    end
  endtask


  task automatic finish_test(input string test_name);
    begin
      if (error_count == 0) begin
        $display("PASS: %s", test_name);
      end
      else begin
        $fatal(1, "FAIL: %s, %0d errors", test_name, error_count);
      end
    end
  endtask


  task automatic check_decoded_message(input logic [7:0] expected_message_type, input logic [7:0] expected_flags, input logic [31:0] expected_sequence_number, input logic [15:0] expected_symbol_id, input logic [47:0] expected_timestamp, input logic [31:0] expected_payload_0, input logic [31:0] expected_payload_1, input logic [31:0] expected_payload_2, input logic [31:0] expected_payload_3, input logic expected_packet_start, input logic expected_packet_end, input string check_label);
    begin
      check_condition(decoded_valid === 1'b1, $sformatf("%s: decoded_valid was not asserted", check_label));
      check_condition(decoded_message_type === expected_message_type, $sformatf("%s: incorrect message type", check_label));
      check_condition(decoded_flags === expected_flags, $sformatf("%s: incorrect flags", check_label));
      check_condition(decoded_sequence_number === expected_sequence_number, $sformatf("%s: incorrect sequence number", check_label));
      check_condition(decoded_symbol_id === expected_symbol_id, $sformatf("%s: incorrect symbol ID", check_label));
      check_condition(decoded_timestamp === expected_timestamp, $sformatf("%s: incorrect timestamp", check_label));
      check_condition(decoded_payload_0 === expected_payload_0, $sformatf("%s: incorrect payload 0", check_label));
      check_condition(decoded_payload_1 === expected_payload_1, $sformatf("%s: incorrect payload 1", check_label));
      check_condition(decoded_payload_2 === expected_payload_2, $sformatf("%s: incorrect payload 2", check_label));
      check_condition(decoded_payload_3 === expected_payload_3, $sformatf("%s: incorrect payload 3", check_label));
      check_condition(decoded_packet_start === expected_packet_start, $sformatf("%s: incorrect packet-start output", check_label));
      check_condition(decoded_packet_end === expected_packet_end, $sformatf("%s: incorrect packet-end output", check_label));
      check_condition(decoded_packet_abort === 1'b0, $sformatf("%s: unexpected packet abort", check_label));
      check_condition(protocol_error === 1'b0, $sformatf("%s: unexpected protocol error", check_label));
    end
  endtask

  task automatic check_protocol_rejection(input string check_label);
    begin
      check_condition(decoded_valid === 1'b0, $sformatf("%s: decoded_valid unexpectedly asserted", check_label));
      check_condition(decoded_packet_start === 1'b0, $sformatf("%s: decoded_packet_start unexpectedly asserted", check_label));
      check_condition(decoded_packet_end === 1'b0, $sformatf("%s: decoded_packet_end unexpectedly asserted", check_label));
      check_condition(decoded_packet_abort === 1'b1, $sformatf("%s: decoded_packet_abort was not asserted", check_label));
      check_condition(protocol_error === 1'b1, $sformatf("%s: protocol_error was not asserted", check_label));
    end
  endtask


  task automatic check_order_intent_protocol_violation(input logic [7:0] expected_flags, input logic [31:0] expected_sequence_number, input logic [15:0] expected_symbol_id, input logic [47:0] expected_timestamp, input logic [31:0] expected_payload_0, input logic [31:0] expected_payload_1, input logic [31:0] expected_payload_2, input logic [31:0] expected_payload_3, input logic expected_packet_start, input logic expected_packet_end, input string check_label);
    begin
      check_condition(decoded_valid === 1'b1, $sformatf("%s: decoded_valid was not asserted", check_label));
      check_condition(decoded_message_type === ORDER_INTENT, $sformatf("%s: incorrect message type", check_label));
      check_condition(decoded_flags === expected_flags, $sformatf("%s: incorrect flags", check_label));
      check_condition(decoded_sequence_number === expected_sequence_number, $sformatf("%s: incorrect sequence number", check_label));
      check_condition(decoded_symbol_id === expected_symbol_id, $sformatf("%s: incorrect symbol ID", check_label));
      check_condition(decoded_timestamp === expected_timestamp, $sformatf("%s: incorrect timestamp", check_label));
      check_condition(decoded_payload_0 === expected_payload_0, $sformatf("%s: incorrect payload 0", check_label));
      check_condition(decoded_payload_1 === expected_payload_1, $sformatf("%s: incorrect payload 1", check_label));
      check_condition(decoded_payload_2 === expected_payload_2, $sformatf("%s: incorrect payload 2", check_label));
      check_condition(decoded_payload_3 === expected_payload_3, $sformatf("%s: incorrect payload 3", check_label));
      check_condition(decoded_packet_start === expected_packet_start, $sformatf("%s: incorrect packet-start output", check_label));
      check_condition(decoded_packet_end === expected_packet_end, $sformatf("%s: incorrect packet-end output", check_label));
      check_condition(decoded_packet_abort === 1'b1, $sformatf("%s: decoded_packet_abort was not asserted", check_label));
      check_condition(protocol_error === 1'b1, $sformatf("%s: protocol_error was not asserted", check_label));
    end
  endtask


  task automatic run_valid_config_case(input logic [31:0] sequence_number, input logic [15:0] symbol_id, input logic [47:0] timestamp, input logic [31:0] config_opcode, input logic [31:0] config_value_0, input logic [31:0] config_value_1, input logic [31:0] config_id, input string check_label);

    logic [255:0] test_message;

    begin
      test_message = pack_message(CONFIG_CONTROL, 8'h00, 16'h0000, sequence_number, symbol_id, timestamp, config_opcode, config_value_0, config_value_1, config_id);
      drive_message(test_message, 1'b1, 1'b1);
      check_decoded_message(CONFIG_CONTROL, 8'h00, sequence_number, symbol_id, timestamp, config_opcode, config_value_0, config_value_1, config_id, 1'b1, 1'b1, check_label);
      drive_idle();
      check_no_output_pulses($sformatf("after %s", check_label));
    end
  endtask


  task automatic run_invalid_config_case(input logic [31:0] sequence_number, input logic [15:0] symbol_id, input logic [31:0] config_opcode, input logic [31:0] config_value_0, input logic [31:0] config_value_1, input string check_label);

    logic [255:0] test_message;

    begin
      test_message = pack_message(CONFIG_CONTROL, 8'h00, 16'h0000, sequence_number, symbol_id, 48'h0102_0304_0506, config_opcode, config_value_0, config_value_1, 32'hCAFE_0000 | sequence_number);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection(check_label);
      drive_idle();
      check_no_output_pulses($sformatf("after %s", check_label));
    end
  endtask


  // ==========================================================================
  // Test cases
  // ==========================================================================

  task automatic test_reset_and_idle;
    begin
      $display("TEST: reset and idle");

      error_count = 0;
      reset_dut();
      check_no_output_pulses("after reset");

      drive_idle();
      check_no_output_pulses("first idle cycle");

      drive_idle();
      check_no_output_pulses("second idle cycle");

      finish_test("reset and idle");
    end
  endtask

  task automatic test_valid_session_status_boundaries;

    logic [255:0] test_message;

    begin
      $display("TEST: valid SESSION_STATUS boundaries");

      error_count = 0;

      reset_dut();
      test_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h1020_3040, 16'h0000, 48'h1122_3344_5566, 32'd0, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b0);
      check_decoded_message(SESSION_STATUS, 8'h00, 32'h1020_3040, 16'h0000, 48'h1122_3344_5566, 32'd0, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b0, "SESSION_STATUS value 0");

      drive_idle();
      check_no_output_pulses("after SESSION_STATUS value 0");

      test_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h5060_7080, 16'h0000, 48'hA1B2_C3D4_E5F6, 32'd6, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b0, 1'b1);
      check_decoded_message(SESSION_STATUS, 8'h00, 32'h5060_7080, 16'h0000, 48'hA1B2_C3D4_E5F6, 32'd6, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b1, "SESSION_STATUS value 6");

      drive_idle();
      check_no_output_pulses("after SESSION_STATUS value 6");
      finish_test("valid SESSION_STATUS boundaries");
    end
  endtask


  task automatic test_invalid_session_status;

    logic [255:0] test_message;

    begin
      $display("TEST: invalid SESSION_STATUS");

      error_count = 0;
      reset_dut();

      // Reserved status value
      test_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h0000_0001, 16'h0000, 48'h0000_0000_0001, 32'd7, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SESSION_STATUS value 7");
      drive_idle();
      check_no_output_pulses("after SESSION_STATUS value 7");

      // Nonzero flags
      test_message = pack_message(SESSION_STATUS, 8'h01, 16'h0000, 32'h0000_0002, 16'h0000, 48'h0000_0000_0002, 32'd1, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SESSION_STATUS nonzero flags");
      drive_idle();
      check_no_output_pulses("after SESSION_STATUS nonzero flags");

      // Nonzero symbol ID
      test_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h0000_0003, 16'h1234, 48'h0000_0000_0003, 32'd2, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SESSION_STATUS nonzero symbol ID");
      drive_idle();
      check_no_output_pulses("after SESSION_STATUS nonzero symbol ID");

      // Nonzero unused payload
      test_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h0000_0004, 16'h0000, 48'h0000_0000_0004, 32'd3, 32'h0000_0001, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SESSION_STATUS nonzero unused payload");
      drive_idle();
      check_no_output_pulses("after SESSION_STATUS nonzero unused payload");
      finish_test("invalid SESSION_STATUS");
    end
  endtask


  task automatic test_valid_tob_variants;

    logic [255:0] test_message;

    begin
      $display("TEST: valid TOB_UPDATE variants");

      error_count = 0;
      reset_dut();

      // Empty book
      test_message = pack_message(TOB_UPDATE, 8'b0000_0000, 16'h0000, 32'h0000_0010, 16'h1234, 48'h0102_0304_0506, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b0);
      check_decoded_message(TOB_UPDATE, 8'b0000_0000, 32'h0000_0010, 16'h1234, 48'h0102_0304_0506, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b0, "TOB_UPDATE empty book");

      drive_idle();
      check_no_output_pulses("after TOB_UPDATE empty book");

      // Valid bid only
      test_message = pack_message(TOB_UPDATE, 8'b0000_0001, 16'h0000, 32'h0000_0011, 16'h2345, 48'h1112_1314_1516, 32'h0012_3456, 32'h0000_0100, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b0, 1'b0);
      check_decoded_message(TOB_UPDATE, 8'b0000_0001, 32'h0000_0011, 16'h2345, 48'h1112_1314_1516, 32'h0012_3456, 32'h0000_0100, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0, "TOB_UPDATE bid only");

      drive_idle();
      check_no_output_pulses("after TOB_UPDATE bid only");


      // Valid ask only
      test_message = pack_message(TOB_UPDATE, 8'b0000_0010, 16'h0000, 32'h0000_0012, 16'h3456, 48'h2122_2324_2526, 32'h0000_0000, 32'h0000_0000, 32'h0065_4321, 32'h0000_0200);
      drive_message(test_message, 1'b0, 1'b0);
      check_decoded_message(TOB_UPDATE, 8'b0000_0010, 32'h0000_0012, 16'h3456, 48'h2122_2324_2526, 32'h0000_0000, 32'h0000_0000, 32'h0065_4321, 32'h0000_0200, 1'b0, 1'b0, "TOB_UPDATE ask only");

      drive_idle();
      check_no_output_pulses("after TOB_UPDATE ask only");

      // Valid bid and ask
      test_message = pack_message(TOB_UPDATE, 8'b0000_0011, 16'h0000, 32'h0000_0013, 16'h4567, 48'h3132_3334_3536, 32'h0011_2233, 32'h0000_0300, 32'h0044_5566, 32'h0000_0400);

      drive_message(test_message, 1'b0, 1'b1);
      check_decoded_message(TOB_UPDATE, 8'b0000_0011, 32'h0000_0013, 16'h4567, 48'h3132_3334_3536, 32'h0011_2233, 32'h0000_0300, 32'h0044_5566, 32'h0000_0400, 1'b0, 1'b1, "TOB_UPDATE bid and ask");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE bid and ask");

      finish_test("valid TOB_UPDATE variants");
    end
  endtask


  task automatic test_invalid_tob_variants;

    logic [255:0] test_message;

    begin
      $display("TEST: invalid TOB_UPDATE variants");

      error_count = 0;
      reset_dut();

      // Reserved flag bit set
      test_message = pack_message(TOB_UPDATE, 8'b0000_0101, 16'h0000, 32'h0000_0020, 16'h1234, 48'h0102_0304_0506, 32'h0012_3456, 32'h0000_0100, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE reserved flag bit");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE reserved flag bit");

      // Zero symbol ID
      test_message = pack_message(TOB_UPDATE, 8'b0000_0011, 16'h0000, 32'h0000_0021, 16'h0000, 48'h1112_1314_1516, 32'h0011_2233, 32'h0000_0100, 32'h0044_5566, 32'h0000_0200);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE zero symbol ID");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE zero symbol ID");

      // Invalid bid carries a nonzero bid price
      test_message = pack_message(TOB_UPDATE, 8'b0000_0010, 16'h0000, 32'h0000_0022, 16'h2345, 48'h2122_2324_2526, 32'h0012_3456, 32'h0000_0000, 32'h0065_4321, 32'h0000_0200);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE invalid bid with nonzero price");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE invalid bid with nonzero price");

      // Invalid bid carries a nonzero bid quantity
      test_message = pack_message(TOB_UPDATE, 8'b0000_0010, 16'h0000, 32'h0000_0023, 16'h3456, 48'h3132_3334_3536, 32'h0000_0000, 32'h0000_0100, 32'h0065_4321, 32'h0000_0200);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE invalid bid with nonzero quantity");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE invalid bid with nonzero quantity");

      // Invalid ask carries a nonzero ask price
      test_message = pack_message(TOB_UPDATE, 8'b0000_0001, 16'h0000, 32'h0000_0024, 16'h4567, 48'h4142_4344_4546, 32'h0012_3456, 32'h0000_0100, 32'h0065_4321, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE invalid ask with nonzero price");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE invalid ask with nonzero price");

      // Invalid ask carries a nonzero ask quantity
      test_message = pack_message(TOB_UPDATE, 8'b0000_0001, 16'h0000, 32'h0000_0025, 16'h5678, 48'h5152_5354_5556, 32'h0012_3456, 32'h0000_0100, 32'h0000_0000, 32'h0000_0200);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE invalid ask with nonzero quantity");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE invalid ask with nonzero quantity");


      finish_test("invalid TOB_UPDATE variants");
    end
  endtask


  task automatic test_valid_symbol_status_boundaries;

    logic [255:0] test_message;

    begin
      $display("TEST: valid SYMBOL_STATUS boundaries");

      error_count = 0;
      reset_dut();

      // Lowest defined status: INVALID
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0030, 16'h1234, 48'h0102_0304_0506, 32'd0, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b0);
      check_decoded_message(SYMBOL_STATUS, 8'h00, 32'h0000_0030, 16'h1234, 48'h0102_0304_0506, 32'd0, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b0, "SYMBOL_STATUS value 0");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS value 0");

      // Highest defined status: TRADING
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0031, 16'h5678, 48'h1112_1314_1516, 32'd4, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b0, 1'b1);
      check_decoded_message(SYMBOL_STATUS, 8'h00, 32'h0000_0031, 16'h5678, 48'h1112_1314_1516, 32'd4, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b1, "SYMBOL_STATUS value 4");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS value 4");


      finish_test("valid SYMBOL_STATUS boundaries");
    end
  endtask


  task automatic test_invalid_symbol_status;

    logic [255:0] test_message;

    begin
      $display("TEST: invalid SYMBOL_STATUS");

      error_count = 0;
      reset_dut();

      // Reserved status value
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0040, 16'h1234, 48'h0102_0304_0506, 32'd5, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SYMBOL_STATUS value 5");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS value 5");

      // Nonzero flags
      test_message = pack_message(SYMBOL_STATUS, 8'h01, 16'h0000, 32'h0000_0041, 16'h1234, 48'h1112_1314_1516, 32'd4, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SYMBOL_STATUS nonzero flags");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS nonzero flags");


      // Zero symbol ID
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0042, 16'h0000, 48'h2122_2324_2526, 32'd4, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SYMBOL_STATUS zero symbol ID");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS zero symbol ID");


      // Nonzero payload_1
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0043, 16'h2345, 48'h3132_3334_3536, 32'd2, 32'h0000_0001, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SYMBOL_STATUS nonzero payload_1");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS nonzero payload_1");

      // Nonzero payload_2
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0044, 16'h3456, 48'h4142_4344_4546, 32'd2, 32'h0000_0000, 32'h0000_0001, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SYMBOL_STATUS nonzero payload_2");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS nonzero payload_2");

      // Nonzero payload_3
      test_message = pack_message(SYMBOL_STATUS, 8'h00, 16'h0000, 32'h0000_0045, 16'h4567, 48'h5152_5354_5556, 32'd2, 32'h0000_0000, 32'h0000_0000, 32'h0000_0001);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("SYMBOL_STATUS nonzero payload_3");
      drive_idle();
      check_no_output_pulses("after SYMBOL_STATUS nonzero payload_3");


      finish_test("invalid SYMBOL_STATUS");
    end
  endtask



  task automatic test_valid_order_intent_field_extraction;

    logic [255:0] test_message;

    begin
      $display("TEST: valid ORDER_INTENT field extraction");

      error_count = 0;
      reset_dut();

      // Valid BUY order intent
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h1234_5678, 16'h9ABC, 48'h1122_3344_5566, 32'h0000_0001, 32'hA1B2_C3D4, 32'h1020_3040, 32'hDEAD_BEEF);
      drive_message(test_message, 1'b1, 1'b1);
      check_decoded_message(ORDER_INTENT, 8'h00, 32'h1234_5678, 16'h9ABC, 48'h1122_3344_5566, 32'h0000_0001, 32'hA1B2_C3D4, 32'h1020_3040, 32'hDEAD_BEEF, 1'b1, 1'b1, "valid BUY ORDER_INTENT");
      drive_idle();
      check_no_output_pulses("after valid BUY ORDER_INTENT");


      finish_test("valid ORDER_INTENT field extraction");
    end
  endtask

  task automatic test_order_intent_risk_values_pass_through;

    logic [255:0] test_message;

    begin
      $display("TEST: ORDER_INTENT risk values pass through");

      error_count = 0;
      reset_dut();


      // UNKNOWN_INVALID side passes to the risk checker
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0050, 16'h1234, 48'h0102_0304_0506, 32'd0, 32'h0012_3456, 32'h0000_0100, 32'hA000_0001);
      drive_message(test_message, 1'b1, 1'b1);
      check_decoded_message(ORDER_INTENT, 8'h00, 32'h0000_0050, 16'h1234, 48'h0102_0304_0506, 32'd0, 32'h0012_3456, 32'h0000_0100, 32'hA000_0001, 1'b1, 1'b1, "ORDER_INTENT UNKNOWN_INVALID side");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT UNKNOWN_INVALID side");


      // Zero order price passes to the risk checker
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0051, 16'h2345, 48'h1112_1314_1516, 32'd1, 32'h0000_0000, 32'h0000_0200, 32'hA000_0002);
      drive_message(test_message, 1'b1, 1'b1);
      check_decoded_message(ORDER_INTENT, 8'h00, 32'h0000_0051, 16'h2345, 48'h1112_1314_1516, 32'd1, 32'h0000_0000, 32'h0000_0200, 32'hA000_0002, 1'b1, 1'b1, "ORDER_INTENT zero price");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT zero price");


      // Zero order quantity passes to the risk checker
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0052, 16'h3456, 48'h2122_2324_2526, 32'd2, 32'h0065_4321, 32'h0000_0000, 32'hA000_0003);
      drive_message(test_message, 1'b1, 1'b1);
      check_decoded_message(ORDER_INTENT, 8'h00, 32'h0000_0052, 16'h3456, 48'h2122_2324_2526, 32'd2, 32'h0065_4321, 32'h0000_0000, 32'hA000_0003, 1'b1, 1'b1, "ORDER_INTENT zero quantity");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT zero quantity");


      finish_test("ORDER_INTENT risk values pass through");
    end
  endtask


  task automatic test_order_intent_protocol_violations;

    logic [255:0] test_message;

    begin
      $display("TEST: ORDER_INTENT protocol violations");

      error_count = 0;
      reset_dut();


      // Nonzero flags
      test_message = pack_message(ORDER_INTENT, 8'h01, 16'h0000, 32'h0000_0060, 16'h1234, 48'h0102_0304_0506, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hB000_0001);
      drive_message(test_message, 1'b1, 1'b1);
      check_order_intent_protocol_violation(8'h01, 32'h0000_0060, 16'h1234, 48'h0102_0304_0506, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hB000_0001, 1'b1, 1'b1, "ORDER_INTENT nonzero flags");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT nonzero flags");

      // Nonzero common reserved field
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0001, 32'h0000_0061, 16'h2345, 48'h1112_1314_1516, 32'd1, 32'h0023_4567, 32'h0000_0200, 32'hB000_0002);
      drive_message(test_message, 1'b1, 1'b1);
      check_order_intent_protocol_violation(8'h00, 32'h0000_0061, 16'h2345, 48'h1112_1314_1516, 32'd1, 32'h0023_4567, 32'h0000_0200, 32'hB000_0002, 1'b1, 1'b1, "ORDER_INTENT nonzero reserved field");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT nonzero reserved field");

      // Zero symbol ID
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0062, 16'h0000, 48'h2122_2324_2526, 32'd2, 32'h0034_5678, 32'h0000_0300, 32'hB000_0003);
      drive_message(test_message, 1'b1, 1'b1);
      check_order_intent_protocol_violation(8'h00, 32'h0000_0062, 16'h0000, 48'h2122_2324_2526, 32'd2, 32'h0034_5678, 32'h0000_0300, 32'hB000_0003, 1'b1, 1'b1, "ORDER_INTENT zero symbol ID");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT zero symbol ID");

      // Reserved order-side value
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0063, 16'h3456, 48'h3132_3334_3536, 32'd3, 32'h0045_6789, 32'h0000_0400, 32'hB000_0004);
      drive_message(test_message, 1'b1, 1'b1);
      check_order_intent_protocol_violation(8'h00, 32'h0000_0063, 16'h3456, 48'h3132_3334_3536, 32'd3, 32'h0045_6789, 32'h0000_0400, 32'hB000_0004, 1'b1, 1'b1, "ORDER_INTENT reserved side value");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT reserved side value");

      // ORDER_INTENT is not the final message in the packet
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0064, 16'h4567, 48'h4142_4344_4546, 32'd1, 32'h0056_789A, 32'h0000_0500, 32'hB000_0005);
      drive_message(test_message, 1'b0, 1'b0);
      check_order_intent_protocol_violation(8'h00, 32'h0000_0064, 16'h4567, 48'h4142_4344_4546, 32'd1, 32'h0056_789A, 32'h0000_0500, 32'hB000_0005, 1'b0, 1'b0, "ORDER_INTENT without packet end");
      drive_idle();
      check_no_output_pulses("after ORDER_INTENT without packet end");


      finish_test("ORDER_INTENT protocol violations");
    end
  endtask
  task automatic test_valid_config_commands;
    begin
      $display("TEST: valid CONFIG_CONTROL commands");

      error_count = 0;
      reset_dut();


      // NOP
      run_valid_config_case(32'h0000_0070, 16'h0000, 48'h0102_0304_0506, CONFIG_NOP, 32'h0000_0000, 32'h0000_0000, 32'hC000_0001, "CONFIG_CONTROL NOP");

      // RESET_ALL
      run_valid_config_case(32'h0000_0071, 16'h0000, 48'h1112_1314_1516, CONFIG_RESET_ALL, 32'h0000_000F, 32'h0000_0000, 32'hC000_0002, "CONFIG_CONTROL RESET_ALL");

      // RESET_SYMBOL
      run_valid_config_case(32'h0000_0072, 16'h1234, 48'h2122_2324_2526, CONFIG_RESET_SYMBOL, 32'h0000_000F, 32'h0000_0000, 32'hC000_0003, "CONFIG_CONTROL RESET_SYMBOL");

      // SET_SYMBOL_ENABLED
      run_valid_config_case(32'h0000_0073, 16'h2345, 48'h3132_3334_3536, CONFIG_SET_SYMBOL_ENABLED, 32'h0000_0001, 32'h0000_0000, 32'hC000_0004, "CONFIG_CONTROL SET_SYMBOL_ENABLED");

      // SET_MAX_ORDER_QTY
      run_valid_config_case(32'h0000_0074, 16'h3456, 48'h4142_4344_4546, CONFIG_SET_MAX_ORDER_QTY, 32'h0001_0000, 32'h0000_0000, 32'hC000_0005, "CONFIG_CONTROL SET_MAX_ORDER_QTY");

      // SET_MAX_NOTIONAL
      run_valid_config_case(32'h0000_0075, 16'h4567, 48'h5152_5354_5556, CONFIG_SET_MAX_NOTIONAL, 32'h1122_3344, 32'h5566_7788, 32'hC000_0006, "CONFIG_CONTROL SET_MAX_NOTIONAL");

      // SET_PRICE_BAND_TICKS
      run_valid_config_case(32'h0000_0076, 16'h5678, 48'h6162_6364_6566, CONFIG_SET_PRICE_BAND_TICKS, 32'h0000_0020, 32'h0000_0000, 32'hC000_0007, "CONFIG_CONTROL SET_PRICE_BAND_TICKS");

      finish_test("valid CONFIG_CONTROL commands");
    end
  endtask


  task automatic test_invalid_config_commands;
    begin
      $display("TEST: invalid CONFIG_CONTROL commands");

      error_count = 0;
      reset_dut();


      // Unknown opcode
      run_invalid_config_case(32'h0000_0080, 16'h0000, 32'h0000_0008, 32'h0000_0000, 32'h0000_0000, "CONFIG_CONTROL unknown opcode");

      // NOP with nonzero symbol ID
      run_invalid_config_case(32'h0000_0081, 16'h1234, CONFIG_NOP, 32'h0000_0000, 32'h0000_0000, "CONFIG_CONTROL NOP nonzero symbol ID");

      // RESET_ALL with nonzero symbol ID
      run_invalid_config_case(32'h0000_0082, 16'h1234, CONFIG_RESET_ALL, 32'h0000_0001, 32'h0000_0000, "CONFIG_CONTROL RESET_ALL nonzero symbol ID");

      // RESET_ALL with reserved reset-mask bit 4
      run_invalid_config_case(32'h0000_0083, 16'h0000, CONFIG_RESET_ALL, 32'h0000_0010, 32'h0000_0000, "CONFIG_CONTROL RESET_ALL reserved mask bit");

      // RESET_SYMBOL with zero symbol ID
      run_invalid_config_case(32'h0000_0084, 16'h0000, CONFIG_RESET_SYMBOL, 32'h0000_0001, 32'h0000_0000, "CONFIG_CONTROL RESET_SYMBOL zero symbol ID");

      // SET_SYMBOL_ENABLED with value greater than 1
      run_invalid_config_case(32'h0000_0085, 16'h2345, CONFIG_SET_SYMBOL_ENABLED, 32'h0000_0002, 32'h0000_0000, "CONFIG_CONTROL SET_SYMBOL_ENABLED invalid value");

      // SET_MAX_ORDER_QTY with nonzero unused value_1
      run_invalid_config_case(32'h0000_0086, 16'h3456, CONFIG_SET_MAX_ORDER_QTY, 32'h0000_1000, 32'h0000_0001, "CONFIG_CONTROL SET_MAX_ORDER_QTY nonzero value_1");

      // SET_MAX_NOTIONAL with zero symbol ID
      run_invalid_config_case(32'h0000_0087, 16'h0000, CONFIG_SET_MAX_NOTIONAL, 32'h1122_3344, 32'h5566_7788, "CONFIG_CONTROL SET_MAX_NOTIONAL zero symbol ID");

      // SET_PRICE_BAND_TICKS with nonzero unused value_1
      run_invalid_config_case(32'h0000_0088, 16'h4567, CONFIG_SET_PRICE_BAND_TICKS, 32'h0000_0020, 32'h0000_0001, "CONFIG_CONTROL SET_PRICE_BAND_TICKS nonzero value_1");

      // RESET_SYMBOL with reserved reset-mask bit 4
      run_invalid_config_case(32'h0000_0089, 16'h1234, CONFIG_RESET_SYMBOL, 32'h0000_0010, 32'h0000_0000, "CONFIG_CONTROL RESET_SYMBOL reserved mask bit");

      // Opcode 7 is reserved
      run_invalid_config_case(32'h0000_008A, 16'h0000, 32'h0000_0007, 32'h0000_0000, 32'h0000_0000, "CONFIG_CONTROL reserved opcode 7");

      finish_test("invalid CONFIG_CONTROL commands");
    end
  endtask

  task automatic test_unknown_message_type;

    logic [255:0] test_message;

    begin
      $display("TEST: unknown message type");
      error_count = 0;
      reset_dut();

      // Reserved message type
      test_message = pack_message(8'h80, 8'h00, 16'h0000, 32'h1234_5678, 16'h1234, 48'h1122_3344_5566, 32'hA1A2_A3A4, 32'hB1B2_B3B4, 32'hC1C2_C3C4, 32'hD1D2_D3D4);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("unknown message type");
      drive_idle();
      check_no_output_pulses("after unknown message type");

      finish_test("unknown message type");
    end
  endtask

  task automatic test_nonzero_common_reserved_field;

    logic [255:0] test_message;

    begin
      $display("TEST: nonzero common reserved field");
      error_count = 0;
      reset_dut();

      // TOB_UPDATE with nonzero common reserved field
      test_message = pack_message(TOB_UPDATE, 8'b0000_0011, 16'h00A5, 32'h1234_5678, 16'h2345, 48'h1122_3344_5566, 32'h0012_3456, 32'h0000_0100, 32'h0065_4321, 32'h0000_0200);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("TOB_UPDATE nonzero common reserved field");
      drive_idle();
      check_no_output_pulses("after TOB_UPDATE nonzero common reserved field");

      finish_test("nonzero common reserved field");
    end
  endtask


  task automatic test_upstream_abort_priority;

    logic [255:0] test_message;

    begin
      $display("TEST: upstream abort priority");
      error_count = 0;
      reset_dut();

      // Abort and valid message asserted together
      test_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h1234_5678, 16'h2345, 48'h1122_3344_5566, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hDEAD_BEEF);
      drive_abort(test_message, 1'b1, 1'b1, 1'b1);
      check_condition(decoded_valid === 1'b0, "upstream abort: decoded_valid unexpectedly asserted");
      check_condition(decoded_packet_start === 1'b0, "upstream abort: decoded_packet_start unexpectedly asserted");
      check_condition(decoded_packet_end === 1'b0, "upstream abort: decoded_packet_end unexpectedly asserted");
      check_condition(decoded_packet_abort === 1'b1, "upstream abort: decoded_packet_abort was not asserted");
      check_condition(protocol_error === 1'b0, "upstream abort: protocol_error unexpectedly asserted");
      drive_idle();
      check_no_output_pulses("after upstream abort");

      finish_test("upstream abort priority");
    end
  endtask


  task automatic test_back_to_back_messages;

    logic [255:0] tob_message;
    logic [255:0] order_message;

    begin
      $display("TEST: back-to-back messages");
      error_count = 0;
      reset_dut();

      // First packet message: TOB_UPDATE
      tob_message = pack_message(TOB_UPDATE, 8'b0000_0011, 16'h0000, 32'h0000_0090, 16'h2345, 48'h0102_0304_0506, 32'h0012_3456, 32'h0000_0100, 32'h0065_4321, 32'h0000_0200);
      drive_message(tob_message, 1'b1, 1'b0);
      check_decoded_message(TOB_UPDATE, 8'b0000_0011, 32'h0000_0090, 16'h2345, 48'h0102_0304_0506, 32'h0012_3456, 32'h0000_0100, 32'h0065_4321, 32'h0000_0200, 1'b1, 1'b0, "back-to-back TOB_UPDATE");

      // Immediately following packet message: ORDER_INTENT
      order_message = pack_message(ORDER_INTENT, 8'h00, 16'h0000, 32'h0000_0091, 16'h2345, 48'h1112_1314_1516, 32'd1, 32'h0012_3460, 32'h0000_0010, 32'hDEAD_BEEF);
      drive_message(order_message, 1'b0, 1'b1);
      check_decoded_message(ORDER_INTENT, 8'h00, 32'h0000_0091, 16'h2345, 48'h1112_1314_1516, 32'd1, 32'h0012_3460, 32'h0000_0010, 32'hDEAD_BEEF, 1'b0, 1'b1, "back-to-back ORDER_INTENT");

      // Outputs return to idle after the packet
      drive_idle();
      check_no_output_pulses("after back-to-back messages");

      finish_test("back-to-back messages");
    end
  endtask


  task automatic test_output_pulses_clear;

    logic [255:0] test_message;

    begin
      $display("TEST: output pulses clear");

      error_count = 0;
      reset_dut();

      // Valid-message pulses clear
      test_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h0000_00A0, 16'h0000, 48'h0102_0304_0506, 32'd1, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_decoded_message(SESSION_STATUS, 8'h00, 32'h0000_00A0, 16'h0000, 48'h0102_0304_0506, 32'd1, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b1, "valid-message pulse cycle");
      drive_idle();
      check_no_output_pulses("cycle after valid message");

      // General protocol-error pulses clear
      test_message = pack_message(8'h80, 8'h00, 16'h0000, 32'h0000_00A1, 16'h1234, 48'h1112_1314_1516, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(test_message, 1'b1, 1'b1);
      check_protocol_rejection("protocol-error pulse cycle");
      drive_idle();
      check_no_output_pulses("cycle after protocol error");

      // Malformed ORDER_INTENT pulses clear
      test_message = pack_message(ORDER_INTENT, 8'h01, 16'h0000, 32'h0000_00A2, 16'h2345, 48'h2122_2324_2526, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hDEAD_BEEF);
      drive_message(test_message, 1'b1, 1'b1);
      check_order_intent_protocol_violation(8'h01, 32'h0000_00A2, 16'h2345, 48'h2122_2324_2526, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hDEAD_BEEF, 1'b1, 1'b1, "ORDER_INTENT violation pulse cycle");
      drive_idle();
      check_no_output_pulses("cycle after ORDER_INTENT violation");

      finish_test("output pulses clear");
    end
  endtask


  task automatic test_recovery_without_reset;

    logic [255:0] error_message;
    logic [255:0] valid_message;

    begin
      $display("TEST: recovery without reset");

      error_count = 0;
      reset_dut();

      // Unknown type followed immediately by valid SESSION_STATUS
      error_message = pack_message(8'h80, 8'h00, 16'h0000, 32'h0000_00B0, 16'h1234, 48'h0102_0304_0506, 32'h1111_1111, 32'h2222_2222, 32'h3333_3333, 32'h4444_4444);
      drive_message(error_message, 1'b1, 1'b1);
      check_protocol_rejection("unknown type before recovery");
      valid_message = pack_message(SESSION_STATUS, 8'h00, 16'h0000, 32'h0000_00B1, 16'h0000, 48'h1112_1314_1516, 32'd4, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
      drive_message(valid_message, 1'b1, 1'b1);
      check_decoded_message(SESSION_STATUS, 8'h00, 32'h0000_00B1, 16'h0000, 48'h1112_1314_1516, 32'd4, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b1, "SESSION_STATUS after unknown type");

      // Malformed ORDER_INTENT followed immediately by valid TOB_UPDATE
      error_message = pack_message(ORDER_INTENT, 8'h01, 16'h0000, 32'h0000_00B2, 16'h2345, 48'h2122_2324_2526, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hDEAD_BEEF);
      drive_message(error_message, 1'b1, 1'b1);
      check_order_intent_protocol_violation(8'h01, 32'h0000_00B2, 16'h2345, 48'h2122_2324_2526, 32'd1, 32'h0012_3456, 32'h0000_0100, 32'hDEAD_BEEF, 1'b1, 1'b1, "malformed ORDER_INTENT before recovery");
      valid_message = pack_message(TOB_UPDATE, 8'b0000_0011, 16'h0000, 32'h0000_00B3, 16'h3456, 48'h3132_3334_3536, 32'h0011_2233, 32'h0000_0200, 32'h0044_5566, 32'h0000_0300);
      drive_message(valid_message, 1'b1, 1'b1);
      check_decoded_message(TOB_UPDATE, 8'b0000_0011, 32'h0000_00B3, 16'h3456, 48'h3132_3334_3536, 32'h0011_2233, 32'h0000_0200, 32'h0044_5566, 32'h0000_0300, 1'b1, 1'b1, "TOB_UPDATE after malformed ORDER_INTENT");

      // Outputs return to idle after recovery
      drive_idle();
      check_no_output_pulses("after recovery sequences");

      finish_test("recovery without reset");
    end
  endtask


  // ==========================================================================
  // Test sequence
  // =========================================================================

  initial begin

    test_reset_and_idle();
    test_valid_session_status_boundaries();
    test_invalid_session_status();
    test_valid_tob_variants();
    test_invalid_tob_variants();
    test_valid_symbol_status_boundaries();
    test_invalid_symbol_status();
    test_valid_order_intent_field_extraction();
    test_order_intent_risk_values_pass_through();
    test_order_intent_protocol_violations();
    test_valid_config_commands();
    test_invalid_config_commands();
    test_unknown_message_type();
    test_nonzero_common_reserved_field();
    test_upstream_abort_priority();
    test_back_to_back_messages();
    test_output_pulses_clear();
    test_recovery_without_reset();

    $display("PASS: ALL TESTS PASSED");
    $finish;
  end

endmodule
