// Stores per-symbol market state and risk limits.
// A failed packet is recovered through STREAM_FAULT and RESET_ALL replay.

module symbol_state_store (
    input logic clk,
    input logic rst,

    input logic message_valid,
    input logic [7:0] message_type,
    input logic [7:0] message_flags,
    input logic [15:0] message_symbol_id,
    input logic [31:0] message_payload_0,
    input logic [31:0] message_payload_1,
    input logic [31:0] message_payload_2,
    input logic [31:0] message_payload_3,

    output logic lookup_valid,
    output logic lookup_symbol_known,
    output logic lookup_symbol_enabled,
    output logic [2:0] lookup_symbol_status,

    output logic lookup_bid_valid,
    output logic lookup_ask_valid,
    output logic [31:0] lookup_bid_price,
    output logic [31:0] lookup_bid_quantity,
    output logic [31:0] lookup_ask_price,
    output logic [31:0] lookup_ask_quantity,

    output logic [31:0] lookup_max_order_quantity,
    output logic [63:0] lookup_max_notional,
    output logic [31:0] lookup_max_price_band_ticks,

    output logic state_clear_busy
);

  localparam int unsigned SYMBOL_ADDRESS_WIDTH = 14;
  localparam int unsigned SYMBOL_COUNT = 1 << SYMBOL_ADDRESS_WIDTH;  // support 2^14 (~16k symbols) fully in BRAM

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

  // Bit 1: symbol is known. Bit 0: symbol is enabled.
  (*ram_style = "block"*)
  logic [1:0] symbol_enable_memory[0:SYMBOL_COUNT-1];  // 0x:symbol unknown, 10:known,disabled 11:known,enabled

  (*ram_style = "block"*)
  logic [2:0] symbol_status_memory[0:SYMBOL_COUNT-1];

  // Bit 1: ask valid. Bit 0: bid valid.
  (*ram_style = "block"*)
  logic [1:0] top_of_book_valid_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [31:0] bid_price_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [31:0] bid_quantity_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [31:0] ask_price_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [31:0] ask_quantity_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [31:0] max_order_quantity_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [63:0] max_notional_memory[0:SYMBOL_COUNT-1];

  (*ram_style = "block"*)
  logic [31:0] max_price_band_ticks_memory[0:SYMBOL_COUNT-1];


  logic [1:0] lookup_symbol_enable_state;
  logic [1:0] lookup_top_of_book_valid;

  logic [SYMBOL_ADDRESS_WIDTH-1:0] clear_address;

  // clear_mask[0] = clear top-of-book
  // clear_mask[1] = clear symbol status
  // clear_mask[2] = clear known/enabled state
  // clear_mask[3] = clear risk limits
  logic [3:0] clear_mask;

  logic message_symbol_in_range;
  logic [SYMBOL_ADDRESS_WIDTH-1:0] message_symbol_address;
  logic [3:0] requested_state_groups_to_clear;

  assign lookup_symbol_known = lookup_symbol_enable_state[1];
  assign lookup_symbol_enabled = lookup_symbol_enable_state[0];

  assign lookup_bid_valid = lookup_top_of_book_valid[0];
  assign lookup_ask_valid = lookup_top_of_book_valid[1];

  assign message_symbol_in_range = message_symbol_id[15:14] == 2'b00;

  assign message_symbol_address = message_symbol_id[13:0];

  assign requested_state_groups_to_clear = (message_payload_1 == 32'h0) ? 4'b1111 : message_payload_1[3:0];


  always_ff @(posedge clk) begin
    if (rst) begin
      lookup_valid <= 1'b0;
      lookup_symbol_enable_state <= '0;
      lookup_symbol_status <= '0;
      lookup_top_of_book_valid <= '0;
      lookup_bid_price <= '0;
      lookup_bid_quantity <= '0;
      lookup_ask_price <= '0;
      lookup_ask_quantity <= '0;
      lookup_max_order_quantity <= '0;
      lookup_max_notional <= '0;
      lookup_max_price_band_ticks <= '0;

      state_clear_busy <= 1'b1;
      clear_address <= '0;
      clear_mask <= 4'b1111;
    end
    else begin
      lookup_valid <= 1'b0;

      if (state_clear_busy) begin
        if (clear_mask[0]) begin
          top_of_book_valid_memory[clear_address] <= '0;
          bid_price_memory[clear_address] <= '0;
          bid_quantity_memory[clear_address] <= '0;
          ask_price_memory[clear_address] <= '0;
          ask_quantity_memory[clear_address] <= '0;
        end

        if (clear_mask[1]) begin
          symbol_status_memory[clear_address] <= '0;
        end

        if (clear_mask[2]) begin
          symbol_enable_memory[clear_address] <= '0;
        end

        if (clear_mask[3]) begin
          max_order_quantity_memory[clear_address] <= '0;
          max_notional_memory[clear_address] <= '0;
          max_price_band_ticks_memory[clear_address] <= '0;
        end

        if (&clear_address) begin
          //final address reacehd
          state_clear_busy <= 1'b0;
          clear_address <= '0;
        end
        else begin
          clear_address <= clear_address + 1'b1;
        end

        // Orders received while clearing must fail closed
        if (message_valid && (message_type == ORDER_INTENT)) begin
          lookup_valid <= 1'b1;
          lookup_symbol_enable_state <= '0;
          lookup_symbol_status <= '0;
          lookup_top_of_book_valid <= '0;
          lookup_bid_price <= '0;
          lookup_bid_quantity <= '0;
          lookup_ask_price <= '0;
          lookup_ask_quantity <= '0;
          lookup_max_order_quantity <= '0;
          lookup_max_notional <= '0;
          lookup_max_price_band_ticks <= '0;
        end
      end
      else if (message_valid) begin
        case (message_type)
          TOB_UPDATE: begin
            if (message_symbol_in_range) begin
              top_of_book_valid_memory[message_symbol_address] <= message_flags[1:0];
              bid_price_memory[message_symbol_address] <= message_payload_0;
              bid_quantity_memory[message_symbol_address] <= message_payload_1;
              ask_price_memory[message_symbol_address] <= message_payload_2;
              ask_quantity_memory[message_symbol_address] <= message_payload_3;
            end
          end

          SYMBOL_STATUS: begin
            if (message_symbol_in_range) begin
              symbol_status_memory[message_symbol_address] <= message_payload_0[2:0];
            end
          end

          ORDER_INTENT: begin
            lookup_valid <= 1'b1;

            if (message_symbol_in_range) begin
              lookup_symbol_enable_state <= symbol_enable_memory[message_symbol_address];
              lookup_symbol_status <= symbol_status_memory[message_symbol_address];
              lookup_top_of_book_valid <= top_of_book_valid_memory[message_symbol_address];
              lookup_bid_price <= bid_price_memory[message_symbol_address];
              lookup_bid_quantity <= bid_quantity_memory[message_symbol_address];
              lookup_ask_price <= ask_price_memory[message_symbol_address];
              lookup_ask_quantity <= ask_quantity_memory[message_symbol_address];
              lookup_max_order_quantity <= max_order_quantity_memory[message_symbol_address];
              lookup_max_notional <= max_notional_memory[message_symbol_address];
              lookup_max_price_band_ticks <= max_price_band_ticks_memory[message_symbol_address];
            end
            else begin
              lookup_symbol_enable_state <= '0;
              lookup_symbol_status <= '0;
              lookup_top_of_book_valid <= '0;
              lookup_bid_price <= '0;
              lookup_bid_quantity <= '0;
              lookup_ask_price <= '0;
              lookup_ask_quantity <= '0;
              lookup_max_order_quantity <= '0;
              lookup_max_notional <= '0;
              lookup_max_price_band_ticks <= '0;
            end
          end

          CONFIG_CONTROL: begin
            case (message_payload_0)
              CONFIG_RESET_ALL: begin
                // Bit 4 affects counters, not this state store
                if ((message_payload_1 == 32'h0) || (message_payload_1[3:0] != 4'b0000)) begin
                  state_clear_busy <= 1'b1;
                  clear_address <= '0;
                  clear_mask <= requested_state_groups_to_clear;
                end
              end

              CONFIG_RESET_SYMBOL: begin
                if (message_symbol_in_range) begin
                  if (requested_state_groups_to_clear[0]) begin
                    top_of_book_valid_memory[message_symbol_address] <= '0;
                    bid_price_memory[message_symbol_address] <= '0;
                    bid_quantity_memory[message_symbol_address] <= '0;
                    ask_price_memory[message_symbol_address] <= '0;
                    ask_quantity_memory[message_symbol_address] <= '0;
                  end

                  if (requested_state_groups_to_clear[1]) begin
                    symbol_status_memory[message_symbol_address] <= '0;
                  end

                  if (requested_state_groups_to_clear[2]) begin
                    symbol_enable_memory[message_symbol_address] <= '0;
                  end

                  if (requested_state_groups_to_clear[3]) begin
                    max_order_quantity_memory[message_symbol_address] <= '0;
                    max_notional_memory[message_symbol_address] <= '0;
                    max_price_band_ticks_memory[message_symbol_address] <= '0;
                  end
                end
              end

              CONFIG_SET_SYMBOL_ENABLED: begin
                if (message_symbol_in_range) begin
                  symbol_enable_memory[message_symbol_address] <= {1'b1, message_payload_1[0]};
                end
              end

              CONFIG_SET_MAX_ORDER_QTY: begin
                if (message_symbol_in_range) begin
                  max_order_quantity_memory[message_symbol_address] <= message_payload_1;
                end
              end

              CONFIG_SET_MAX_NOTIONAL: begin
                if (message_symbol_in_range) begin
                  max_notional_memory[message_symbol_address] <= {message_payload_1, message_payload_2};
                end
              end

              CONFIG_SET_PRICE_BAND_TICKS: begin
                if (message_symbol_in_range) begin
                  max_price_band_ticks_memory[message_symbol_address] <= message_payload_1;
                end
              end

              default: begin
              end
            endcase
          end

          default: begin
          end
        endcase
      end
    end
  end

endmodule
