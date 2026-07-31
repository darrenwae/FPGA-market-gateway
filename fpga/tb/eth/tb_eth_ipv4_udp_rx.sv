`timescale 1ns / 1ps

module tb_eth_ipv4_udp_rx;

  // ---------------------------------------------------------------------------
  // DUT configuration
  // ---------------------------------------------------------------------------

  localparam int unsigned UDP_PAYLOAD_OFFSET = 49;
  localparam int unsigned FCS_BYTES = 4;
  localparam int unsigned MAX_UDP_PAYLOAD_BYTES = 1472;
  localparam int unsigned MAX_FRAME_BYTE_COUNT = UDP_PAYLOAD_OFFSET + MAX_UDP_PAYLOAD_BYTES + FCS_BYTES;
  localparam int unsigned MAX_PAYLOAD_WORDS = MAX_UDP_PAYLOAD_BYTES / 8;


  // ---------------------------------------------------------------------------
  // DUT interface
  // ---------------------------------------------------------------------------

  logic clk;
  logic rst;
  logic [63:0] frame_data;
  logic [7:0] frame_keep;
  logic frame_start;
  logic frame_end;
  logic frame_valid;
  logic frame_abort;

  logic [63:0] udp_payload_data;
  logic udp_payload_start;
  logic udp_payload_end;
  logic udp_payload_valid;
  logic udp_packet_abort;

  logic parser_error;


  // ---------------------------------------------------------------------------
  // Testbench state
  // ---------------------------------------------------------------------------

  logic [7:0] frame_bytes[0:MAX_FRAME_BYTE_COUNT-1];
  logic [63:0] expected_payload_words[0:MAX_PAYLOAD_WORDS-1];
  int unsigned frame_byte_count;
  int unsigned expected_payload_word_count;
  int unsigned received_word_count;
  int unsigned error_count;

  int unsigned parser_error_count;
  int unsigned udp_packet_abort_count;

  // ---------------------------------------------------------------------------
  // Clock
  // ---------------------------------------------------------------------------

  localparam realtime CLK_PERIOD_NS = 6.20606;
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS / 2.0) clk = ~clk;


  // ---------------------------------------------------------------------------
  // DUT instance
  // ---------------------------------------------------------------------------

  eth_ipv4_udp_rx dut (
      .clk(clk),
      .rst(rst),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_abort(frame_abort),
      .udp_payload_data(udp_payload_data),
      .udp_payload_start(udp_payload_start),
      .udp_payload_end(udp_payload_end),
      .udp_payload_valid(udp_payload_valid),
      .udp_packet_abort(udp_packet_abort),
      .parser_error(parser_error)
  );

  // ---------------------------------------------------------------------------
  // Low-level input driver
  // ---------------------------------------------------------------------------

  task automatic drive_idle;
    begin
      @(negedge clk);
      frame_data = '0;
      frame_keep = '0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_valid = 1'b0;
      frame_abort = 1'b0;
    end
  endtask


  task automatic drive_beat(input logic [63:0] data, input logic [7:0] keep, input logic start, input logic last);
    begin
      @(negedge clk);
      frame_data = data;
      frame_keep = keep;
      frame_start = start;
      frame_end = last;
      frame_valid = 1'b1;
      frame_abort = 1'b0;
    end
  endtask

  task automatic drive_frame_abort;
    begin
      @(negedge clk);
      frame_data = '0;
      frame_keep = '0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_valid = 1'b0;
      frame_abort = 1'b1;
    end
  endtask


  task automatic reset_dut;
    begin
      rst = 1'b1;
      frame_data = '0;
      frame_keep = '0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_valid = 1'b0;
      frame_abort = 1'b0;

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;
    end
  endtask

  task automatic clear_test_results;
    begin
      received_word_count = 0;
      parser_error_count = 0;
      udp_packet_abort_count = 0;
      error_count = 0;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Frame construction
  // ---------------------------------------------------------------------------

  function automatic logic [63:0] pack_bytes(input int unsigned first_byte, input int unsigned byte_count);
    logic [63:0] packed_word;

    begin
      packed_word = '0;
      for (int unsigned i = 0; i < byte_count; i++) begin
        packed_word[i*8+:8] = frame_bytes[first_byte+i];
      end
      pack_bytes = packed_word;
    end
  endfunction


  task automatic build_valid_frame(input int unsigned payload_byte_count);
    logic [15:0] udp_length;
    logic [15:0] ipv4_total_length;

    begin
      if ((payload_byte_count == 0) || (payload_byte_count > MAX_UDP_PAYLOAD_BYTES) || ((payload_byte_count % 32) != 0)) begin
        $fatal(1, "Invalid test payload size: %0d bytes", payload_byte_count);
      end

      udp_length = payload_byte_count + 16'd8;
      ipv4_total_length = payload_byte_count + 16'd28;

      frame_byte_count = UDP_PAYLOAD_OFFSET + payload_byte_count + FCS_BYTES;
      for (int unsigned i = 0; i < MAX_FRAME_BYTE_COUNT; i++) begin
        frame_bytes[i] = 8'h00;
      end

      // Remaining preamble and SFD after /S/.
      frame_bytes[0] = 8'h55;
      frame_bytes[1] = 8'h55;
      frame_bytes[2] = 8'h55;
      frame_bytes[3] = 8'h55;
      frame_bytes[4] = 8'h55;
      frame_bytes[5] = 8'h55;
      frame_bytes[6] = 8'hD5;

      // Destination MAC: 02:00:00:00:00:01
      frame_bytes[7] = 8'h02;
      frame_bytes[8] = 8'h00;
      frame_bytes[9] = 8'h00;
      frame_bytes[10] = 8'h00;
      frame_bytes[11] = 8'h00;
      frame_bytes[12] = 8'h01;

      // Source MAC: 02:00:00:00:00:02
      frame_bytes[13] = 8'h02;
      frame_bytes[14] = 8'h00;
      frame_bytes[15] = 8'h00;
      frame_bytes[16] = 8'h00;
      frame_bytes[17] = 8'h00;
      frame_bytes[18] = 8'h02;

      // EtherType: IPv4
      frame_bytes[19] = 8'h08;
      frame_bytes[20] = 8'h00;

      // IPv4 header
      frame_bytes[21] = 8'h45;
      frame_bytes[22] = 8'h00;
      frame_bytes[23] = ipv4_total_length[15:8];
      frame_bytes[24] = ipv4_total_length[7:0];
      frame_bytes[25] = 8'h00;
      frame_bytes[26] = 8'h00;
      frame_bytes[27] = 8'h40;
      frame_bytes[28] = 8'h00;
      frame_bytes[29] = 8'h40;
      frame_bytes[30] = 8'h11;
      frame_bytes[31] = 8'h00;
      frame_bytes[32] = 8'h00;

      // Source IP: 192.168.1.1
      frame_bytes[33] = 8'hC0;
      frame_bytes[34] = 8'hA8;
      frame_bytes[35] = 8'h01;
      frame_bytes[36] = 8'h01;

      // Destination IP: 192.168.1.2
      frame_bytes[37] = 8'hC0;
      frame_bytes[38] = 8'hA8;
      frame_bytes[39] = 8'h01;
      frame_bytes[40] = 8'h02;

      // UDP source port: 16'h1234
      frame_bytes[41] = 8'h12;
      frame_bytes[42] = 8'h34;

      // UDP destination port: 5000
      frame_bytes[43] = 8'h13;
      frame_bytes[44] = 8'h88;

      frame_bytes[45] = udp_length[15:8];
      frame_bytes[46] = udp_length[7:0];

      // UDP checksum
      frame_bytes[47] = 8'h00;
      frame_bytes[48] = 8'h00;

      // Payload byte pattern: 00, 01, 02, ...
      for (int unsigned i = 0; i < payload_byte_count; i++) begin
        frame_bytes[UDP_PAYLOAD_OFFSET+i] = i[7:0];
      end

      // Arbitrary FCS bytes
      frame_bytes[frame_byte_count-4] = 8'hDE;
      frame_bytes[frame_byte_count-3] = 8'hAD;
      frame_bytes[frame_byte_count-2] = 8'hBE;
      frame_bytes[frame_byte_count-1] = 8'hEF;
    end
  endtask


  task automatic build_expected_payload(input int unsigned payload_byte_count);
    begin
      expected_payload_word_count = payload_byte_count >> 3;

      for (int unsigned word_index = 0; word_index < expected_payload_word_count; word_index++) begin
        expected_payload_words[word_index] = '0;
        for (int unsigned byte_lane = 0; byte_lane < 8; byte_lane++) begin
          expected_payload_words[word_index][byte_lane*8+:8] = word_index * 8 + byte_lane;
        end
      end
    end
  endtask


  // ---------------------------------------------------------------------------
  // Packet sender
  // ---------------------------------------------------------------------------

  task automatic send_start0_frame;
    int unsigned byte_offset;

    begin
      // START_0 beat carries seven bytes after /S/.
      drive_beat(pack_bytes(0, 7), 8'h7F, 1'b1, 1'b0);
      byte_offset = 7;

      // Complete eight-byte middle beats.
      while ((byte_offset + 8) <= frame_byte_count) begin
        drive_beat(pack_bytes(byte_offset, 8), 8'hFF, 1'b0, 1'b0);
        byte_offset += 8;
      end

      // Final six bytes:
      // payload bytes 30 and 31 followed by four FCS bytes.
      drive_beat(pack_bytes(byte_offset, frame_byte_count - byte_offset), 8'h3F, 1'b0, 1'b1);
      drive_idle();
    end
  endtask

  task automatic send_start4_frame;
    int unsigned byte_offset;

    begin
      // START_4 beat carries three bytes after /S/.
      drive_beat(pack_bytes(0, 3), 8'h07, 1'b1, 1'b0);
      byte_offset = 3;

      // Complete eight-byte beats
      // The final full beat contains:
      //   payload bytes 26..31
      //   first two FCS bytes
      while ((byte_offset + 8) <= frame_byte_count) begin
        drive_beat(pack_bytes(byte_offset, 8), 8'hFF, 1'b0, 1'b0);
        byte_offset += 8;
      end

      // Remaining two FCS bytes.
      drive_beat(pack_bytes(byte_offset, frame_byte_count - byte_offset), 8'h03, 1'b0, 1'b1);
      drive_idle();
    end
  endtask


  task automatic send_truncated_header_frame;
    begin
      // Legal START_0 beat: post-/S/ bytes 0..6.
      drive_beat(pack_bytes(0, 7), 8'h7F, 1'b1, 1'b0);

      // One complete header beat: bytes 7..14.
      drive_beat(pack_bytes(7, 8), 8'hFF, 1'b0, 1'b0);

      // Frame terminates after only 22 post-/S/ bytes.
      drive_beat(pack_bytes(15, 7), 8'h7F, 1'b0, 1'b1);
      drive_idle();
    end
  endtask


  task automatic send_truncated_payload_frame;
    begin
      // START_0 beat: post-/S/ bytes 0..6.
      drive_beat(pack_bytes(0, 7), 8'h7F, 1'b1, 1'b0);

      // Fixed-header beats.
      drive_beat(pack_bytes(7, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(15, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(23, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(31, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(39, 8), 8'hFF, 1'b0, 1'b0);

      // Contains the final two UDP-header bytes and payload bytes 0..5.
      // The DUT buffers this beat when entering PAYLOAD.
      drive_beat(pack_bytes(47, 8), 8'hFF, 1'b0, 1'b0);

      // Completes payload output word 0: payload bytes 0..7.
      drive_beat(pack_bytes(55, 8), 8'hFF, 1'b0, 1'b0);

      // Frame terminates before the declared 64-byte payload completes.
      drive_beat(pack_bytes(63, 4), 8'h0F, 1'b0, 1'b1);
      drive_idle();
    end
  endtask

  task automatic send_abort_during_header;
    begin
      // Legal START_0 beat.
      drive_beat(pack_bytes(0, 7), 8'h7F, 1'b1, 1'b0);

      // Two normal header beats.
      drive_beat(pack_bytes(7, 8), 8'hFF, 1'b0, 1'b0);

      drive_beat(pack_bytes(15, 8), 8'hFF, 1'b0, 1'b0);

      // Upstream PCS/MAC invalidates the frame.
      drive_frame_abort();
      drive_idle();
    end
  endtask

  task automatic send_abort_after_payload_started;
    begin
      // START_0 beat.
      drive_beat(pack_bytes(0, 7), 8'h7F, 1'b1, 1'b0);

      // Fixed header.
      drive_beat(pack_bytes(7, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(15, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(23, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(31, 8), 8'hFF, 1'b0, 1'b0);
      drive_beat(pack_bytes(39, 8), 8'hFF, 1'b0, 1'b0);

      // Final two UDP-header bytes and payload bytes 0..5.
      drive_beat(pack_bytes(47, 8), 8'hFF, 1'b0, 1'b0);

      // Completes and emits payload word 0.
      drive_beat(pack_bytes(55, 8), 8'hFF, 1'b0, 1'b0);

      // Upstream invalidates the frame after output has begun.
      drive_frame_abort();
      drive_idle();
    end
  endtask

  task automatic send_start0_bad_final_keep;
    int unsigned byte_offset;

    begin
      drive_beat(pack_bytes(0, 7), 8'h7F, 1'b1, 1'b0);
      byte_offset = 7;

      while ((byte_offset + 8) <= frame_byte_count) begin
        drive_beat(pack_bytes(byte_offset, 8), 8'hFF, 1'b0, 1'b0);
        byte_offset += 8;
      end

      // A valid START_0 ending requires keep = 8'h3F.
      // Deliberately claim seven valid bytes instead.
      drive_beat(pack_bytes(byte_offset, frame_byte_count - byte_offset), 8'h7F, 1'b0, 1'b1);
      drive_idle();
    end
  endtask

  task automatic send_start4_bad_drain_beat;
    int unsigned byte_offset;

    begin
      // START_4 beat carries three bytes after /S/.
      drive_beat(pack_bytes(0, 3), 8'h07, 1'b1, 1'b0);
      byte_offset = 3;

      // Send all complete beats, including the beat that completes
      // the final aligned UDP payload word.
      while ((byte_offset + 8) <= frame_byte_count) begin
        drive_beat(pack_bytes(byte_offset, 8), 8'hFF, 1'b0, 1'b0);
        byte_offset += 8;
      end

      // Valid START_4 drain requires keep = 8'h03.
      // Deliberately claim only one valid FCS byte.
      drive_beat(pack_bytes(byte_offset, frame_byte_count - byte_offset), 8'h01, 1'b0, 1'b1);
      drive_idle();
    end
  endtask

  // ---------------------------------------------------------------------------
  // Output checker
  // ---------------------------------------------------------------------------

  task automatic check_dut_outputs;
    begin
      if (!rst) begin
        if (parser_error) begin
          parser_error_count++;
        end

        if (udp_packet_abort) begin
          udp_packet_abort_count++;
        end

        if (udp_payload_valid) begin
          if (received_word_count >= expected_payload_word_count) begin
            $error("Received more than %0d UDP payload words", expected_payload_word_count);
            error_count++;
          end
          else begin
            if (udp_payload_data !== expected_payload_words[received_word_count]) begin
              $error("Payload word %0d mismatch: expected %016h, received %016h", received_word_count, expected_payload_words[received_word_count], udp_payload_data);
              error_count++;
            end

            if (udp_payload_start !== (received_word_count == 0)) begin
              $error("Incorrect udp_payload_start on word %0d", received_word_count);
              error_count++;
            end

            if (udp_payload_end !== ((received_word_count == expected_payload_word_count - 1))) begin
              $error("Incorrect udp_payload_end on word %0d", received_word_count);
              error_count++;
            end
          end
          received_word_count++;
        end
      end
    end
  endtask

  always @(negedge clk) begin
    check_dut_outputs();
  end


  // ---------------------------------------------------------------------------
  // Test cases
  // ---------------------------------------------------------------------------

  task automatic test_valid_start0_frame;
    begin
      received_word_count = 0;
      error_count = 0;

      clear_test_results();
      build_valid_frame(32);
      build_expected_payload(32);
      reset_dut();
      $display("TEST: valid 32-byte UDP payload with START_0 alignment");
      send_start0_frame();
      repeat (3) @(negedge clk);

      // Allow the monitor to observe any final output pulses.
      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d UDP payload words, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: valid START_0 frame");
      end
      else begin
        if (parser_error_count != 0) begin
          $error("Expected no parser_error pulses, observed %0d", parser_error_count);
          error_count++;
        end
        if (udp_packet_abort_count != 0) begin
          $error("Expected no udp_packet_abort pulses, observed %0d", udp_packet_abort_count);
          error_count++;
        end
        $fatal(1, "FAIL: valid START_0 frame, %0d errors", error_count);
      end
    end
  endtask


  task automatic test_valid_start4_frame;
    begin
      received_word_count = 0;
      error_count = 0;

      clear_test_results();
      build_valid_frame(32);
      build_expected_payload(32);
      reset_dut();
      $display("TEST: valid 32-byte UDP payload with START_4 alignment");
      send_start4_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d UDP payload words, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: valid START_4 frame");
      end
      else begin
        if (parser_error_count != 0) begin
          $error("Expected no parser_error pulses, observed %0d", parser_error_count);
          error_count++;
        end
        if (udp_packet_abort_count != 0) begin
          $error("Expected no udp_packet_abort pulses, observed %0d", udp_packet_abort_count);
          error_count++;
        end
        $fatal(1, "FAIL: valid START_4 frame, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_valid_64byte_start0_frame;
    begin
      received_word_count = 0;
      error_count = 0;

      clear_test_results();
      build_valid_frame(64);
      build_expected_payload(64);
      reset_dut();
      $display("TEST: valid 64-byte UDP payload with START_0 alignment");
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d UDP payload words, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: two-message UDP payload with START_0 alignment");
      end
      else begin
        if (parser_error_count != 0) begin
          $error("Expected no parser_error pulses, observed %0d", parser_error_count);
          error_count++;
        end

        if (udp_packet_abort_count != 0) begin
          $error("Expected no udp_packet_abort pulses, observed %0d", udp_packet_abort_count);
          error_count++;
        end
        $fatal(1, "FAIL: 64-byte START_0 frame, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_valid_64byte_start4_frame;
    begin
      received_word_count = 0;
      error_count = 0;

      clear_test_results();
      build_valid_frame(64);
      build_expected_payload(64);
      reset_dut();
      $display("TEST: valid 64-byte UDP payload with START_4 alignment");
      send_start4_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d UDP payload words, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: two-message UDP payload with START_4 alignment");
      end
      else begin
        if (parser_error_count != 0) begin
          $error("Expected no parser_error pulses, observed %0d", parser_error_count);
          error_count++;
        end

        if (udp_packet_abort_count != 0) begin
          $error("Expected no udp_packet_abort pulses, observed %0d", udp_packet_abort_count);
          error_count++;
        end
        $fatal(1, "FAIL: 64-byte START_4 frame, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_invalid_udp_length_start0;
    begin
      clear_test_results();
      build_valid_frame(32);

      // No payload output is expected from this malformed packet.
      expected_payload_word_count = 0;

      // Invalid UDP length:
      // 8-byte UDP header + 33-byte payload = 41 bytes.
      frame_bytes[45] = 8'h00;
      frame_bytes[46] = 8'h29;

      reset_dut();
      $display("TEST: reject invalid UDP length with START_0 alignment");
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != 0) begin
        $error("Expected no UDP payload words, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: invalid UDP length rejected");
      end
      else begin
        $fatal(1, "FAIL: invalid UDP length test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_udp_length_below_minimum;
    begin
      clear_test_results();
      build_valid_frame(32);

      // No payload output is expected.
      expected_payload_word_count = 0;

      // UDP length = 8 bytes: UDP header only, no internal message.
      frame_bytes[45] = 8'h00;
      frame_bytes[46] = 8'h08;

      reset_dut();
      $display("TEST: reject UDP length below minimum");
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != 0) begin
        $error("Expected no UDP payload words, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: UDP length below minimum rejected");
      end
      else begin
        $fatal(1, "FAIL: UDP length below minimum test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_udp_length_above_maximum;
    begin
      clear_test_results();
      build_valid_frame(32);

      // No payload output is expected.
      expected_payload_word_count = 0;

      // UDP length = 1512 bytes:
      // 8-byte UDP header + 47 complete 32-byte messages.
      // This exceeds the v0 maximum of 1480 bytes.
      frame_bytes[45] = 8'h05;
      frame_bytes[46] = 8'hE8;

      reset_dut();
      $display("TEST: reject UDP length above maximum");
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != 0) begin
        $error("Expected no UDP payload words, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: UDP length above maximum rejected");
      end
      else begin
        $fatal(1, "FAIL: UDP length above maximum test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_maximum_valid_udp_payload;
    begin
      clear_test_results();
      build_valid_frame(1472);
      build_expected_payload(1472);
      reset_dut();
      $display("TEST: maximum valid 1472-byte UDP payload");
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d UDP payload words, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (parser_error_count != 0) begin
        $error("Expected no parser_error pulses, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no udp_packet_abort pulses, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: maximum valid UDP payload accepted");
      end
      else begin
        $fatal(1, "FAIL: maximum UDP payload test, %0d errors", error_count);
      end
    end
  endtask


  task automatic test_frame_ends_during_header;
    begin
      clear_test_results();
      build_valid_frame(32);
      expected_payload_word_count = 0;
      reset_dut();
      $display("TEST: reject frame ending during fixed header");
      send_truncated_header_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != 0) begin
        $error("Expected no UDP payload words, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: truncated header frame rejected");
      end
      else begin
        $fatal(1, "FAIL: truncated header test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_frame_ends_during_payload;
    begin
      clear_test_results();
      build_valid_frame(64);
      build_expected_payload(64);
      reset_dut();
      $display("TEST: abort frame ending before declared UDP payload completes");
      send_truncated_payload_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != 1) begin
        $error("Expected one emitted payload word before truncation, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 1) begin
        $error("Expected one udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: truncated UDP payload aborted");
      end
      else begin
        $fatal(1, "FAIL: truncated UDP payload test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_frame_abort_before_payload;
    begin
      clear_test_results();
      build_valid_frame(32);
      expected_payload_word_count = 0;
      reset_dut();
      $display("TEST: frame_abort before UDP payload output");
      send_abort_during_header();
      repeat (3) @(negedge clk);

      if (received_word_count != 0) begin
        $error("Expected no UDP payload words, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 0) begin
        $error("Expected no parser_error pulses, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no udp_packet_abort pulses, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: frame aborted before payload without downstream abort");
      end
      else begin
        $fatal(1, "FAIL: pre-payload frame_abort test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_frame_abort_after_payload;
    begin
      clear_test_results();
      build_valid_frame(64);
      build_expected_payload(64);
      reset_dut();
      $display("TEST: frame_abort after UDP payload output begins");
      send_abort_after_payload_started();
      repeat (3) @(negedge clk);

      if (received_word_count != 1) begin
        $error("Expected one payload word before frame_abort, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 0) begin
        $error("Expected no parser_error pulses, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 1) begin
        $error("Expected one udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: frame_abort invalidated partial UDP payload");
      end
      else begin
        $fatal(1, "FAIL: post-payload frame_abort test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_invalid_start0_final_beat;
    begin
      clear_test_results();
      build_valid_frame(32);
      build_expected_payload(32);
      reset_dut();
      $display("TEST: reject malformed final START_0 beat");
      send_start0_bad_final_keep();
      repeat (3) @(negedge clk);

      if (received_word_count != 3) begin
        $error("Expected three payload words before malformed final beat, received %0d", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 1) begin
        $error("Expected one udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: malformed final START_0 beat rejected");
      end
      else begin
        $fatal(1, "FAIL: malformed START_0 final-beat test, %0d errors", error_count);
      end
    end
  endtask

  task automatic test_invalid_start4_drain_beat;
    begin
      clear_test_results();
      build_valid_frame(32);
      build_expected_payload(32);
      reset_dut();
      $display("TEST: reject malformed START_4 FCS-drain beat");
      send_start4_bad_drain_beat();
      repeat (3) @(negedge clk);

      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d payload words before malformed drain beat, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 1) begin
        $error("Expected one udp_packet_abort pulse, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: malformed START_4 drain beat rejected");
      end
      else begin
        $fatal(1, "FAIL: malformed START_4 drain-beat test, %0d errors", error_count);
      end
    end
  endtask


  task automatic test_recovery_after_rejected_frame;
    begin
      // -----------------------------------------------------------------------
      // First frame: reject an invalid UDP length
      // -----------------------------------------------------------------------

      clear_test_results();
      build_valid_frame(32);
      expected_payload_word_count = 0;

      // UDP length = 41 bytes, which cannot contain complete 32-byte messages.
      frame_bytes[45] = 8'h00;
      frame_bytes[46] = 8'h29;

      reset_dut();
      $display("TEST: recover after rejected frame without reset");
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != 0) begin
        $error("Rejected frame emitted %0d payload words", received_word_count);
        error_count++;
      end

      if (parser_error_count != 1) begin
        $error("Rejected frame expected one parser_error pulse, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Rejected frame expected no packet abort, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count != 0) begin
        $fatal(1, "FAIL: recovery test malformed-frame phase, %0d errors", error_count);
      end

      // -----------------------------------------------------------------------
      // Second frame: valid packet, with no reset between frames
      // -----------------------------------------------------------------------

      clear_test_results();
      build_valid_frame(32);
      build_expected_payload(32);
      send_start0_frame();
      repeat (3) @(negedge clk);

      if (received_word_count != expected_payload_word_count) begin
        $error("Expected %0d payload words after recovery, received %0d", expected_payload_word_count, received_word_count);
        error_count++;
      end

      if (parser_error_count != 0) begin
        $error("Expected no parser_error after recovery, observed %0d", parser_error_count);
        error_count++;
      end

      if (udp_packet_abort_count != 0) begin
        $error("Expected no packet abort after recovery, observed %0d", udp_packet_abort_count);
        error_count++;
      end

      if (error_count == 0) begin
        $display("PASS: parser recovered after rejected frame");
      end
      else begin
        $fatal(1, "FAIL: recovery test valid-frame phase, %0d errors", error_count);
      end
    end
  endtask
  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------

  initial begin
    test_valid_start0_frame();
    test_valid_start4_frame();
    test_valid_64byte_start0_frame();
    test_valid_64byte_start4_frame();
    test_invalid_udp_length_start0();
    test_udp_length_below_minimum();
    test_udp_length_above_maximum();
    test_maximum_valid_udp_payload();
    test_frame_ends_during_header();
    test_frame_ends_during_payload();
    test_frame_abort_before_payload();
    test_frame_abort_after_payload();
    test_invalid_start0_final_beat();
    test_invalid_start4_drain_beat();
    test_recovery_after_rejected_frame();
    $display("PASS: All eth_ipv4_udp_test");
    $finish;
  end

endmodule
