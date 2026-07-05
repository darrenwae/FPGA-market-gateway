module eth_top (
	input SFP1_in_M2, SFP1_in_M1, SFP2_in_K2, SFP2_in_K1, MGTREFCLK1_Y7, MGTREFCLK1_Y6,
	output SFP1_out_N5, SFP1_out_N4, SFP2_out_L5, SFP2_out_L4,
	input logic clk_freerun, 
	output logic SFP1_TDIS, SFP2_TDIS, SFP1_RATE_SELECT0, SFP1_RATE_SELECT1, SFP2_RATE_SELECT0, SFP2_RATE_SELECT1 );
    
    wire ref_clk;
    wire master_reset = 1'b0;
    wire [1:0] gtytxn_out;
    wire [1:0] gtytxp_out;

    assign SFP1_TDIS = 1'b0;
    assign SFP2_TDIS = 1'b0;
    assign SFP1_RATE_SELECT0 = 1'b1;
    assign SFP1_RATE_SELECT1 = 1'b1;
    assign SFP2_RATE_SELECT0 = 1'b1;
    assign SFP2_RATE_SELECT1 = 1'b1;
    assign SFP1_out_N5 = gtytxp_out[0];
    assign SFP2_out_L5 = gtytxp_out[1];
    assign SFP1_out_N4 = gtytxn_out[0];
    assign SFP2_out_L4 = gtytxn_out[1];
	
	//instatiate interface
	gt_eth_if gt_eth_if_inst ();

    //instantiate IBUFDS_GTE4
    IBUFDS_GTE4 #( 
        .REFCLK_EN_TX_PATH  (1'b0),
        .REFCLK_HROW_CK_SEL (2'b00),
        .REFCLK_ICNTL_RX    (2'b00))

        u_ibufds_gte4_inst (
            .I(MGTREFCLK1_Y7),
            .IB(MGTREFCLK1_Y6),
            .O(ref_clk),
            .ODIV2(),
            .CEB(1'b0)
        );
	
	//instantiate gt wizard
	gtwizard_ultrascale_0 gtwizard(
        .gtwiz_userclk_tx_reset_in(gt_eth_if_inst.gtwiz_userclk_tx_reset_in),
        .gtwiz_userclk_tx_srcclk_out(gt_eth_if_inst.gtwiz_userclk_tx_srcclk_out),
        .gtwiz_userclk_tx_usrclk_out(gt_eth_if_inst.gtwiz_userclk_tx_usrclk_out),
        .gtwiz_userclk_tx_usrclk2_out(gt_eth_if_inst.gtwiz_userclk_tx_usrclk2_out),
        .gtwiz_userclk_tx_active_out(gt_eth_if_inst.gtwiz_userclk_tx_active_out),
        .gtwiz_userclk_rx_reset_in(gt_eth_if_inst.gtwiz_userclk_rx_reset_in),
        .gtwiz_userclk_rx_srcclk_out(gt_eth_if_inst.gtwiz_userclk_rx_srcclk_out),
        .gtwiz_userclk_rx_usrclk_out(gt_eth_if_inst.gtwiz_userclk_rx_usrclk_out),
        .gtwiz_userclk_rx_usrclk2_out(gt_eth_if_inst.gtwiz_userclk_rx_usrclk2_out),
        .gtwiz_userclk_rx_active_out(gt_eth_if_inst.gtwiz_userclk_rx_active_out),
        .gtwiz_reset_clk_freerun_in(clk_freerun),
        .gtwiz_reset_all_in(master_reset),
        .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
        .gtwiz_reset_tx_datapath_in(1'b0),
        .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
        .gtwiz_reset_rx_datapath_in(1'b0),
        .gtwiz_reset_rx_cdr_stable_out(gt_eth_if_inst.gtwiz_reset_rx_cdr_stable_out),
        .gtwiz_reset_tx_done_out(gt_eth_if_inst.gtwiz_reset_tx_done_out),
        .gtwiz_reset_rx_done_out(gt_eth_if_inst.gtwiz_reset_rx_done_out),
        .gtwiz_userdata_tx_in(gt_eth_if_inst.gtwiz_userdata_tx_in),
        .gtwiz_userdata_rx_out(gt_eth_if_inst.gtwiz_userdata_rx_out),
        .gtrefclk00_in(ref_clk),
        .qpll0outclk_out(gt_eth_if_inst.qpll0outclk_out),
        .qpll0outrefclk_out(gt_eth_if_inst.qpll0outrefclk_out),
        .gtyrxn_in({SFP2_in_K1, SFP1_in_M1}),
        .gtyrxp_in({SFP2_in_K2, SFP1_in_M2}),
        .gtpowergood_out(gt_eth_if_inst.gtpowergood_out),
        .gtytxn_out(gtytxn_out),
        .gtytxp_out(gtytxp_out),
        .rxpmaresetdone_out(gt_eth_if_inst.rxpmaresetdone_out),
        .txpmaresetdone_out(gt_eth_if_inst.txpmaresetdone_out)
    );

endmodule