`timescale 1ns / 1ps

module tb_order_risk_engine;

  localparam time CLK_PERIOD = 6.206ns;

  localparam logic [31:0] ORDER_SIDE_BUY = 32'd1;
  localparam logic [31:0] ORDER_SIDE_SELL = 32'd2;

  localparam logic [2:0] SYMBOL_TRADING = 3'd4;

  localparam logic [31:0] DECISION_ACCEPT = 32'd1;
  localparam logic [31:0] DECISION_REJECT = 32'd2;

  localparam logic [31:0] REJECT_NONE = 32'h0;
  localparam logic [31:0] REJECT_STREAM_FAULT = 32'h1;
  localparam logic [31:0] REJECT_PROTOCOL_VIOLATION = 32'h2;
  localparam logic [31:0] REJECT_UNKNOWN_SYMBOL = 32'h3;
  localparam logic [31:0] REJECT_SYMBOL_DISABLED = 32'h4;
  localparam logic [31:0] REJECT_SYMBOL_NOT_TRADING = 32'h5;
  localparam logic [31:0] REJECT_TOB_INVALID = 32'h6;
  localparam logic [31:0] REJECT_INVALID_SIDE = 32'h7;
  localparam logic [31:0] REJECT_ZERO_QUANTITY = 32'h8;
  localparam logic [31:0] REJECT_MAX_QUANTITY = 32'h9;
  localparam logic [31:0] REJECT_ZERO_PRICE = 32'hA;
  localparam logic [31:0] REJECT_PRICE_BAND = 32'hB;
  localparam logic [31:0] REJECT_MAX_NOTIONAL = 32'hC;
  localparam logic [31:0] REJECT_SESSION_NOT_TRADING = 32'hD;

  localparam logic [31:0] GOOD_SEQUENCE_NUMBER = 32'd100;
  localparam logic [15:0] GOOD_SYMBOL_ID = 16'd123;
  localparam logic [31:0] GOOD_INTENT_ID = 32'h1234_5678;

  localparam logic [31:0] BID_PRICE = 32'd1_000_000;
  localparam logic [31:0] ASK_PRICE = 32'd1_000_100;
  localparam logic [31:0] ORDER_QUANTITY = 32'd10;
  localparam logic [31:0] MAX_ORDER_QUANTITY = 32'd100;
  localparam logic [63:0] MAX_NOTIONAL = 64'd1_000_000_000;
  localparam logic [31:0] PRICE_BAND = 32'd100;

  localparam logic [63:0] GOOD_ORDER_NOTIONAL = 64'd10_001_000;


  logic clk;
  logic rst;

  logic order_valid;
  logic order_protocol_violation;
  logic [31:0] order_sequence_number;
  logic [15:0] order_symbol_id;
  logic [31:0] order_side;
  logic [31:0] order_price;
  logic [31:0] order_quantity;
  logic [31:0] order_intent_id;

  logic effective_stream_fault;
  logic market_hours_active;

  logic lookup_valid;
  logic lookup_symbol_known;
  logic lookup_symbol_enabled;
  logic [2:0] lookup_symbol_status;

  logic lookup_bid_valid;
  logic lookup_ask_valid;
  logic [31:0] lookup_bid_price;
  logic [31:0] lookup_ask_price;

  logic [31:0] lookup_max_order_quantity;
  logic [63:0] lookup_max_notional;
  logic [31:0] lookup_max_price_band_ticks;

  logic decision_valid;
  logic [31:0] decision_sequence_number;
  logic [15:0] decision_symbol_id;
  logic [31:0] decision_intent_id;
  logic [31:0] decision;
  logic [31:0] reject_reason;


  order_risk_engine dut (
      .clk(clk),
      .rst(rst),

      .order_valid(order_valid),
      .order_protocol_violation(order_protocol_violation),
      .order_sequence_number(order_sequence_number),
      .order_symbol_id(order_symbol_id),
      .order_side(order_side),
      .order_price(order_price),
      .order_quantity(order_quantity),
      .order_intent_id(order_intent_id),
      .effective_stream_fault(effective_stream_fault),
      .market_hours_active(market_hours_active),
      .lookup_valid(lookup_valid),
      .lookup_symbol_known(lookup_symbol_known),
      .lookup_symbol_enabled(lookup_symbol_enabled),
      .lookup_symbol_status(lookup_symbol_status),
      .lookup_bid_valid(lookup_bid_valid),
      .lookup_ask_valid(lookup_ask_valid),
      .lookup_bid_price(lookup_bid_price),
      .lookup_ask_price(lookup_ask_price),
      .lookup_max_order_quantity(lookup_max_order_quantity),
      .lookup_max_notional(lookup_max_notional),
      .lookup_max_price_band_ticks(lookup_max_price_band_ticks),
      .decision_valid(decision_valid),
      .decision_sequence_number(decision_sequence_number),
      .decision_symbol_id(decision_symbol_id),
      .decision_intent_id(decision_intent_id),
      .decision(decision),
      .reject_reason(reject_reason)
  );


  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;


  task automatic set_valid_inputs;
    begin
      order_valid = 1'b0;
      order_protocol_violation = 1'b0;
      order_sequence_number = GOOD_SEQUENCE_NUMBER;
      order_symbol_id = GOOD_SYMBOL_ID;
      order_side = ORDER_SIDE_BUY;
      order_price = ASK_PRICE;
      order_quantity = ORDER_QUANTITY;
      order_intent_id = GOOD_INTENT_ID;

      effective_stream_fault = 1'b0;
      market_hours_active = 1'b1;

      lookup_valid = 1'b0;
      lookup_symbol_known = 1'b1;
      lookup_symbol_enabled = 1'b1;
      lookup_symbol_status = SYMBOL_TRADING;

      lookup_bid_valid = 1'b1;
      lookup_ask_valid = 1'b1;
      lookup_bid_price = BID_PRICE;
      lookup_ask_price = ASK_PRICE;

      lookup_max_order_quantity = MAX_ORDER_QUANTITY;
      lookup_max_notional = MAX_NOTIONAL;
      lookup_max_price_band_ticks = PRICE_BAND;
    end
  endtask


  task automatic initialize_inputs;
    begin
      rst = 1'b0;
      set_valid_inputs();
    end
  endtask


  task automatic apply_reset;
    begin
      @(negedge clk);
      set_valid_inputs();
      rst = 1'b1;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask


  task automatic check_no_decision(input string check_label);
    begin
      if (decision_valid !== 1'b0) $fatal(1, "%s: unexpected decision_valid", check_label);
    end
  endtask


  task automatic check_decision(input logic [31:0] expected_decision, input logic [31:0] expected_reject_reason, input logic [31:0] expected_sequence_number, input logic [15:0] expected_symbol_id, input logic [31:0] expected_intent_id, input string check_label);
    begin
      if (decision_valid !== 1'b1) $fatal(1, "%s: decision_valid was not asserted", check_label);
      if (decision !== expected_decision) $fatal(1, "%s: expected decision %08h, received %08h", check_label, expected_decision, decision);
      if (reject_reason !== expected_reject_reason) $fatal(1, "%s: expected reject reason %08h, received %08h", check_label, expected_reject_reason, reject_reason);
      if (decision_sequence_number !== expected_sequence_number) $fatal(1, "%s: expected sequence %08h, received %08h", check_label, expected_sequence_number, decision_sequence_number);
      if (decision_symbol_id !== expected_symbol_id) $fatal(1, "%s: expected symbol %04h, received %04h", check_label, expected_symbol_id, decision_symbol_id);
      if (decision_intent_id !== expected_intent_id) $fatal(1, "%s: expected intent %08h, received %08h", check_label, expected_intent_id, decision_intent_id);
    end
  endtask


  task automatic run_current_order(input logic [31:0] expected_decision, input logic [31:0] expected_reject_reason, input string check_label);
    logic [31:0] expected_sequence_number;
    logic [15:0] expected_symbol_id;
    logic [31:0] expected_intent_id;

    begin
      expected_sequence_number = order_sequence_number;
      expected_symbol_id = order_symbol_id;
      expected_intent_id = order_intent_id;

      @(negedge clk);
      order_valid = 1'b1;
      lookup_valid = 1'b0;

      @(posedge clk);
      #1ps;

      if (decision_valid !== 1'b0) $fatal(1, "%s: decision produced before lookup", check_label);

      @(negedge clk);
      order_valid = 1'b0;
      lookup_valid = 1'b1;

      @(posedge clk);
      #1ps;

      check_decision(expected_decision, expected_reject_reason, expected_sequence_number, expected_symbol_id, expected_intent_id, check_label);

      @(negedge clk);
      lookup_valid = 1'b0;

      @(posedge clk);
      #1ps;
      if (decision_valid !== 1'b0) $fatal(1, "%s: decision_valid remained asserted", check_label);

    end
  endtask


  task automatic test_reset_and_idle;
    begin
      /*
      Purpose:
      Verify reset and idle behavior.

      Input:
      Reset followed by idle cycles.

      Expected output:
      Outputs reset to zero and no decision is produced.
      */

      $display("TEST: reset and idle");

      apply_reset();

      if ((decision_valid !== 1'b0) || (decision_sequence_number !== 32'h0) || (decision_symbol_id !== 16'h0) || (decision_intent_id !== 32'h0) || (decision !== 32'h0) || (reject_reason !== 32'h0)) $fatal(1, "Reset outputs are incorrect");

      repeat (2) begin
        @(posedge clk);
        #1ps;
        check_no_decision("idle");
      end

      $display("PASS: reset and idle");
    end
  endtask


  task automatic test_valid_buy;
    begin
      /*
      Purpose:
      Verify acceptance of a valid BUY order.

      Input:
      Valid order and symbol state using the ask as the price reference.

      Expected output:
      ACCEPT with reject reason NONE and matching identifiers.
      */

      $display("TEST: valid BUY");

      apply_reset();
      set_valid_inputs();

      run_current_order(DECISION_ACCEPT, REJECT_NONE, "valid BUY");

      $display("PASS: valid BUY");
    end
  endtask


  task automatic test_valid_sell;
    begin
      /*
      Purpose:
      Verify acceptance of a valid SELL order.

      Input:
      Valid order and symbol state using the bid as the price reference.

      Expected output:
      ACCEPT with reject reason NONE.
      */

      $display("TEST: valid SELL");

      apply_reset();
      set_valid_inputs();

      order_side = ORDER_SIDE_SELL;
      order_price = BID_PRICE;

      run_current_order(DECISION_ACCEPT, REJECT_NONE, "valid SELL");

      $display("PASS: valid SELL");
    end
  endtask


  task automatic test_reject_reasons;
    begin
      /*
      Purpose:
      Verify every documented rejection reason.

      Input:
      One order for each rejection condition.

      Expected output:
      REJECT with the corresponding reason code.
      */

      $display("TEST: reject reasons");

      apply_reset();

      set_valid_inputs();
      effective_stream_fault = 1'b1;
      run_current_order(DECISION_REJECT, REJECT_STREAM_FAULT, "stream fault");

      set_valid_inputs();
      order_protocol_violation = 1'b1;
      run_current_order(DECISION_REJECT, REJECT_PROTOCOL_VIOLATION, "protocol violation");

      set_valid_inputs();
      market_hours_active = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_SESSION_NOT_TRADING, "session not trading");

      set_valid_inputs();
      lookup_symbol_known = 1'b0;
      lookup_symbol_enabled = 1'b0;
      lookup_symbol_status = 3'd0;
      lookup_bid_valid = 1'b0;
      lookup_ask_valid = 1'b0;
      lookup_bid_price = '0;
      lookup_ask_price = '0;
      lookup_max_order_quantity = '0;
      lookup_max_notional = '0;
      lookup_max_price_band_ticks = '0;
      run_current_order(DECISION_REJECT, REJECT_UNKNOWN_SYMBOL, "unknown symbol");

      set_valid_inputs();
      lookup_symbol_enabled = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_SYMBOL_DISABLED, "symbol disabled");

      set_valid_inputs();
      lookup_symbol_status = 3'd2;
      run_current_order(DECISION_REJECT, REJECT_SYMBOL_NOT_TRADING, "symbol not trading");

      set_valid_inputs();
      order_side = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_INVALID_SIDE, "invalid order side");

      set_valid_inputs();
      order_quantity = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_ZERO_QUANTITY, "zero quantity");

      set_valid_inputs();
      order_price = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_ZERO_PRICE, "zero price");

      set_valid_inputs();
      lookup_ask_valid = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_TOB_INVALID, "BUY ask invalid");

      set_valid_inputs();
      order_side = ORDER_SIDE_SELL;
      order_price = BID_PRICE;
      lookup_bid_valid = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_TOB_INVALID, "SELL bid invalid");

      set_valid_inputs();
      order_quantity = MAX_ORDER_QUANTITY + 32'd1;
      run_current_order(DECISION_REJECT, REJECT_MAX_QUANTITY, "maximum quantity exceeded");

      set_valid_inputs();
      order_price = ASK_PRICE + PRICE_BAND + 32'd1;
      run_current_order(DECISION_REJECT, REJECT_PRICE_BAND, "BUY price band violation");

      set_valid_inputs();
      order_side = ORDER_SIDE_SELL;
      order_price = BID_PRICE - PRICE_BAND - 32'd1;
      run_current_order(DECISION_REJECT, REJECT_PRICE_BAND, "SELL price band violation");

      set_valid_inputs();
      lookup_max_notional = GOOD_ORDER_NOTIONAL - 64'd1;
      run_current_order(DECISION_REJECT, REJECT_MAX_NOTIONAL, "maximum notional exceeded");

      $display("PASS: reject reasons");
    end
  endtask


  task automatic test_limit_boundaries;
    begin
      /*
      Purpose:
      Verify equality at each configured limit and correct TOB-side selection.

      Input:
      Orders exactly on quantity, notional and price-band boundaries.

      Expected output:
      Boundary orders are accepted. BUY uses only the ask and SELL uses only the bid.
      */

      $display("TEST: limit boundaries");

      apply_reset();

      set_valid_inputs();
      lookup_max_order_quantity = ORDER_QUANTITY;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "quantity equal to maximum");

      set_valid_inputs();
      lookup_max_notional = GOOD_ORDER_NOTIONAL;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "notional equal to maximum");

      set_valid_inputs();
      order_price = ASK_PRICE + PRICE_BAND;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "BUY at price-band boundary");

      set_valid_inputs();
      order_side = ORDER_SIDE_SELL;
      order_price = BID_PRICE - PRICE_BAND;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "SELL at price-band boundary");

      set_valid_inputs();
      lookup_bid_valid = 1'b0;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "BUY ignores invalid bid");

      set_valid_inputs();
      order_side = ORDER_SIDE_SELL;
      order_price = BID_PRICE;
      lookup_ask_valid = 1'b0;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "SELL ignores invalid ask");

      $display("PASS: limit boundaries");
    end
  endtask


  task automatic test_arithmetic_width;
    begin
      /*
      Purpose:
      Verify full-width notional and price-band arithmetic.

      Input:
      Values that would fail if multiplication, addition or subtraction
      wrapped at 32 bits.

      Expected output:
      Decisions follow the mathematical 64-bit and 33-bit results.
      */

      $display("TEST: arithmetic width");

      apply_reset();

      set_valid_inputs();
      order_price = 32'h8000_0000;
      order_quantity = 32'd2;
      lookup_ask_price = 32'hFFFF_FFFF;
      lookup_max_order_quantity = 32'd2;
      lookup_max_notional = 64'h0000_0001_0000_0000;
      lookup_max_price_band_ticks = 32'd0;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "64-bit notional equality");

      set_valid_inputs();
      order_price = 32'h8000_0000;
      order_quantity = 32'd2;
      lookup_ask_price = 32'hFFFF_FFFF;
      lookup_max_order_quantity = 32'd2;
      lookup_max_notional = 64'h0000_0000_FFFF_FFFF;
      lookup_max_price_band_ticks = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_MAX_NOTIONAL, "64-bit notional exceeded");

      set_valid_inputs();
      order_price = 32'hFFFF_FFFF;
      order_quantity = 32'd1;
      lookup_ask_price = 32'hFFFF_FFF0;
      lookup_max_order_quantity = 32'd1;
      lookup_max_notional = 64'hFFFF_FFFF_FFFF_FFFF;
      lookup_max_price_band_ticks = 32'h0000_0020;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "BUY price-band addition overflow");

      set_valid_inputs();
      order_side = ORDER_SIDE_SELL;
      order_price = 32'd1;
      order_quantity = 32'd1;
      lookup_bid_price = 32'd10;
      lookup_max_order_quantity = 32'd1;
      lookup_max_notional = 64'hFFFF_FFFF_FFFF_FFFF;
      lookup_max_price_band_ticks = 32'd20;
      run_current_order(DECISION_ACCEPT, REJECT_NONE, "SELL price-band subtraction underflow");

      $display("PASS: arithmetic width");
    end
  endtask


  task automatic test_reject_priority;
    begin
      /*
      Purpose:
      Verify the documented reject-reason priority.

      Input:
      Adjacent rejection conditions asserted together.

      Expected output:
      The higher-priority reason is selected.
      */

      $display("TEST: reject priority");

      apply_reset();

      set_valid_inputs();
      effective_stream_fault = 1'b1;
      order_protocol_violation = 1'b1;
      run_current_order(DECISION_REJECT, REJECT_STREAM_FAULT, "stream fault over protocol violation");

      set_valid_inputs();
      order_protocol_violation = 1'b1;
      market_hours_active = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_PROTOCOL_VIOLATION, "protocol violation over session");

      set_valid_inputs();
      market_hours_active = 1'b0;
      lookup_symbol_known = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_SESSION_NOT_TRADING, "session over unknown symbol");

      set_valid_inputs();
      lookup_symbol_known = 1'b0;
      lookup_symbol_enabled = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_UNKNOWN_SYMBOL, "unknown symbol over disabled");

      set_valid_inputs();
      lookup_symbol_enabled = 1'b0;
      lookup_symbol_status = 3'd0;
      run_current_order(DECISION_REJECT, REJECT_SYMBOL_DISABLED, "disabled over symbol status");

      set_valid_inputs();
      lookup_symbol_status = 3'd0;
      order_side = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_SYMBOL_NOT_TRADING, "symbol status over invalid side");

      set_valid_inputs();
      order_side = 32'd0;
      order_quantity = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_INVALID_SIDE, "invalid side over zero quantity");

      set_valid_inputs();
      order_quantity = 32'd0;
      order_price = 32'd0;
      run_current_order(DECISION_REJECT, REJECT_ZERO_QUANTITY, "zero quantity over zero price");

      set_valid_inputs();
      order_price = 32'd0;
      lookup_ask_valid = 1'b0;
      run_current_order(DECISION_REJECT, REJECT_ZERO_PRICE, "zero price over invalid TOB");

      set_valid_inputs();
      lookup_ask_valid = 1'b0;
      order_quantity = MAX_ORDER_QUANTITY + 32'd1;
      run_current_order(DECISION_REJECT, REJECT_TOB_INVALID, "invalid TOB over maximum quantity");

      set_valid_inputs();
      order_quantity = MAX_ORDER_QUANTITY + 32'd1;
      order_price = ASK_PRICE + PRICE_BAND + 32'd1;
      run_current_order(DECISION_REJECT, REJECT_MAX_QUANTITY, "maximum quantity over price band");

      set_valid_inputs();
      order_price = ASK_PRICE + PRICE_BAND + 32'd1;
      lookup_max_notional = 64'd0;
      run_current_order(DECISION_REJECT, REJECT_PRICE_BAND, "price band over maximum notional");

      $display("PASS: reject priority");
    end
  endtask


  task automatic test_back_to_back_orders;
    begin
      /*
      Purpose:
      Verify one order per clock without crossing order and lookup data.

      Input:
      A valid order immediately followed by an over-limit order.

      Expected output:
      Consecutive decisions: ACCEPT for the first order and maximum-quantity
      REJECT for the second, with the correct identifiers.
      */

      $display("TEST: back-to-back orders");

      apply_reset();
      set_valid_inputs();

      @(negedge clk);
      order_valid = 1'b1;
      lookup_valid = 1'b0;

      @(posedge clk);
      #1ps;
      check_no_decision("before first lookup");

      @(negedge clk);
      lookup_valid = 1'b1;

      order_sequence_number = 32'd101;
      order_symbol_id = 16'd124;
      order_quantity = 32'd11;
      order_intent_id = 32'h8765_4321;

      @(posedge clk);
      #1ps;
      check_decision(DECISION_ACCEPT, REJECT_NONE, GOOD_SEQUENCE_NUMBER, GOOD_SYMBOL_ID, GOOD_INTENT_ID, "first back-to-back order");

      @(negedge clk);
      order_valid = 1'b0;
      lookup_max_order_quantity = 32'd10;

      @(posedge clk);
      #1ps;
      check_decision(DECISION_REJECT, REJECT_MAX_QUANTITY, 32'd101, 16'd124, 32'h8765_4321, "second back-to-back order");

      @(negedge clk);
      lookup_valid = 1'b0;

      @(posedge clk);
      #1ps;
      check_no_decision("after back-to-back orders");

      $display("PASS: back-to-back orders");
    end
  endtask


  initial begin
    initialize_inputs();
    test_reset_and_idle();
    test_valid_buy();
    test_valid_sell();
    test_reject_reasons();
    test_limit_boundaries();
    test_arithmetic_width();
    test_reject_priority();
    test_back_to_back_orders();

    $display("PASS: all order risk engine tests");
    $finish;
  end

endmodule
