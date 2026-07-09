module pcs_rx_descrambler #() (
    input logic [63:0] pcs_rx_scrambled_block_payload_in, // 64b/66b aligned block    
    input logic [1:0]  pcs_rx_header_in, // 2-bit sync header
    input logic pcs_rx_block_valid_in,
    input logic clk, rst,
    output logic [63:0] pcs_rx_descrambled_block_payload_out, //64 bits descrambled data
    output logic [1:0] pcs_rx_header_out, //pass through header
    output logic pcs_rx_header_valid_out
);

    logic [57:0] Rx_lfsr;
    logic [63:0] descrambled_data_out;

    always_ff @(posedge clk) begin
        if (rst) begin
            Rx_lfsr <= 58'b0;
        end
        else begin
            if (pcs_rx_block_valid_in) begin
                Rx_lfsr <= pcs_rx_scrambled_block_payload_in[57:0];
            end
            pcs_rx_header_out <= pcs_rx_header_in;
            pcs_rx_header_valid_out <= pcs_rx_block_valid_in;
            pcs_rx_descrambled_block_payload_out <= descrambled_data_out;
        end
    end

    always_comb begin
        for (int j = 0; j < 64; j++) begin
            descrambled_data_out[j] = pcs_rx_scrambled_block_payload_in[j] ^ ((j <= 24) ? pcs_rx_scrambled_block_payload_in[j+39] : Rx_lfsr[j-25]) ^ ((j <= 5) ? pcs_rx_scrambled_block_payload_in[j+58] : Rx_lfsr[j-6]);
        end
    end

endmodule
