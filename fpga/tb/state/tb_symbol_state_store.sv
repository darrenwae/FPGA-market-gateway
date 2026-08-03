`timescale 1ns / 1ps

module tb_symbol_state_store;

  localparam time CLK_PERIOD = 6.206ns;
  localparam int unsigned SYMBOL_COUNT = 16384;

  localparam logic [7:0] TOB_UPDATE = 8'h02;
  localparam logic [7:0] SYMBOL_STATUS = 8'h03;
  localparam logic [7:0] ORDER_INTENT = 8'h04;
  localparam logic [7:0] CONFIG_CONTROL = 8'h05;

  localparam logic [31:0] CONFIG_RESET_ALL = 32'h1;
  localparam logic [31:0] CONFIG_RESET_SYMBOL = 32'h2;
  localparam logic [31:0] CONFIG_SET_SYMBOL_ENABLED = 32'h3;
  localparam logic [31:0] CONFIG_SET_MAX_ORDER_QTY = 32'h4;
  localparam logic [31:0] CONFIG_SET_MAX_NOTIONAL = 32'h5;
  localparam logic [31:0] CONFIG_SET_PRICE_BAND_TICKS = 32'h6;

  localparam logic [15:0] SYMBOL_A = 16'd100;
  localparam logic [15:0] SYMBOL_B = 16'd101;

  // Same lower 14 address bits as SYMBOL_A, but outside the table
  localparam logic [15:0] OUT_OF_RANGE_ALIAS = 16'h4064;

  localparam logic [2:0] SYMBOL_TRADING = 3'd4;

  localparam logic [31:0] BID_PRICE = 32'd1_000_000;
  localparam logic [31:0] ASK_PRICE = 32'd1_000_100;

  localparam logic [31:0] MAX_ORDER_QUANTITY = 32'd1_000;
  localparam logic [63:0] MAX_NOTIONAL = 64'h0000_0001_2345_6789;
  localparam logic [31:0] MAX_PRICE_BAND_TICKS = 32'd25;


  typedef struct packed {
    logic known;
    logic enabled;
    logic [2:0] status;

    logic bid_valid;
    logic ask_valid;
    logic [31:0] bid_price;
    logic [31:0] ask_price;

    logic [31:0] max_order_quantity;
    logic [63:0] max_notional;
    logic [31:0] max_price_band_ticks;
  } symbol_state_t;


  logic clk;
  logic rst;

  logic message_valid;
  logic [7:0] message_type;
  logic [1:0] message_flags;
  logic [15:0] message_symbol_id;
  logic [31:0] message_payload_0;
  logic [31:0] message_payload_1;
  logic [31:0] message_payload_2;

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

  logic state_clear_busy;


  symbol_state_store dut (
      .clk(clk),
      .rst(rst),

      .message_valid(message_valid),
      .message_type(message_type),
      .message_flags(message_flags),
      .message_symbol_id(message_symbol_id),
      .message_payload_0(message_payload_0),
      .message_payload_1(message_payload_1),
      .message_payload_2(message_payload_2),
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

      .state_clear_busy(state_clear_busy)
  );


  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;


  task automatic initialize_inputs;
    begin
      rst = 1'b0;
      message_valid = 1'b0;
      message_type = '0;
      message_flags = '0;
      message_symbol_id = '0;
      message_payload_0 = '0;
      message_payload_1 = '0;
      message_payload_2 = '0;
    end
  endtask


  task automatic drive_inputs_idle;
    begin
      message_valid = 1'b0;
      message_type = '0;
      message_flags = '0;
      message_symbol_id = '0;
      message_payload_0 = '0;
      message_payload_1 = '0;
      message_payload_2 = '0;
    end
  endtask


  task automatic wait_for_state_clear;
    int unsigned cycles_waited;

    begin
      cycles_waited = 0;
      while (state_clear_busy) begin
        @(posedge clk);
        #1ps;
        cycles_waited++;
        if (cycles_waited > SYMBOL_COUNT + 2) begin
          $fatal(1, "State clear did not complete");
        end
      end
    end
  endtask


  task automatic apply_reset;
    begin
      @(negedge clk);
      drive_inputs_idle();
      rst = 1'b1;

      repeat (3) @(posedge clk);
      #1ps;

      if (state_clear_busy !== 1'b1) $fatal(1, "Reset did not start the state clear");

      @(negedge clk);
      rst = 1'b0;

      wait_for_state_clear();
      if (state_clear_busy !== 1'b0) $fatal(1, "State clear remained busy after completion");

    end
  endtask


  task automatic send_message(input logic [7:0] current_message_type, input logic [1:0] current_flags, input logic [15:0] current_symbol_id, input logic [31:0] current_payload_0, input logic [31:0] current_payload_1, input logic [31:0] current_payload_2);
    begin
      @(negedge clk);
      message_valid = 1'b1;
      message_type = current_message_type;
      message_flags = current_flags;
      message_symbol_id = current_symbol_id;
      message_payload_0 = current_payload_0;
      message_payload_1 = current_payload_1;
      message_payload_2 = current_payload_2;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      drive_inputs_idle();
    end
  endtask


  task automatic send_top_of_book(input logic [15:0] symbol_id);
    begin
      send_message(TOB_UPDATE, 2'b11, symbol_id, BID_PRICE, 32'h0, ASK_PRICE);
    end
  endtask


  task automatic send_symbol_status(input logic [15:0] symbol_id, input logic [2:0] symbol_status);
    begin
      send_message(SYMBOL_STATUS, 2'b00, symbol_id, {29'd0, symbol_status}, 32'h0, 32'h0);
    end
  endtask


  task automatic send_config(input logic [31:0] config_opcode, input logic [15:0] symbol_id, input logic [31:0] config_value_0, input logic [31:0] config_value_1);
    begin
      send_message(CONFIG_CONTROL, 2'b00, symbol_id, config_opcode, config_value_0, config_value_1);
    end
  endtask


  task automatic send_order_lookup(input logic [15:0] symbol_id);
    begin
      send_message(ORDER_INTENT, 2'b00, symbol_id, 32'h0, 32'h0, 32'h0);
    end
  endtask


  task automatic configure_complete_symbol(input logic [15:0] symbol_id);
    begin
      send_config(CONFIG_SET_SYMBOL_ENABLED, symbol_id, 32'd1, 32'h0);
      send_symbol_status(symbol_id, SYMBOL_TRADING);
      send_top_of_book(symbol_id);
      send_config(CONFIG_SET_MAX_ORDER_QTY, symbol_id, MAX_ORDER_QUANTITY, 32'h0);
      send_config(CONFIG_SET_MAX_NOTIONAL, symbol_id, MAX_NOTIONAL[63:32], MAX_NOTIONAL[31:0]);
      send_config(CONFIG_SET_PRICE_BAND_TICKS, symbol_id, MAX_PRICE_BAND_TICKS, 32'h0);
    end
  endtask


  function automatic symbol_state_t empty_symbol_state;
    symbol_state_t state;

    begin
      state = '0;
      empty_symbol_state = state;
    end
  endfunction


  function automatic symbol_state_t complete_symbol_state;
    symbol_state_t state;

    begin
      state = '0;

      state.known = 1'b1;
      state.enabled = 1'b1;
      state.status = SYMBOL_TRADING;

      state.bid_valid = 1'b1;
      state.ask_valid = 1'b1;
      state.bid_price = BID_PRICE;
      state.ask_price = ASK_PRICE;

      state.max_order_quantity = MAX_ORDER_QUANTITY;
      state.max_notional = MAX_NOTIONAL;
      state.max_price_band_ticks = MAX_PRICE_BAND_TICKS;

      complete_symbol_state = state;
    end
  endfunction


  function automatic symbol_state_t observed_lookup_state;
    symbol_state_t state;

    begin
      state.known = lookup_symbol_known;
      state.enabled = lookup_symbol_enabled;
      state.status = lookup_symbol_status;

      state.bid_valid = lookup_bid_valid;
      state.ask_valid = lookup_ask_valid;
      state.bid_price = lookup_bid_price;
      state.ask_price = lookup_ask_price;

      state.max_order_quantity = lookup_max_order_quantity;
      state.max_notional = lookup_max_notional;
      state.max_price_band_ticks = lookup_max_price_band_ticks;

      observed_lookup_state = state;
    end
  endfunction


  task automatic check_lookup(input symbol_state_t expected_state, input string check_label);
    symbol_state_t observed_state;

    begin
      observed_state = observed_lookup_state();

      if (lookup_valid !== 1'b1) $fatal(1, "%s: lookup_valid was not asserted", check_label);

      if (observed_state !== expected_state) begin
        $display("%s expected: known=%b enabled=%b status=%0d", check_label, expected_state.known, expected_state.enabled, expected_state.status);
        $display("%s received: known=%b enabled=%b status=%0d", check_label, observed_state.known, observed_state.enabled, observed_state.status);
        $display("Expected TOB: bid=%b/%0d ask=%b/%0d", expected_state.bid_valid, expected_state.bid_price, expected_state.ask_valid, expected_state.ask_price);
        $display("Received TOB: bid=%b/%0d ask=%b/%0d", observed_state.bid_valid, observed_state.bid_price, observed_state.ask_valid, observed_state.ask_price);
        $display("Expected limits: quantity=%0d notional=%h band=%0d", expected_state.max_order_quantity, expected_state.max_notional, expected_state.max_price_band_ticks);
        $display("Received limits: quantity=%0d notional=%h band=%0d", observed_state.max_order_quantity, observed_state.max_notional, observed_state.max_price_band_ticks);
        $fatal(1, "%s: symbol-state mismatch", check_label);
      end
    end
  endtask


  task automatic check_lookup_pulse_clears;
    begin
      @(posedge clk);
      #1ps;

      if (lookup_valid !== 1'b0) $fatal(1, "lookup_valid remained asserted for more than one cycle");
    end
  endtask


  task automatic test_reset_state;
    /*
    Purpose:
    Verify that reset clears every symbol and leaves the store ready.

    Input:
    Apply reset, wait for the full BRAM clear, then look up SYMBOL_A.

    Expected output:
    The store leaves clear-busy and SYMBOL_A is unknown with zero state.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: reset state");

      apply_reset();

      expected_state = empty_symbol_state();

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "lookup after reset");
      check_lookup_pulse_clears();

      $display("PASS: reset state");
    end
  endtask


  task automatic test_complete_symbol_lookup;
    /*
    Purpose:
    Verify storage and lookup of every v0 per-symbol field.

    Input:
    Configure enable state, trading status, full top-of-book and all risk limits.

    Expected output:
    One order lookup returns every stored field unchanged.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: complete symbol lookup");

      apply_reset();
      configure_complete_symbol(SYMBOL_A);

      expected_state = complete_symbol_state();

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "complete symbol lookup");

      $display("PASS: complete symbol lookup");
    end
  endtask


  task automatic test_known_disabled_symbol;
    /*
    Purpose:
    Distinguish a configured disabled symbol from an unknown symbol.

    Input:
    SET_SYMBOL_ENABLED with the enabled value cleared.

    Expected output:
    known is asserted and enabled is cleared.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: known disabled symbol");

      apply_reset();

      send_config(CONFIG_SET_SYMBOL_ENABLED, SYMBOL_A, 32'd0, 32'h0);

      expected_state = empty_symbol_state();
      expected_state.known = 1'b1;
      expected_state.enabled = 1'b0;

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "known disabled symbol");

      $display("PASS: known disabled symbol");
    end
  endtask


  task automatic test_symbol_isolation_and_range;
    /*
    Purpose:
    Verify that symbols are isolated and an out-of-range ID cannot alias a
    valid 14-bit BRAM address.

    Input:
    Fully configure SYMBOL_A, then access SYMBOL_B and OUT_OF_RANGE_ALIAS.

    Expected output:
    SYMBOL_B and the out-of-range symbol are unknown. SYMBOL_A remains intact.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: symbol isolation and range");

      apply_reset();
      configure_complete_symbol(SYMBOL_A);

      expected_state = empty_symbol_state();

      send_order_lookup(SYMBOL_B);
      check_lookup(expected_state, "unconfigured SYMBOL_B");
      send_config(CONFIG_SET_SYMBOL_ENABLED, OUT_OF_RANGE_ALIAS, 32'd0, 32'h0);
      send_order_lookup(OUT_OF_RANGE_ALIAS);
      check_lookup(expected_state, "out-of-range symbol");

      expected_state = complete_symbol_state();

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "SYMBOL_A after alias attempt");

      $display("PASS: symbol isolation and range");
    end
  endtask


  task automatic test_back_to_back_update_and_lookup;
    /*
    Purpose:
    Verify that an order immediately following an update reads the new state.

    Input:
    A TOB_UPDATE followed on the next clock by an ORDER_INTENT.

    Expected output:
    The lookup returns the newly written top-of-book state.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: back-to-back update and lookup");

      apply_reset();

      @(negedge clk);
      message_valid = 1'b1;
      message_type = TOB_UPDATE;
      message_flags = 2'b11;
      message_symbol_id = SYMBOL_A;
      message_payload_0 = BID_PRICE;
      message_payload_1 = 32'h0;
      message_payload_2 = ASK_PRICE;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      message_type = ORDER_INTENT;
      message_flags = 2'b00;
      message_payload_0 = 32'h0;
      message_payload_1 = 32'h0;
      message_payload_2 = 32'h0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      drive_inputs_idle();

      expected_state = empty_symbol_state();
      expected_state.bid_valid = 1'b1;
      expected_state.ask_valid = 1'b1;
      expected_state.bid_price = BID_PRICE;
      expected_state.ask_price = ASK_PRICE;
      check_lookup(expected_state, "back-to-back lookup");

      $display("PASS: back-to-back update and lookup");
    end
  endtask


  task automatic test_reset_symbol;
    /*
    Purpose:
    Verify selective and full reset of one symbol.

    Input:
    Configure SYMBOL_A, selectively reset state groups, then issue a full
    RESET_SYMBOL.

    Expected output:
    Only selected fields clear, and a zero mask clears the complete symbol.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: RESET_SYMBOL");

      apply_reset();
      configure_complete_symbol(SYMBOL_A);

      // Clear only top-of-book state.
      send_config(CONFIG_RESET_SYMBOL, SYMBOL_A, 32'h0000_0001, 32'h0);

      expected_state = complete_symbol_state();
      expected_state.bid_valid = 1'b0;
      expected_state.ask_valid = 1'b0;
      expected_state.bid_price = '0;
      expected_state.ask_price = '0;

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "after TOB reset");

      // Clear status and known/enabled state.
      send_config(CONFIG_RESET_SYMBOL, SYMBOL_A, 32'h0000_0006, 32'h0);

      expected_state.known = 1'b0;
      expected_state.enabled = 1'b0;
      expected_state.status = '0;

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "after status and enable reset");

      // Restore the symbol, then verify that zero means a full reset.
      configure_complete_symbol(SYMBOL_A);

      send_config(CONFIG_RESET_SYMBOL, SYMBOL_A, 32'h0000_0000, 32'h0);

      expected_state = empty_symbol_state();

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "after full symbol reset");

      $display("PASS: RESET_SYMBOL");
    end
  endtask


  task automatic test_full_reset_all;
    /*
    Purpose:
    Verify full-table clearing and fail-closed lookup while clearing.

    Input:
    Configure SYMBOL_A, send RESET_ALL with a zero mask and request an order
    lookup before clearing completes.

    Expected output:
    state_clear_busy asserts. The in-progress lookup and the lookup after
    completion both report an unknown symbol.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: full RESET_ALL");

      apply_reset();
      configure_complete_symbol(SYMBOL_A);

      send_config(CONFIG_RESET_ALL, 16'h0000, 32'h0000_0000, 32'h0);

      if (state_clear_busy !== 1'b1) $fatal(1, "RESET_ALL did not start the state clear");

      expected_state = empty_symbol_state();

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "lookup while clearing");

      wait_for_state_clear();

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "lookup after RESET_ALL");

      $display("PASS: full RESET_ALL");
    end
  endtask


  task automatic test_selective_reset_all;
    /*
    Purpose:
    Verify selective global reset and counter-only reset behavior.

    Input:
    Configure SYMBOL_A, globally clear only risk limits, then send a
    counter-only RESET_ALL.

    Expected output:
    Risk limits clear while market state remains. Counter-only reset does not
    start a symbol-memory clear or modify symbol state.
    */
    symbol_state_t expected_state;

    begin
      $display("TEST: selective RESET_ALL");

      apply_reset();
      configure_complete_symbol(SYMBOL_A);

      send_config(CONFIG_RESET_ALL, 16'h0000, 32'h0000_0008, 32'h0);

      if (state_clear_busy !== 1'b1) $fatal(1, "Selective RESET_ALL did not start the state clear");

      wait_for_state_clear();

      expected_state = complete_symbol_state();
      expected_state.max_order_quantity = '0;
      expected_state.max_notional = '0;
      expected_state.max_price_band_ticks = '0;

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "after global risk-limit reset");

      // Bit 4 belongs to counters and must not clear symbol BRAM
      send_config(CONFIG_RESET_ALL, 16'h0000, 32'h0000_0010, 32'h0);

      if (state_clear_busy !== 1'b0) begin
        $fatal(1, "Counter-only reset incorrectly started a state clear");
      end

      send_order_lookup(SYMBOL_A);
      check_lookup(expected_state, "after counter-only reset");

      $display("PASS: selective RESET_ALL");
    end
  endtask


  initial begin
    initialize_inputs();
    test_reset_state();
    test_complete_symbol_lookup();
    test_known_disabled_symbol();
    test_symbol_isolation_and_range();
    test_back_to_back_update_and_lookup();
    test_reset_symbol();
    test_full_reset_all();
    test_selective_reset_all();

    $display("PASS: all symbol state store tests");
    $finish;
  end

endmodule
