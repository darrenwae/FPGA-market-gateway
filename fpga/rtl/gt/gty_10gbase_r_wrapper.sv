module gty_10gbase_r_wrapper (
    input logic clk_freerun, // free running 100Mhz clk used by GT reset controller
    input logic rst,
    input logic gt_refclk_p, // 156.25 Mhz MGT ref clk
    input logic gt_refclk_n, 

    // Channel 0: SFP 1
    // Channel 1: SFP 2
    input logic [1:0] sfp_rx_p,
    input logic [1:0] sfp_rx_n,
    output logic [1:0] sfp_tx_p,
    output logic [1:0] sfp_tx_n,

    input logic [1:0][63:0] tx_data,
    input logic [1:0][5:0] tx_header,
    input logic [1:0][6:0] tx_sequence,
    
    input logic [1:0] rx_gearbox_slip,
    
    output logic [1:0][63:0] rx_data,
    output logic [1:0][5:0] rx_header,
    output logic [1:0][1:0] rx_data_valid,
    output logic [1:0][1:0] rx_header_valid,
    output logic [1:0][1:0] rx_start_of_seq,

    output logic tx_pcs_clk,
    output logic rx_pcs_clk,

    output logic tx_reset_done,
    output logic rx_reset_done,
    output logic rx_cdr_stable,
    output logic [1:0] gt_power_good
);

    logic gt_refclk;
    logic tx_userclk_reset;
    logic rx_userclk_reset;

    assign tx_userclk_reset = ~tx_reset_done;
    assign rx_userclk_reset = ~rx_reset_done;

    IBUFDS_GTE4 #(.REFCLK_EN_TX_PATH(1'b0), .REFCLK_HROW_CK_SEL(2'b00), .REFCLK_ICNTL_RX(2'b00))
        u_gt_refclk_buf (
            .I(gt_refclk_p), 
            .IB(gt_refclk_n), 
            .O(gt_refclk), 
            .ODIV2(),
            .CEB(1'b0)
        );


    gtwizard_ultrascale_0 u_gtwizard (
        // TX user clock helper
        .gtwiz_userclk_tx_reset_in(tx_userclk_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_pcs_clk),
        .gtwiz_userclk_tx_active_out(),

        // RX user clock helper
        .gtwiz_userclk_rx_reset_in(rx_userclk_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_pcs_clk),
        .gtwiz_userclk_rx_active_out(),

        // GT reset controller
        .gtwiz_reset_clk_freerun_in(clk_freerun),
        .gtwiz_reset_all_in(rst),
        .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
        .gtwiz_reset_tx_datapath_in(1'b0),
        .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
        .gtwiz_reset_rx_datapath_in(1'b0),
        .gtwiz_reset_rx_cdr_stable_out(rx_cdr_stable),
        .gtwiz_reset_tx_done_out(tx_reset_done),
        .gtwiz_reset_rx_done_out(rx_reset_done),

        // Parallel 64b/66b gearbox interface
        .gtwiz_userdata_tx_in(tx_data),
        .gtwiz_userdata_rx_out(rx_data),
        .rxgearboxslip_in(rx_gearbox_slip),
        .txheader_in(tx_header),
        .txsequence_in(tx_sequence),
        .rxdatavalid_out(rx_data_valid),
        .rxheader_out(rx_header),
        .rxheadervalid_out(rx_header_valid),
        .rxstartofseq_out(rx_start_of_seq),

        // GT reference clock
        .gtrefclk00_in(gt_refclk),
        .qpll0outclk_out(),
        .qpll0outrefclk_out(),

        // Physical SFP serial channels
        .gtyrxn_in(sfp_rx_n),
        .gtyrxp_in(sfp_rx_p),
        .gtytxn_out(sfp_tx_n),
        .gtytxp_out(sfp_tx_p),

        // GT status
        .gtpowergood_out(gt_power_good),
        .rxpmaresetdone_out(),
        .txpmaresetdone_out()
    );

endmodule
