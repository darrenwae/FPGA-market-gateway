module xem8320_top (
    input logic sys_clk_p,  // free running 100Mhz clk used by GT reset controller
    input logic sys_clk_n,

    input logic gt_refclk_p,  // 156.25 Mhz MGT ref clk
    input logic gt_refclk_n,

    input  logic [1:0] sfp_rx_p,
    input  logic [1:0] sfp_rx_n,
    output logic [1:0] sfp_tx_p,
    output logic [1:0] sfp_tx_n,

    output logic [1:0] sfp_tx_disable,
    output logic [1:0] sfp_rate_select_0,
    output logic [1:0] sfp_rate_select_1
);

  localparam logic [7:0] SESSION_STATUS_MESSAGE = 8'h01;
  localparam logic [7:0] ORDER_INTENT_MESSAGE = 8'h04;
  localparam logic [7:0] CONFIG_CONTROL_MESSAGE = 8'h05;
  localparam logic [31:0] CONFIG_RESET_ALL = 32'h1;

  // Clock and GT status signals
  logic clk_freerun;
  logic tx_pcs_clk;
  logic rx_pcs_clk;

  logic tx_reset_done;
  logic rx_reset_done;
  logic rx_cdr_stable;
  logic [1:0] gt_power_good;


  // TX PCS-to-GT gearbox interface
  logic [1:0][63:0] tx_data;
  logic [1:0][5:0] tx_header;
  logic [1:0][6:0] tx_sequence;

  //RX GT-to-PCS gearbox interface
  logic [1:0][63:0] rx_data;
  logic [1:0][5:0] rx_header;
  logic [1:0][1:0] rx_data_valid;
  logic [1:0][1:0] rx_header_valid;
  logic [1:0] rx_gearbox_slip;


  // RX PCS reset synchronization
  logic rx_pcs_rst;
  (*ASYNC_REG = "TRUE"*)
  logic [1:0] rx_pcs_reset_sync;


  // Channel 0 application RX path
  logic rx0_block_lock;
  logic [63:0] rx0_frame_data;
  logic [7:0] rx0_frame_keep;
  logic rx0_frame_start;
  logic rx0_frame_end;
  logic rx0_frame_valid;
  logic rx0_frame_abort;

  logic rx0_bad_block;
  logic rx0_sequence_error;

  logic rx0_fcs_result_valid;
  logic rx0_fcs_ok;

  logic [63:0] rx0_udp_payload_data;
  logic rx0_udp_payload_start;
  logic rx0_udp_payload_end;
  logic rx0_udp_payload_valid;
  logic rx0_udp_packet_abort;
  logic rx0_parser_error;

  // Internal message assembler
  logic [255:0] rx0_message_data;
  logic rx0_message_valid;
  logic rx0_message_packet_start;
  logic rx0_message_packet_end;
  logic rx0_message_packet_abort;


  // Internal protocol decoder
  logic rx0_decoded_valid;
  logic [7:0] rx0_decoded_message_type;
  logic [7:0] rx0_decoded_flags;
  logic [31:0] rx0_decoded_sequence_number;
  logic [15:0] rx0_decoded_symbol_id;
  logic [47:0] rx0_decoded_timestamp;
  logic [31:0] rx0_decoded_payload_0;
  logic [31:0] rx0_decoded_payload_1;
  logic [31:0] rx0_decoded_payload_2;
  logic [31:0] rx0_decoded_payload_3;

  logic rx0_decoded_packet_start;
  logic rx0_decoded_packet_end;
  logic rx0_decoded_packet_abort;
  logic rx0_protocol_error;


  // Packet controller
  logic rx0_packet_commit;
  logic rx0_packet_discard;

  logic rx0_integrity_known;
  logic rx0_integrity_result_valid;
  logic rx0_integrity_ok;
  logic rx0_integrity_failure;

  logic rx0_message_is_full_reset_all;
  logic rx0_sequence_mismatch_event;
  logic rx0_stream_fault;
  logic rx0_effective_stream_fault;
  logic [31:0] rx0_verified_next_sequence_number;


  assign rx0_message_is_full_reset_all = rx0_decoded_valid && (rx0_decoded_message_type == CONFIG_CONTROL_MESSAGE) && (rx0_decoded_payload_0 == CONFIG_RESET_ALL) && (rx0_decoded_payload_1 == 32'h0);

  // Symbol state lookup
  logic rx0_lookup_valid;
  logic rx0_lookup_symbol_known;
  logic rx0_lookup_symbol_enabled;
  logic [2:0] rx0_lookup_symbol_status;

  logic rx0_lookup_bid_valid;
  logic rx0_lookup_ask_valid;
  logic [31:0] rx0_lookup_bid_price;
  logic [31:0] rx0_lookup_ask_price;

  logic [31:0] rx0_lookup_max_order_quantity;
  logic [63:0] rx0_lookup_max_notional;
  logic [31:0] rx0_lookup_max_price_band_ticks;

  logic rx0_state_clear_busy;
  logic rx0_market_hours_active;

  // Order risk decision
  logic rx0_order_decision_valid;
  logic [31:0] rx0_order_decision_sequence_number;
  logic [15:0] rx0_order_decision_symbol_id;
  logic [31:0] rx0_order_decision_intent_id;
  logic [31:0] rx0_order_decision;
  logic [31:0] rx0_order_reject_reason;

  // TX PCS is not implemented yet. Keep the GT TX gearbox inputs inactive
  assign tx_data = '0;
  assign tx_header = '0;
  assign tx_sequence = '0;

  assign sfp_tx_disable = 2'b11;  // change to 2'b00 when Tx PCS is implemented
  assign sfp_rate_select_0 = 2'b11;
  assign sfp_rate_select_1 = 2'b11;


  // buffer for 100 Mhz free running clock
  IBUFDS u_sys_clk_buf (
      .I (sys_clk_p),
      .IB(sys_clk_n),
      .O (clk_freerun)
  );

  // GTY transceiver
  gty_10gbase_r_wrapper u_gty_10gbase_r (
      .clk_freerun(clk_freerun),
      .rst(1'b0),
      .gt_refclk_p(gt_refclk_p),
      .gt_refclk_n(gt_refclk_n),
      .sfp_rx_p(sfp_rx_p),
      .sfp_rx_n(sfp_rx_n),
      .sfp_tx_p(sfp_tx_p),
      .sfp_tx_n(sfp_tx_n),
      .tx_data(tx_data),
      .tx_header(tx_header),
      .tx_sequence(tx_sequence),
      .rx_gearbox_slip(rx_gearbox_slip),
      .rx_data(rx_data),
      .rx_header(rx_header),
      .rx_data_valid(rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .tx_pcs_clk(tx_pcs_clk),
      .rx_pcs_clk(rx_pcs_clk),
      .tx_reset_done(tx_reset_done),
      .rx_reset_done(rx_reset_done),
      .rx_cdr_stable(rx_cdr_stable),
      .gt_power_good(gt_power_good)
  );

  // rx_reset_done is asynchronous w.r.t rx_pcs_clk
  // Assert PCS reset when the GT RX path is not ready
  // Deassert reset synchronously in the RX PCS clock domain
  always_ff @(posedge rx_pcs_clk or negedge rx_reset_done) begin
    if (!rx_reset_done) begin
      rx_pcs_reset_sync <= 2'b11;
    end
    else begin
      rx_pcs_reset_sync <= {rx_pcs_reset_sync[0], 1'b0};
    end
  end

  assign rx_pcs_rst = rx_pcs_reset_sync[1];

  // Channel 0 is the host-to-FPGA application receive path.
  eth_rx_channel u_eth_rx_channel (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .rx_data(rx_data[0]),
      .rx_header(rx_header[0][1:0]),
      .rx_data_valid(rx_data_valid[0][0]),
      .rx_header_valid(rx_header_valid[0][0]),
      .rx_gearbox_slip(rx_gearbox_slip[0]),
      .block_lock(rx0_block_lock),
      .frame_data(rx0_frame_data),
      .frame_keep(rx0_frame_keep),
      .frame_start(rx0_frame_start),
      .frame_end(rx0_frame_end),
      .frame_valid(rx0_frame_valid),
      .frame_abort(rx0_frame_abort),
      .bad_block(rx0_bad_block),
      .sequence_error(rx0_sequence_error),
      .fcs_result_valid(rx0_fcs_result_valid),
      .fcs_ok(rx0_fcs_ok)
  );

  eth_ipv4_udp_rx u_eth_ipv4_udp_rx (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .frame_data(rx0_frame_data),
      .frame_keep(rx0_frame_keep),
      .frame_start(rx0_frame_start),
      .frame_end(rx0_frame_end),
      .frame_valid(rx0_frame_valid),
      .frame_abort(rx0_frame_abort),
      .udp_payload_data(rx0_udp_payload_data),
      .udp_payload_start(rx0_udp_payload_start),
      .udp_payload_end(rx0_udp_payload_end),
      .udp_payload_valid(rx0_udp_payload_valid),
      .udp_packet_abort(rx0_udp_packet_abort),
      .parser_error(rx0_parser_error)
  );

  internal_message_assembler u_internal_message_assembler (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .udp_payload_data(rx0_udp_payload_data),
      .udp_payload_start(rx0_udp_payload_start),
      .udp_payload_end(rx0_udp_payload_end),
      .udp_payload_valid(rx0_udp_payload_valid),
      .udp_packet_abort(rx0_udp_packet_abort),
      .message_data(rx0_message_data),
      .message_valid(rx0_message_valid),
      .message_packet_start(rx0_message_packet_start),
      .message_packet_end(rx0_message_packet_end),
      .message_packet_abort(rx0_message_packet_abort)
  );

  internal_protocol_decoder u_internal_protocol_decoder (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .message_data(rx0_message_data),
      .message_valid(rx0_message_valid),
      .message_packet_start(rx0_message_packet_start),
      .message_packet_end(rx0_message_packet_end),
      .message_packet_abort(rx0_message_packet_abort),
      .decoded_valid(rx0_decoded_valid),
      .decoded_message_type(rx0_decoded_message_type),
      .decoded_flags(rx0_decoded_flags),
      .decoded_sequence_number(rx0_decoded_sequence_number),
      .decoded_symbol_id(rx0_decoded_symbol_id),
      .decoded_timestamp(rx0_decoded_timestamp),
      .decoded_payload_0(rx0_decoded_payload_0),
      .decoded_payload_1(rx0_decoded_payload_1),
      .decoded_payload_2(rx0_decoded_payload_2),
      .decoded_payload_3(rx0_decoded_payload_3),
      .decoded_packet_start(rx0_decoded_packet_start),
      .decoded_packet_end(rx0_decoded_packet_end),
      .decoded_packet_abort(rx0_decoded_packet_abort),
      .protocol_error(rx0_protocol_error)
  );

  market_hours_tracker u_market_hours_tracker (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .session_status_valid(rx0_decoded_valid && (rx0_decoded_message_type == SESSION_STATUS_MESSAGE)),
      .session_state(rx0_decoded_payload_0[2:0]),
      .full_reset_all(rx0_message_is_full_reset_all),
      .market_hours_active(rx0_market_hours_active)
  );

  symbol_state_store u_symbol_state_store (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .message_valid(rx0_decoded_valid),
      .message_type(rx0_decoded_message_type),
      .message_flags(rx0_decoded_flags[1:0]),
      .message_symbol_id(rx0_decoded_symbol_id),
      .message_payload_0(rx0_decoded_payload_0),
      .message_payload_1(rx0_decoded_payload_1),
      .message_payload_2(rx0_decoded_payload_2),
      .lookup_valid(rx0_lookup_valid),
      .lookup_symbol_known(rx0_lookup_symbol_known),
      .lookup_symbol_enabled(rx0_lookup_symbol_enabled),
      .lookup_symbol_status(rx0_lookup_symbol_status),
      .lookup_bid_valid(rx0_lookup_bid_valid),
      .lookup_ask_valid(rx0_lookup_ask_valid),
      .lookup_bid_price(rx0_lookup_bid_price),
      .lookup_ask_price(rx0_lookup_ask_price),
      .lookup_max_order_quantity(rx0_lookup_max_order_quantity),
      .lookup_max_notional(rx0_lookup_max_notional),
      .lookup_max_price_band_ticks(rx0_lookup_max_price_band_ticks),
      .state_clear_busy(rx0_state_clear_busy)
  );

  downstream_sequence_tracker u_downstream_sequence_tracker (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .message_valid(rx0_decoded_valid),
      .message_sequence_number(rx0_decoded_sequence_number),
      .message_packet_start(rx0_decoded_packet_start),
      .message_packet_end(rx0_decoded_packet_end),
      .message_is_full_reset_all(rx0_message_is_full_reset_all),
      .packet_commit(rx0_packet_commit),
      .packet_discard(rx0_packet_discard),
      .integrity_failure(rx0_integrity_failure),
      .sequence_mismatch_event(rx0_sequence_mismatch_event),
      .stream_fault(rx0_stream_fault),
      .effective_stream_fault(rx0_effective_stream_fault),
      .verified_next_sequence_number(rx0_verified_next_sequence_number)
  );

  order_risk_engine u_order_risk_engine (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .order_valid(rx0_decoded_valid && (rx0_decoded_message_type == ORDER_INTENT_MESSAGE)),
      .order_protocol_violation(rx0_protocol_error),
      .order_sequence_number(rx0_decoded_sequence_number),
      .order_symbol_id(rx0_decoded_symbol_id),
      .order_side(rx0_decoded_payload_0),
      .order_price(rx0_decoded_payload_1),
      .order_quantity(rx0_decoded_payload_2),
      .order_intent_id(rx0_decoded_payload_3),
      .effective_stream_fault(rx0_effective_stream_fault),
      .market_hours_active(rx0_market_hours_active),
      .lookup_valid(rx0_lookup_valid),
      .lookup_symbol_known(rx0_lookup_symbol_known),
      .lookup_symbol_enabled(rx0_lookup_symbol_enabled),
      .lookup_symbol_status(rx0_lookup_symbol_status),
      .lookup_bid_valid(rx0_lookup_bid_valid),
      .lookup_ask_valid(rx0_lookup_ask_valid),
      .lookup_bid_price(rx0_lookup_bid_price),
      .lookup_ask_price(rx0_lookup_ask_price),
      .lookup_max_order_quantity(rx0_lookup_max_order_quantity),
      .lookup_max_notional(rx0_lookup_max_notional),
      .lookup_max_price_band_ticks(rx0_lookup_max_price_band_ticks),
      .decision_valid(rx0_order_decision_valid),
      .decision_sequence_number(rx0_order_decision_sequence_number),
      .decision_symbol_id(rx0_order_decision_symbol_id),
      .decision_intent_id(rx0_order_decision_intent_id),
      .decision(rx0_order_decision),
      .reject_reason(rx0_order_reject_reason)
  );

  rx_packet_controller u_rx_packet_controller (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .packet_failure_event(rx0_sequence_mismatch_event),
      .packet_start(rx0_udp_payload_valid && rx0_udp_payload_start),
      .decode_complete(rx0_decoded_valid && rx0_decoded_packet_end),
      .frame_abort(rx0_frame_abort),
      .decode_abort(rx0_decoded_packet_abort),
      .fcs_result_valid(rx0_fcs_result_valid),
      .fcs_ok(rx0_fcs_ok),
      .packet_commit(rx0_packet_commit),
      .packet_discard(rx0_packet_discard),
      .integrity_known(rx0_integrity_known),
      .integrity_result_valid(rx0_integrity_result_valid),
      .integrity_ok(rx0_integrity_ok),
      .integrity_failure(rx0_integrity_failure)
  );


  // Channel 1 RX is not used by the v0 application.
  assign rx_gearbox_slip[1] = 1'b0;

endmodule
