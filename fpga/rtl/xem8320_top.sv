module xem8320_top (
    input logic sys_clk_p, // free running 100Mhz clk used by GT reset controller
    input logic sys_clk_n,

    input logic gt_refclk_p, // 156.25 Mhz MGT ref clk
    input logic gt_refclk_n,

    input logic [1:0] sfp_rx_p,
    input logic [1:0] sfp_rx_n,
    output logic [1:0] sfp_tx_p,
    output logic [1:0] sfp_tx_n,

    output logic [1:0] sfp_tx_disable,
    output logic [1:0] sfp_rate_select_0,
    output logic [1:0] sfp_rate_select_1
    
);

    logic clk_freerun;
    logic [1:0][63:0] tx_data;
    logic [1:0][5:0] tx_header;
    logic [1:0][6:0] tx_sequence;

    logic [1:0] rx_gearbox_slip;

    logic [1:0][63:0] rx_data;
    logic [1:0][5:0] rx_header;
    logic [1:0][1:0] rx_data_valid;
    logic [1:0][1:0] rx_header_valid;
    logic [1:0][1:0] rx_start_of_seq;

    logic tx_pcs_clk;
    logic rx_pcs_clk;
    logic tx_reset_done;
    logic rx_reset_done;
    logic rx_cdr_stable;
    logic [1:0] gt_power_good;

    // temporarily defined
    assign tx_data = '0;
    assign tx_header = '0;
    assign tx_sequence = '0;
    assign rx_gearbox_slip = '0; // awaiting block_lock controller

    assign sfp_tx_disable = 2'b11; // change to 2'b00 when Tx PCS is implemented
    assign sfp_rate_select_0 = 2'b11;
    assign sfp_rate_select_1 = 2'b11;

    IBUFDS u_sys_clk_buf (
        .I(sys_clk_p),
        .IB(sys_clk_n),
        .O(clk_freerun)
    );


    gty_10gbase_r_wrapper u_gty_10gbase_r (
        .clk_freerun(clk_freerun),
        .rst(1'b0),

        .gt_refclk_p(gt_refclk_p),
        .gt_refclk_n(gt_refclk_n),

        .sfp_rx_p(sfp_rx_p),
        .sfp_rx_n(sfp_rx_n),
        .sfp_tx_p(sfp_tx_p),
        .sfp_tx_n(sfp_tx_n),

        .tx_data(tx_data),
        .tx_header(tx_header),
        .tx_sequence(tx_sequence),

        .rx_gearbox_slip(rx_gearbox_slip),

        .rx_data(rx_data),
        .rx_header(rx_header),
        .rx_data_valid(rx_data_valid),
        .rx_header_valid(rx_header_valid),
        .rx_start_of_seq(rx_start_of_seq),

        .tx_pcs_clk(tx_pcs_clk),
        .rx_pcs_clk(rx_pcs_clk),

        .tx_reset_done(tx_reset_done),
        .rx_reset_done(rx_reset_done),
        .rx_cdr_stable(rx_cdr_stable),
        .gt_power_good(gt_power_good)
    );

endmodule
