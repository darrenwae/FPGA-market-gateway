`timescale 1ns / 1ps

module tb_eth_rx_channel;

  localparam time CLK_PERIOD = 6.206ns;
  localparam int FRAME_BYTE_COUNT = 71;

  localparam logic [1:0] SYNC_DATA = 2'b01;
  localparam logic [1:0] SYNC_CTRL = 2'b10;

  localparam logic [7:0] BLOCK_TYPE_START_0 = 8'h78;
  localparam logic [7:0] BLOCK_TYPE_TERM_0 = 8'h87;

  localparam logic [63:0] IDLE_BLOCK = 64'h0000_0000_0000_001E;

  logic clk;
  logic rst;

  logic [63:0] rx_data;
  logic [5:0] rx_header;
  logic [1:0] rx_data_valid;
  logic [1:0] rx_header_valid;
  logic [1:0] rx_start_of_seq;

  logic rx_gearbox_slip;
  logic block_lock;

  logic [63:0] frame_data;
  logic [7:0] frame_keep;
  logic frame_start;
  logic frame_end;
  logic frame_valid;
  logic frame_abort;

  logic bad_block;
  logic sequence_error;

  logic fcs_result_valid;
  logic fcs_ok;

  logic [57:0] tx_lfsr;
  logic [7:0] valid_frame[0:FRAME_BYTE_COUNT-1];

  eth_rx_channel dut (
      .clk(clk),
      .rst(rst),

      .rx_data(rx_data),
      .rx_header(rx_header),
      .rx_data_valid(rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .rx_start_of_seq(rx_start_of_seq),
      .rx_gearbox_slip(rx_gearbox_slip),
      .block_lock(block_lock),
      .frame_data(frame_data),
      .frame_keep(frame_keep),
      .frame_start(frame_start),
      .frame_end(frame_end),
      .frame_valid(frame_valid),
      .frame_abort(frame_abort),
      .bad_block(bad_block),
      .sequence_error(sequence_error),
      .fcs_result_valid(fcs_result_valid),
      .fcs_ok(fcs_ok)
  );

  initial begin
    clk = 1'b0;
  end

  always #(CLK_PERIOD / 2) begin
    clk = ~clk;
  end

  function automatic logic [63:0] to_descrambler_order(input logic [63:0] normalized_block);
    begin
      for (int i = 0; i < 64; i++) begin
        to_descrambler_order[63-i] = normalized_block[i];
      end
    end
  endfunction

  task automatic initialize_inputs;
    begin
      rst = 1'b0;

      rx_data = '0;
      rx_header = '0;
      rx_data_valid = '0;
      rx_header_valid = '0;
      rx_start_of_seq = '0;

      tx_lfsr = '0;
    end
  endtask

  task automatic apply_reset;
    begin
      @(negedge clk);

      rx_data = '0;
      rx_header = '0;
      rx_data_valid = '0;
      rx_header_valid = '0;
      rx_start_of_seq = '0;

      rst = 1'b1;

      repeat (4) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic drive_gearbox_sample(input logic [63:0] payload, input logic [1:0] header, input logic valid);
    begin
      @(negedge clk);

      rx_data = payload;
      rx_header = {4'b0, header};
      rx_data_valid = valid ? 2'b01 : 2'b00;
      rx_header_valid = valid ? 2'b01 : 2'b00;
      rx_start_of_seq = 2'b00;

      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic scramble_block(input logic [63:0] plaintext, output logic [63:0] scrambled);

    logic [57:0] lfsr_work;

    begin
      lfsr_work = tx_lfsr;

      for (int bit_index = 63; bit_index >= 0; bit_index--) begin
        scrambled[bit_index] = plaintext[bit_index] ^ lfsr_work[38] ^ lfsr_work[57];

        lfsr_work = {lfsr_work[56:0], scrambled[bit_index]};
      end

      tx_lfsr = lfsr_work;
    end
  endtask

  task automatic drive_normalized_block(input logic [63:0] normalized_block, input logic [1:0] header);

    logic [63:0] plaintext;
    logic [63:0] scrambled;

    begin
      plaintext = to_descrambler_order(normalized_block);
      scramble_block(plaintext, scrambled);
      drive_gearbox_sample(scrambled, header, 1'b1);
    end
  endtask

  task automatic advance_pipeline;
    begin
      drive_gearbox_sample('0, 2'b00, 1'b0);
    end
  endtask

  task automatic acquire_lock;
    begin
      apply_reset();

      for (int header_index = 0; header_index < 64; header_index++) begin
        drive_gearbox_sample(64'h0000_0000_0000_0000, SYNC_CTRL, 1'b1);
      end

      if (block_lock !== 1'b1) begin
        $fatal(1, "Block lock was not acquired");
      end

      if (rx_gearbox_slip !== 1'b0) begin
        $fatal(1, "Unexpected gearbox slip after lock");
      end

      tx_lfsr = {58{1'b1}};

      // First block after lock synchronizes the RX descrambler.
      drive_normalized_block(IDLE_BLOCK, SYNC_CTRL);

      if (frame_valid !== 1'b0) begin
        $fatal(1, "Descrambler warm-up block produced frame data");
      end
    end
  endtask

  task automatic build_valid_frame;
    begin
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

      // Minimum 46-byte Ethernet payload.
      for (int i = 0; i < 46; i++) begin
        valid_frame[21+i] = i[7:0];
      end

      // Ethernet FCS = E7C87B32, transmitted LSB byte first.
      valid_frame[67] = 8'h32;
      valid_frame[68] = 8'h7B;
      valid_frame[69] = 8'hC8;
      valid_frame[70] = 8'hE7;
    end
  endtask

  task automatic drive_start_0;
    logic [63:0] normalized_block;

    begin
      normalized_block = '0;
      normalized_block[7:0] = BLOCK_TYPE_START_0;

      for (int lane = 0; lane < 7; lane++) begin
        normalized_block[8+lane*8+:8] = valid_frame[lane];
      end

      drive_normalized_block(normalized_block, SYNC_CTRL);
    end
  endtask

  task automatic drive_data_word(input int unsigned byte_index);

    logic [63:0] normalized_block;

    begin
      normalized_block = '0;

      for (int lane = 0; lane < 8; lane++) begin
        normalized_block[lane*8+:8] = valid_frame[byte_index+lane];
      end

      drive_normalized_block(normalized_block, SYNC_DATA);
    end
  endtask

  task automatic drive_term_0;
    logic [63:0] normalized_block;

    begin
      normalized_block = '0;
      normalized_block[7:0] = BLOCK_TYPE_TERM_0;

      drive_normalized_block(normalized_block, SYNC_CTRL);
    end
  endtask

  task automatic send_complete_frame;
    int unsigned byte_index;

    begin
      drive_start_0();

      byte_index = 7;

      while ((FRAME_BYTE_COUNT - byte_index) >= 8) begin
        drive_data_word(byte_index);
        byte_index = byte_index + 8;
      end

      if (byte_index != FRAME_BYTE_COUNT) begin
        $fatal(1, "Frame does not end at TERM_0: byte_index=%0d", byte_index);
      end

      drive_term_0();
    end
  endtask

  task automatic test_valid_frame;
    begin
      $display("TEST: valid frame through Ethernet RX channel");

      build_valid_frame();
      acquire_lock();
      send_complete_frame();

      // FCS checker consumes the decoder's TERM beat here.
      advance_pipeline();

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Valid frame did not produce an FCS result");
      end

      if (fcs_ok !== 1'b1) begin
        $fatal(1, "Valid frame failed integrated FCS checking");
      end

      if (frame_abort !== 1'b0) begin
        $fatal(1, "Valid frame incorrectly asserted frame_abort");
      end

      advance_pipeline();

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "fcs_result_valid did not clear after one cycle");
      end

      $display("PASS: valid frame through Ethernet RX channel");
    end
  endtask

  task automatic test_corrupted_payload;
    begin
      $display("TEST: corrupted frame through Ethernet RX channel");

      build_valid_frame();

      // Corrupt protected data while retaining the original FCS.
      valid_frame[21] = valid_frame[21] ^ 8'h01;

      acquire_lock();
      send_complete_frame();
      advance_pipeline();

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Corrupted frame did not produce an FCS result");
      end

      if (fcs_ok !== 1'b0) begin
        $fatal(1, "Corrupted frame incorrectly passed FCS");
      end

      $display("PASS: corrupted frame rejected by integrated FCS checker");
    end
  endtask

  task automatic test_abort_recovery;
    begin
      $display("TEST: frame abort recovery");

      build_valid_frame();
      acquire_lock();

      drive_start_0();
      drive_data_word(7);

      // A second START before TERMINATE aborts the active frame.
      drive_start_0();

      if (frame_abort !== 1'b1) begin
        $fatal(1, "Repeated START did not assert frame_abort");
      end

      if (frame_valid !== 1'b0) begin
        $fatal(1, "Abort cycle incorrectly emitted frame data");
      end

      // FCS checker consumes frame_abort here.
      advance_pipeline();

      if (fcs_result_valid !== 1'b0) begin
        $fatal(1, "Aborted frame produced an FCS result");
      end

      if (fcs_ok !== 1'b0) begin
        $fatal(1, "Aborted frame left fcs_ok asserted");
      end

      // No reset. The next complete frame must pass.
      send_complete_frame();
      advance_pipeline();

      if (fcs_result_valid !== 1'b1) begin
        $fatal(1, "Frame after abort did not produce an FCS result");
      end

      if (fcs_ok !== 1'b1) begin
        $fatal(1, "Valid frame after abort failed FCS");
      end

      $display("PASS: frame abort recovery");
    end
  endtask

  initial begin
    initialize_inputs();

    test_valid_frame();
    test_corrupted_payload();
    test_abort_recovery();

    $display("PASS: all Ethernet RX channel tests");
    $finish;
  end

endmodule
