`timescale 1ns / 1ps

module tb_pcs_rx_lock_descrambler;

  localparam realtime CLK_PERIOD_NS = 6.20606;

  logic clk;
  logic rst;

  logic [63:0] rx_data;
  logic [5:0] rx_header;
  logic [1:0] rx_data_valid;
  logic [1:0] rx_header_valid;
  logic rx_gearbox_slip;

  logic [63:0] block_payload;
  logic [1:0] block_header;
  logic block_valid;
  logic block_lock;

  logic [63:0] descrambled_payload;
  logic [1:0] header_out;
  logic descrambled_payload_valid;

  logic [57:0] tx_lfsr;

  logic [63:0] plaintext_0;
  logic [63:0] plaintext_1;
  logic [63:0] scrambled_0;
  logic [63:0] scrambled_1;

  initial clk = 1'b0;
  always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

  pcs_rx_block_lock u_block_lock (
      .clk(clk),
      .rst(rst),
      .rx_data(rx_data),
      .rx_header(rx_header),
      .rx_data_valid(rx_data_valid),
      .rx_header_valid(rx_header_valid),
      .rx_gearbox_slip(rx_gearbox_slip),
      .block_payload(block_payload),
      .block_header(block_header),
      .block_valid(block_valid),
      .block_lock(block_lock)
  );

  pcs_rx_descrambler u_descrambler (
      .clk(clk),
      .rst(rst),
      .block_lock(block_lock),
      .block_payload(block_payload),
      .block_header(block_header),
      .block_valid(block_valid),
      .descrambled_payload(descrambled_payload),
      .header_out(header_out),
      .descrambled_payload_valid(descrambled_payload_valid)
  );

  task automatic initialize_inputs;
    begin
      rst = 1'b0;
      rx_data = '0;
      rx_header = '0;
      rx_data_valid = '0;
      rx_header_valid = '0;
      tx_lfsr = '0;
    end
  endtask


  task automatic apply_reset;
    begin
      // Quiesce gearbox interface before resetting DUT
      rx_data = '0;
      rx_header = '0;
      rx_data_valid = '0;
      rx_header_valid = '0;

      // Change reset away from the active clock edge.
      @(negedge clk);
      rst = 1'b1;
      repeat (4) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      // Allow the DUT to observe one complete non-reset cycle.
      @(posedge clk);
      #1ps;
    end
  endtask


  task automatic drive_gearbox_sample(input logic [63:0] payload, input logic [1:0] header, input logic valid);
    begin
      // Drive inputs on the falling edge so they are stable before
      // the DUT samples them on the following rising edge.
      @(negedge clk);

      rx_data = payload;
      rx_header = {4'b0000, header};
      rx_data_valid = valid ? 2'b01 : 2'b00;
      rx_header_valid = valid ? 2'b01 : 2'b00;

      @(posedge clk);
      #1ps;
    end
  endtask


  task automatic scramble_block(input logic [63:0] plaintext, output logic [63:0] scrambled);
    logic [57:0] lfsr_work;

    begin
      lfsr_work = tx_lfsr;

      // Bit 63 transmitted first.
      for (int bit_index = 63; bit_index >= 0; bit_index--) begin
        scrambled[bit_index] = plaintext[bit_index] ^ lfsr_work[38] ^ lfsr_work[57];

        // newest scrambled bit enters position zero.
        lfsr_work = {lfsr_work[56:0], scrambled[bit_index]};
      end

      tx_lfsr = lfsr_work;
    end
  endtask

  task automatic test_acquisition_and_slip_wait;
    begin
      $display("TEST: acquisition and slip wait");
      apply_reset();

      if (block_lock !== 1'b0) $fatal(1, "Block lock asserted after reset");

      // Begin acquisition but do not reach the threshold.
      for (int i = 0; i < 20; i++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted during partial acquisition");
      end

      // Illegal header must reject the current candidate alignment and request one gearbox slip.
      drive_gearbox_sample(64'h0, 2'b00, 1'b1);

      if (rx_gearbox_slip !== 1'b1) $fatal(1, "Expected gearbox-slip pulse after illegal header");
      if (block_lock !== 1'b0) $fatal(1, "Block lock asserted after illegal header");

      // The GT gearbox requires 32 RX clock cycles after a slip.
      for (int i = 0; i < 32; i++) begin
        drive_gearbox_sample(64'h0, 2'b00, 1'b0);
        if (rx_gearbox_slip !== 1'b0) $fatal(1, "Gearbox-slip pulse lasted longer than one cycle");
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted during slip wait");
      end

      // Lock on established after 64 consecutive legal header observed.
      for (int i = 0; i < 63; i++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted before 64 legal headers");
      end

      // The 64th consecutive legal header establishes block lock.
      drive_gearbox_sample(64'h0, 2'b10, 1'b1);
      if (block_lock !== 1'b1) $fatal(1, "Block lock did not assert after 64 legal headers");

      $display("PASS: acquisition and slip wait");
    end
  endtask

  task automatic test_acquisition_with_bubbles;
    begin
      $display("TEST: acquisition with gearbox bubbles");

      apply_reset();

      // Accumulate 32 legal headers.
      for (int i = 0; i < 32; i++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted too early");
      end

      // Invalid interface cycles are gearbox bubbles.
      // They must neither advance nor clear the acquisition count.
      for (int i = 0; i < 7; i++) begin
        drive_gearbox_sample(64'h0, 2'b00, 1'b0);
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted during gearbox bubble");
        if (rx_gearbox_slip !== 1'b0) $fatal(1, "Gearbox bubble incorrectly caused a slip");
      end

      // Reach 63 total real legal headers.
      for (int i = 0; i < 31; i++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted before 64 real headers");
      end

      // The next real legal header is number 64.
      drive_gearbox_sample(64'h0, 2'b10, 1'b1);
      if (block_lock !== 1'b1) $fatal(1, "Gearbox bubbles incorrectly disturbed acquisition");

      $display("PASS: acquisition with gearbox bubbles");
    end
  endtask

  task automatic acquire_lock;
    begin
      apply_reset();

      for (int i = 0; i < 64; i++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
      end

      if (block_lock !== 1'b1) $fatal(1, "Failed to establish block lock");
    end
  endtask

  task automatic test_descrambler_stream;
    logic [63:0] plaintext;
    logic [63:0] scrambled;

    begin
      $display("TEST: descrambler stream");
      acquire_lock();

      // Arbitrary transmitter scrambler state at lock acquisition.
      tx_lfsr = {58{1'b1}};

      // First aligned block synchronizes the receiver LFSR.
      plaintext = 64'h0123_4567_89AB_CDEF;
      scramble_block(plaintext, scrambled);
      drive_gearbox_sample(scrambled, 2'b10, 1'b1);
      if (descrambled_payload_valid !== 1'b0) $fatal(1, "Descrambler exposed synchronization block");

      // Bubble must not advance the receiver LFSR.
      drive_gearbox_sample(64'h0, 2'b00, 1'b0);
      if (descrambled_payload_valid !== 1'b0) $fatal(1, "Descrambler asserted valid during gearbox bubble");

      // Check several consecutive complete blocks.
      for (int block_index = 0; block_index < 4; block_index++) begin
        plaintext = 64'h1020_3040_5060_7080 + block_index;
        scramble_block(plaintext, scrambled);
        drive_gearbox_sample(scrambled, block_index[0] ? 2'b01 : 2'b10, 1'b1);
        if (descrambled_payload_valid !== 1'b1) $fatal(1, "Descrambler valid missing on block %0d", block_index);
        if (descrambled_payload !== plaintext) $fatal(1, "Descrambler mismatch on block %0d: expected %h, received %h", block_index, plaintext, descrambled_payload);
        if (header_out !== (block_index[0] ? 2'b01 : 2'b10)) $fatal(1, "Header mismatch on block %0d", block_index);
      end

      $display("PASS: descrambler stream");
    end
  endtask

  task automatic test_lock_retention_and_window_rollover;
    begin
      $display("TEST: lock retention and monitoring-window rollover");
      acquire_lock();

      // Fifteen illegal headers in one 64-block window must not
      // reach the lock-loss threshold.
      for (int block_index = 0; block_index < 64; block_index++) begin
        drive_gearbox_sample(64'h0, (block_index < 15) ? 2'b00 : 2'b10, 1'b1);
        if (block_lock !== 1'b1) $fatal(1, "Block lock lost below threshold at block %0d", block_index);
        if (rx_gearbox_slip !== 1'b0) $fatal(1, "Unexpected gearbox slip below lock-loss threshold");
      end

      // The previous window contained 15 illegal headers. This first
      // illegal header in the new window must be counted independently
      // If invalid_count was not cleared at rollover, lock would be lost
      drive_gearbox_sample(64'h0, 2'b00, 1'b1);
      if (block_lock !== 1'b1) $fatal(1, "Invalid-header count was not cleared at window rollover");
      if (rx_gearbox_slip !== 1'b0) $fatal(1, "Window rollover incorrectly caused a gearbox slip");

      $display("PASS: lock retention and monitoring-window rollover");
    end
  endtask

  task automatic test_lock_loss_and_reacquisition;
    begin
      $display("TEST: lock loss and reacquisition");

      acquire_lock();

      // The first 15 illegal headers must not cause lock loss.
      for (int invalid_index = 0; invalid_index < 15; invalid_index++) begin
        drive_gearbox_sample(64'h0, 2'b00, 1'b1);
        if (block_lock !== 1'b1) $fatal(1, "Block lock lost before the 16th illegal header");
        if (rx_gearbox_slip !== 1'b0) $fatal(1, "Gearbox slip asserted before the 16th illegal header");
      end

      // The 16th illegal header must clear lock and request one slip.
      drive_gearbox_sample(64'h0, 2'b00, 1'b1);

      if (block_lock !== 1'b0) $fatal(1, "Block lock did not clear on the 16th illegal header");
      if (rx_gearbox_slip !== 1'b1) $fatal(1, "Gearbox slip was not asserted on lock loss");

      // Wait for the new gearbox alignment to propagate.
      for (int wait_cycle = 0; wait_cycle < 32; wait_cycle++) begin
        drive_gearbox_sample(64'h0, 2'b00, 1'b0);
        if (block_lock !== 1'b0) $fatal(1, "Block lock asserted during post-slip wait");
        if (rx_gearbox_slip !== 1'b0) $fatal(1, "Gearbox slip remained asserted for more than one cycle");
      end

      // The first 63 legal headers must not reacquire lock.
      for (int header_index = 0; header_index < 63; header_index++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
        if (block_lock !== 1'b0) $fatal(1, "Block lock reacquired before 64 legal headers");
      end

      // The 64th legal header must restore lock.
      drive_gearbox_sample(64'h0, 2'b10, 1'b1);

      if (block_lock !== 1'b1) $fatal(1, "Block lock did not reacquire after 64 legal headers");

      $display("PASS: lock loss and reacquisition");
    end
  endtask

  task automatic test_reset_while_locked;
    logic [63:0] plaintext;
    logic [63:0] scrambled;

    begin
      $display("TEST: reset while locked");

      acquire_lock();

      // Synchronize the descrambler and prove it is producing valid data.
      tx_lfsr = {58{1'b1}};

      plaintext = 64'h0123_4567_89AB_CDEF;
      scramble_block(plaintext, scrambled);
      drive_gearbox_sample(scrambled, 2'b10, 1'b1);

      plaintext = 64'hDEAD_BEEF_CAFE_F00D;
      scramble_block(plaintext, scrambled);
      drive_gearbox_sample(scrambled, 2'b01, 1'b1);

      if (descrambled_payload_valid !== 1'b1) $fatal(1, "Descrambler was not active before reset");
      if (descrambled_payload !== plaintext) $fatal(1, "Incorrect payload before reset");

      // Quiesce the interface and assert synchronous DUT reset.
      @(negedge clk);
      rx_data_valid = '0;
      rx_header_valid = '0;
      rst = 1'b1;

      @(posedge clk);
      #1ps;

      if (block_lock !== 1'b0) $fatal(1, "Block lock did not clear during reset");
      if (descrambled_payload_valid !== 1'b0) $fatal(1, "Descrambler valid remained asserted during reset");

      repeat (3) @(posedge clk);

      @(negedge clk);
      rst = 1'b0;

      @(posedge clk);
      #1ps;

      // Reacquire block lock after reset.
      for (int header_index = 0; header_index < 64; header_index++) begin
        drive_gearbox_sample(64'h0, 2'b10, 1'b1);
      end

      if (block_lock !== 1'b1) $fatal(1, "Block lock did not reacquire after reset");

      // The descrambler must synchronize again from scratch.
      tx_lfsr = {2'b10, 56'h1234_5678_9ABC_DE};
      plaintext = 64'h1122_3344_5566_7788;
      scramble_block(plaintext, scrambled);
      drive_gearbox_sample(scrambled, 2'b10, 1'b1);

      if (descrambled_payload_valid !== 1'b0) $fatal(1, "First block after reset was not suppressed");

      plaintext = 64'hA1B2_C3D4_E5F6_0718;
      scramble_block(plaintext, scrambled);
      drive_gearbox_sample(scrambled, 2'b01, 1'b1);

      if (descrambled_payload_valid !== 1'b1) $fatal(1, "Descrambler did not resynchronize after reset");
      if (descrambled_payload !== plaintext) $fatal(1, "Post-reset payload mismatch: expected %h, received %h", plaintext, descrambled_payload);

      $display("PASS: reset while locked");
    end
  endtask


  initial begin
    initialize_inputs();
    test_acquisition_and_slip_wait();
    test_acquisition_with_bubbles();
    test_descrambler_stream();
    test_lock_retention_and_window_rollover();
    test_lock_loss_and_reacquisition();
    test_reset_while_locked();

    $display("PASS: all RX PCS tests");
    $finish;
  end

endmodule
