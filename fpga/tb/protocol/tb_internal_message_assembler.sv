`timescale 1ns / 1ps

module tb_internal_message_assembler;

  // ---------------------------------------------------------------------------
  // DUT interface
  // ---------------------------------------------------------------------------

  logic clk;
  logic rst;

  logic [63:0] udp_payload_data;
  logic udp_payload_start;
  logic udp_payload_end;
  logic udp_payload_valid;
  logic udp_packet_abort;

  logic [255:0] message_data;
  logic message_valid;
  logic message_packet_start;
  logic message_packet_end;
  logic message_packet_abort;
  logic assembler_error;

  int unsigned error_count;



  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------

  internal_message_assembler dut (
      .clk(clk),
      .rst(rst),
      .udp_payload_data(udp_payload_data),
      .udp_payload_start(udp_payload_start),
      .udp_payload_end(udp_payload_end),
      .udp_payload_valid(udp_payload_valid),
      .udp_packet_abort(udp_packet_abort),
      .message_data(message_data),
      .message_valid(message_valid),
      .message_packet_start(message_packet_start),
      .message_packet_end(message_packet_end),
      .message_packet_abort(message_packet_abort),
      .assembler_error(assembler_error)
  );


  // ---------------------------------------------------------------------------
  // Clock
  // ---------------------------------------------------------------------------

  initial clk = 1'b0;
  always #5ns clk = ~clk;

  // ---------------------------------------------------------------------------
  // Low-level driver
  // ---------------------------------------------------------------------------

  task automatic drive_idle;
    begin
      @(negedge clk);
      udp_payload_data = '0;
      udp_payload_start = 1'b0;
      udp_payload_end = 1'b0;
      udp_payload_valid = 1'b0;
      udp_packet_abort = 1'b0;
    end
  endtask


  task automatic drive_word(input logic [63:0] data, input logic start, input logic last);
    begin
      @(negedge clk);
      udp_payload_data = data;
      udp_payload_start = start;
      udp_payload_end = last;
      udp_payload_valid = 1'b1;
      udp_packet_abort = 1'b0;
    end
  endtask


  task automatic drive_abort;
    begin
      @(negedge clk);
      udp_payload_data = '0;
      udp_payload_start = 1'b0;
      udp_payload_end = 1'b0;
      udp_payload_valid = 1'b0;
      udp_packet_abort = 1'b1;
    end
  endtask

  task automatic reset_dut;
    begin
      rst = 1'b1;
      udp_payload_data = '0;
      udp_payload_start = 1'b0;
      udp_payload_end = 1'b0;
      udp_payload_valid = 1'b0;
      udp_packet_abort = 1'b0;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Output checker
  // ---------------------------------------------------------------------------


  task automatic check_condition(input logic condition, input string failure_message);
    begin
      if (!condition) begin
        $error("%s", failure_message);
        error_count++;
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Test cases
  // ---------------------------------------------------------------------------

  task automatic test_single_message_packet;
    localparam logic [63:0] WORD_0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] WORD_1 = 64'h0F0E_0D0C_0B0A_0908;
    localparam logic [63:0] WORD_2 = 64'h1716_1514_1312_1110;
    localparam logic [63:0] WORD_3 = 64'h1F1E_1D1C_1B1A_1918;

    logic [255:0] expected_message;

    begin
      $display("TEST: single-message packet");
      reset_dut();
      error_count = 0;
      expected_message = {WORD_3, WORD_2, WORD_1, WORD_0};

      drive_word(WORD_0, 1'b1, 1'b0);
      drive_word(WORD_1, 1'b0, 1'b0);
      drive_word(WORD_2, 1'b0, 1'b0);
      drive_word(WORD_3, 1'b0, 1'b1);

      // Deassert inputs after the DUT samples word 3.
      drive_idle();

      check_condition(message_valid === 1'b1, "Expected message_valid");
      check_condition(message_data === expected_message, "Assembled message_data is incorrect");
      check_condition(message_packet_start === 1'b1, "Expected message_packet_start");
      check_condition(message_packet_end === 1'b1, "Expected message_packet_end");
      check_condition(message_packet_abort === 1'b0, "Unexpected message_packet_abort");
      check_condition(assembler_error === 1'b0, "Unexpected assembler_error");

      drive_idle();

      check_condition(message_valid === 1'b0, "message_valid must be a one-cycle pulse");
      check_condition(message_packet_start === 1'b0, "message_packet_start must be a one-cycle pulse");
      check_condition(message_packet_end === 1'b0, "message_packet_end must be a one-cycle pulse");

      if (error_count == 0) begin
        $display("PASS: single-message packet");
      end
      else begin
        $fatal(1, "FAIL: single-message packet, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_two_messages_one_packet;
    localparam logic [63:0] A0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] A1 = 64'h0F0E_0D0C_0B0A_0908;
    localparam logic [63:0] A2 = 64'h1716_1514_1312_1110;
    localparam logic [63:0] A3 = 64'h1F1E_1D1C_1B1A_1918;

    localparam logic [63:0] B0 = 64'h2726_2524_2322_2120;
    localparam logic [63:0] B1 = 64'h2F2E_2D2C_2B2A_2928;
    localparam logic [63:0] B2 = 64'h3736_3534_3332_3130;
    localparam logic [63:0] B3 = 64'h3F3E_3D3C_3B3A_3938;

    logic [255:0] expected_a;
    logic [255:0] expected_b;

    begin
      $display("TEST: two messages in one packet");
      reset_dut();

      error_count = 0;

      expected_a = {A3, A2, A1, A0};
      expected_b = {B3, B2, B1, B0};

      drive_word(A0, 1'b1, 1'b0);
      drive_word(A1, 1'b0, 1'b0);
      drive_word(A2, 1'b0, 1'b0);
      drive_word(A3, 1'b0, 1'b0);

      // Apply B0 after A3 has been sampled.
      // The output from message A is visible here.
      drive_word(B0, 1'b0, 1'b0);
      check_condition(message_valid === 1'b1, "Expected message_valid for message A");
      check_condition(message_data === expected_a, "Message A data is incorrect");
      check_condition(message_packet_start === 1'b1, "Message A should be the packet start");
      check_condition(message_packet_end === 1'b0, "Message A should not be the packet end");
      check_condition(message_packet_abort === 1'b0, "Unexpected abort while emitting message A");
      check_condition(assembler_error === 1'b0, "Unexpected assembler error while emitting message A");

      drive_word(B1, 1'b0, 1'b0);
      check_condition(message_valid === 1'b0, "message_valid should deassert between messages");

      drive_word(B2, 1'b0, 1'b0);
      drive_word(B3, 1'b0, 1'b1);

      drive_idle();

      check_condition(message_valid === 1'b1, "Expected message_valid for message B");
      check_condition(message_data === expected_b, "Message B data is incorrect");
      check_condition(message_packet_start === 1'b0, "Message B should not be the packet start");
      check_condition(message_packet_end === 1'b1, "Message B should be the packet end");
      check_condition(message_packet_abort === 1'b0, "Unexpected abort while emitting message B");
      check_condition(assembler_error === 1'b0, "Unexpected assembler error while emitting message B");

      drive_idle();

      check_condition(message_valid === 1'b0, "message_valid must be a one-cycle pulse");

      if (error_count == 0) begin
        $display("PASS: two messages in one packet");
      end
      else begin
        $fatal(1, "FAIL: two messages in one packet, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_back_to_back_packets;
    localparam logic [63:0] A0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] A1 = 64'h0F0E_0D0C_0B0A_0908;
    localparam logic [63:0] A2 = 64'h1716_1514_1312_1110;
    localparam logic [63:0] A3 = 64'h1F1E_1D1C_1B1A_1918;

    localparam logic [63:0] B0 = 64'hA7A6_A5A4_A3A2_A1A0;
    localparam logic [63:0] B1 = 64'hAFAE_ADAC_ABAA_A9A8;
    localparam logic [63:0] B2 = 64'hB7B6_B5B4_B3B2_B1B0;
    localparam logic [63:0] B3 = 64'hBFBE_BDBC_BBBA_B9B8;

    logic [255:0] expected_a;
    logic [255:0] expected_b;

    begin
      $display("TEST: back-to-back packets");
      reset_dut();

      error_count = 0;

      expected_a = {A3, A2, A1, A0};
      expected_b = {B3, B2, B1, B0};

      // Packet A
      drive_word(A0, 1'b1, 1'b0);
      drive_word(A1, 1'b0, 1'b0);
      drive_word(A2, 1'b0, 1'b0);
      drive_word(A3, 1'b0, 1'b1);

      // Packet B starts on the immediately following cycle.
      drive_word(B0, 1'b1, 1'b0);

      check_condition(message_valid === 1'b1, "Expected message_valid for packet A");
      check_condition(message_data === expected_a, "Packet A message data is incorrect");
      check_condition(message_packet_start === 1'b1, "Packet A should assert message_packet_start");
      check_condition(message_packet_end === 1'b1, "Packet A should assert message_packet_end");
      check_condition(assembler_error === 1'b0, "Unexpected error between back-to-back packets");
      check_condition(message_packet_abort === 1'b0, "Unexpected abort between back-to-back packets");

      drive_word(B1, 1'b0, 1'b0);
      drive_word(B2, 1'b0, 1'b0);
      drive_word(B3, 1'b0, 1'b1);

      drive_idle();

      check_condition(message_valid === 1'b1, "Expected message_valid for packet B");
      check_condition(message_data === expected_b, "Packet B message data is incorrect");
      check_condition(message_packet_start === 1'b1, "Packet B should assert message_packet_start");
      check_condition(message_packet_end === 1'b1, "Packet B should assert message_packet_end");
      check_condition(assembler_error === 1'b0, "Unexpected assembler error for packet B");
      check_condition(message_packet_abort === 1'b0, "Unexpected packet abort for packet B");

      drive_idle();
      check_condition(message_valid === 1'b0, "message_valid must be a one-cycle pulse");

      if (error_count == 0) begin
        $display("PASS: back-to-back packets");
      end
      else begin
        $fatal(1, "FAIL: back-to-back packets, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_idle_gaps_between_words;
    localparam logic [63:0] W0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] W1 = 64'h0F0E_0D0C_0B0A_0908;
    localparam logic [63:0] W2 = 64'h1716_1514_1312_1110;
    localparam logic [63:0] W3 = 64'h1F1E_1D1C_1B1A_1918;

    logic [255:0] expected_message;

    begin
      $display("TEST: idle gaps between words");
      reset_dut();

      error_count = 0;
      expected_message = {W3, W2, W1, W0};

      drive_word(W0, 1'b1, 1'b0);
      drive_idle();
      check_condition(message_valid === 1'b0, "Unexpected message_valid after word 0");

      drive_idle();
      check_condition(message_valid === 1'b0, "Unexpected message_valid during idle gap");

      drive_word(W1, 1'b0, 1'b0);
      drive_idle();
      check_condition(message_valid === 1'b0, "Unexpected message_valid after word 1");

      drive_word(W2, 1'b0, 1'b0);
      drive_idle();
      check_condition(message_valid === 1'b0, "Unexpected message_valid after word 2");

      drive_idle();
      drive_word(W3, 1'b0, 1'b1);
      drive_idle();

      check_condition(message_valid === 1'b1, "Expected message_valid after word 3");
      check_condition(message_data === expected_message, "Message data is incorrect after idle gaps");
      check_condition(message_packet_start === 1'b1, "Expected message_packet_start");
      check_condition(message_packet_end === 1'b1, "Expected message_packet_end");
      check_condition(message_packet_abort === 1'b0, "Unexpected message_packet_abort");
      check_condition(assembler_error === 1'b0, "Unexpected assembler_error");

      drive_idle();
      check_condition(message_valid === 1'b0, "message_valid must be a one-cycle pulse");

      if (error_count == 0) begin
        $display("PASS: idle gaps between words");
      end
      else begin
        $fatal(1, "FAIL: idle gaps between words, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_abort_during_partial_message;
    localparam logic [63:0] W0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] W1 = 64'h0F0E_0D0C_0B0A_0908;

    begin
      $display("TEST: abort during partial message");
      reset_dut();
      error_count = 0;

      drive_word(W0, 1'b1, 1'b0);
      drive_word(W1, 1'b0, 1'b0);
      check_condition(message_valid === 1'b0, "Partial message must not be emitted");
      drive_abort();
      drive_idle();
      check_condition(message_valid === 1'b0, "Abort must not emit a message");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort");
      check_condition(assembler_error === 1'b0, "Upstream abort must not be reported as assembler_error");
      drive_idle();
      check_condition(message_packet_abort === 1'b0, "message_packet_abort must be a one-cycle pulse");
      check_condition(message_valid === 1'b0, "Discarded partial message appeared after abort");

      if (error_count == 0) begin
        $display("PASS: abort during partial message");
      end
      else begin
        $fatal(1, "FAIL: abort during partial message, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_abort_after_complete_message;
    localparam logic [63:0] A0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] A1 = 64'h0F0E_0D0C_0B0A_0908;
    localparam logic [63:0] A2 = 64'h1716_1514_1312_1110;
    localparam logic [63:0] A3 = 64'h1F1E_1D1C_1B1A_1918;
    localparam logic [63:0] B0 = 64'hA7A6_A5A4_A3A2_A1A0;
    localparam logic [63:0] B1 = 64'hAFAE_ADAC_ABAA_A9A8;

    logic [255:0] expected_a;

    begin
      $display("TEST: abort after one complete message");
      reset_dut();

      error_count = 0;
      expected_a = {A3, A2, A1, A0};

      // Complete message A, but keep the UDP packet open.
      drive_word(A0, 1'b1, 1'b0);
      drive_word(A1, 1'b0, 1'b0);
      drive_word(A2, 1'b0, 1'b0);
      drive_word(A3, 1'b0, 1'b0);

      // Begin message B. Message A output is visible now.
      drive_word(B0, 1'b0, 1'b0);
      check_condition(message_valid === 1'b1, "Expected message A to be emitted");
      check_condition(message_data === expected_a, "Message A data is incorrect");
      check_condition(message_packet_start === 1'b1, "Message A should be the packet start");
      check_condition(message_packet_end === 1'b0, "Message A should not be the packet end");
      check_condition(message_packet_abort === 1'b0, "Unexpected abort while emitting message A");
      check_condition(assembler_error === 1'b0, "Unexpected assembler error while emitting message A");

      drive_word(B1, 1'b0, 1'b0);
      check_condition(message_valid === 1'b0, "Partial message B must not be emitted");
      drive_abort();
      drive_idle();
      check_condition(message_valid === 1'b0, "Abort must not emit partial message B");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort after upstream abort");
      check_condition(assembler_error === 1'b0, "Upstream abort must not cause assembler_error");

      drive_idle();
      check_condition(message_packet_abort === 1'b0, "message_packet_abort must be a one-cycle pulse");
      check_condition(message_valid === 1'b0, "Partial message appeared after abort");

      if (error_count == 0) begin
        $display("PASS: abort after one complete message");
      end
      else begin
        $fatal(1, "FAIL: abort after one complete message, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_missing_packet_start;
    localparam logic [63:0] W0 = 64'h0706_0504_0302_0100;

    begin
      $display("TEST: missing packet start");
      reset_dut();

      error_count = 0;

      // Illegal: payload arrives while no packet is active,
      // but udp_payload_start is not asserted.
      drive_word(W0, 1'b0, 1'b0);
      drive_idle();

      check_condition(message_valid === 1'b0, "Malformed input must not emit a message");
      check_condition(assembler_error === 1'b1, "Expected assembler_error for missing packet start");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort for missing packet start");

      drive_idle();
      check_condition(assembler_error === 1'b0, "assembler_error must be a one-cycle pulse");
      check_condition(message_packet_abort === 1'b0, "message_packet_abort must be a one-cycle pulse");
      check_condition(message_valid === 1'b0, "Malformed input produced a delayed message");

      if (error_count == 0) begin
        $display("PASS: missing packet start");
      end
      else begin
        $fatal(1, "FAIL: missing packet start, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_repeated_packet_start;
    localparam logic [63:0] W0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] W1 = 64'h0F0E_0D0C_0B0A_0908;

    begin
      $display("TEST: repeated packet start");
      reset_dut();
      error_count = 0;
      drive_word(W0, 1'b1, 1'b0);

      // Illegal: another packet start appears before the first packet ends.
      drive_word(W1, 1'b1, 1'b0);
      drive_idle();

      check_condition(message_valid === 1'b0, "Repeated packet start must not emit a message");
      check_condition(assembler_error === 1'b1, "Expected assembler_error for repeated packet start");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort for repeated packet start");

      drive_idle();
      check_condition(assembler_error === 1'b0, "assembler_error must be a one-cycle pulse");
      check_condition(message_packet_abort === 1'b0, "message_packet_abort must be a one-cycle pulse");
      check_condition(message_valid === 1'b0, "Discarded partial message appeared after framing error");

      if (error_count == 0) begin
        $display("PASS: repeated packet start");
      end
      else begin
        $fatal(1, "FAIL: repeated packet start, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_premature_packet_end;
    localparam logic [63:0] W0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] W1 = 64'h0F0E_0D0C_0B0A_0908;

    begin
      $display("TEST: premature packet end");
      reset_dut();

      error_count = 0;

      drive_word(W0, 1'b1, 1'b0);

      // Illegal: packet ends on message word 1 rather than word 3.
      drive_word(W1, 1'b0, 1'b1);
      drive_idle();

      check_condition(message_valid === 1'b0, "Premature packet end must not emit a message");
      check_condition(assembler_error === 1'b1, "Expected assembler_error for premature packet end");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort for premature packet end");

      drive_idle();
      check_condition(assembler_error === 1'b0, "assembler_error must be a one-cycle pulse");
      check_condition(message_packet_abort === 1'b0, "message_packet_abort must be a one-cycle pulse");
      check_condition(message_valid === 1'b0, "Discarded partial message appeared after framing error");

      if (error_count == 0) begin
        $display("PASS: premature packet end");
      end
      else begin
        $fatal(1, "FAIL: premature packet end, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_recovery_after_error;
    localparam logic [63:0] BAD_0 = 64'h0706_0504_0302_0100;
    localparam logic [63:0] BAD_1 = 64'h0F0E_0D0C_0B0A_0908;

    localparam logic [63:0] GOOD_0 = 64'hA7A6_A5A4_A3A2_A1A0;
    localparam logic [63:0] GOOD_1 = 64'hAFAE_ADAC_ABAA_A9A8;
    localparam logic [63:0] GOOD_2 = 64'hB7B6_B5B4_B3B2_B1B0;
    localparam logic [63:0] GOOD_3 = 64'hBFBE_BDBC_BBBA_B9B8;

    logic [255:0] expected_message;

    begin
      $display("TEST: recovery after framing error");
      reset_dut();

      error_count = 0;
      expected_message = {GOOD_3, GOOD_2, GOOD_1, GOOD_0};

      // Malformed packet: ends on word 1.
      drive_word(BAD_0, 1'b1, 1'b0);
      drive_word(BAD_1, 1'b0, 1'b1);
      drive_idle();

      check_condition(message_valid === 1'b0, "Malformed packet must not emit a message");
      check_condition(assembler_error === 1'b1, "Expected assembler_error for malformed packet");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort for malformed packet");

      // No reset. Begin a new valid packet.
      drive_word(GOOD_0, 1'b1, 1'b0);
      check_condition(assembler_error === 1'b0, "assembler_error did not clear after malformed packet");
      check_condition(message_packet_abort === 1'b0, "message_packet_abort did not clear after malformed packet");

      drive_word(GOOD_1, 1'b0, 1'b0);
      drive_word(GOOD_2, 1'b0, 1'b0);
      drive_word(GOOD_3, 1'b0, 1'b1);

      drive_idle();
      check_condition(message_valid === 1'b1, "Valid packet was not emitted after recovery");
      check_condition(message_data === expected_message, "Recovered packet message data is incorrect");
      check_condition(message_packet_start === 1'b1, "Recovered message should be the packet start");
      check_condition(message_packet_end === 1'b1, "Recovered message should be the packet end");
      check_condition(assembler_error === 1'b0, "Unexpected assembler_error on recovered packet");
      check_condition(message_packet_abort === 1'b0, "Unexpected message_packet_abort on recovered packet");

      drive_idle();
      check_condition(message_valid === 1'b0, "message_valid must be a one-cycle pulse");

      if (error_count == 0) begin
        $display("PASS: recovery after framing error");
      end
      else begin
        $fatal(1, "FAIL: recovery after framing error, %0d errors", error_count);
      end
    end
  endtask
  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------

  initial begin
    test_single_message_packet();
    test_two_messages_one_packet();
    test_back_to_back_packets();
    test_idle_gaps_between_words();
    test_abort_during_partial_message();
    test_abort_after_complete_message();
    test_missing_packet_start();
    test_repeated_packet_start();
    test_premature_packet_end();
    test_recovery_after_error();
    $display("PASS: ALL TESTS PASSED");
    $finish;
  end

endmodule
