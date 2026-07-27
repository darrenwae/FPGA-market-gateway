// Tracks the global downstream message sequence across UDP packets
// Sequence progress becomes verified only when the packet commits

module downstream_sequence_tracker (
    input logic clk,
    input logic rst,

    input logic message_valid,
    input logic [31:0] message_sequence_number,
    input logic message_packet_start,
    input logic message_packet_end,
    input logic message_is_reset_all,

    input logic packet_commit,
    input logic packet_discard,
    input logic integrity_failure,

    output logic sequence_mismatch_event,

    // Persistent fault state, cleared only by a committed RESET_ALL packet
    output logic stream_fault,

    // Immediate risk-engine view, including a fault discovered this cycle
    output logic effective_stream_fault,

    output logic [31:0] verified_next_sequence_number
);

  localparam logic [31:0] INITIAL_SEQUENCE_NUMBER = 32'd1;

  logic [31:0] current_packet_next_sequence_number;
  logic current_packet_has_sequence_mismatch;

  // Remembers an isolated RESET_ALL while waiting for packet resolution
  logic reset_all_recovery_pending;
  logic [31:0] reset_all_recovery_next_sequence_number;

  logic [31:0] expected_sequence_number_for_current_message;
  logic [31:0] next_sequence_number_after_current_message;

  logic current_message_has_sequence_mismatch;
  logic current_message_is_isolated_reset_all;
  logic reset_all_recovery_commit;

  assign expected_sequence_number_for_current_message = message_packet_start ? verified_next_sequence_number : current_packet_next_sequence_number;

  assign next_sequence_number_after_current_message = message_sequence_number + 32'd1;

  assign current_message_has_sequence_mismatch = message_valid && !stream_fault && !current_packet_has_sequence_mismatch && (message_sequence_number != expected_sequence_number_for_current_message);

  assign current_message_is_isolated_reset_all = message_valid && message_packet_start && message_packet_end && message_is_reset_all;

  assign reset_all_recovery_commit = packet_commit && stream_fault && (reset_all_recovery_pending || current_message_is_isolated_reset_all);

  assign sequence_mismatch_event = current_message_has_sequence_mismatch;

  assign effective_stream_fault = stream_fault || current_packet_has_sequence_mismatch || current_message_has_sequence_mismatch || integrity_failure;

  always_ff @(posedge clk) begin
    if (rst) begin
      verified_next_sequence_number <= INITIAL_SEQUENCE_NUMBER;

      current_packet_next_sequence_number <= INITIAL_SEQUENCE_NUMBER;

      current_packet_has_sequence_mismatch <= 1'b0;

      reset_all_recovery_pending <= 1'b0;

      reset_all_recovery_next_sequence_number <= INITIAL_SEQUENCE_NUMBER;

      stream_fault <= 1'b0;
    end
    else begin
      if (integrity_failure || current_message_has_sequence_mismatch) begin
        stream_fault <= 1'b1;
      end
      else if (reset_all_recovery_commit) begin
        stream_fault <= 1'b0;
      end

      if (packet_discard) begin
        current_packet_next_sequence_number <= verified_next_sequence_number;

        current_packet_has_sequence_mismatch <= 1'b0;
        reset_all_recovery_pending <= 1'b0;
      end
      else if (packet_commit) begin
        current_packet_has_sequence_mismatch <= 1'b0;
        reset_all_recovery_pending <= 1'b0;

        if (reset_all_recovery_commit && !integrity_failure) begin

          if (current_message_is_isolated_reset_all) begin
            verified_next_sequence_number <= next_sequence_number_after_current_message;

            current_packet_next_sequence_number <= next_sequence_number_after_current_message;
          end
          else begin
            verified_next_sequence_number <= reset_all_recovery_next_sequence_number;

            current_packet_next_sequence_number <= reset_all_recovery_next_sequence_number;
          end
        end
        else if (!stream_fault && !current_packet_has_sequence_mismatch && !current_message_has_sequence_mismatch && !integrity_failure) begin

          if (message_valid) begin
            verified_next_sequence_number <= next_sequence_number_after_current_message;

            current_packet_next_sequence_number <= next_sequence_number_after_current_message;
          end
          else begin
            verified_next_sequence_number <= current_packet_next_sequence_number;
          end
        end
        else begin
          current_packet_next_sequence_number <= verified_next_sequence_number;
        end
      end
      else begin
        if (message_valid && !stream_fault && !integrity_failure) begin

          if (current_message_has_sequence_mismatch) begin
            current_packet_has_sequence_mismatch <= 1'b1;
          end
          else begin
            current_packet_next_sequence_number <= next_sequence_number_after_current_message;
          end
        end

        if (stream_fault && current_message_is_isolated_reset_all && !integrity_failure) begin

          reset_all_recovery_pending <= 1'b1;

          reset_all_recovery_next_sequence_number <= next_sequence_number_after_current_message;
        end
      end
    end
  end

endmodule
