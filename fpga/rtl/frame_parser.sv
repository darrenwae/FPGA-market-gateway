// 49 Bytes: [6 Preamble][1 SFD][6 Dest Addr][6 Source Addr][2 EtherType][28 IPv4/UDP]

module frame_parser (
    input logic [1:0] pcs_header, // 2 bit sync header
    
    // Declared [0:63] (MSB-first) intentionally, opposite of the
    // [63:0] convention used elsewhere. This makes descrambled_data_in[0:7] equal
    // to byte 0 (first bit transmitted on the wire), matching serial order directly
    // pcs_rx_descrambler's [63:0] output must connect here positionally so bit 63
    // (first transmitted) lands on index 0. Do not "fix" this to [63:0] without also 
    // reversing the byte-slice logic below.
    input logic [0:63] descrambled_data_in, // 64 bit block
    input logic valid_data_in,
    input logic rst, clk,
    output logic payload_valid, // assert upon payload_bytes_left == 0
    output logic [255:0] payload //32 bytes(256 bits) payload
    
);

    localparam NOT_IN_FRAME = 0, IN_FRAME = 1;

    logic [5:0] header_bytes_undiscarded = 6'd49; // countdown from 49 header bytes to discard
    logic [5:0] header_bytes_undiscarded_next;

    logic [4:0] payload_bytes_consumed;
    logic [4:0] payload_bytes_consumed_next;

    logic [255:0] payload_next;
    logic payload_valid_next;
    logic state, next_state;

    logic [3:0] real_byte_count; // number of data bytes in a block
    logic [3:0] discard_now; // number of useless header bytes to discard in this block
    logic [3:0] payload_now; // number of payload bytes in this block
    logic frame_start, frame_end, protocol_error;
    logic [7:0] type_field;

    logic [4:0] dest_slot;

    always_ff @(posedge clk) begin
        if (rst) begin 
            payload <= 256'b0;
            payload_valid <= 0;
            header_bytes_undiscarded <= 6'd49;
            payload_bytes_consumed <= 5'd0;
            state <= NOT_IN_FRAME;
        end
        else begin
            if (valid_data_in) begin
                payload <= payload_next;
                payload_valid <= payload_valid_next;
                header_bytes_undiscarded <= header_bytes_undiscarded_next;
                payload_bytes_consumed <= payload_bytes_consumed_next;
                state <= next_state;
            end
        end
    end

    always_comb begin 
        next_state =state;
        header_bytes_undiscarded_next = header_bytes_undiscarded;

        payload_bytes_consumed_next = payload_bytes_consumed;
        payload_valid_next = 1'b0;
        payload_next = payload;
        dest_slot = 5'b0;

        type_field = descrambled_data_in[0:7];
        if (pcs_header == 2'b01) begin
            real_byte_count = 4'd8;
            frame_start = 0; // 1 if frame begins in the block, transition to IN_FRAME
            frame_end = 0; // 1 is frame ends in this block
            protocol_error = 0;
        end 
        else begin
            case (type_field)
                8'h78: begin real_byte_count = 4'd7; frame_start = 1; frame_end = 0; protocol_error = 0;end
                8'h1e: begin real_byte_count = 4'd0; frame_start = 0; frame_end = 0; protocol_error = 0;end
                8'h87: begin real_byte_count = 4'd0; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'h99: begin real_byte_count = 4'd1; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'haa: begin real_byte_count = 4'd2; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'hb4: begin real_byte_count = 4'd3; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'hcc: begin real_byte_count = 4'd4; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'hd2: begin real_byte_count = 4'd5; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'he1: begin real_byte_count = 4'd6; frame_start = 0; frame_end = 1; protocol_error = 0;end
                8'hff: begin real_byte_count = 4'd7; frame_start = 0; frame_end = 1; protocol_error = 0;end
                default: begin real_byte_count = 4'd0; frame_start = 0; frame_end = 0; protocol_error = 1;end
            endcase
        end
        discard_now = (header_bytes_undiscarded > real_byte_count) ? real_byte_count : header_bytes_undiscarded[3:0];
        payload_now = real_byte_count - discard_now;

        case (state)
            NOT_IN_FRAME: begin
                if (frame_start) begin
                    next_state = IN_FRAME;
                    header_bytes_undiscarded_next = 6'd49 - {2'b0, real_byte_count};
                end
            end 
            IN_FRAME: begin
                header_bytes_undiscarded_next = header_bytes_undiscarded - {2'b0, discard_now};
                for (int i = 0; i < 8; i++) begin
                    if (i >= discard_now && i < real_byte_count) begin
                        dest_slot = payload_bytes_consumed + (i - discard_now);
                        payload_next[dest_slot*8+:8] = pcs_header == 2'b01 ? descrambled_data_in[i*8+:8] : descrambled_data_in[(i+1)*8+:8];
                    end
                end
                payload_valid_next = ({1'b0, payload_bytes_consumed} + {2'b0, payload_now}) >= 6'd32;
                payload_bytes_consumed_next = payload_bytes_consumed + payload_now;
            
                if (frame_end || protocol_error) begin
                    next_state = NOT_IN_FRAME;
                end
            end
            default: 
                next_state = NOT_IN_FRAME;
        endcase
    end

endmodule
