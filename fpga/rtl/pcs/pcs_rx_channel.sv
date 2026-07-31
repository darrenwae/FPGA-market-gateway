module pcs_rx_channel (
    input logic clk,
    input logic rst,

    input logic [63:0] rx_data,
    input logic [1:0] rx_header,
    input logic rx_data_valid,
    input logic rx_header_valid,

    output logic rx_gearbox_slip,
    output logic block_lock,

    output logic [63:0] frame_data,
    output logic [7:0] frame_keep,
    output logic frame_start,
    output logic frame_end,
    output logic frame_valid,
    output logic frame_abort,
    output logic bad_block,
    output logic sequence_error
);

  logic [63:0] block_payload;
  logic [1:0] block_header;
  logic block_valid;

  logic [63:0] descrambled_payload;
  logic [1:0] descrambled_header;
  logic descrambled_valid;

  pcs_rx_block_lock u_block_lock (
      .clk(clk),
      .rst(rst),
      .rx_data(rx_data),
      .rx_header(rx_header),
      .rx_data_valid(rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .rx_gearbox_slip(rx_gearbox_slip),
      .block_payload(block_payload),
      .block_header(block_header),
      .block_valid(block_valid),
      .block_lock(block_lock)
  );

  pcs_rx_descrambler u_descrambler (
      .clk(clk),
      .rst(rst),
      .block_lock(block_lock),
      .block_payload(block_payload),
      .block_header(block_header),
      .block_valid(block_valid),
      .descrambled_payload(descrambled_payload),
      .header_out(descrambled_header),
      .descrambled_payload_valid(descrambled_valid)
  );

  pcs_rx_block_decoder u_block_decoder (
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

endmodule
