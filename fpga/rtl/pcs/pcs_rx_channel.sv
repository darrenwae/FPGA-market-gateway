// Per-channel 10GBASE-R receive PCS front end.
// Acquires 64b/66b block alignment and descrambles aligned payload blocks.

module pcs_rx_channel (
    input logic clk,
    input logic rst,

    input logic [63:0] rx_data,
    input logic [ 5:0] rx_header,
    input logic [ 1:0] rx_data_valid,
    input logic [ 1:0] rx_header_valid,
    input logic [ 1:0] rx_start_of_seq,

    output logic rx_gearbox_slip,
    output logic block_lock,

    output logic [63:0] descrambled_payload,
    output logic [1:0] descrambled_header,
    output logic descrambled_valid
);

  logic [63:0] block_payload;
  logic [1:0] block_header;
  logic block_valid;

  pcs_rx_block_lock u_block_lock (
      .clk(clk),
      .rst(rst),
      .rx_data(rx_data),
      .rx_header(rx_header),
      .rx_data_valid(rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .rx_start_of_seq(rx_start_of_seq),
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

endmodule
