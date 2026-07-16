// implements self synchronising 64/66b payload descrambler

module pcs_rx_descrambler (
    input logic clk,
    input logic rst,

    input logic block_lock,
    input logic [63:0] block_payload,
    input logic [1:0] block_header,
    input logic block_valid,

    output logic [63:0] descrambled_payload,
    output logic [1:0] header_out,
    output logic descrambled_payload_valid
);

    //rx_lfsr[57] = scrambled bit received 58 bit-times ago
    //rx_lfsr[0]  = most recently received scrambled bit
    logic [57:0] rx_lfsr;
    logic sync_pending;
    logic [63:0] descrambled_payload_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_lfsr <= '0;
            sync_pending <= 1'b1;
            descrambled_payload <= '0;
            header_out <= '0;
            descrambled_payload_valid <= 1'b0;
        end
        else begin
            descrambled_payload_valid <= 1'b0;
            if (!block_lock) begin
                // alignment lost, have to re-sync
                rx_lfsr <= '0;
                sync_pending <= 1'b1;
            end
            else if (block_valid) begin
                // last 58 bits used as lfsr for descrambling next block
                rx_lfsr <= block_payload[57:0];
                if (sync_pending) begin
                    // first aligned block used for synchronising lfsr with transmitter's lfsr
                    sync_pending <= 1'b0;
                end
                else begin
                    descrambled_payload <= descrambled_payload_next;
                    header_out <= block_header;
                    descrambled_payload_valid <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        for (int j = 0; j < 64; j++) begin
            descrambled_payload_next[j] = block_payload[j] ^ ((j <= 24) ? block_payload[j + 39] : rx_lfsr[j - 25]) ^ ((j <= 5) ? block_payload[j + 58] : rx_lfsr[j - 6]);
        end
    end

endmodule
