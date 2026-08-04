// Tracks the global downstream message sequence across UDP packets
// Sequence progress becomes verified only when the packet commits

module downstream_sequence_tracker (
    input logic clk,
    input logic rst,

    input logic message_valid,
    input logic [31:0] message_sequence_number,
    input logic message_packet_start,
    input logic message_packet_end,
    input logic message_is_full_reset_all,

    input logic packet_commit,
    input logic packet_discard,
    input logic integrity_failure,

    output logic sequence_mismatch_event,
    output logic stream_fault,
    output logic effective_stream_fault,
    output logic [31:0] verified_next_sequence_number
);

  localparam logic [31:0] INITIAL_SEQUENCE_NUMBER = 32'd1;

  logic [31:0] current_packet_next_sequence_number;
  logic full_reset_recovery_pending;

  logic [31:0] next_sequence_number_after_current_message;
  logic current_message_has_sequence_mismatch;
  logic current_message_is_isolated_full_reset_all;

  assign next_sequence_number_after_current_message = message_sequence_number + 32'd1;
  assign current_message_has_sequence_mismatch = message_valid && !stream_fault && (message_sequence_number != current_packet_next_sequence_number);
  assign current_message_is_isolated_full_reset_all = message_valid && message_packet_start && message_packet_end && message_is_full_reset_all;
  assign sequence_mismatch_event = current_message_has_sequence_mismatch;
  assign effective_stream_fault = stream_fault || current_message_has_sequence_mismatch || integrity_failure;

  always_ff @(posedge clk) begin
    if (rst) begin
      verified_next_sequence_number <= INITIAL_SEQUENCE_NUMBER;
      current_packet_next_sequence_number <= INITIAL_SEQUENCE_NUMBER;
      full_reset_recovery_pending <= 1'b0;
      stream_fault <= 1'b0;
    end
    else begin
      if (integrity_failure || current_message_has_sequence_mismatch || packet_discard) begin
        stream_fault <= 1'b1;
      end
      else if (packet_commit && full_reset_recovery_pending) begin
        stream_fault <= 1'b0;
      end

      if (packet_discard) begin
        current_packet_next_sequence_number <= verified_next_sequence_number;

        full_reset_recovery_pending <= 1'b0;
      end
      else if (packet_commit) begin
        if (!stream_fault || full_reset_recovery_pending) begin
          verified_next_sequence_number <= current_packet_next_sequence_number;
        end
        full_reset_recovery_pending <= 1'b0;
      end
      else if (message_valid) begin
        if (!stream_fault) begin
          if (!current_message_has_sequence_mismatch) begin
            current_packet_next_sequence_number <= next_sequence_number_after_current_message;
          end
        end
        else if (current_message_is_isolated_full_reset_all) begin
          current_packet_next_sequence_number <= next_sequence_number_after_current_message;

          full_reset_recovery_pending <= 1'b1;
        end
      end
    end
  end

endmodule
