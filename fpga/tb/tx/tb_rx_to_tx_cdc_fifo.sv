`timescale 1ns / 1ps

module tb_rx_to_tx_cdc_fifo;

  localparam time RX_CLK_PERIOD = 6.206ns;
  localparam time TX_CLK_PERIOD = 6.400ns;

  logic rx_clk;
  logic tx_clk;
  logic rst;

  logic rx_order_intent_valid;

  logic rx_decision_valid;
  logic [31:0] rx_decision_sequence_number;
  logic [15:0] rx_decision_symbol_id;
  logic [31:0] rx_decision_intent_id;
  logic [31:0] rx_decision;
  logic [31:0] rx_reject_reason;
  logic rx_source_frame_ok;

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


  rx_to_tx_cdc_fifo dut (
      .rx_clk(rx_clk),
      .tx_clk(tx_clk),
      .rst(rst),

      .rx_order_intent_valid(rx_order_intent_valid),

      .rx_decision_valid(rx_decision_valid),
      .rx_decision_sequence_number(rx_decision_sequence_number),
      .rx_decision_symbol_id(rx_decision_symbol_id),
      .rx_decision_intent_id(rx_decision_intent_id),
      .rx_decision(rx_decision),
      .rx_reject_reason(rx_reject_reason),
      .rx_source_frame_ok(rx_source_frame_ok),

      .tx_response_start_valid(tx_response_start_valid),
      .tx_response_start_ready(tx_response_start_ready),

      .tx_decision_valid(tx_decision_valid),
      .tx_decision_ready(tx_decision_ready),

      .tx_decision_sequence_number(tx_decision_sequence_number),
      .tx_decision_symbol_id(tx_decision_symbol_id),
      .tx_decision_intent_id(tx_decision_intent_id),
      .tx_decision(tx_decision),
      .tx_reject_reason(tx_reject_reason),
      .tx_source_frame_ok(tx_source_frame_ok)
  );


  initial begin
    rx_clk = 1'b0;
    forever #(RX_CLK_PERIOD / 2) rx_clk = ~rx_clk;
  end

  initial begin
    tx_clk = 1'b0;
    forever #(TX_CLK_PERIOD / 2) tx_clk = ~tx_clk;
  end


  task automatic initialize_inputs;
    begin
      rst = 1'b1;

      rx_order_intent_valid = 1'b0;

      rx_decision_valid = 1'b0;
      rx_decision_sequence_number = '0;
      rx_decision_symbol_id = '0;
      rx_decision_intent_id = '0;
      rx_decision = '0;
      rx_reject_reason = '0;
      rx_source_frame_ok = 1'b0;

      tx_response_start_ready = 1'b0;
      tx_decision_ready = 1'b0;
    end
  endtask


  task automatic apply_reset;
    begin
      @(negedge rx_clk);
      rst = 1'b1;
      rx_order_intent_valid = 1'b0;
      rx_decision_valid = 1'b0;
      tx_response_start_ready = 1'b0;
      tx_decision_ready = 1'b0;

      repeat (5) @(posedge rx_clk);

      @(negedge rx_clk);
      rst = 1'b0;

      // XPM reset crosses to the read domain and then acknowledges back to the write domain.
      fork
        begin
          repeat (64) @(posedge rx_clk);
        end
        begin
          repeat (64) @(posedge tx_clk);
        end
      join

      #1ps;
    end
  endtask


  task automatic send_start_event;
    begin
      @(negedge rx_clk);
      rx_order_intent_valid = 1'b1;

      @(negedge rx_clk);
      rx_order_intent_valid = 1'b0;
    end
  endtask


  task automatic send_decision_event(input logic [31:0] sequence_number, input logic [15:0] symbol_id, input logic [31:0] intent_id, input logic [31:0] decision_value, input logic [31:0] reject_reason, input logic source_frame_ok);
    begin
      @(negedge rx_clk);
      rx_decision_valid = 1'b1;
      rx_decision_sequence_number = sequence_number;
      rx_decision_symbol_id = symbol_id;
      rx_decision_intent_id = intent_id;
      rx_decision = decision_value;
      rx_reject_reason = reject_reason;
      rx_source_frame_ok = source_frame_ok;

      @(negedge rx_clk);
      rx_decision_valid = 1'b0;
    end
  endtask


  task automatic wait_for_start_event(input string label);
    int unsigned cycles;

    begin
      cycles = 0;

      while (!tx_response_start_valid && (cycles < 40)) begin
        if (tx_decision_valid) begin
          $fatal(1, "%s: DECISION appeared before START", label);
        end

        @(negedge tx_clk);
        cycles++;
      end

      if (!tx_response_start_valid) $fatal(1, "%s: timed out waiting for START", label);
    end
  endtask


  task automatic wait_for_decision_event(input string label);
    int unsigned cycles;

    begin
      cycles = 0;

      while (!tx_decision_valid && (cycles < 40)) begin
        if (tx_response_start_valid) begin
          $fatal(1, "%s: unexpected START before DECISION", label);
        end

        @(negedge tx_clk);
        cycles++;
      end

      if (!tx_decision_valid) $fatal(1, "%s: timed out waiting for DECISION", label);
    end
  endtask


  task automatic accept_start_event;
    begin
      if (!tx_response_start_valid) $fatal(1, "Attempted to accept START when it was not valid");

      @(negedge tx_clk);
      tx_response_start_ready = 1'b1;

      @(posedge tx_clk);
      #1ps;
      tx_response_start_ready = 1'b0;
    end
  endtask


  task automatic accept_decision_event;
    begin
      if (!tx_decision_valid) $fatal(1, "Attempted to accept DECISION when it was not valid");

      @(negedge tx_clk);
      tx_decision_ready = 1'b1;

      @(posedge tx_clk);
      #1ps;
      tx_decision_ready = 1'b0;
    end
  endtask


  task automatic check_no_tx_event(input string label);
    begin
      if (tx_response_start_valid !== 1'b0) $fatal(1, "%s: unexpected START event", label);
      if (tx_decision_valid !== 1'b0) $fatal(1, "%s: unexpected DECISION event", label);
    end
  endtask


  task automatic check_decision(input logic [31:0] expected_sequence_number, input logic [15:0] expected_symbol_id, input logic [31:0] expected_intent_id, input logic [31:0] expected_decision, input logic [31:0] expected_reject_reason, input logic expected_source_frame_ok, input string label);
    begin
      if (!tx_decision_valid) $fatal(1, "%s: DECISION is not valid", label);
      if (tx_decision_sequence_number !== expected_sequence_number) $fatal(1, "%s: sequence number mismatch", label);
      if (tx_decision_symbol_id !== expected_symbol_id) $fatal(1, "%s: symbol ID mismatch", label);
      if (tx_decision_intent_id !== expected_intent_id) $fatal(1, "%s: intent ID mismatch", label);
      if (tx_decision !== expected_decision) $fatal(1, "%s: decision mismatch", label);
      if (tx_reject_reason !== expected_reject_reason) $fatal(1, "%s: reject reason mismatch", label);
      if (tx_source_frame_ok !== expected_source_frame_ok) $fatal(1, "%s: source-frame integrity mismatch", label);
    end
  endtask


  task automatic test_reset_state;
    begin
      // Input: reset.
      // Expected: no TX-side events.

      $display("TEST: reset state");

      apply_reset();
      check_no_tx_event("after reset");

      $display("PASS: reset state");
    end
  endtask


  task automatic test_start_event_backpressure;
    begin
      // Input: one START event while TX ready is low.
      // Expected: START remains valid until accepted.

      $display("TEST: START event backpressure");

      send_start_event();
      wait_for_start_event("START crossing");

      repeat (3) begin
        @(negedge tx_clk);
        if (!tx_response_start_valid) $fatal(1, "START did not remain valid while ready was low");
      end

      accept_start_event();

      repeat (2) @(negedge tx_clk);
      check_no_tx_event("after accepting START");

      $display("PASS: START event backpressure");
    end
  endtask


  task automatic test_decision_transfer;
    begin
      // Input: START followed by one decision.
      // Expected: all decision fields cross unchanged and remain stable.

      $display("TEST: decision transfer");

      send_start_event();

      send_decision_event(32'h0102_0304, 16'h1122, 32'hA1A2_A3A4, 32'd1, 32'd0, 1'b1);

      wait_for_start_event("decision test START");
      accept_start_event();

      wait_for_decision_event("decision test DECISION");

      repeat (3) begin
        check_decision(32'h0102_0304, 16'h1122, 32'hA1A2_A3A4, 32'd1, 32'd0, 1'b1, "stalled decision");

        @(negedge tx_clk);
      end

      accept_decision_event();

      repeat (2) @(negedge tx_clk);
      check_no_tx_event("after accepting decision");

      $display("PASS: decision transfer");
    end
  endtask


  task automatic test_event_ordering;
    begin
      // Input: two complete START/DECISION pairs.
      // Expected: TX receives the same order and integrity association.

      $display("TEST: event ordering");

      send_start_event();

      send_decision_event(32'h1111_0001, 16'h1001, 32'hAAAA_0001, 32'd1, 32'd0, 1'b1);

      send_start_event();

      send_decision_event(32'h2222_0002, 16'h2002, 32'hBBBB_0002, 32'd2, 32'h0000_000B, 1'b0);

      wait_for_start_event("first START");
      accept_start_event();

      wait_for_decision_event("first DECISION");

      check_decision(32'h1111_0001, 16'h1001, 32'hAAAA_0001, 32'd1, 32'd0, 1'b1, "first DECISION");

      accept_decision_event();

      wait_for_start_event("second START");
      accept_start_event();

      wait_for_decision_event("second DECISION");

      check_decision(32'h2222_0002, 16'h2002, 32'hBBBB_0002, 32'd2, 32'h0000_000B, 1'b0, "second DECISION");

      accept_decision_event();

      repeat (2) @(negedge tx_clk);
      check_no_tx_event("after ordered events");

      $display("PASS: event ordering");
    end
  endtask


  initial begin
    initialize_inputs();

    test_reset_state();  // Performs the one startup reset
    test_start_event_backpressure();
    test_decision_transfer();
    test_event_ordering();

    $display("PASS: rx to tx CDC tests");
    $finish;
  end

endmodule
