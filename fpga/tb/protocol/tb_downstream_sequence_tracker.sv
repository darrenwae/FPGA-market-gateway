`timescale 1ns / 1ps

module tb_downstream_sequence_tracker;

  localparam time CLK_PERIOD = 6.206ns;

  // ==========================================================================
  // DUT signals
  // ==========================================================================

  logic clk;
  logic rst;

  logic message_valid;
  logic [31:0] message_sequence_number;
  logic message_packet_start;
  logic message_packet_end;
  logic message_is_full_reset_all;

  logic packet_commit;
  logic packet_discard;
  logic integrity_failure;

  logic sequence_mismatch_event;
  logic stream_fault;
  logic effective_stream_fault;
  logic [31:0] verified_next_sequence_number;

  // ==========================================================================
  // DUT
  // ==========================================================================

  downstream_sequence_tracker dut (
      .clk(clk),
      .rst(rst),

      .message_valid(message_valid),
      .message_sequence_number(message_sequence_number),
      .message_packet_start(message_packet_start),
      .message_packet_end(message_packet_end),
      .message_is_full_reset_all(message_is_full_reset_all),

      .packet_commit(packet_commit),
      .packet_discard(packet_discard),
      .integrity_failure(integrity_failure),

      .sequence_mismatch_event(sequence_mismatch_event),
      .stream_fault(stream_fault),
      .effective_stream_fault(effective_stream_fault),
      .verified_next_sequence_number(verified_next_sequence_number)
  );

  // ==========================================================================
  // Clock
  // ==========================================================================

  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;

  // ==========================================================================
  // Common tasks
  // ==========================================================================

  task automatic initialize_inputs;
    begin
      rst = 1'b0;

      message_valid = 1'b0;
      message_sequence_number = '0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b0;

      packet_commit = 1'b0;
      packet_discard = 1'b0;
      integrity_failure = 1'b0;
    end
  endtask

  task automatic apply_reset;
    begin
      @(negedge clk);

      message_valid = 1'b0;
      packet_commit = 1'b0;
      packet_discard = 1'b0;
      integrity_failure = 1'b0;

      rst = 1'b1;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic check_outputs(input logic [31:0] expected_verified_sequence, input logic expected_mismatch_event, input logic expected_stream_fault, input logic expected_effective_stream_fault, input string check_label);
    begin
      if (verified_next_sequence_number !== expected_verified_sequence) begin
        $fatal(1, "%s: verified sequence expected %0d, received %0d", check_label, expected_verified_sequence, verified_next_sequence_number);
      end

      if (sequence_mismatch_event !== expected_mismatch_event) begin
        $fatal(1, "%s: sequence_mismatch_event expected %b, received %b", check_label, expected_mismatch_event, sequence_mismatch_event);
      end

      if (stream_fault !== expected_stream_fault) begin
        $fatal(1, "%s: stream_fault expected %b, received %b", check_label, expected_stream_fault, stream_fault);
      end

      if (effective_stream_fault !== expected_effective_stream_fault) begin
        $fatal(1, "%s: effective_stream_fault expected %b, received %b", check_label, expected_effective_stream_fault, effective_stream_fault);
      end
    end
  endtask

  // ==========================================================================
  // Tests
  // ==========================================================================

  task automatic test_reset_state;
    /*
    Purpose: Verify the initial downstream sequence and fault state.
    Input: Assert and release reset.
    Expected output: Next verified sequence is 1 and all fault outputs are clear.
    */
    begin
      $display("TEST: reset state");
      apply_reset();
      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "after reset");
      $display("PASS: reset state");
    end
  endtask


  task automatic test_single_message_commit;
    /*
    Purpose:
    Verify that a correct message advances the verified sequence only after its packet commits.

    Input:
    One packet containing sequence number 1, followed by packet_commit.

    Expected output:
    The verified next sequence remains 1 before commit and becomes 2 after commit. No fault is asserted.
    */
    begin
      $display("TEST: single-message packet commit");

      apply_reset();

      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      #1ps;

      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "correct message presented");

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;

      #1ps;
      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "before packet commit");
      packet_commit = 1'b1;

      @(posedge clk);
      #1ps;
      check_outputs(32'd2, 1'b0, 1'b0, 1'b0, "after packet commit");

      @(negedge clk);
      packet_commit = 1'b0;

      $display("PASS: single-message packet commit");
    end
  endtask


  task automatic test_multiple_message_commit;
    /*
    Purpose:
    Verify sequence tracking across multiple messages in one UDP packet.

    Input:
    One packet containing sequence numbers 1, 2 and 3, followed by commit.

    Expected output:
    No mismatch occurs. The verified next sequence remains 1 until commit,
    then advances to 4.
    */

    $display("TEST: multiple-message packet commit");
    begin

      apply_reset();

      // First message
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b0;

      #1ps;
      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "first message");

      @(posedge clk);
      #1ps;

      // Second message
      @(negedge clk);
      message_sequence_number = 32'd2;
      message_packet_start = 1'b0;

      #1ps;
      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "second message");

      @(posedge clk);
      #1ps;

      // Final message
      @(negedge clk);
      message_sequence_number = 32'd3;
      message_packet_end = 1'b1;

      #1ps;
      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "final message");

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_end = 1'b0;
      packet_commit = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd4, 1'b0, 1'b0, 1'b0, "after packet commit");

      @(negedge clk);
      packet_commit = 1'b0;

      $display("PASS: multiple-message packet commit");
    end
  endtask


  task automatic test_packet_discard;
    /*
    Purpose:
    Verify that sequence progress from a discarded packet is removed.

    Input:
    A packet containing sequences 1 and 2 is discarded.The following packet begins again with sequence 1.

    Expected output:
    The verified next sequence remains 1 after discard. The new sequence-1 packet is accepted and commits to sequence 2.
    */

    begin
      $display("TEST: packet discard");

      apply_reset();

      // First message of discarded packet
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      // Final message of discarded packet
      @(negedge clk);
      message_sequence_number = 32'd2;
      message_packet_start = 1'b0;
      message_packet_end = 1'b1;

      @(posedge clk);
      #1ps;

      // Discard the packet
      @(negedge clk);
      message_valid = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "after packet discard");

      @(negedge clk);
      packet_discard = 1'b0;

      // A new packet must still begin with sequence 1.
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;

      #1ps;

      check_outputs(32'd1, 1'b0, 1'b0, 1'b0, "new packet after discard");

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_commit = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd2, 1'b0, 1'b0, 1'b0, "new packet committed");

      @(negedge clk);
      packet_commit = 1'b0;

      $display("PASS: packet discard");
    end
  endtask


  task automatic test_sequence_mismatch;
    /*
    Purpose:
    Verify that an unexpected sequence number is detected immediately
    and permanently places the downstream stream into fault.

    Input:
    The first packet starts with sequence number 2 when sequence 1 is expected.

    Expected output:
    sequence_mismatch_event and effective_stream_fault assert immediately.
    stream_fault asserts after the clock edge.
    The verified next sequence remains 1.
    */
    begin
      $display("TEST: sequence mismatch");

      apply_reset();

      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd2;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      #1ps;

      check_outputs(32'd1, 1'b1, 1'b0, 1'b1, "mismatching message presented");

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "mismatch registered");

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "mismatching packet discarded");

      @(negedge clk);
      packet_discard = 1'b0;

      $display("PASS: sequence mismatch");
    end
  endtask


  task automatic test_mismatch_after_speculative_progress;
    /*
  Purpose:
  Verify that a mismatch after valid speculative progress faults the stream.

  Input:
  One packet containing sequence 1, unexpected sequence 3, then sequence 4.

  Expected output:
  Sequence 3 produces one mismatch event. Later messages are ignored,
  the packet is discarded, and the verified sequence remains 1.
  */
    begin
      $display("TEST: mismatch after speculative progress");

      apply_reset();

      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_sequence_number = 32'd3;
      message_packet_start = 1'b0;

      #1ps;
      check_outputs(32'd1, 1'b1, 1'b0, 1'b1, "later sequence mismatch");

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "mismatch registered");

      // A later message in the failed packet must not advance sequence state.
      @(negedge clk);
      message_sequence_number = 32'd4;
      message_packet_end = 1'b1;

      #1ps;
      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "later message ignored");

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "failed packet discarded");

      @(negedge clk);
      packet_discard = 1'b0;

      $display("PASS: mismatch after speculative progress");
    end
  endtask



  task automatic test_integrity_failure;
    /*
    Purpose:
    Verify that a bad incoming frame faults the stream and prevents speculative sequence progress from becoming verified.

    Input:
    A correct sequence-1 message followed by integrity_failure.

    Expected output:
    effective_stream_fault asserts immediately.
    stream_fault asserts after the clock edge.
    verified_next_sequence_number remains 1.
    */
    begin
      $display("TEST: integrity failure");

      apply_reset();

      // Decode a correct message speculatively.
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      integrity_failure = 1'b1;

      #1ps;

      check_outputs(32'd1, 1'b0, 1'b0, 1'b1, "integrity failure presented");

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "integrity failure registered");

      @(negedge clk);
      integrity_failure = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "failed packet discarded");

      @(negedge clk);
      packet_discard = 1'b0;

      $display("PASS: integrity failure");
    end
  endtask


  task automatic test_fault_persistence;
    /*
    Purpose:
    Verify that ordinary packets cannot clear stream_fault.

    Input:
    Cause a sequence mismatch, discard that packet, then present and commit
    a later ordinary packet.

    Expected output:
    stream_fault remains asserted and the verified sequence remains unchanged.
    */
    begin
      $display("TEST: fault persistence");

      apply_reset();

      // Cause the initial sequence fault.
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd2;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      packet_discard = 1'b0;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "after initial fault");

      // Present an ordinary packet while the stream is faulted.
      message_valid = 1'b1;
      message_sequence_number = 32'd1;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "ordinary message during fault");

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_commit = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "ordinary packet committed during fault");

      @(negedge clk);
      packet_commit = 1'b0;

      $display("PASS: fault persistence");
    end
  endtask


  task automatic test_reset_all_recovery;
    /*
    Purpose:
    Verify recovery from stream_fault using a committed isolated RESET_ALL.

    Input:
    Cause a sequence mismatch, then send an isolated RESET_ALL withsequence number 100 and commit its packet.

    Expected output:
    stream_fault remains high until commit, then clears.
    The next verified sequence becomes 101.
    */
    begin
      $display("TEST: RESET_ALL recovery");

      apply_reset();

      // Cause a sequence fault.
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd2;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      packet_discard = 1'b0;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "before RESET_ALL");

      // Present an isolated RESET_ALL recovery message.
      message_valid = 1'b1;
      message_sequence_number = 32'd100;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b1;

      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "RESET_ALL presented");

      @(posedge clk);
      #1ps;

      // Commit the recovery packet.
      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b0;
      packet_commit = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd101, 1'b0, 1'b0, 1'b0, "RESET_ALL committed");

      @(negedge clk);
      packet_commit = 1'b0;

      $display("PASS: RESET_ALL recovery");
    end
  endtask


  task automatic test_discarded_reset_all;
    /*
    Purpose:
    Verify that RESET_ALL recovery occurs only after packet commit.

    Input:
    Cause a sequence fault, then present an isolated RESET_ALL packetand discard it.

    Expected output:
    stream_fault remains asserted and the verified sequence remains 1.
    */
    begin
      $display("TEST: discarded RESET_ALL");

      apply_reset();

      // Cause a sequence fault.
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd2;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      packet_discard = 1'b0;

      // Present an isolated RESET_ALL recovery message.
      message_valid = 1'b1;
      message_sequence_number = 32'd100;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "RESET_ALL awaiting resolution");

      // Discard the recovery packet.
      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "RESET_ALL discarded");

      @(negedge clk);
      packet_discard = 1'b0;

      $display("PASS: discarded RESET_ALL");
    end
  endtask

  task automatic test_non_isolated_reset_all;
    /*
    Purpose:
    Verify that RESET_ALL recovery requires a single-message packet.

    Input:
    Cause a sequence fault, then commit a two-message packet whose first message is RESET_ALL.

    Expected output:
    stream_fault remains asserted and the verified sequence remains 1.
    */
    begin
      $display("TEST: non-isolated RESET_ALL");

      apply_reset();

      // Cause a sequence fault.
      @(negedge clk);
      message_valid = 1'b1;
      message_sequence_number = 32'd2;
      message_packet_start = 1'b1;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_start = 1'b0;
      message_packet_end = 1'b0;
      packet_discard = 1'b1;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      packet_discard = 1'b0;

      // First message is RESET_ALL, but the packet contains another message.
      message_valid = 1'b1;
      message_sequence_number = 32'd100;
      message_packet_start = 1'b1;
      message_packet_end = 1'b0;
      message_is_full_reset_all = 1'b1;

      @(posedge clk);
      #1ps;

      // Final ordinary message.
      @(negedge clk);
      message_sequence_number = 32'd101;
      message_packet_start = 1'b0;
      message_packet_end = 1'b1;
      message_is_full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_valid = 1'b0;
      message_packet_end = 1'b0;
      packet_commit = 1'b1;

      @(posedge clk);
      #1ps;

      check_outputs(32'd1, 1'b0, 1'b1, 1'b1, "non-isolated RESET_ALL committed");

      @(negedge clk);
      packet_commit = 1'b0;

      $display("PASS: non-isolated RESET_ALL");
    end
  endtask


  // ==========================================================================
  // Test selection
  // ==========================================================================

  initial begin
    initialize_inputs();
    test_reset_state();
    test_single_message_commit();
    test_multiple_message_commit();
    test_packet_discard();
    test_sequence_mismatch();
    test_mismatch_after_speculative_progress();
    test_integrity_failure();
    test_fault_persistence();
    test_reset_all_recovery();
    test_discarded_reset_all();
    test_non_isolated_reset_all();

    $display("PASS: All downstream sequence tracker tests");
    $finish;
  end

endmodule
