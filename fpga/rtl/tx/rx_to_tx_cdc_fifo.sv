// Transfers speculative response events from recovered RX clock to the TX clock
// rst is synchronous to rx_clk and must remain asserted until both clocks are stable

module rx_to_tx_cdc_fifo (
    input logic rx_clk,
    input logic tx_clk,
    input logic rst,

    input logic rx_order_intent_valid,  // assert on valid order intent detected

    input logic rx_decision_valid,  // assert on valid decision output by risk engine
    input logic [31:0] rx_decision_sequence_number,
    input logic [15:0] rx_decision_symbol_id,
    input logic [31:0] rx_decision_intent_id,
    input logic [31:0] rx_decision,
    input logic [31:0] rx_reject_reason,
    input logic rx_source_frame_ok,

    output logic tx_response_start_valid,  // next fifo entry is START
    input  logic tx_response_start_ready,

    output logic tx_decision_valid,  // next fifo entry is DECISION
    input  logic tx_decision_ready,

    output logic [31:0] tx_decision_sequence_number,
    output logic [15:0] tx_decision_symbol_id,
    output logic [31:0] tx_decision_intent_id,
    output logic [31:0] tx_decision,
    output logic [31:0] tx_reject_reason,
    output logic tx_source_frame_ok
);

  localparam int unsigned EVENT_WIDTH = 146;

  logic [EVENT_WIDTH-1:0] fifo_write_data;
  logic [EVENT_WIDTH-1:0] fifo_read_data;

  logic fifo_write;
  logic fifo_read;
  logic fifo_full;
  logic fifo_empty;
  logic fifo_write_reset_busy;
  logic fifo_read_reset_busy;

  logic tx_event_is_decision;


  // ORDER_INTENT detection and accept/reject decision cannot occur together because decoded messages are separated by at least four RX clocks
  assign fifo_write = !rst && !fifo_full && !fifo_write_reset_busy && (rx_order_intent_valid || rx_decision_valid);
  assign fifo_write_data = {rx_decision_valid, rx_source_frame_ok, rx_decision_sequence_number, rx_decision_symbol_id, rx_decision_intent_id, rx_decision, rx_reject_reason};
  assign {tx_event_is_decision, tx_source_frame_ok, tx_decision_sequence_number, tx_decision_symbol_id, tx_decision_intent_id, tx_decision, tx_reject_reason} = fifo_read_data;
  assign tx_response_start_valid = !fifo_empty && !fifo_read_reset_busy && !tx_event_is_decision;
  assign tx_decision_valid = !fifo_empty && !fifo_read_reset_busy && tx_event_is_decision;
  assign fifo_read = (tx_response_start_valid && tx_response_start_ready) || (tx_decision_valid && tx_decision_ready);


  xpm_fifo_async #(
      .CDC_SYNC_STAGES(2),
      .FIFO_MEMORY_TYPE("auto"),
      .FIFO_READ_LATENCY(0),
      .FIFO_WRITE_DEPTH(16),
      .READ_DATA_WIDTH(EVENT_WIDTH),
      .READ_MODE("fwft"),
      .RELATED_CLOCKS(0),
      .USE_ADV_FEATURES("0000"),
      .WRITE_DATA_WIDTH(EVENT_WIDTH)
  ) u_response_event_fifo (
      .rst(rst),

      .wr_clk(rx_clk),  // write occurs in rx clk domain
      .wr_en(fifo_write),
      .din(fifo_write_data),
      .full(fifo_full),
      .wr_rst_busy(fifo_write_reset_busy),  // write side reset ongoing, no writes allowed

      .rd_clk(tx_clk),  // read and remove occurs in tx clk domain
      .rd_en(fifo_read),
      .dout(fifo_read_data),
      .empty(fifo_empty),
      .rd_rst_busy(fifo_read_reset_busy),  // read side reset ongoing, no read allowed

      .sleep(1'b0),
      .injectsbiterr(1'b0),
      .injectdbiterr(1'b0),
      .almost_empty(),
      .almost_full(),
      .data_valid(),
      .dbiterr(),
      .overflow(),
      .prog_empty(),
      .prog_full(),
      .rd_data_count(),
      .sbiterr(),
      .underflow(),
      .wr_ack(),
      .wr_data_count()
  );

endmodule
