`timescale 1ns / 1ps

module tb_pcs_tx_channel;

  localparam time CLK_PERIOD = 6.206ns;

  localparam int unsigned FRAME_BYTE_COUNT = 85;

  localparam logic [1:0] SYNC_DATA = 2'b01;
  localparam logic [1:0] SYNC_CONTROL = 2'b10;

  localparam logic [7:0] BLOCK_TYPE_IDLE = 8'h1E;


  logic clk;
  logic rst;

  logic [63:0] frame_data;
  logic frame_start;
  logic frame_end;
  logic frame_valid;
  logic frame_start_ready;

  logic [63:0] tx_data;
  logic [5:0] tx_header;
  logic [6:0] tx_sequence;


  logic loopback_block_valid;

  logic [63:0] loopback_descrambled_payload;
  logic [1:0] loopback_descrambled_header;
  logic loopback_descrambled_valid;

  logic [63:0] loopback_normalized_payload;

  logic [63:0] loopback_frame_data;
  logic [7:0] loopback_frame_keep;
  logic loopback_frame_start;
  logic loopback_frame_end;
  logic loopback_frame_valid;
  logic loopback_frame_abort;
  logic loopback_bad_block;
  logic loopback_sequence_error;


  logic [7:0] test_frame_bytes[0:1][0:FRAME_BYTE_COUNT-1];

  int unsigned received_frame_count;
  int unsigned received_byte_count;
  int unsigned idle_block_count;

  int unsigned interframe_idle_count;
  int unsigned last_interframe_idle_count;

  logic receiving_frame;
  logic waiting_for_next_frame;
  logic saw_pause_during_frame;

  logic sequence_tracking_started;
  logic [5:0] previous_sequence;
  logic [63:0] pause_data;
  logic [5:0] pause_header;


  pcs_tx_channel dut (
      .clk(clk),
      .rst(rst),

      .frame_data(frame_data),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_start_ready(frame_start_ready),

      .tx_data(tx_data),
      .tx_header(tx_header),
      .tx_sequence(tx_sequence)
  );


  assign loopback_block_valid = !rst && (tx_sequence[5:0] != 6'd32);

  pcs_rx_descrambler u_loopback_descrambler (
      .clk(clk),
      .rst(rst),

      .block_lock(1'b1),
      .block_payload(tx_data),
      .block_header(tx_header[1:0]),
      .block_valid(loopback_block_valid),

      .descrambled_payload(loopback_descrambled_payload),
      .header_out(loopback_descrambled_header),
      .descrambled_payload_valid(loopback_descrambled_valid)
  );


  pcs_rx_block_decoder u_loopback_decoder (
      .clk(clk),
      .rst(rst),

      .descrambled_payload(loopback_descrambled_payload),
      .descrambled_header (loopback_descrambled_header),
      .descrambled_valid  (loopback_descrambled_valid),

      .frame_data (loopback_frame_data),
      .frame_keep (loopback_frame_keep),
      .frame_start(loopback_frame_start),
      .frame_end  (loopback_frame_end),
      .frame_valid(loopback_frame_valid),
      .frame_abort(loopback_frame_abort),

      .bad_block(loopback_bad_block),
      .sequence_error(loopback_sequence_error)
  );


  function automatic logic [63:0] reverse_payload_bits(input logic [63:0] payload);
    begin
      for (int bit_index = 0; bit_index < 64; bit_index++) begin
        reverse_payload_bits[bit_index] = payload[63-bit_index];
      end
    end
  endfunction


  assign loopback_normalized_payload = reverse_payload_bits(loopback_descrambled_payload);


  function automatic logic [63:0] pack_frame_bytes(input int unsigned frame_index, input int unsigned first_byte, input int unsigned byte_count);
    logic [63:0] packed_word;

    begin
      packed_word = '0;

      for (int unsigned byte_index = 0; byte_index < byte_count; byte_index++) begin

        packed_word[byte_index*8+:8] = test_frame_bytes[frame_index][first_byte+byte_index];
      end

      pack_frame_bytes = packed_word;
    end
  endfunction


  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end


  task automatic drive_idle;
    begin
      frame_data = '0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_valid = 1'b0;
    end
  endtask


  task automatic initialize_inputs;
    begin
      rst = 1'b1;
      drive_idle();
    end
  endtask


  task automatic build_test_frames;
    begin
      for (int unsigned byte_index = 0; byte_index < FRAME_BYTE_COUNT; byte_index++) begin

        test_frame_bytes[0][byte_index] = byte_index[7:0];

        test_frame_bytes[1][byte_index] = 8'hA5 ^ byte_index[7:0];
      end
    end
  endtask


  task automatic apply_reset;
    begin
      @(negedge clk);
      #1ps;

      rst = 1'b1;
      drive_idle();

      repeat (4) @(posedge clk);

      @(negedge clk);
      #1ps;

      rst = 1'b0;
    end
  endtask


  // Must be called while clk is low.
  task automatic send_frame_when_ready(input int unsigned frame_index);
    begin
      while (!frame_start_ready) begin
        @(negedge clk);
      end

      frame_data = pack_frame_bytes(frame_index, 0, 8);

      frame_start = 1'b1;
      frame_end = 1'b0;
      frame_valid = 1'b1;

      for (int unsigned byte_offset = 8; byte_offset < 80; byte_offset += 8) begin

        @(negedge clk);

        frame_data = pack_frame_bytes(frame_index, byte_offset, 8);

        frame_start = 1'b0;
        frame_end = 1'b0;
        frame_valid = 1'b1;
      end

      @(negedge clk);

      frame_data = pack_frame_bytes(frame_index, 80, 5);

      frame_start = 1'b0;
      frame_end = 1'b1;
      frame_valid = 1'b1;

      @(negedge clk);
      drive_idle();
    end
  endtask


  task automatic wait_for_idle_blocks(input int unsigned expected_count, input string label);
    int unsigned timeout_cycles;

    begin
      timeout_cycles = 0;

      while ((idle_block_count < expected_count) && (timeout_cycles < 200)) begin
        @(posedge clk);
        timeout_cycles++;
      end

      if (idle_block_count < expected_count) begin
        $fatal(1, "%s: timed out waiting for idle blocks", label);
      end
    end
  endtask


  task automatic wait_for_frames(input int unsigned expected_count, input string label);
    int unsigned timeout_cycles;

    begin
      timeout_cycles = 0;

      while ((received_frame_count < expected_count) && (timeout_cycles < 300)) begin
        @(posedge clk);
        timeout_cycles++;
      end

      if (received_frame_count < expected_count) begin
        $fatal(1, "%s: expected %0d frames, received %0d", label, expected_count, received_frame_count);
      end
    end
  endtask


  always @(negedge clk) begin
    if (rst) begin
      received_frame_count = 0;
      received_byte_count = 0;
      idle_block_count = 0;

      interframe_idle_count = 0;
      last_interframe_idle_count = 0;

      receiving_frame = 1'b0;
      waiting_for_next_frame = 1'b0;
      saw_pause_during_frame = 1'b0;

      sequence_tracking_started = 1'b0;
      previous_sequence = '0;
      pause_data = '0;
      pause_header = '0;
    end
    else begin
      if (tx_sequence[6] !== 1'b0) $fatal(1, "tx_sequence[6] must remain zero");
      if (tx_header[5:2] !== 4'b0000) $fatal(1, "Unused tx_header bits are not zero");
      if ((tx_header[1:0] !== SYNC_DATA) && (tx_header[1:0] !== SYNC_CONTROL)) $fatal(1, "Invalid TX sync header %b", tx_header[1:0]);

      if (sequence_tracking_started) begin
        if (previous_sequence == 6'd32) begin
          if (tx_sequence[5:0] !== 6'd0) begin
            $fatal(1, "TX sequence did not wrap from 32 to 0");
          end

          if ((tx_data !== pause_data) || (tx_header !== pause_header)) begin
            $fatal(1, "TX data changed between pause sequence 32 and sequence 0");
          end
        end
        else if (tx_sequence[5:0] !== (previous_sequence + 1'b1)) begin
          $fatal(1, "TX sequence expected %0d, received %0d", previous_sequence + 1'b1, tx_sequence[5:0]);
        end
      end
      else begin
        sequence_tracking_started = 1'b1;
      end

      if (tx_sequence[5:0] == 6'd32) begin
        pause_data = tx_data;
        pause_header = tx_header;

        if (receiving_frame) begin
          saw_pause_during_frame = 1'b1;
        end
      end

      previous_sequence = tx_sequence[5:0];


      if (loopback_frame_abort) $fatal(1, "Loopback decoder asserted frame_abort");
      if (loopback_bad_block) $fatal(1, "Loopback decoder detected a bad block");
      if (loopback_sequence_error) $fatal(1, "Loopback decoder detected a sequence error");


      if (loopback_descrambled_valid && !loopback_frame_valid) begin

        if (loopback_descrambled_header !== SYNC_CONTROL) $fatal(1, "Idle block used incorrect sync header");
        if (loopback_normalized_payload !== 64'h0000_0000_0000_001E) $fatal(1, "Invalid idle block payload: %016h", loopback_normalized_payload);

        idle_block_count++;

        if (waiting_for_next_frame) begin
          interframe_idle_count++;
        end
      end

      if (loopback_frame_valid) begin
        if (loopback_frame_start) begin
          if (receiving_frame) $fatal(1, "Received START while a frame was active");
          if (received_frame_count >= 2) $fatal(1, "Received more test frames than expected");

          receiving_frame = 1'b1;
          received_byte_count = 0;

          if (loopback_frame_keep !== 8'h7F) $fatal(1, "START block keep expected 7F, received %02h", loopback_frame_keep);

          if (waiting_for_next_frame) begin
            last_interframe_idle_count = interframe_idle_count;
            waiting_for_next_frame = 1'b0;
          end
        end
        else if (!receiving_frame) $fatal(1, "Received frame data without START");

        if (loopback_frame_end) begin
          if (loopback_frame_keep !== 8'h3F) $fatal(1, "TERMINATE block keep expected 3F, received %02h", loopback_frame_keep);
        end
        else if (!loopback_frame_start && (loopback_frame_keep !== 8'hFF)) begin
          $fatal(1, "Data block keep expected FF, received %02h", loopback_frame_keep);
        end


        for (int unsigned lane_index = 0; lane_index < 8; lane_index++) begin

          if (loopback_frame_keep[lane_index]) begin
            if (received_byte_count >= FRAME_BYTE_COUNT) begin
              $fatal(1, "Received too many bytes in frame %0d", received_frame_count);
            end

            if (loopback_frame_data[lane_index*8+:8] !== test_frame_bytes[received_frame_count][received_byte_count]) begin
              $fatal(1, "Frame %0d byte %0d mismatch: expected %02h, received %02h", received_frame_count, received_byte_count, test_frame_bytes[received_frame_count][received_byte_count], loopback_frame_data[lane_index*8+:8]);
            end

            received_byte_count++;
          end
        end


        if (loopback_frame_end) begin
          if (received_byte_count != FRAME_BYTE_COUNT) begin
            $fatal(1, "Frame %0d expected 85 bytes, received %0d", received_frame_count, received_byte_count);
          end

          receiving_frame = 1'b0;
          received_frame_count++;

          waiting_for_next_frame = 1'b1;
          interframe_idle_count = 0;
        end
      end
    end
  end


  task automatic test_idle_output;
    begin
      // Purpose: verify continuous valid idle blocks and gearbox sequencing.
      // Input: reset followed by no frame traffic.
      // Expected: valid decoded idle blocks and no decoder errors.

      $display("TEST: idle output");

      apply_reset();
      wait_for_idle_blocks(4, "idle output");

      if (received_frame_count != 0) begin
        $fatal(1, "Idle test unexpectedly received a frame");
      end

      $display("PASS: idle output");
    end
  endtask


  task automatic test_frame_crossing_gearbox_pause;
    int unsigned timeout_cycles;

    begin
      // Purpose: verify that a frame remains continuous across sequence 32.
      // Input: one 85-byte frame started shortly before the pause.
      // Expected: all 85 bytes recovered exactly once with no block error.

      $display("TEST: frame crossing gearbox pause");

      apply_reset();
      wait_for_idle_blocks(4, "pause test synchronization");

      @(negedge clk);
      timeout_cycles = 0;

      while (((tx_sequence[5:0] != 6'd27) || !frame_start_ready) && (timeout_cycles < 100)) begin
        @(negedge clk);
        timeout_cycles++;
      end

      if (timeout_cycles == 100) $fatal(1, "Timed out aligning frame with gearbox pause");

      send_frame_when_ready(0);
      wait_for_frames(1, "frame crossing gearbox pause");

      if (!saw_pause_during_frame) $fatal(1, "Frame did not encounter the intended gearbox pause");

      $display("PASS: frame crossing gearbox pause");
    end
  endtask


  task automatic test_back_to_back_frames;
    begin
      // Purpose: verify the minimum implemented gap between queued responses.
      // Input: two frames supplied whenever frame_start_ready permits.
      // Expected: both frames recovered with exactly two idle blocks between.

      $display("TEST: back-to-back frames");

      apply_reset();
      wait_for_idle_blocks(4, "back-to-back synchronization");

      @(negedge clk);

      send_frame_when_ready(0);
      send_frame_when_ready(1);
      wait_for_frames(2, "back-to-back frames");

      if (last_interframe_idle_count != 2) $fatal(1, "Expected two inter-frame idle blocks, observed %0d", last_interframe_idle_count);

      $display("PASS: back-to-back frames");
    end
  endtask


  initial begin
    initialize_inputs();
    build_test_frames();
    test_idle_output();
    test_frame_crossing_gearbox_pause();
    test_back_to_back_frames();

    $display("PASS: all PCS TX channel tests");
    $finish;
  end

endmodule
