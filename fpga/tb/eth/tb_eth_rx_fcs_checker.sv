`timescale 1ns / 1ps

module tb_eth_rx_fcs_checker;

  localparam time CLK_PERIOD = 6.206ns;
  localparam int MAX_FRAME_BYTE_COUNT = 78;

  logic clk;
  logic rst;

  logic [63:0] frame_data;
  logic [7:0] frame_keep;
  logic frame_start;
  logic frame_end;
  logic frame_valid;
  logic frame_abort;

  logic fcs_result_valid;
  logic fcs_ok;

  logic [7:0] valid_frame[0:MAX_FRAME_BYTE_COUNT-1];

  eth_rx_fcs_checker dut (
      .clk(clk),
      .rst(rst),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_abort(frame_abort),
      .fcs_result_valid(fcs_result_valid),
      .fcs_ok(fcs_ok)
  );

  initial begin
    clk = 1'b0;
  end

  always #(CLK_PERIOD / 2) begin
    clk = ~clk;
  end

  task automatic build_valid_frame(input int unsigned extra_payload_bytes);

    logic [31:0] expected_fcs;
    int unsigned fcs_index;

    begin
      if (extra_payload_bytes > 7) begin
        $fatal(1, "extra_payload_bytes must be between 0 and 7, received %0d", extra_payload_bytes);
      end

      for (int i = 0; i < MAX_FRAME_BYTE_COUNT; i++) begin
        valid_frame[i] = 8'h00;
      end

      // Six remaining preamble bytes followed by the SFD.
      for (int i = 0; i < 6; i++) begin
        valid_frame[i] = 8'h55;
      end

      valid_frame[6] = 8'hD5;

      // Destination MAC: 02:00:00:00:00:01
      valid_frame[7] = 8'h02;
      valid_frame[8] = 8'h00;
      valid_frame[9] = 8'h00;
      valid_frame[10] = 8'h00;
      valid_frame[11] = 8'h00;
      valid_frame[12] = 8'h01;

      // Source MAC: 02:00:00:00:00:02
      valid_frame[13] = 8'h02;
      valid_frame[14] = 8'h00;
      valid_frame[15] = 8'h00;
      valid_frame[16] = 8'h00;
      valid_frame[17] = 8'h00;
      valid_frame[18] = 8'h02;

      // EtherType: IPv4
      valid_frame[19] = 8'h08;
      valid_frame[20] = 8'h00;

      // Base 46-byte payload plus zero through seven extra bytes.
      for (int i = 0; i < 46 + extra_payload_bytes; i++) begin
        valid_frame[21+i] = i[7:0];
      end

      // Independently calculated Ethernet CRC-32 values.
      case (extra_payload_bytes)
        0: expected_fcs = 32'hE7C8_7B32;
        1: expected_fcs = 32'hC6E4_7BB9;
        2: expected_fcs = 32'hCBA8_3D87;
        3: expected_fcs = 32'h87CC_619F;
        4: expected_fcs = 32'hE3EB_AD03;
        5: expected_fcs = 32'h833F_041A;
        6: expected_fcs = 32'h9033_48E5;
        7: expected_fcs = 32'h2346_3E87;
        default: expected_fcs = '0;
      endcase

      fcs_index = 67 + extra_payload_bytes;

      // Ethernet transmits the FCS least-significant byte first.
      valid_frame[fcs_index+0] = expected_fcs[7:0];
      valid_frame[fcs_index+1] = expected_fcs[15:8];
      valid_frame[fcs_index+2] = expected_fcs[23:16];
      valid_frame[fcs_index+3] = expected_fcs[31:24];
    end

  endtask

  task automatic apply_reset;
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

      #1ps;
    end
  endtask

  task automatic insert_frame_valid_bubble;
    begin
      @(negedge clk);

      frame_data = '0;
      frame_keep = '0;
      frame_valid = 1'b0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_abort = 1'b0;

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "frame_valid bubble incorrectly produced an FCS result");
      end
    end
  endtask

  task automatic send_frame(input int unsigned start_word_byte_count, input int unsigned frame_byte_count, input logic insert_bubbles);

    logic [63:0] word_data;
    logic [7:0] word_keep;
    int unsigned byte_index;
    int unsigned final_byte_count;

    begin
      if (frame_byte_count > MAX_FRAME_BYTE_COUNT) begin
        $fatal(1, "frame_byte_count %0d exceeds capacity %0d", frame_byte_count, MAX_FRAME_BYTE_COUNT);
      end

      if (frame_byte_count < start_word_byte_count) begin
        $fatal(1, "frame_byte_count %0d is smaller than START word byte count %0d", frame_byte_count, start_word_byte_count);
      end

      if ((start_word_byte_count != 3) && (start_word_byte_count != 7)) begin
        $fatal(1, "start_word_byte_count must be 3 or 7, received %0d", start_word_byte_count);
      end

      byte_index = 0;

      // Send the PCS START word.
      word_data = '0;
      word_keep = '0;

      for (int lane = 0; lane < start_word_byte_count; lane++) begin
        word_data[lane*8+:8] = valid_frame[byte_index+lane];
        word_keep[lane] = 1'b1;
      end

      @(negedge clk);

      frame_data = word_data;
      frame_keep = word_keep;
      frame_valid = 1'b1;
      frame_start = 1'b1;
      frame_end = 1'b0;
      frame_abort = 1'b0;

      @(posedge clk);
      #1ps;

      byte_index = byte_index + start_word_byte_count;
      if (insert_bubbles) begin
        insert_frame_valid_bubble();
      end

      // Send complete eight-byte data words.
      while ((frame_byte_count - byte_index) >= 8) begin
        word_data = '0;
        word_keep = 8'hFF;

        for (int lane = 0; lane < 8; lane++) begin
          word_data[lane*8+:8] = valid_frame[byte_index+lane];
        end

        @(negedge clk);

        frame_data = word_data;
        frame_keep = word_keep;
        frame_valid = 1'b1;
        frame_start = 1'b0;
        frame_end = 1'b0;
        frame_abort = 1'b0;

        @(posedge clk);
        #1ps;

        byte_index = byte_index + 8;
        if (insert_bubbles) begin
          insert_frame_valid_bubble();
        end
      end

      // Send the PCS TERMINATE word. It may contain zero through
      // seven final frame bytes before the termination character.
      final_byte_count = frame_byte_count - byte_index;
      if (final_byte_count > 7) begin
        $fatal(1, "Internal driver error: final_byte_count = %0d", final_byte_count);
      end
      word_data = '0;
      word_keep = '0;

      for (int lane = 0; lane < final_byte_count; lane++) begin
        word_data[lane*8 +:8] = valid_frame[byte_index+lane];
        word_keep[lane] = 1'b1;
      end

      @(negedge clk);

      frame_data = word_data;
      frame_keep = word_keep;
      frame_valid = 1'b1;
      frame_start = 1'b0;
      frame_end = 1'b1;
      frame_abort = 1'b0;

      @(posedge clk);
      #1ps;

      @(negedge clk);

      frame_data = '0;
      frame_keep = '0;
      frame_valid = 1'b0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_abort = 1'b0;

      #1ps;
    end

  endtask

  task automatic send_aborted_frame;

    logic [63:0] word_data;

    begin
      // Send a real START_0 word containing the seven preamble/SFD bytes.
      word_data = '0;

      for (int lane = 0; lane < 7; lane++) begin
        word_data[lane*8+:8] = valid_frame[lane];
      end

      @(negedge clk);

      frame_data = word_data;
      frame_keep = 8'h7F;
      frame_valid = 1'b1;
      frame_start = 1'b1;
      frame_end = 1'b0;
      frame_abort = 1'b0;

      @(posedge clk);
      #1ps;

      // Send one ordinary frame word.
      word_data = '0;

      for (int lane = 0; lane < 8; lane++) begin
        word_data[lane*8+:8] = valid_frame[7+lane];
      end

      @(negedge clk);

      frame_data = word_data;
      frame_keep = 8'hFF;
      frame_valid = 1'b1;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_abort = 1'b0;

      @(posedge clk);
      #1ps;

      // Abort the incomplete frame.
      @(negedge clk);

      frame_data = '0;
      frame_keep = '0;
      frame_valid = 1'b0;
      frame_start = 1'b0;
      frame_end = 1'b0;
      frame_abort = 1'b1;

      @(posedge clk);
      #1ps;

      // Return the interface to idle.
      @(negedge clk);

      frame_abort = 1'b0;

      #1ps;
    end

  endtask

  task automatic test_valid_start_0;
    begin
      $display("TEST: valid frame using START_0");
      build_valid_frame(0);
      apply_reset();
      send_frame(7, 71, 1'b0);

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Expected an FCS result when the valid frame ended");
      end

      if (fcs_ok !== 1'b1) begin
        $fatal(1, "Valid START_0 frame failed the FCS check");
      end

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after one cycle");
      end

      $display("PASS: valid frame using START_0");
    end
  endtask

  task automatic test_corrupted_payload;
    begin
      $display("TEST: corrupted payload");
      build_valid_frame(0);
      apply_reset();

      // Corrupt one protected byte while retaining the original FCS.
      valid_frame[21] = valid_frame[21] ^ 8'h01;

      send_frame(7, 71, 1'b0);

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Expected an FCS result for the corrupted frame");
      end

      if (fcs_ok !== 1'b0) begin
        $fatal(1, "Corrupted payload incorrectly passed the FCS check");
      end

      // Restore the golden frame.
      valid_frame[21] = valid_frame[21] ^ 8'h01;

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after one cycle");
      end

      $display("PASS: corrupted payload rejected");
    end
  endtask

  task automatic test_valid_start_4;
    begin
      $display("TEST: valid frame using START_4");
      build_valid_frame(0);
      apply_reset();
      send_frame(3, 71, 1'b0);

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Expected an FCS result when the valid START_4 frame ended");
      end

      if (fcs_ok !== 1'b1) begin
        $fatal(1, "Valid START_4 frame failed the FCS check");
      end

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after START_4 frame");
      end

      $display("PASS: valid frame using START_4");
    end
  endtask

  task automatic test_corrupted_fcs;
    begin
      $display("TEST: corrupted FCS");
      build_valid_frame(0);
      apply_reset();

      // Corrupt one received FCS byte while leaving the frame data unchanged.
      valid_frame[67] = valid_frame[67] ^ 8'h01;

      send_frame(7, 71, 1'b0);

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Expected an FCS result for the corrupted-FCS frame");
      end

      if (fcs_ok !== 1'b0) begin
        $fatal(1, "Corrupted FCS incorrectly passed");
      end

      // Restore the golden FCS.
      valid_frame[67] = valid_frame[67] ^ 8'h01;

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after corrupted FCS");
      end

      $display("PASS: corrupted FCS rejected");
    end
  endtask

  task automatic test_all_termination_positions;

    int unsigned frame_byte_count;

    begin
      $display("TEST: all termination positions");

      for (int extra_payload_bytes = 0; extra_payload_bytes < 8; extra_payload_bytes++) begin
        build_valid_frame(extra_payload_bytes);
        apply_reset();

        frame_byte_count = 71 + extra_payload_bytes;
        send_frame(7, frame_byte_count, 1'b0);

        if (fcs_result_valid !== 1'b1) begin
          $fatal(1, "TERM_%0d did not produce an FCS result", extra_payload_bytes);
        end

        if (fcs_ok !== 1'b1) begin
          $fatal(1, "Valid frame ending at TERM_%0d failed FCS", extra_payload_bytes);
        end

        @(posedge clk);
        #1ps;

        if (fcs_result_valid !== 1'b0) begin
          $fatal(1, "fcs_result_valid did not clear after TERM_%0d", extra_payload_bytes);
        end

        $display("PASS: TERM_%0d", extra_payload_bytes);
      end

      $display("PASS: all termination positions");
    end

  endtask

  task automatic test_frame_abort;
    begin
      $display("TEST: aborted frame recovery");

      build_valid_frame(0);
      apply_reset();
      send_aborted_frame();

      // An abandoned frame did not reach a normal Ethernet termination,
      // so the FCS checker must not report a completed-frame result.
      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "Aborted frame incorrectly produced an FCS result");
      end

      if (fcs_ok !== 1'b0) begin
        $fatal(1, "Aborted frame left fcs_ok asserted");
      end

      // Do not reset the DUT. The abort itself must clear the old CRC state.
      send_frame(7, 71, 1'b0);

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Valid frame after abort did not produce an FCS result");
      end

      if (fcs_ok !== 1'b1) begin
        $fatal(1, "Valid frame after abort failed the FCS check");
      end

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after abort-recovery test");
      end

      $display("PASS: aborted frame discarded and next frame accepted");
    end
  endtask

  task automatic test_frame_valid_bubbles;
    begin
      $display("TEST: frame_valid bubbles");

      build_valid_frame(0);
      apply_reset();

      send_frame(7, 71, 1'b1);

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Frame with frame_valid bubbles did not produce an FCS result");
      end

      if (fcs_ok !== 1'b1) begin
        $fatal(1, "Valid frame was corrupted by frame_valid bubbles");
      end

      @(posedge clk);
      #1ps;

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after bubble test");
      end

      $display("PASS: frame_valid bubbles ignored correctly");
    end
  endtask

  initial begin
    test_valid_start_0();
    test_valid_start_4();
    test_corrupted_payload();
    test_corrupted_fcs();
    test_all_termination_positions();
    test_frame_abort();
    test_frame_valid_bubbles();
    $display("ALL FCS CHECKER TESTS PASSED");
    $finish;
  end

endmodule
