`timescale 1ns / 1ps

module tb_rx_packet_controller;

  // ==========================================================================
  // Constants
  // ==========================================================================

  localparam time CLK_PERIOD = 6.206ns;

  // ==========================================================================
  // DUT inputs
  // ==========================================================================

  logic clk;
  logic rst;
  logic packet_failure_event;
  logic packet_start;
  logic decode_complete;
  logic decode_abort;
  logic frame_abort;

  logic fcs_result_valid;
  logic fcs_ok;


  // ==========================================================================
  // DUT outputs
  // ==========================================================================

  logic packet_commit;
  logic packet_discard;

  logic integrity_known;
  logic integrity_result_valid;
  logic integrity_ok;
  logic integrity_failure;

  logic controller_error;

  int unsigned error_count;


  // ==========================================================================
  // DUT instantiation
  // ==========================================================================

  rx_packet_controller dut (
      .clk(clk),
      .rst(rst),
      .packet_failure_event(packet_failure_event),
      .packet_start(packet_start),
      .decode_complete(decode_complete),
      .decode_abort(decode_abort),
      .frame_abort(frame_abort),
      .fcs_result_valid(fcs_result_valid),
      .fcs_ok(fcs_ok),
      .packet_commit(packet_commit),
      .packet_discard(packet_discard),
      .integrity_known(integrity_known),
      .integrity_result_valid(integrity_result_valid),
      .integrity_ok(integrity_ok),
      .integrity_failure(integrity_failure),
      .controller_error(controller_error)
  );


  // ==========================================================================
  // Clock generation
  // ==========================================================================

  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;


  // ==========================================================================
  // Input-driving helpers
  // ==========================================================================

  task automatic initialize_inputs;
    begin
      rst = 1'b0;

      packet_start = 1'b0;
      decode_complete = 1'b0;
      decode_abort = 1'b0;
      frame_abort = 1'b0;
      fcs_result_valid = 1'b0;
      fcs_ok = 1'b0;
      packet_failure_event = 1'b0;
      error_count = 0;
    end
  endtask


  task automatic drive_events_with_failure(input logic start, input logic complete, input logic decode_failed, input logic frame_failed, input logic fcs_valid, input logic fcs_passed, input logic packet_failed);
    begin
      @(negedge clk);

      packet_start = start;
      decode_complete = complete;
      decode_abort = decode_failed;
      frame_abort = frame_failed;
      fcs_result_valid = fcs_valid;
      fcs_ok = fcs_passed;
      packet_failure_event = packet_failed;

      @(posedge clk);
      #1ps;
    end
  endtask


  task automatic drive_events(input logic start, input logic complete, input logic decode_failed, input logic frame_failed, input logic fcs_valid, input logic fcs_passed);
    begin
      drive_events_with_failure(start, complete, decode_failed, frame_failed, fcs_valid, fcs_passed, 1'b0);
    end
  endtask


  task automatic drive_idle;
    begin
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    end
  endtask


  task automatic reset_dut;
    begin
      @(negedge clk);
      packet_start = 1'b0;
      packet_failure_event = 1'b0;
      decode_complete = 1'b0;
      decode_abort = 1'b0;
      frame_abort = 1'b0;
      fcs_result_valid = 1'b0;
      fcs_ok = 1'b0;
      rst = 1'b1;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

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


  task automatic check_no_pulses(input string check_label);
    begin
      check_condition(packet_commit === 1'b0, $sformatf("%s: unexpected packet_commit", check_label));
      check_condition(packet_discard === 1'b0, $sformatf("%s: unexpected packet_discard", check_label));
      check_condition(integrity_result_valid === 1'b0, $sformatf("%s: unexpected integrity_result_valid", check_label));
      check_condition(integrity_failure === 1'b0, $sformatf("%s: unexpected integrity_failure", check_label));
      check_condition(controller_error === 1'b0, $sformatf("%s: unexpected controller_error", check_label));
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


  // ==========================================================================
  // Test cases
  // ==========================================================================

  task automatic test_reset_and_idle;
    begin
      $display("TEST: reset and idle");

      error_count = 0;
      reset_dut();
      check_no_pulses("after reset");
      check_condition(integrity_known === 1'b0, "integrity_known was not cleared by reset");
      check_condition(integrity_ok === 1'b0, "integrity_ok was not cleared by reset");

      drive_idle();
      check_no_pulses("first idle cycle");
      drive_idle();
      check_no_pulses("second idle cycle");

      finish_test("reset and idle");
    end
  endtask


  task automatic test_good_fcs_before_decode;
    begin
      $display("TEST: good FCS before decode");

      error_count = 0;
      reset_dut();

      // Start the packet.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");
      check_condition(integrity_known === 1'b0, "integrity became known before the FCS result");

      // Good FCS arrives before decoding completes.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "good FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "good FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b1, "good FCS did not set integrity_ok");
      check_condition(integrity_failure === 1'b0, "good FCS unexpectedly asserted integrity_failure");
      check_condition(packet_commit === 1'b0, "packet committed before decoding completed");
      check_condition(packet_discard === 1'b0, "good FCS unexpectedly discarded the packet");

      // Integrity remains stored while waiting for decode.
      drive_idle();
      check_condition(integrity_known === 1'b1, "stored integrity result was lost");
      check_condition(integrity_ok === 1'b1, "stored good-FCS result was lost");

      // Decode completion resolves the transaction.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
      check_condition(packet_commit === 1'b1, "packet did not commit after decode completed");
      check_condition(packet_discard === 1'b0, "valid packet was discarded");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      // Commit is a one-cycle pulse.
      drive_idle();
      check_no_pulses("after packet commit");

      finish_test("good FCS before decode");
    end
  endtask


  task automatic test_decode_before_good_fcs;
    begin
      $display("TEST: decode before good FCS");

      error_count = 0;
      reset_dut();

      // Start the packet.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Decoding completes before integrity is known.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after decode completion");
      check_condition(integrity_known === 1'b0, "integrity became known before the FCS result");
      check_condition(packet_commit === 1'b0, "packet committed without an FCS result");

      // Good FCS completes and resolves the transaction.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "good FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "good FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b1, "good FCS did not set integrity_ok");
      check_condition(integrity_failure === 1'b0, "good FCS unexpectedly asserted integrity_failure");
      check_condition(packet_commit === 1'b1, "packet did not commit when the good FCS arrived");
      check_condition(packet_discard === 1'b0, "valid packet was discarded");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      // Resolution outputs are one-cycle pulses.
      drive_idle();
      check_no_pulses("after packet commit");

      finish_test("decode before good FCS");
    end
  endtask


  task automatic test_good_fcs_with_decode;
    begin
      $display("TEST: good FCS with decode");

      error_count = 0;
      reset_dut();

      // Start the packet.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Decode and FCS complete together.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "same-cycle FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "same-cycle FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b1, "same-cycle good FCS did not set integrity_ok");
      check_condition(integrity_failure === 1'b0, "same-cycle good FCS asserted integrity_failure");
      check_condition(packet_commit === 1'b1, "same-cycle completion did not commit the packet");
      check_condition(packet_discard === 1'b0, "same-cycle valid packet was discarded");
      check_condition(controller_error === 1'b0, "same-cycle completion caused a controller error");

      // All event outputs are one-cycle pulses.
      drive_idle();
      check_no_pulses("after same-cycle commit");

      finish_test("good FCS with decode");
    end
  endtask


  task automatic test_bad_fcs_before_decode;
    begin
      $display("TEST: bad FCS before decode");

      error_count = 0;
      reset_dut();

      // Start the packet.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Bad FCS arrives before decoding completes.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
      check_condition(integrity_result_valid === 1'b1, "bad FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "bad FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b0, "bad FCS incorrectly set integrity_ok");
      check_condition(integrity_failure === 1'b1, "bad FCS did not assert integrity_failure");
      check_condition(packet_commit === 1'b0, "bad-FCS packet was committed");
      check_condition(packet_discard === 1'b0, "packet was discarded before decoding finished");

      // Failure remains stored, but event pulses clear.
      drive_idle();
      check_no_pulses("waiting for decode after bad FCS");
      check_condition(integrity_known === 1'b1, "stored bad-FCS result was lost");
      check_condition(integrity_ok === 1'b0, "stored bad-FCS result became good");

      // Decode completion now resolves the failed transaction.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
      check_condition(packet_commit === 1'b0, "bad-FCS packet committed after decode");
      check_condition(packet_discard === 1'b1, "bad-FCS packet was not discarded after decode");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      // Discard is a one-cycle pulse.
      drive_idle();
      check_no_pulses("after bad-FCS discard");

      finish_test("bad FCS before decode");
    end
  endtask


  task automatic test_decode_before_bad_fcs;
    begin
      $display("TEST: decode before bad FCS");

      error_count = 0;
      reset_dut();

      // Start the packet.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Decoding completes while integrity remains unknown.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("waiting for FCS after decode");
      check_condition(integrity_known === 1'b0, "integrity became known before the FCS result");

      // Late bad FCS resolves the transaction as a discard.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
      check_condition(integrity_result_valid === 1'b1, "bad FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "bad FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b0, "bad FCS incorrectly set integrity_ok");
      check_condition(integrity_failure === 1'b1, "bad FCS did not assert integrity_failure");
      check_condition(packet_commit === 1'b0, "bad-FCS packet was committed");
      check_condition(packet_discard === 1'b1, "bad-FCS packet was not discarded");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      // Resolution outputs are one-cycle pulses.
      drive_idle();
      check_no_pulses("after late bad-FCS discard");
      finish_test("decode before bad FCS");
    end
  endtask


  task automatic test_frame_abort_before_decode_abort;
    begin
      $display("TEST: frame abort before decode abort");

      error_count = 0;
      reset_dut();

      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Physical failure is known before the decoder drains.
      drive_events(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
      check_condition(integrity_result_valid === 1'b1, "frame abort did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "frame abort did not set integrity_known");
      check_condition(integrity_ok === 1'b0, "frame abort incorrectly set integrity_ok");
      check_condition(integrity_failure === 1'b1, "frame abort did not assert integrity_failure");
      check_condition(packet_commit === 1'b0, "aborted frame was committed");
      check_condition(packet_discard === 1'b0, "packet was discarded before decoder abort");
      check_condition(controller_error === 1'b0, "frame abort caused a controller error");

      drive_idle();
      check_no_pulses("waiting for decoder abort");

      // Decoder abort confirms that the logical path is drained.
      drive_events(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
      check_condition(packet_commit === 1'b0, "aborted packet was committed");
      check_condition(packet_discard === 1'b1, "packet was not discarded after decoder abort");
      check_condition(integrity_result_valid === 1'b0, "decoder abort produced a second integrity result");
      check_condition(controller_error === 1'b0, "decoder abort caused a controller error");

      drive_idle();
      check_no_pulses("after frame-abort discard");

      finish_test("frame abort before decode abort");
    end
  endtask


  task automatic test_decode_abort_before_frame_abort;
    begin
      $display("TEST: decode abort before frame abort");

      error_count = 0;
      reset_dut();

      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Decoder terminates while physical integrity remains unknown.
      drive_events(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
      check_no_pulses("waiting for frame abort");
      check_condition(integrity_known === 1'b0, "decode abort incorrectly made integrity known");
      check_condition(packet_discard === 1'b0, "packet was discarded before integrity became known");

      drive_idle();
      check_no_pulses("decode abort stored");

      // Physical abort supplies the missing integrity result.
      drive_events(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
      check_condition(integrity_result_valid === 1'b1, "frame abort did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "frame abort did not set integrity_known");
      check_condition(integrity_ok === 1'b0, "frame abort incorrectly set integrity_ok");
      check_condition(integrity_failure === 1'b1, "frame abort did not assert integrity_failure");
      check_condition(packet_commit === 1'b0, "aborted packet was committed");
      check_condition(packet_discard === 1'b1, "packet was not discarded after both paths finished");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      drive_idle();
      check_no_pulses("after decode-abort discard");

      finish_test("decode abort before frame abort");
    end
  endtask


  task automatic test_good_fcs_before_decode_abort;
    begin
      $display("TEST: good FCS before decode abort");

      error_count = 0;
      reset_dut();

      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");


      // Physical integrity passes before the decoded path terminates.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "good FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "good FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b1, "good FCS did not set integrity_ok");
      check_condition(integrity_failure === 1'b0, "good FCS asserted integrity_failure");
      check_condition(packet_commit === 1'b0, "packet committed before decode termination");
      check_condition(packet_discard === 1'b0, "packet discarded before decode termination");

      drive_idle();
      check_no_pulses("waiting for decode abort");

      // Logical failure overrides the good physical integrity result.
      drive_events(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
      check_condition(packet_commit === 1'b0, "decoder-aborted packet was committed");
      check_condition(packet_discard === 1'b1, "decoder-aborted packet was not discarded");
      check_condition(integrity_failure === 1'b0, "logical abort incorrectly reported an integrity failure");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      drive_idle();
      check_no_pulses("after decoder-abort discard");

      finish_test("good FCS before decode abort");
    end
  endtask


  task automatic test_decode_abort_before_good_fcs;
    begin
      $display("TEST: decode abort before good FCS");

      error_count = 0;
      reset_dut();

      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after packet start");

      // Logical processing fails before integrity is known.
      drive_events(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
      check_no_pulses("waiting for FCS after decode abort");
      check_condition(integrity_known === 1'b0, "decode abort incorrectly made integrity known");
      check_condition(packet_discard === 1'b0, "packet discarded before FCS arrived");
      drive_idle();
      check_no_pulses("decode failure stored");

      // Good FCS cannot recover the logically failed packet.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "good FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "good FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b1, "good FCS did not set integrity_ok");
      check_condition(integrity_failure === 1'b0, "good FCS asserted integrity_failure");
      check_condition(packet_commit === 1'b0, "logically failed packet was committed");
      check_condition(packet_discard === 1'b1, "logically failed packet was not discarded");
      check_condition(controller_error === 1'b0, "unexpected controller error");

      drive_idle();
      check_no_pulses("after stored decode-failure discard");

      finish_test("decode abort before good FCS");
    end
  endtask


  task automatic test_untracked_fcs_ignored;
    begin
      $display("TEST: untracked integrity results");

      error_count = 0;
      reset_dut();

      // Good FCS without an active packet.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_no_pulses("untracked good FCS");
      check_condition(integrity_known === 1'b0, "untracked good FCS changed integrity state");

      // Bad FCS without an active packet.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
      check_no_pulses("untracked bad FCS");
      check_condition(integrity_known === 1'b0, "untracked bad FCS changed integrity state");

      // Physical abort without an accepted packet.
      drive_events(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
      check_no_pulses("untracked frame abort");
      check_condition(integrity_known === 1'b0, "untracked frame abort changed integrity state");

      drive_idle();
      check_no_pulses("after untracked integrity events");

      finish_test("untracked integrity results");
    end
  endtask

  task automatic test_controller_errors;
    begin
      $display("TEST: controller errors");

      error_count = 0;
      reset_dut();

      // Decode completion without an active packet.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
      check_condition(controller_error === 1'b1, "decode completion without a packet was not rejected");
      check_condition(packet_commit === 1'b0, "invalid decode completion caused a commit");
      check_condition(packet_discard === 1'b0, "invalid decode completion caused a discard");

      drive_idle();
      check_no_pulses("after invalid decode completion");

      // Overlapping packet starts.
      reset_dut();
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after first packet start");
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_condition(controller_error === 1'b1, "overlapping packet start was not rejected");
      check_condition(packet_commit === 1'b0, "overlapping packet start caused a commit");
      check_condition(packet_discard === 1'b0, "overlapping packet start caused a discard");

      drive_idle();
      check_condition(controller_error === 1'b0, "overlap error did not clear after one cycle");

      // Duplicate FCS result.
      reset_dut();
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(controller_error === 1'b0, "first FCS result caused a controller error");
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
      check_condition(controller_error === 1'b1, "duplicate FCS result was not rejected");
      check_condition(integrity_result_valid === 1'b0, "duplicate FCS was reported as a new integrity result");
      check_condition(integrity_known === 1'b1, "duplicate FCS cleared the stored integrity result");
      check_condition(integrity_ok === 1'b1, "duplicate FCS changed the original good result");

      drive_idle();
      check_condition(controller_error === 1'b0, "duplicate-FCS error did not clear after one cycle");

      // packet_failure_event without an active packet is invalid.
      reset_dut();
      drive_events_with_failure(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
      check_condition(controller_error === 1'b1, "untracked packet_failure_event did not assert controller_error");
      check_condition(packet_commit === 1'b0, "untracked packet_failure_event caused a commit");
      check_condition(packet_discard === 1'b0, "untracked packet_failure_event caused a discard");
      drive_idle();

      check_condition(controller_error === 1'b0, "untracked packet_failure_event error did not clear after one cycle");
      finish_test("controller errors");
    end
  endtask


  task automatic test_recovery_without_reset;
    begin
      $display("TEST: recovery without reset");

      error_count = 0;
      reset_dut();

      // First packet starts.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      check_no_pulses("after failed-packet start");

      // Decode completion and bad FCS discard the first packet.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
      check_condition(integrity_result_valid === 1'b1, "failed packet did not report an integrity result");
      check_condition(integrity_failure === 1'b1, "failed packet did not report integrity failure");
      check_condition(packet_commit === 1'b0, "failed packet was committed");
      check_condition(packet_discard === 1'b1, "failed packet was not discarded");
      check_condition(controller_error === 1'b0, "failed packet caused a controller error");

      drive_idle();
      check_no_pulses("after failed-packet discard");
      check_condition(integrity_known === 1'b1, "failed packet integrity result was not retained");
      check_condition(integrity_ok === 1'b0, "failed packet integrity result became good");

      // Start another packet without resetting the controller.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      ;
      check_no_pulses("after recovery-packet start");
      check_condition(integrity_known === 1'b0, "new packet did not clear the previous integrity result");
      check_condition(integrity_ok === 1'b0, "new packet retained the previous integrity value");

      // Valid decode and FCS resolve the second packet.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "recovery packet did not report its integrity result");
      check_condition(integrity_known === 1'b1, "recovery packet integrity did not become known");
      check_condition(integrity_ok === 1'b1, "recovery packet did not retain its good FCS");
      check_condition(integrity_failure === 1'b0, "recovery packet reported an integrity failure");
      check_condition(packet_commit === 1'b1, "recovery packet was not committed");
      check_condition(packet_discard === 1'b0, "recovery packet was discarded");
      check_condition(controller_error === 1'b0, "recovery packet caused a controller error");

      drive_idle();
      check_no_pulses("after recovery-packet commit");

      finish_test("recovery without reset");
    end
  endtask


  task automatic test_packet_failure_waits_for_resolution;
    begin
      $display("TEST: packet failure waits for resolution");

      error_count = 0;
      reset_dut();

      // Start the packet.
      drive_events(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

      check_no_pulses("after packet start");
      check_condition(integrity_known === 1'b0, "integrity became known before an FCS result");

      // A logical failure occurs while decoding is still active.
      drive_events_with_failure(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
      check_condition(packet_commit === 1'b0, "packet committed when packet_failure_event was asserted");
      check_condition(packet_discard === 1'b0, "packet discarded before decoding completed");
      check_condition(integrity_result_valid === 1'b0, "logical packet failure incorrectly produced an integrity result");
      check_condition(integrity_failure === 1'b0, "logical packet failure incorrectly asserted integrity_failure");
      check_condition(controller_error === 1'b0, "tracked packet_failure_event caused a controller error");

      // The Ethernet frame itself passes FCS.
      drive_events(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
      check_condition(integrity_result_valid === 1'b1, "good FCS did not assert integrity_result_valid");
      check_condition(integrity_known === 1'b1, "good FCS did not set integrity_known");
      check_condition(integrity_ok === 1'b1, "good FCS did not set integrity_ok");
      check_condition(integrity_failure === 1'b0, "good FCS incorrectly asserted integrity_failure");
      check_condition(packet_commit === 1'b0, "logically failed packet committed before decoding completed");
      check_condition(packet_discard === 1'b0, "packet discarded before decoding completed");
      check_condition(controller_error === 1'b0, "good FCS caused a controller error");

      // Decode completion resolves the transaction.
      drive_events(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
      check_condition(packet_commit === 1'b0, "logically failed packet was committed");
      check_condition(packet_discard === 1'b1, "logically failed packet was not discarded");
      check_condition(integrity_failure === 1'b0, "logical packet failure was incorrectly reported as an FCS failure");
      check_condition(controller_error === 1'b0, "packet resolution caused a controller error");

      // Discard is a one-cycle pulse.
      drive_idle();
      check_no_pulses("after logical packet discard");

      finish_test("packet failure waits for resolution");
    end
  endtask


  // ==========================================================================
  // Test sequence
  // ==========================================================================

  initial begin
    initialize_inputs();

    test_reset_and_idle();
    test_good_fcs_before_decode();
    test_decode_before_good_fcs();
    test_good_fcs_with_decode();
    test_bad_fcs_before_decode();
    test_decode_before_bad_fcs();
    test_frame_abort_before_decode_abort();
    test_decode_abort_before_frame_abort();
    test_good_fcs_before_decode_abort();
    test_decode_abort_before_good_fcs();
    test_untracked_fcs_ignored();
    test_controller_errors();
    test_recovery_without_reset();
    test_packet_failure_waits_for_resolution();
    $display("PASS: ALL TESTS PASSED");
    $finish;
  end

endmodule
