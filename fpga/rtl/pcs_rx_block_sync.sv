module pcs_rx_block_sync #(parameter SREG_WIDTH = 160, WORD_SIZE = 32) (
    input logic [31:0] gtwiz_userdata_rx_out, // 32-bit word from GT wizard
    input logic clk, rst,
    output logic [63:0] pcs_rx_block_payload, // 64b/66b aligned block    
    output logic [1:0]  pcs_rx_block_header, // 2-bit sync header
    output logic pcs_rx_block_valid // high when a complete block is ready
);
    localparam SEARCHING = 1'b0, LOCKED = 1'b1;

    logic state, next_state;
    logic [6:0] offset, offset_next; // block boundary offset, is always even
    logic [6:0] gphase, gphase_next; // running extraction phase, is always even
    logic [6:0] p, p_next; // candidate offset under test, is even and mod 66
    logic [5:0] period_cnt, period_cnt_next; // 33-cycle period counter
    logic [6:0] match_counter, match_counter_next; // consecutive valid header count, max 64


    logic [SREG_WIDTH-1:0] sreg;
    always_ff @(posedge clk) begin
        if (rst) sreg <= {SREG_WIDTH{1'b0}};
        else begin
            sreg[SREG_WIDTH-1:WORD_SIZE] <= sreg[SREG_WIDTH-1-WORD_SIZE:0];
            sreg[WORD_SIZE-1:0] <= gtwiz_userdata_rx_out;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= SEARCHING;
            offset <= 7'd0;
            gphase <= 7'd0;
            p <= 7'd0;
            period_cnt <= 6'd0;
            match_counter <= 7'd0;
        end 
    else begin
            state <= next_state;
            offset <= offset_next;
            gphase <= gphase_next;
            p <= p_next;
            period_cnt <= period_cnt_next;
            match_counter <= match_counter_next;
    end
    end

    always_comb begin
        next_state = state;
        offset_next = offset;
        gphase_next = gphase;
        p_next = p;
        period_cnt_next = (period_cnt == 6'd32) ? 6'd0 : period_cnt + 6'd1;
        match_counter_next = match_counter;

        case (state)
            SEARCHING: begin
                if (period_cnt == 6'd32) begin
                    if (sreg[p+:2] == 2'b01 || sreg[p+:2] == 2'b10) begin
                        if (match_counter == 7'd63) begin
                            // 64 consecutive valid checks: declare lock
                            offset_next = p;
                            match_counter_next = 7'd0;
                            next_state = LOCKED;
                            gphase_next = (p + 7'd32 >= 7'd66) ? p + 7'd32 - 7'd66 : p + 7'd32;
                        end 
                        else begin
                            match_counter_next = match_counter + 7'd1;
                        end
                    end 
                    else begin
                        // invalid at this phase: try next candidate
                        p_next = (p + 7'd2 >= 7'd66) ? 7'd0 : p + 7'd2;
                        match_counter_next = 7'd0;
                    end
                end
            end

            LOCKED: begin
                if (gphase + 7'd32 >= 7'd66) begin
                    gphase_next = gphase + 7'd32 - 7'd66;
                    if (sreg[gphase+:2] == 2'b11 || sreg[gphase+:2] == 2'b00) begin
                        // lost lock: restart search
                        next_state = SEARCHING;
                        p_next = 7'd0;
                        period_cnt_next = 6'd0;
                        match_counter_next = 7'd0;
                        gphase_next = 7'd0;
                    end
                end else begin
                    gphase_next = gphase + 7'd32;
                end
            end

            default: next_state = SEARCHING;
        endcase

        if (state == LOCKED) begin
            pcs_rx_block_payload = sreg[gphase + 7'd2 +: 64];
            pcs_rx_block_header = sreg[gphase +: 2];
            pcs_rx_block_valid = ((gphase + 7'd32 >= 7'd66) && (sreg[gphase+:2] == 2'b01 || sreg[gphase+:2] == 2'b10));
        end 
        else begin
            pcs_rx_block_payload = 64'b0;
            pcs_rx_block_header = 2'b0;
            pcs_rx_block_valid = 1'b0;
        end
    end

endmodule
