`timescale 1ns / 1ps

module tb_order_decision_frame_generator;

  localparam time CLK_PERIOD = 6.206ns;

  localparam logic [47:0] SOURCE_MAC_ADDRESS = 48'h02_00_00_00_00_01;
  localparam logic [47:0] DESTINATION_MAC_ADDRESS = 48'h02_00_00_00_00_02;
  localparam logic [31:0] SOURCE_IP_ADDRESS = 32'hC0A8_0102;
  localparam logic [31:0] DESTINATION_IP_ADDRESS = 32'hC0A8_0101;
  localparam logic [15:0] SOURCE_UDP_PORT = 16'd5000;
  localparam logic [15:0] DESTINATION_UDP_PORT = 16'd5001;

  localparam logic [31:0] TEST_SEQUENCE_NUMBER = 32'h0102_0304;
  localparam logic [15:0] TEST_SYMBOL_ID = 16'h1122;
  localparam logic [31:0] TEST_INTENT_ID = 32'hA1A2_A3A4;
  localparam logic [31:0] TEST_DECISION = 32'd2;
  localparam logic [31:0] TEST_REJECT_REASON = 32'h0000_000B;

  localparam logic [31:0] CRC32_POLY_REFLECTED = 32'hEDB8_8320;

  logic clk;
  logic rst;

  logic tx_response_start_valid;
  logic tx_response_start_ready;

  logic tx_decision_valid;
  logic tx_decision_ready;
  logic [31:0] tx_decision_sequence_number;
  logic [15:0] tx_decision_symbol_id;
  logic [31:0] tx_decision_intent_id;
  logic [31:0] tx_decision;
  logic [31:0] tx_reject_reason;
  logic tx_source_frame_ok;

  logic frame_start_ready;

  logic [63:0] frame_data;
  logic [7:0] frame_keep;
  logic frame_start;
  logic frame_end;
  logic frame_valid;

  logic [7:0] expected_frame_bytes[0:84];


  order_decision_frame_generator #(
      .SOURCE_MAC_ADDRESS(SOURCE_MAC_ADDRESS),
      .DESTINATION_MAC_ADDRESS(DESTINATION_MAC_ADDRESS),
      .SOURCE_IP_ADDRESS(SOURCE_IP_ADDRESS),
      .DESTINATION_IP_ADDRESS(DESTINATION_IP_ADDRESS),
      .SOURCE_UDP_PORT(SOURCE_UDP_PORT),
      .DESTINATION_UDP_PORT(DESTINATION_UDP_PORT)
  ) dut (
      .clk(clk),
      .rst(rst),

      .tx_response_start_valid(tx_response_start_valid),
      .tx_response_start_ready(tx_response_start_ready),

      .tx_decision_valid(tx_decision_valid),
      .tx_decision_ready(tx_decision_ready),
      .tx_decision_sequence_number(tx_decision_sequence_number),
      .tx_decision_symbol_id(tx_decision_symbol_id),
      .tx_decision_intent_id(tx_decision_intent_id),
      .tx_decision(tx_decision),
      .tx_reject_reason(tx_reject_reason),
      .tx_source_frame_ok(tx_source_frame_ok),

      .frame_start_ready(frame_start_ready),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid)
  );


  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end


  function automatic logic [31:0] reference_crc32_update_byte(input logic [31:0] crc_in, input logic [7:0] data_byte);
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

      reference_crc32_update_byte = crc;
    end
  endfunction


  task automatic initialize_inputs;
    begin
      rst = 1'b1;

      tx_response_start_valid = 1'b0;

      tx_decision_valid = 1'b0;
      tx_decision_sequence_number = '0;
      tx_decision_symbol_id = '0;
      tx_decision_intent_id = '0;
      tx_decision = '0;
      tx_reject_reason = '0;
      tx_source_frame_ok = 1'b0;

      frame_start_ready = 1'b0;
    end
  endtask


  task automatic apply_reset;
    begin
      @(negedge clk);

      rst = 1'b1;
      tx_response_start_valid = 1'b0;
      tx_decision_valid = 1'b0;
      frame_start_ready = 1'b0;

      repeat (3) @(posedge clk);

      if (frame_valid !== 1'b0) begin
        $fatal(1, "reset: frame_valid is asserted");
      end

      if (tx_response_start_ready !== 1'b0) begin
        $fatal(1, "reset: START ready is asserted");
      end

      if (tx_decision_ready !== 1'b0) begin
        $fatal(1, "reset: DECISION ready is asserted");
      end

      @(negedge clk);
      rst = 1'b0;
    end
  endtask


  task automatic write_u16(input int unsigned byte_offset, input logic [15:0] value);
    begin
      expected_frame_bytes[byte_offset] = value[15:8];
      expected_frame_bytes[byte_offset+1] = value[7:0];
    end
  endtask


  task automatic write_u32(input int unsigned byte_offset, input logic [31:0] value);
    begin
      expected_frame_bytes[byte_offset] = value[31:24];
      expected_frame_bytes[byte_offset+1] = value[23:16];
      expected_frame_bytes[byte_offset+2] = value[15:8];
      expected_frame_bytes[byte_offset+3] = value[7:0];
    end
  endtask


  task automatic write_u48(input int unsigned byte_offset, input logic [47:0] value);
    begin
      expected_frame_bytes[byte_offset] = value[47:40];
      expected_frame_bytes[byte_offset+1] = value[39:32];
      expected_frame_bytes[byte_offset+2] = value[31:24];
      expected_frame_bytes[byte_offset+3] = value[23:16];
      expected_frame_bytes[byte_offset+4] = value[15:8];
      expected_frame_bytes[byte_offset+5] = value[7:0];
    end
  endtask


  task automatic build_expected_frame(input logic [31:0] sequence_number, input logic [15:0] symbol_id, input logic [31:0] intent_id, input logic [31:0] decision_value, input logic [31:0] reject_reason, input logic source_frame_ok);
    logic [31:0] crc;
    logic [31:0] response_fcs;

    begin
      for (int i = 0; i < 85; i++) begin
        expected_frame_bytes[i] = 8'h00;
      end

      for (int i = 0; i < 6; i++) begin
        expected_frame_bytes[i] = 8'h55;
      end

      expected_frame_bytes[6] = 8'hD5;

      write_u48(7, DESTINATION_MAC_ADDRESS);
      write_u48(13, SOURCE_MAC_ADDRESS);
      write_u16(19, 16'h0800);

      expected_frame_bytes[21] = 8'h45;
      expected_frame_bytes[22] = 8'h00;
      write_u16(23, 16'd60);
      write_u16(25, 16'h0000);
      write_u16(27, 16'h4000);
      expected_frame_bytes[29] = 8'h40;
      expected_frame_bytes[30] = 8'h11;
      write_u16(31, 16'hB75D);
      write_u32(33, SOURCE_IP_ADDRESS);
      write_u32(37, DESTINATION_IP_ADDRESS);

      write_u16(41, SOURCE_UDP_PORT);
      write_u16(43, DESTINATION_UDP_PORT);
      write_u16(45, 16'd40);
      write_u16(47, 16'h0000);

      expected_frame_bytes[49] = 8'h81;
      write_u32(53, sequence_number);
      write_u16(57, symbol_id);
      write_u32(65, decision_value);
      write_u32(69, reject_reason);
      write_u32(77, intent_id);

      crc = 32'hFFFF_FFFF;

      for (int i = 7; i <= 80; i++) begin
        crc = reference_crc32_update_byte(crc, expected_frame_bytes[i]);
      end

      response_fcs = ~crc;

      if (!source_frame_ok) begin
        response_fcs ^= 32'h0000_0001;
      end

      expected_frame_bytes[81] = response_fcs[7:0];
      expected_frame_bytes[82] = response_fcs[15:8];
      expected_frame_bytes[83] = response_fcs[23:16];
      expected_frame_bytes[84] = response_fcs[31:24];
    end
  endtask


  task automatic check_no_frame_output(input string label);
    begin
      if (frame_valid !== 1'b0) $fatal(1, "%s: unexpected frame_valid", label);
      if (frame_start !== 1'b0) $fatal(1, "%s: unexpected frame_start", label);
      if (frame_end !== 1'b0) $fatal(1, "%s: unexpected frame_end", label);
      if (tx_decision_ready !== 1'b0) $fatal(1, "%s: unexpected DECISION ready", label);
    end
  endtask


  task automatic check_frame_beat(input int unsigned beat_index, input string label);
    logic [7:0] expected_keep;
    int unsigned first_byte;

    begin
      expected_keep = (beat_index == 10) ? 8'h1F : 8'hFF;
      first_byte = beat_index * 8;

      if (frame_valid !== 1'b1) $fatal(1, "%s: frame_valid is not asserted on beat %0d", label, beat_index);
      if (frame_start !== (beat_index == 0)) $fatal(1, "%s: incorrect frame_start on beat %0d", label, beat_index);
      if (frame_end !== (beat_index == 10)) $fatal(1, "%s: incorrect frame_end on beat %0d", label, beat_index);
      if (frame_keep !== expected_keep) $fatal(1, "%s: frame_keep mismatch on beat %0d", label, beat_index);
      if (tx_response_start_ready !== (beat_index == 0)) $fatal(1, "%s: incorrect START ready on beat %0d", label, beat_index);
      if (tx_decision_ready !== (beat_index == 10)) $fatal(1, "%s: incorrect DECISION ready on beat %0d", label, beat_index);

      for (int lane = 0; lane < 8; lane++) begin
        if (expected_keep[lane]) begin
          if (frame_data[lane*8+:8] !== expected_frame_bytes[first_byte+lane]) begin
            $fatal(1, "%s: byte %0d expected %02h, received %02h", label, first_byte + lane, expected_frame_bytes[first_byte+lane], frame_data[lane*8+:8]);
          end
        end
        else if (frame_data[lane*8+:8] !== 8'h00) begin
          $fatal(1, "%s: invalid lane %0d is not zero", label, lane);
        end
      end
    end
  endtask


  task automatic run_response(input logic [31:0] sequence_number, input logic [15:0] symbol_id, input logic [31:0] intent_id, input logic [31:0] decision_value, input logic [31:0] reject_reason, input logic source_frame_ok, input int unsigned start_stall_cycles, input string label);
    begin
      build_expected_frame(sequence_number, symbol_id, intent_id, decision_value, reject_reason, source_frame_ok);

      @(negedge clk);
      frame_start_ready = (start_stall_cycles == 0);
      tx_response_start_valid = 1'b1;

      for (int i = 0; i < start_stall_cycles; i++) begin
        @(posedge clk);

        if (tx_response_start_ready !== 1'b0) $fatal(1, "%s: START ready asserted during backpressure", label);
        check_no_frame_output(label);
        @(negedge clk);
      end

      frame_start_ready = 1'b1;

      for (int beat = 0; beat <= 10; beat++) begin
        @(posedge clk);
        check_frame_beat(beat, label);

        @(negedge clk);

        if (beat == 0) begin
          tx_response_start_valid = 1'b0;
        end

        if (beat == 2) begin
          tx_decision_sequence_number = sequence_number;
          tx_decision_symbol_id = symbol_id;
          tx_decision_intent_id = intent_id;
          tx_decision = decision_value;
          tx_reject_reason = reject_reason;
          tx_source_frame_ok = source_frame_ok;
          tx_decision_valid = 1'b1;
        end
      end

      tx_decision_valid = 1'b0;

      @(posedge clk);
      #1ps;

      check_no_frame_output({label, " after completion"});
      if (tx_response_start_ready !== 1'b1) $fatal(1, "%s: generator did not return to idle", label);

    end
  endtask


  task automatic test_reset_state;
    begin
      // Purpose: verify reset and idle output state.
      // Input: synchronous reset, followed by an idle ready PCS.
      // Expected: no frame or DECISION handshake; START can be accepted.

      $display("TEST: reset state");

      apply_reset();

      @(negedge clk);
      frame_start_ready = 1'b1;
      #1ps;

      check_no_frame_output("idle after reset");
      if (tx_response_start_ready !== 1'b1) $fatal(1, "idle after reset: START is not ready");

      $display("PASS: reset state");
    end
  endtask


  task automatic test_valid_response;
    begin
      // Purpose: verify start backpressure and one correct response frame.
      // Input: a REJECT decision from a source frame that passed integrity.
      // Expected: exact 85-byte frame and correct Ethernet FCS.

      $display("TEST: valid ORDER_DECISION response");

      run_response(TEST_SEQUENCE_NUMBER, TEST_SYMBOL_ID, TEST_INTENT_ID, TEST_DECISION, TEST_REJECT_REASON, 1'b1, 3, "valid response");

      if ({expected_frame_bytes[84], expected_frame_bytes[83], expected_frame_bytes[82], expected_frame_bytes[81]} !== 32'h9CF9_0A72) begin
        $fatal(1, "valid response: unexpected reference FCS");
      end

      $display("PASS: valid ORDER_DECISION response");
    end
  endtask


  task automatic test_stomped_response_fcs;
    begin
      // Purpose: verify fail-closed handling of a failed source frame.
      // Input: the same decision with source_frame_ok cleared.
      // Expected: identical response through byte 80 and a bad FCS.

      $display("TEST: stomped response FCS");

      run_response(TEST_SEQUENCE_NUMBER, TEST_SYMBOL_ID, TEST_INTENT_ID, TEST_DECISION, TEST_REJECT_REASON, 1'b0, 0, "stomped response");

      if ({expected_frame_bytes[84], expected_frame_bytes[83], expected_frame_bytes[82], expected_frame_bytes[81]} !== 32'h9CF9_0A73) begin
        $fatal(1, "stomped response: FCS was not poisoned as expected");
      end

      $display("PASS: stomped response FCS");
    end
  endtask


  initial begin
    initialize_inputs();

    test_reset_state();
    test_valid_response();
    test_stomped_response_fcs();

    $display("PASS: order decision frame generator tests");
    $finish;
  end

endmodule
