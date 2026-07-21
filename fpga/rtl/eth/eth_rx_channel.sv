// Integrates the 10GBASE-R PCS receive path with Ethernet FCS checking

module eth_rx_channel (
    input logic clk,
    input logic rst,

    input logic [63:0] rx_data,
    input logic [5:0] rx_header,
    input logic [1:0] rx_data_valid,
    input logic [1:0] rx_header_valid,
    input logic [1:0] rx_start_of_seq,

    output logic rx_gearbox_slip,
    output logic block_lock,

    output logic [63:0] frame_data,
    output logic [7:0] frame_keep,
    output logic frame_start,
    output logic frame_end,
    output logic frame_valid,
    output logic frame_abort,

    output logic bad_block,
    output logic sequence_error,

    output logic fcs_result_valid,
    output logic fcs_ok
);

  pcs_rx_channel u_pcs_rx_channel (
      .clk(clk),
      .rst(rst),
      .rx_data(rx_data),
      .rx_header(rx_header),
      .rx_data_valid(rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .rx_start_of_seq(rx_start_of_seq),
      .rx_gearbox_slip(rx_gearbox_slip),
      .block_lock(block_lock),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_abort(frame_abort),
      .bad_block(bad_block),
      .sequence_error(sequence_error)
  );

  eth_rx_fcs_checker u_fcs_checker (
      .clk(clk),
      .rst(rst),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_abort(frame_abort),
      .fcs_result_valid(fcs_result_valid),
      .fcs_ok(fcs_ok)
  );

endmodule
