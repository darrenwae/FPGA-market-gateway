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

  localparam logic [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01;
  localparam logic [31:0] LOCAL_IP = 32'hC0A8_0102;
  localparam logic [15:0] LOCAL_UDP_PORT = 16'd5000;

  localparam logic [7:0] CONFIG_CONTROL_MESSAGE = 8'h05;
  localparam logic [31:0] CONFIG_RESET_ALL = 32'h0000_0001;

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
  logic [1:0][1:0] rx_start_of_seq;
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
  logic rx0_assembler_error;


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
  logic rx0_controller_error;

  logic rx0_message_is_reset_all;

  (* MARK_DEBUG = "TRUE" *)
  logic rx0_sequence_mismatch_event;

  (* MARK_DEBUG = "TRUE" *)
  logic rx0_stream_fault;

  (* MARK_DEBUG = "TRUE" *)
  logic rx0_effective_stream_fault;

  (* MARK_DEBUG = "TRUE" *)
  logic [31:0] rx0_verified_next_sequence_number;


  // Temporary integration observability
  (* MARK_DEBUG = "TRUE" *)
  logic [239:0] rx0_last_decoded_fields;

  (* MARK_DEBUG = "TRUE" *)
  logic [31:0] rx0_decoded_count;

  (* MARK_DEBUG = "TRUE" *)
  logic [31:0] rx0_error_count;

  (* MARK_DEBUG = "TRUE" *)
  logic [13:0] rx0_last_event_flags;


  assign rx0_message_is_reset_all = rx0_decoded_valid && (rx0_decoded_message_type == CONFIG_CONTROL_MESSAGE) && (rx0_decoded_payload_0 == CONFIG_RESET_ALL);

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
      .rx_start_of_seq(rx_start_of_seq),
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
  (*DONT_TOUCH = "yes"*)
  eth_rx_channel u_eth_rx_channel (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .rx_data(rx_data[0]),
      .rx_header(rx_header[0]),
      .rx_data_valid(rx_data_valid[0]),
      .rx_header_valid(rx_header_valid[0]),
      .rx_start_of_seq(rx_start_of_seq[0]),
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

  eth_ipv4_udp_rx #(
      .LOCAL_MAC(LOCAL_MAC),
      .LOCAL_IP(LOCAL_IP),
      .LOCAL_UDP_PORT(LOCAL_UDP_PORT)
  ) u_eth_ipv4_udp_rx (
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
      .message_packet_abort(rx0_message_packet_abort),
      .assembler_error(rx0_assembler_error)
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

  downstream_sequence_tracker u_downstream_sequence_tracker (
      .clk(rx_pcs_clk),
      .rst(rx_pcs_rst),
      .message_valid(rx0_decoded_valid),
      .message_sequence_number(rx0_decoded_sequence_number),
      .message_packet_start(rx0_decoded_packet_start),
      .message_packet_end(rx0_decoded_packet_end),
      .message_is_reset_all(rx0_message_is_reset_all),
      .packet_commit(rx0_packet_commit),
      .packet_discard(rx0_packet_discard),
      .integrity_failure(rx0_integrity_failure),
      .sequence_mismatch_event(rx0_sequence_mismatch_event),
      .stream_fault(rx0_stream_fault),
      .effective_stream_fault(rx0_effective_stream_fault),
      .verified_next_sequence_number(rx0_verified_next_sequence_number)
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
      .integrity_failure(rx0_integrity_failure),
      .controller_error(rx0_controller_error)
  );

  // temporary consumer
  always_ff @(posedge rx_pcs_clk) begin
    if (rx_pcs_rst) begin
      rx0_last_decoded_fields <= '0;
      rx0_decoded_count <= '0;
      rx0_error_count <= '0;
      rx0_last_event_flags <= '0;
    end
    else begin
      if (rx0_decoded_valid) begin
        rx0_last_decoded_fields <= {rx0_decoded_payload_3, rx0_decoded_payload_2, rx0_decoded_payload_1, rx0_decoded_payload_0, rx0_decoded_timestamp, rx0_decoded_symbol_id, rx0_decoded_sequence_number, rx0_decoded_flags, rx0_decoded_message_type};
        rx0_decoded_count <= rx0_decoded_count + 1'b1;
      end

      if (rx0_parser_error || rx0_assembler_error || rx0_protocol_error || rx0_integrity_failure || rx0_sequence_mismatch_event || rx0_controller_error) begin
        rx0_error_count <= rx0_error_count + 1'b1;
      end

      if (rx0_packet_commit || rx0_packet_discard || rx0_integrity_result_valid || rx0_controller_error || rx0_decoded_valid || rx0_decoded_packet_abort || rx0_protocol_error || rx0_assembler_error || rx0_parser_error) begin
        rx0_last_event_flags <= {rx0_parser_error, rx0_assembler_error, rx0_protocol_error, rx0_controller_error, rx0_integrity_failure, rx0_integrity_result_valid, rx0_integrity_ok, rx0_integrity_known, rx0_packet_discard, rx0_packet_commit, rx0_decoded_packet_abort, rx0_decoded_valid, rx0_decoded_packet_end, rx0_decoded_packet_start};
      end
    end
  end

  // Channel 1 RX is not used by the v0 application.
  assign rx_gearbox_slip[1] = 1'b0;

endmodule
