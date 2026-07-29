`timescale 1ns / 1ps

module tb_pcs_rx_block_decoder;

  localparam time CLK_PERIOD = 6.206ns;

  localparam logic [1:0] SYNC_DATA = 2'b01;
  localparam logic [1:0] SYNC_CTRL = 2'b10;

  localparam logic [63:0] IDLE_BLOCK = 64'h0000_0000_0000_001E;
  localparam logic [63:0] START_0_BLOCK = 64'hA6A5_A4A3_A2A1_A0_78;
  localparam logic [63:0] DATA_BLOCK = 64'hB7B6_B5B4_B3B2_B1B0;
  localparam logic [63:0] TERM_3_BLOCK = 64'h0000_0000_D2D1_D0B4;
  localparam logic [63:0] START_4_BLOCK = 64'hC2C1_C0_0000_0000_33;
  localparam logic [63:0] TERM_0_BLOCK = 64'h0000_0000_0000_0087;
  localparam logic [63:0] MALFORMED_CTRL_BLOCK = 64'h0000_0000_0000_011E;

  logic clk;
  logic rst;

  logic [63:0] descrambled_payload;
  logic [1:0] descrambled_header;
  logic descrambled_valid;

  logic [63:0] frame_data;
  logic [7:0] frame_keep;
  logic frame_start;
  logic frame_end;
  logic frame_valid;
  logic frame_abort;
  logic bad_block;
  logic sequence_error;

  pcs_rx_block_decoder dut (
      .clk(clk),
      .rst(rst),
      .descrambled_payload(descrambled_payload),
      .descrambled_header(descrambled_header),
      .descrambled_valid(descrambled_valid),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_abort(frame_abort),
      .bad_block(bad_block),
      .sequence_error(sequence_error)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;

  // Converts the decoder's normalized chronological representation
  // back into the MSB-first representation produced by the descrambler
  function automatic logic [63:0] to_descrambler_order(input logic [63:0] normalized_block);
    for (int i = 0; i < 64; i++) begin
      to_descrambler_order[63-i] = normalized_block[i];
    end
  endfunction

  task automatic initialize_inputs;
    begin
      rst = 1'b0;
      descrambled_payload = '0;
      descrambled_header = '0;
      descrambled_valid = 1'b0;
    end
  endtask

  function automatic logic [7:0] term_block_type(input int unsigned byte_count);
    begin
      case (byte_count)
        0: term_block_type = 8'h87;
        1: term_block_type = 8'h99;
        2: term_block_type = 8'hAA;
        3: term_block_type = 8'hB4;
        4: term_block_type = 8'hCC;
        5: term_block_type = 8'hD2;
        6: term_block_type = 8'hE1;
        7: term_block_type = 8'hFF;
        default: term_block_type = 8'h00;
      endcase
    end
  endfunction

  task automatic apply_reset;
    begin
      @(negedge clk);

      descrambled_payload = '0;
      descrambled_header = '0;
      descrambled_valid = 1'b0;
      rst = 1'b1;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      #1ps;
    end
  endtask

  // Presents one block during the cycle before the decoder state commits.
  // Because decoder outputs are combinational, check them after this task
  // and before calling commit_block()
  task automatic present_block(input logic [63:0] normalized_block, input logic [1:0] header, input logic valid);
    begin
      @(negedge clk);

      descrambled_payload = to_descrambler_order(normalized_block);
      descrambled_header = header;
      descrambled_valid = valid;

      #1ps;
    end
  endtask

  // Advances the sequential frame-state register.
  task automatic commit_block;
    begin
      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic test_complete_frame;
    begin
      $display("TEST: complete frame");

      apply_reset();

      // Inter-frame idle block: no frame-byte event.
      present_block(IDLE_BLOCK, SYNC_CTRL, 1'b1);
      if (frame_valid !== 1'b0) $fatal(1, "Idle block unexpectedly produced frame data");
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "Idle error: bad_block=%b sequence_error=%b inside_frame=%b inside_frame_next=%b block_type=%h normalized_data=%h", bad_block, sequence_error, dut.inside_frame, dut.inside_frame_next, dut.block_type, dut.normalized_data);

      commit_block();
      if (dut.inside_frame !== 1'b0) $fatal(1, "Idle block left decoder inside a frame: inside_frame=%b", dut.inside_frame);

      // START in lane 0 followed by seven frame bytes.
      present_block(START_0_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b1) $fatal(1, "START_0 did not produce a valid beat");
      if (frame_start !== 1'b1 || frame_end !== 1'b0) $fatal(1, "Incorrect START_0 boundary flags");
      if (frame_keep !== 8'h7F) $fatal(1, "Incorrect START_0 keep mask: %h", frame_keep);
      if (frame_data !== 64'h00A6_A5A4_A3A2_A1A0) $fatal(1, "Incorrect START_0 data: expected %h, received %h", 64'h00A6_A5A4_A3A2_A1A0, frame_data);
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "START_0 error: bad_block=%b sequence_error=%b inside_frame=%b inside_frame_next=%b block_type=%h normalized_data=%h", bad_block, sequence_error, dut.inside_frame, dut.inside_frame_next, dut.block_type, dut.normalized_data);

      commit_block();

      // Ordinary data block while inside the frame.
      present_block(DATA_BLOCK, SYNC_DATA, 1'b1);
      if (frame_valid !== 1'b1) $fatal(1, "Data block did not produce a valid beat");
      if (frame_start !== 1'b0 || frame_end !== 1'b0) $fatal(1, "Data block produced a boundary flag");
      if (frame_keep !== 8'hFF) $fatal(1, "Incorrect data-block keep mask: %h", frame_keep);
      if (frame_data !== DATA_BLOCK) $fatal(1, "Incorrect data-block output: expected %h, received %h", DATA_BLOCK, frame_data);
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "Data block produced an unexpected error");

      commit_block();

      // Three final data bytes followed by TERMINATE.
      present_block(TERM_3_BLOCK, SYNC_CTRL, 1'b1);
      if (frame_valid !== 1'b1) $fatal(1, "TERM_3 did not produce a valid boundary event");
      if (frame_start !== 1'b0 || frame_end !== 1'b1) $fatal(1, "Incorrect TERM_3 boundary flags");
      if (frame_keep !== 8'h07) $fatal(1, "Incorrect TERM_3 keep mask: %h", frame_keep);
      if (frame_data !== 64'h0000_0000_00D2_D1D0) $fatal(1, "Incorrect TERM_3 data: expected %h, received %h", 64'h0000_0000_00D2_D1D0, frame_data);
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "TERM_3 produced an unexpected error");

      commit_block();

      // Prove that termination returned the decoder to idle state.
      present_block(IDLE_BLOCK, SYNC_CTRL, 1'b1);
      if (frame_valid !== 1'b0) $fatal(1, "Post-frame idle produced frame data");
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "Post-frame idle produced an error");

      commit_block();

      $display("PASS: complete frame");
    end
  endtask

  task automatic test_start_4_and_term_0;
    begin
      $display("TEST: START_4 and TERM_0");

      apply_reset();

      // START occupies PCS lane 4. Three frame bytes follow it.
      present_block(START_4_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b1) $fatal(1, "START_4 did not produce a valid beat");
      if (frame_start !== 1'b1 || frame_end !== 1'b0) $fatal(1, "Incorrect START_4 boundary flags: start=%b end=%b", frame_start, frame_end);
      if (frame_keep !== 8'h07) $fatal(1, "Incorrect START_4 keep mask: expected 07, received %h", frame_keep);
      if (frame_data !== 64'h0000_0000_00C2_C1C0) $fatal(1, "Incorrect START_4 data: expected %h, received %h", 64'h0000_0000_00C2_C1C0, frame_data);
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "START_4 error: bad_block=%b sequence_error=%b inside_frame=%b inside_frame_next=%b", bad_block, sequence_error, dut.inside_frame, dut.inside_frame_next);

      commit_block();
      if (dut.inside_frame !== 1'b1) $fatal(1, "START_4 did not enter frame state");

      // TERM_0 carries no final frame bytes.
      present_block(TERM_0_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b1) $fatal(1, "TERM_0 did not produce a boundary event");
      if (frame_start !== 1'b0 || frame_end !== 1'b1) $fatal(1, "Incorrect TERM_0 boundary flags: start=%b end=%b", frame_start, frame_end);
      if (frame_keep !== 8'h00) $fatal(1, "Incorrect TERM_0 keep mask: expected 00, received %h", frame_keep);
      if (frame_data !== 64'h0) $fatal(1, "TERM_0 unexpectedly produced frame data: %h", frame_data);
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "TERM_0 error: bad_block=%b sequence_error=%b inside_frame=%b inside_frame_next=%b", bad_block, sequence_error, dut.inside_frame, dut.inside_frame_next);

      commit_block();

      if (dut.inside_frame !== 1'b0) $fatal(1, "TERM_0 did not leave frame state");

      $display("PASS: START_4 and TERM_0");
    end
  endtask


  task automatic test_data_outside_frame;
    begin
      $display("TEST: data outside frame");

      apply_reset();

      present_block(DATA_BLOCK, SYNC_DATA, 1'b1);

      if (frame_valid !== 1'b0) $fatal(1, "Stray data block unexpectedly produced frame data");
      if (bad_block !== 1'b0) $fatal(1, "Stray data block was incorrectly marked malformed");
      if (sequence_error !== 1'b1) $fatal(1, "Stray data block did not assert sequence_error");
      if (dut.inside_frame_next !== 1'b0) $fatal(1, "Stray data block changed frame state");

      commit_block();
      if (dut.inside_frame !== 1'b0) $fatal(1, "Decoder entered frame state after stray data");

      $display("PASS: data outside frame");
    end
  endtask

  task automatic test_term_outside_frame;
    begin
      $display("TEST: TERM outside frame");

      apply_reset();

      present_block(TERM_3_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b0) $fatal(1, "Stray TERM unexpectedly produced a frame event");
      if (bad_block !== 1'b0) $fatal(1, "Stray TERM was incorrectly marked malformed");
      if (sequence_error !== 1'b1) $fatal(1, "Stray TERM did not assert sequence_error");
      if (dut.inside_frame_next !== 1'b0) $fatal(1, "Stray TERM changed frame state");

      commit_block();

      if (dut.inside_frame !== 1'b0) $fatal(1, "Decoder entered frame state after stray TERM");

      $display("PASS: TERM outside frame");
    end
  endtask

  task automatic test_start_while_inside_frame;
    begin
      $display("TEST: START while inside frame");

      apply_reset();

      // Enter a frame normally.
      present_block(START_0_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b1 || frame_start !== 1'b1) $fatal(1, "Initial START_0 did not begin a frame");
      if (frame_abort !== 1'b0) $fatal(1, "Initial START_0 incorrectly asserted frame_abort");

      commit_block();

      if (dut.inside_frame !== 1'b1) $fatal(1, "Initial START_0 did not enter frame state");

      // A second START invalidates the current frame
      // The offending START block is discarded rather than reused as a new boundary
      present_block(START_4_BLOCK, SYNC_CTRL, 1'b1);

      if (sequence_error !== 1'b1) $fatal(1, "Repeated START did not assert sequence_error");
      if (bad_block !== 1'b0) $fatal(1, "Repeated START was incorrectly marked malformed");
      if (frame_abort !== 1'b1) $fatal(1, "Repeated START did not abort the active frame");
      if (frame_valid !== 1'b0) $fatal(1, "Repeated START emitted frame data during abort");
      if (frame_start !== 1'b0 || frame_end !== 1'b0) $fatal(1, "Repeated START emitted boundary flags during abort");
      if (frame_keep !== 8'h00) $fatal(1, "Repeated START emitted a keep mask during abort");
      if (dut.inside_frame_next !== 1'b0) $fatal(1, "Repeated START did not leave the frame state");
      commit_block();

      if (dut.inside_frame !== 1'b0) $fatal(1, "Decoder remained inside frame after repeated START");

      $display("PASS: START while inside frame");
    end
  endtask

  task automatic test_malformed_control_block;
    begin
      $display("TEST: malformed control block");

      apply_reset();

      present_block(MALFORMED_CTRL_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b0) $fatal(1, "Malformed control block produced frame data");
      if (bad_block !== 1'b1) $fatal(1, "Malformed control block did not assert bad_block");
      if (sequence_error !== 1'b0) $fatal(1, "Malformed control block incorrectly asserted sequence_error");
      if (dut.inside_frame_next !== 1'b0) $fatal(1, "Malformed control block changed frame state");

      commit_block();

      if (dut.inside_frame !== 1'b0) $fatal(1, "Decoder entered frame state after malformed control block");

      $display("PASS: malformed control block");
    end
  endtask

  task automatic test_illegal_sync_header;
    begin
      $display("TEST: illegal sync header");

      apply_reset();

      present_block(DATA_BLOCK, 2'b00, 1'b1);

      if (frame_valid !== 1'b0) $fatal(1, "Illegal sync header produced frame data");
      if (bad_block !== 1'b1) $fatal(1, "Illegal sync header did not assert bad_block");
      if (sequence_error !== 1'b0) $fatal(1, "Illegal sync header incorrectly asserted sequence_error");
      if (dut.inside_frame_next !== 1'b0) $fatal(1, "Illegal sync header changed frame state");

      commit_block();

      if (dut.inside_frame !== 1'b0) $fatal(1, "Decoder entered frame state after illegal sync header");

      $display("PASS: illegal sync header");
    end
  endtask

  task automatic test_invalid_cycle_holds_state;
    begin
      $display("TEST: invalid cycle holds state");

      apply_reset();

      // Enter a frame.
      present_block(START_0_BLOCK, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b1 || frame_start !== 1'b1) $fatal(1, "Initial START_0 did not begin a frame");

      commit_block();

      if (dut.inside_frame !== 1'b1) $fatal(1, "Decoder did not enter frame state");

      // Payload and header are deliberately meaningless while valid is low.
      present_block(64'hFFFF_FFFF_FFFF_FFFF, 2'b00, 1'b0);

      if (frame_valid !== 1'b0) $fatal(1, "Invalid cycle produced a frame event");
      if (frame_start !== 1'b0 || frame_end !== 1'b0) $fatal(1, "Invalid cycle produced a boundary flag");
      if (frame_keep !== 8'h00) $fatal(1, "Invalid cycle produced a keep mask");
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "Invalid cycle produced an error");
      if (dut.inside_frame_next !== 1'b1) $fatal(1, "Invalid cycle changed frame state");

      commit_block();

      if (dut.inside_frame !== 1'b1) $fatal(1, "Decoder lost frame state across invalid cycle");

      // Confirm normal decoding resumes afterward.
      present_block(DATA_BLOCK, SYNC_DATA, 1'b1);

      if (frame_valid !== 1'b1 || frame_keep !== 8'hFF) $fatal(1, "Decoder did not resume after invalid cycle");
      if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "Post-bubble data produced an error");

      commit_block();

      $display("PASS: invalid cycle holds state");
    end
  endtask

  task automatic test_all_term_positions;
    logic [63:0] normalized_term;
    logic [63:0] expected_data;
    logic [7:0] expected_keep;

    begin
      $display("TEST: all TERM positions");

      for (int unsigned byte_count = 0; byte_count <= 7; byte_count++) begin
        apply_reset();

        // Establish a valid frame before presenting TERMINATE.
        present_block(START_0_BLOCK, SYNC_CTRL, 1'b1);

        if (frame_valid !== 1'b1 || frame_start !== 1'b1) $fatal(1, "TERM_%0d setup START failed", byte_count);

        commit_block();
        normalized_term = '0;
        normalized_term[7:0] = term_block_type(byte_count);

        // Populate the final frame bytes immediately after block_type.
        for (int unsigned byte_index = 0; byte_index < byte_count; byte_index++) begin
          normalized_term[8+byte_index*8+:8] = 8'hD0 + byte_index;
        end

        expected_data = normalized_term >> 8;
        expected_keep = (8'h01 << byte_count) - 1'b1;

        present_block(normalized_term, SYNC_CTRL, 1'b1);

        if (frame_valid !== 1'b1) $fatal(1, "TERM_%0d did not produce a boundary event", byte_count);
        if (frame_start !== 1'b0 || frame_end !== 1'b1) $fatal(1, "TERM_%0d produced incorrect boundary flags", byte_count);
        if (frame_keep !== expected_keep) $fatal(1, "TERM_%0d keep mismatch: expected %h, received %h", byte_count, expected_keep, frame_keep);
        if (frame_data !== expected_data) $fatal(1, "TERM_%0d data mismatch: expected %h, received %h", byte_count, expected_data, frame_data);
        if (bad_block !== 1'b0 || sequence_error !== 1'b0) $fatal(1, "TERM_%0d produced an error: bad=%b sequence=%b", byte_count, bad_block, sequence_error);

        commit_block();

        if (dut.inside_frame !== 1'b0) $fatal(1, "TERM_%0d did not leave frame state", byte_count);
      end

      $display("PASS: all TERM positions");
    end
  endtask

  task automatic test_malformed_term_block;
    logic [63:0] malformed_term;

    begin
      $display("TEST: malformed TERM block");

      apply_reset();

      present_block(START_0_BLOCK, SYNC_CTRL, 1'b1);
      commit_block();

      if (dut.inside_frame !== 1'b1) $fatal(1, "Malformed TERM setup failed");

      // TERM_3 permits three final data bytes. Everything above bit 31
      // represents fields after TERMINATE and must be encoded IDLE.
      malformed_term = 64'h0000_0001_D2D1_D0B4;

      present_block(malformed_term, SYNC_CTRL, 1'b1);

      if (frame_valid !== 1'b0) $fatal(1, "Malformed TERM unexpectedly produced a frame event");
      if (bad_block !== 1'b1) $fatal(1, "Malformed TERM did not assert bad_block");
      if (frame_abort !== 1'b1) $fatal(1, "Malformed TERM did not abort the active frame");
      if (sequence_error !== 1'b0) $fatal(1, "Malformed TERM incorrectly asserted sequence_error");
      if (dut.inside_frame_next !== 1'b0) $fatal(1, "Malformed TERM did not abandon the current frame");

      commit_block();

      if (dut.inside_frame !== 1'b0) $fatal(1, "Decoder remained inside frame after malformed TERM");

      $display("PASS: malformed TERM block");
    end
  endtask


  initial begin
    initialize_inputs();
    test_complete_frame();
    test_start_4_and_term_0();
    test_data_outside_frame();
    test_term_outside_frame();
    test_start_while_inside_frame();
    test_malformed_control_block();
    test_illegal_sync_header();
    test_invalid_cycle_holds_state();
    test_all_term_positions();
    test_malformed_term_block();
    $display("PASS: all block decoder tests");
    $finish;
  end

endmodule
