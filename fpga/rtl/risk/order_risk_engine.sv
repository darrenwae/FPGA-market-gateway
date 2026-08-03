// Evaluates decoded order intents against global and per-symbol risk state.
// lookup_valid corresponds to the order presented one cycle earlier.

module order_risk_engine (
    input logic clk,
    input logic rst,

    input logic order_valid,
    input logic order_protocol_violation,
    input logic [31:0] order_sequence_number,
    input logic [15:0] order_symbol_id,
    input logic [31:0] order_side,
    input logic [31:0] order_price,
    input logic [31:0] order_quantity,
    input logic [31:0] order_intent_id,

    input logic effective_stream_fault,
    input logic market_hours_active,

    input logic lookup_valid,
    input logic lookup_symbol_known,
    input logic lookup_symbol_enabled,
    input logic [2:0] lookup_symbol_status,

    input logic lookup_bid_valid,
    input logic lookup_ask_valid,
    input logic [31:0] lookup_bid_price,
    input logic [31:0] lookup_ask_price,

    input logic [31:0] lookup_max_order_quantity,
    input logic [63:0] lookup_max_notional,
    input logic [31:0] lookup_max_price_band_ticks,

    output logic decision_valid,
    output logic [31:0] decision_sequence_number,
    output logic [15:0] decision_symbol_id,
    output logic [31:0] decision_intent_id,
    output logic [31:0] decision,
    output logic [31:0] reject_reason
);

  localparam logic [31:0] ORDER_SIDE_BUY = 32'd1;
  localparam logic [31:0] ORDER_SIDE_SELL = 32'd2;

  localparam logic [2:0] SYMBOL_STATUS_TRADING = 3'd4;

  localparam logic [31:0] DECISION_ACCEPT = 32'd1;
  localparam logic [31:0] DECISION_REJECT = 32'd2;

  // rejection reasons
  localparam logic [3:0] REJECT_NONE = 4'h0;
  localparam logic [3:0] REJECT_STREAM_FAULT = 4'h1;
  localparam logic [3:0] REJECT_PROTOCOL_VIOLATION = 4'h2;
  localparam logic [3:0] REJECT_UNKNOWN_SYMBOL = 4'h3;
  localparam logic [3:0] REJECT_SYMBOL_DISABLED = 4'h4;
  localparam logic [3:0] REJECT_SYMBOL_NOT_TRADING = 4'h5;
  localparam logic [3:0] REJECT_TOB_INVALID = 4'h6;
  localparam logic [3:0] REJECT_INVALID_SIDE = 4'h7;
  localparam logic [3:0] REJECT_ZERO_QUANTITY = 4'h8;
  localparam logic [3:0] REJECT_MAX_QUANTITY = 4'h9;
  localparam logic [3:0] REJECT_ZERO_PRICE = 4'hA;
  localparam logic [3:0] REJECT_PRICE_BAND = 4'hB;
  localparam logic [3:0] REJECT_MAX_NOTIONAL = 4'hC;
  localparam logic [3:0] REJECT_SESSION_NOT_TRADING = 4'hD;


  logic pending_protocol_violation;
  logic pending_stream_fault;
  logic pending_market_hours_active;

  logic [31:0] pending_sequence_number;
  logic [15:0] pending_symbol_id;
  logic [31:0] pending_order_side;
  logic [31:0] pending_order_price;
  logic [31:0] pending_order_quantity;
  logic [31:0] pending_intent_id;
  logic [63:0] pending_order_notional;

  logic pending_order_is_buy;
  logic pending_order_is_sell;

  logic reject_stream_fault;
  logic reject_protocol_violation;
  logic reject_session_not_trading;
  logic reject_unknown_symbol;
  logic reject_symbol_disabled;
  logic reject_symbol_not_trading;
  logic reject_invalid_order_side;
  logic reject_zero_order_quantity;
  logic reject_zero_order_price;
  logic reject_required_tob_invalid;
  logic reject_max_order_quantity;
  logic reject_price_band;
  logic reject_max_notional;
  logic [12:0] reject_conditions;

  logic [32:0] maximum_buy_price;
  logic [32:0] sell_order_price_with_band;

  logic [3:0] selected_reject_reason;


  assign pending_order_is_buy = pending_order_side == ORDER_SIDE_BUY;
  assign pending_order_is_sell = pending_order_side == ORDER_SIDE_SELL;


  assign reject_stream_fault = pending_stream_fault;
  assign reject_protocol_violation = pending_protocol_violation;
  assign reject_session_not_trading = !pending_market_hours_active;
  assign reject_unknown_symbol = !lookup_symbol_known;
  assign reject_symbol_disabled = !lookup_symbol_enabled;
  assign reject_symbol_not_trading = lookup_symbol_status != SYMBOL_STATUS_TRADING;
  assign reject_invalid_order_side = !pending_order_is_buy && !pending_order_is_sell;
  assign reject_zero_order_quantity = pending_order_quantity == 32'd0;
  assign reject_zero_order_price = pending_order_price == 32'd0;
  assign reject_required_tob_invalid = (pending_order_is_buy && !lookup_ask_valid) || (pending_order_is_sell && !lookup_bid_valid);
  assign reject_max_order_quantity = pending_order_quantity > lookup_max_order_quantity;

  assign reject_conditions = {
      reject_stream_fault,
      reject_protocol_violation,
      reject_session_not_trading,
      reject_unknown_symbol,
      reject_symbol_disabled,
      reject_symbol_not_trading,
      reject_invalid_order_side,
      reject_zero_order_quantity,
      reject_zero_order_price,
      reject_required_tob_invalid,
      reject_max_order_quantity,
      reject_price_band,
      reject_max_notional
  };

  // Use 33-bit so price-band calculations cannot wrap
  assign maximum_buy_price = {1'b0, lookup_ask_price} + {1'b0, lookup_max_price_band_ticks};
  assign sell_order_price_with_band = {1'b0, pending_order_price} + {1'b0, lookup_max_price_band_ticks};
  assign reject_price_band = (pending_order_is_buy && ({1'b0, pending_order_price} > maximum_buy_price)) || (pending_order_is_sell && (sell_order_price_with_band < {1'b0, lookup_bid_price}));
  assign reject_max_notional = pending_order_notional > lookup_max_notional;


  always_comb begin
    casez (reject_conditions)
      13'b1????????????: selected_reject_reason = REJECT_STREAM_FAULT;
      13'b01???????????: selected_reject_reason = REJECT_PROTOCOL_VIOLATION;
      13'b001??????????: selected_reject_reason = REJECT_SESSION_NOT_TRADING;
      13'b0001?????????: selected_reject_reason = REJECT_UNKNOWN_SYMBOL;
      13'b00001????????: selected_reject_reason = REJECT_SYMBOL_DISABLED;
      13'b000001???????: selected_reject_reason = REJECT_SYMBOL_NOT_TRADING;
      13'b0000001??????: selected_reject_reason = REJECT_INVALID_SIDE;
      13'b00000001?????: selected_reject_reason = REJECT_ZERO_QUANTITY;
      13'b000000001????: selected_reject_reason = REJECT_ZERO_PRICE;
      13'b0000000001???: selected_reject_reason = REJECT_TOB_INVALID;
      13'b00000000001??: selected_reject_reason = REJECT_MAX_QUANTITY;
      13'b000000000001?: selected_reject_reason = REJECT_PRICE_BAND;
      13'b0000000000001: selected_reject_reason = REJECT_MAX_NOTIONAL;
      default: selected_reject_reason = REJECT_NONE;
    endcase
  end


  // Capture the order while symbol-state BRAM performs its lookup
  always_ff @(posedge clk) begin
    if (rst) begin
      pending_protocol_violation <= 1'b0;
      pending_stream_fault <= 1'b0;
      pending_market_hours_active <= 1'b0;

      pending_sequence_number <= '0;
      pending_symbol_id <= '0;
      pending_order_side <= '0;
      pending_order_price <= '0;
      pending_order_quantity <= '0;
      pending_intent_id <= '0;
      pending_order_notional <= '0;
    end
    else if (order_valid) begin
      pending_protocol_violation <= order_protocol_violation;
      pending_stream_fault <= effective_stream_fault;
      pending_market_hours_active <= market_hours_active;

      pending_sequence_number <= order_sequence_number;
      pending_symbol_id <= order_symbol_id;
      pending_order_side <= order_side;
      pending_order_price <= order_price;
      pending_order_quantity <= order_quantity;
      pending_intent_id <= order_intent_id;

      pending_order_notional <= order_price * order_quantity;
    end
  end


  always_ff @(posedge clk) begin
    if (rst) begin
      decision_valid <= 1'b0;
      decision_sequence_number <= '0;
      decision_symbol_id <= '0;
      decision_intent_id <= '0;
      decision <= '0;
      reject_reason <= '0;
    end
    else begin
      decision_valid <= lookup_valid;

      if (lookup_valid) begin
        decision_sequence_number <= pending_sequence_number;
        decision_symbol_id <= pending_symbol_id;
        decision_intent_id <= pending_intent_id;
        reject_reason <= {28'd0, selected_reject_reason};

        if (selected_reject_reason == REJECT_NONE) begin
          decision <= DECISION_ACCEPT;
        end
        else begin
          decision <= DECISION_REJECT;
        end
      end
    end
  end

endmodule
