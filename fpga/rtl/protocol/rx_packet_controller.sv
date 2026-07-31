// Resolves an accepted UDP packet after decoding and frame integrity complete
// Either result may arrive first

module rx_packet_controller (
    input logic clk,
    input logic rst,

    input logic packet_failure_event,  // current packet invalid
    input logic packet_start,  // first accepted UDP payload word
    input logic decode_complete,  // final decoded message
    input logic frame_abort,  // physical receive abort with no FCS result
    input logic decode_abort,  // decoded stream terminated by abort

    input logic fcs_result_valid,  // FCS verdict available
    input logic fcs_ok,  // verdict value

    output logic packet_commit,  // pending writes may update states in BRAM
    output logic packet_discard, // pending writes must be discarded

    output logic integrity_known,  // FCS or physical-abort result is known
    output logic integrity_result_valid,  // new integrity result this cycle
    output logic integrity_ok,  // incoming frame passed FCS
    output logic integrity_failure  // bad incoming FCS; later enters STREAM_FAULT
);

  logic packet_pending;  // Packet is awaiting commit or discard
  logic decode_done;  // Decoder reached packet end or abort
  logic fcs_seen;  // Integrity result has arrived
  logic fcs_passed;  // Captured integrity result was good
  logic packet_failed;  // Packet cannot be committed to BRAM

  logic fcs_event;  // First integrity result for this packet
  logic fcs_event_passed;  // Current integrity result is good
  logic failure_event;  // Current event makes the packet invalid
  logic decode_ready;  // Logical processing is complete
  logic fcs_ready;  // Physical integrity is known
  logic failure_ready;  // Current or earlier failure exists
  logic resolve_event;  // Logical and physical processing are complete
  logic commit_event;  // Resolve with no failure
  logic discard_event;  // Report a packet failure


  assign integrity_known = fcs_seen;
  assign integrity_ok = fcs_seen && fcs_passed;


  always_comb begin
    fcs_event = packet_pending && !fcs_seen && (frame_abort || fcs_result_valid);
    fcs_event_passed = fcs_result_valid && fcs_ok && !frame_abort;
    failure_event = packet_pending && (decode_abort || frame_abort || packet_failure_event || (fcs_event && !fcs_event_passed));
    decode_ready = decode_done || decode_complete || decode_abort;
    fcs_ready = fcs_seen || fcs_event;
    failure_ready = packet_failed || failure_event;
    resolve_event = packet_pending && decode_ready && fcs_ready;
    commit_event = resolve_event && !failure_ready;
    discard_event = resolve_event && failure_ready;
  end


  always_ff @(posedge clk) begin
    if (rst) begin
      packet_pending <= 1'b0;
      decode_done <= 1'b0;
      fcs_seen <= 1'b0;
      fcs_passed <= 1'b0;
      packet_failed <= 1'b0;

      packet_commit <= 1'b0;
      packet_discard <= 1'b0;
      integrity_result_valid <= 1'b0;
      integrity_failure <= 1'b0;
    end
    else begin
      packet_commit <= commit_event;
      packet_discard <= discard_event;
      integrity_result_valid <= fcs_event;
      integrity_failure <= fcs_event && !fcs_event_passed;

      if (packet_start && !packet_pending) begin
        packet_pending <= 1'b1;
        decode_done <= 1'b0;
        fcs_seen <= 1'b0;
        fcs_passed <= 1'b0;
        packet_failed <= 1'b0;
      end

      if (packet_pending) begin
        if (decode_complete || decode_abort) begin
          decode_done <= 1'b1;
        end

        if (fcs_event) begin
          fcs_seen <= 1'b1;
          fcs_passed <= fcs_event_passed;
        end

        if (failure_event) begin
          packet_failed <= 1'b1;
        end

        if (resolve_event) begin
          packet_pending <= 1'b0;
          decode_done <= 1'b0;
          packet_failed <= 1'b0;
        end
      end
    end
  end

endmodule
