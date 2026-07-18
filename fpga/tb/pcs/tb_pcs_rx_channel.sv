`timescale 1ns / 1ps

module tb_pcs_rx_channel;

  localparam time CLK_PERIOD = 6.206ns;

  localparam logic [1:0] SYNC_DATA = 2'b01;
  localparam logic [1:0] SYNC_CTRL = 2'b10;

  // Normalized decoder representation:
  // bits [7:0] contain the earliest byte or block type.
  localparam logic [63:0] IDLE_BLOCK = 64'h0000_0000_0000_001E;

  localparam logic [63:0] START_0_BLOCK = 64'hA6A5_A4A3_A2A1_A0_78;

  localparam logic [63:0] DATA_BLOCK = 64'hB7B6_B5B4_B3B2_B1B0;

  localparam logic [63:0] TERM_3_BLOCK = 64'h0000_0000_D2D1_D0B4;

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

  logic bad_block;
  logic sequence_error;

  logic [57:0] tx_lfsr;

  pcs_rx_channel dut (
      .clk(clk),
      .rst(rst),

      .rx_data        (rx_data),
      .rx_header      (rx_header),
      .rx_data_valid  (rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .rx_start_of_seq(rx_start_of_seq),

      .rx_gearbox_slip(rx_gearbox_slip),
      .block_lock     (block_lock),

      .frame_data (frame_data),
      .frame_keep (frame_keep),
      .frame_start(frame_start),
      .frame_end  (frame_end),
      .frame_valid(frame_valid),

      .bad_block     (bad_block),
      .sequence_error(sequence_error)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD / 2) clk = ~clk;

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

  task automatic acquire_lock;
    begin
      apply_reset();

      for (int header_index = 0; header_index < 64; header_index++) begin
        drive_gearbox_sample(64'h0, SYNC_CTRL, 1'b1);
      end

      if (block_lock !== 1'b1) begin
        $fatal(1, "Block lock was not acquired");
      end

      if (rx_gearbox_slip !== 1'b0) begin
        $fatal(1, "Unexpected gearbox slip after acquisition");
      end
    end
  endtask

  task automatic test_complete_frame;
    begin
      $display("TEST: complete frame through PCS RX channel");

      acquire_lock();

      // Use an arbitrary TX scrambler state. The RX descrambler
      // self-synchronizes from the received scrambled stream.
      tx_lfsr = {58{1'b1}};

      // First block after lock synchronizes the descrambler and must
      // not be emitted by the block decoder.
      drive_normalized_block(IDLE_BLOCK, SYNC_CTRL);

      if (frame_valid !== 1'b0) begin
        $fatal(1, "Descrambler warm-up block produced a frame event");
      end

      if (bad_block !== 1'b0 || sequence_error !== 1'b0) begin
        $fatal(1, "Descrambler warm-up produced a decoder error");
      end

      // START_0 followed by seven frame bytes.
      drive_normalized_block(START_0_BLOCK, SYNC_CTRL);

      if (frame_valid !== 1'b1 || frame_start !== 1'b1 || frame_end !== 1'b0) begin
        $fatal(1, "Incorrect START_0 output");
      end

      if (frame_keep !== 8'h7F) begin
        $fatal(1, "START_0 keep mismatch: %h", frame_keep);
      end

      if (frame_data !== 64'h00A6_A5A4_A3A2_A1A0) begin
        $fatal(1, "START_0 data mismatch: %h", frame_data);
      end

      if (bad_block !== 1'b0 || sequence_error !== 1'b0) begin
        $fatal(1, "START_0 produced an error");
      end

      // Full eight-byte data block.
      drive_normalized_block(DATA_BLOCK, SYNC_DATA);

      if (frame_valid !== 1'b1 || frame_start !== 1'b0 || frame_end !== 1'b0) begin
        $fatal(1, "Incorrect data-block output");
      end

      if (frame_keep !== 8'hFF || frame_data !== DATA_BLOCK) begin
        $fatal(1, "Data-block mismatch: keep=%h data=%h", frame_keep, frame_data);
      end

      if (bad_block !== 1'b0 || sequence_error !== 1'b0) begin
        $fatal(1, "Data block produced an error");
      end

      // Three final bytes followed by TERMINATE.
      drive_normalized_block(TERM_3_BLOCK, SYNC_CTRL);

      if (frame_valid !== 1'b1 || frame_start !== 1'b0 || frame_end !== 1'b1) begin
        $fatal(1, "Incorrect TERM_3 output");
      end

      if (frame_keep !== 8'h07) begin
        $fatal(1, "TERM_3 keep mismatch: %h", frame_keep);
      end

      if (frame_data !== 64'h0000_0000_00D2_D1D0) begin
        $fatal(1, "TERM_3 data mismatch: %h", frame_data);
      end

      if (bad_block !== 1'b0 || sequence_error !== 1'b0) begin
        $fatal(1, "TERM_3 produced an error");
      end

      $display("PASS: complete frame through PCS RX channel");
    end
  endtask

  initial begin
    initialize_inputs();

    test_complete_frame();

    $display("PASS: all PCS RX channel tests");
    $finish;
  end

endmodule
