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

  int unsigned error_count;

  // ---------------------------------------------------------------------------
  // Clock
  // ---------------------------------------------------------------------------

  localparam realtime CLK_PERIOD_NS = 6.20606;
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

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
      .message_packet_abort(message_packet_abort)
  );


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
      check_condition(message_packet_abort === 1'b0, "Unexpected abort between back-to-back packets");

      drive_word(B1, 1'b0, 1'b0);
      drive_word(B2, 1'b0, 1'b0);
      drive_word(B3, 1'b0, 1'b1);

      drive_idle();

      check_condition(message_valid === 1'b1, "Expected message_valid for packet B");
      check_condition(message_data === expected_b, "Packet B message data is incorrect");
      check_condition(message_packet_start === 1'b1, "Packet B should assert message_packet_start");
      check_condition(message_packet_end === 1'b1, "Packet B should assert message_packet_end");
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

      drive_word(B1, 1'b0, 1'b0);
      check_condition(message_valid === 1'b0, "Partial message B must not be emitted");
      drive_abort();
      drive_idle();
      check_condition(message_valid === 1'b0, "Abort must not emit partial message B");
      check_condition(message_packet_abort === 1'b1, "Expected message_packet_abort after upstream abort");

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
    $display("PASS: ALL TESTS PASSED");
    $finish;
  end

endmodule
