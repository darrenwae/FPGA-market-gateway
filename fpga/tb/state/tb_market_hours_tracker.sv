`timescale 1ns / 1ps

module tb_market_hours_tracker;

  localparam time CLK_PERIOD = 6.206ns;

  localparam logic [2:0] INVALID = 3'd0;
  localparam logic [2:0] START_OF_MESSAGES = 3'd1;
  localparam logic [2:0] START_OF_SYSTEM_HOURS = 3'd2;
  localparam logic [2:0] START_OF_MARKET_HOURS = 3'd3;
  localparam logic [2:0] END_OF_MARKET_HOURS = 3'd4;
  localparam logic [2:0] END_OF_SYSTEM_HOURS = 3'd5;
  localparam logic [2:0] END_OF_MESSAGES = 3'd6;

  logic clk;
  logic rst;

  logic session_status_valid;
  logic [2:0] session_state;
  logic full_reset_all;

  logic market_hours_active;


  market_hours_tracker dut (
      .clk(clk),
      .rst(rst),
      .session_status_valid(session_status_valid),
      .session_state(session_state),
      .full_reset_all(full_reset_all),
      .market_hours_active(market_hours_active)
  );


  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;


  task automatic initialize_inputs;
    begin
      rst = 1'b0;
      session_status_valid = 1'b0;
      session_state = INVALID;
      full_reset_all = 1'b0;
    end
  endtask


  task automatic apply_reset;
    begin
      @(negedge clk);

      session_status_valid = 1'b0;
      session_state = INVALID;
      full_reset_all = 1'b0;
      rst = 1'b1;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask


  task automatic send_session_status(input logic [2:0] new_session_state);
    begin
      @(negedge clk);
      session_status_valid = 1'b1;
      session_state = new_session_state;
      full_reset_all = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      session_status_valid = 1'b0;
    end
  endtask


  task automatic send_full_reset_all;
    begin
      @(negedge clk);
      session_status_valid = 1'b0;
      full_reset_all = 1'b1;

      @(posedge clk);
      #1ps;

      @(negedge clk);
      full_reset_all = 1'b0;
    end
  endtask


  task automatic check_market_hours(input logic expected_active, input string check_label);
    begin
      if (market_hours_active !== expected_active) begin
        $fatal(1, "%s: expected market_hours_active=%b, received %b", check_label, expected_active, market_hours_active);
      end
    end
  endtask


  task automatic test_reset_state;
    begin
      /*
      Purpose:
        Verify fail-closed reset behavior.

      Input:
        Hardware reset.

      Expected output:
        market_hours_active is zero.
      */

      $display("TEST: reset state");

      apply_reset();
      check_market_hours(1'b0, "after reset");

      $display("PASS: reset state");
    end
  endtask


  task automatic test_market_open_and_idle_hold;
    begin
      /*
      Purpose:
        Verify that START_OF_MARKET_HOURS opens the market and that input data
        is ignored while session_status_valid is low.

      Input:
        START_OF_MARKET_HOURS followed by an idle cycle carrying another value.

      Expected output:
        market_hours_active remains asserted.
      */

      $display("TEST: market open and idle hold");

      apply_reset();

      send_session_status(START_OF_MARKET_HOURS);
      check_market_hours(1'b1, "after market open");

      @(negedge clk);
      session_state = END_OF_MARKET_HOURS;
      session_status_valid = 1'b0;

      @(posedge clk);
      #1ps;

      check_market_hours(1'b1, "invalid session input ignored");

      $display("PASS: market open and idle hold");
    end
  endtask


  task automatic test_non_trading_session_states;
    logic [2:0] non_trading_states[0:5];

    begin
      /*
      Purpose:
        Verify that every valid state other than START_OF_MARKET_HOURS closes
        the market.

      Input:
        Each non-trading session state after opening the market.

      Expected output:
        market_hours_active clears for every state.
      */

      $display("TEST: non-trading session states");

      non_trading_states[0] = INVALID;
      non_trading_states[1] = START_OF_MESSAGES;
      non_trading_states[2] = START_OF_SYSTEM_HOURS;
      non_trading_states[3] = END_OF_MARKET_HOURS;
      non_trading_states[4] = END_OF_SYSTEM_HOURS;
      non_trading_states[5] = END_OF_MESSAGES;

      apply_reset();

      for (int unsigned i = 0; i < 6; i++) begin
        send_session_status(START_OF_MARKET_HOURS);
        check_market_hours(1'b1, "market reopened");

        send_session_status(non_trading_states[i]);
        check_market_hours(1'b0, "non-trading state");
      end

      $display("PASS: non-trading session states");
    end
  endtask


  task automatic test_back_to_back_status;
    begin
      /*
      Purpose:
        Verify consecutive session updates without an idle cycle.

      Input:
        START_OF_MARKET_HOURS immediately followed by END_OF_MARKET_HOURS.

      Expected output:
        The market opens for one cycle and then closes.
      */

      $display("TEST: back-to-back session status");

      apply_reset();

      @(negedge clk);
      session_status_valid = 1'b1;
      session_state = START_OF_MARKET_HOURS;

      @(posedge clk);
      #1ps;
      check_market_hours(1'b1, "back-to-back market open");

      @(negedge clk);
      session_state = END_OF_MARKET_HOURS;

      @(posedge clk);
      #1ps;
      check_market_hours(1'b0, "back-to-back market close");

      @(negedge clk);
      session_status_valid = 1'b0;

      $display("PASS: back-to-back session status");
    end
  endtask


  task automatic test_full_reset_all;
    begin
      /*
      Purpose:
        Verify that full RESET_ALL returns the global session state to
        fail-closed.

      Input:
        Open market state followed by full_reset_all.

      Expected output:
        market_hours_active clears and may be opened again by a later session
        update.
      */

      $display("TEST: full RESET_ALL");

      apply_reset();

      send_session_status(START_OF_MARKET_HOURS);
      check_market_hours(1'b1, "before full reset");

      send_full_reset_all();
      check_market_hours(1'b0, "after full reset");

      send_session_status(START_OF_MARKET_HOURS);
      check_market_hours(1'b1, "market reopened after full reset");

      $display("PASS: full RESET_ALL");
    end
  endtask


  initial begin
    initialize_inputs();

    test_reset_state();
    test_market_open_and_idle_hold();
    test_non_trading_session_states();
    test_back_to_back_status();
    test_full_reset_all();

    $display("PASS: all market-hours tracker tests");
    $finish;
  end

endmodule
