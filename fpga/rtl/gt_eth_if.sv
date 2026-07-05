interface gt_etf_if;
    logic gtwiz_userclk_tx_reset_in;
    logic gtwiz_userclk_rx_reset_in;
    logic [63:0] gtwiz_userdata_tx_in;
    logic gtwiz_userclk_tx_srcclk_out;
    logic gtwiz_userclk_tx_usrclk_out;
    logic gtwiz_userclk_tx_usrclk2_out;
    logic gtwiz_userclk_tx_active_out;
    logic gtwiz_userclk_rx_srcclk_out;
    logic gtwiz_userclk_rx_usrclk_out;
    logic gtwiz_userclk_rx_usrclk2_out;
    logic gtwiz_userclk_rx_active_out;
    logic gtwiz_reset_tx_done_out;
    logic gtwiz_reset_rx_done_out;
    logic gtwiz_reset_rx_cdr_stable_out;
    logic [63:0] gtwiz_userdata_rx_out;
    logic [1:0] rxpmaresetdone_out;
    logic [1:0] txpmaresetdone_out;
    logic [1:0] gtpowergood_out;
    logic qpll0outclk_out;
    logic qpll0outrefclk_out;
    
    modport gt_side(
    input
        gtwiz_userclk_tx_reset_in,
        gtwiz_userclk_rx_reset_in,
        gtwiz_userdata_tx_in,
    output
        gtwiz_userclk_tx_srcclk_out,
        gtwiz_userclk_tx_usrclk_out,
        gtwiz_userclk_tx_usrclk2_out,
        gtwiz_userclk_tx_active_out,
        gtwiz_userclk_rx_srcclk_out,
        gtwiz_userclk_rx_usrclk_out,
        gtwiz_userclk_rx_usrclk2_out,
        gtwiz_userclk_rx_active_out,
        gtwiz_reset_tx_done_out,
        gtwiz_reset_rx_done_out,
        gtwiz_reset_rx_cdr_stable_out,
        gtwiz_userdata_rx_out,
        rxpmaresetdone_out,
        txpmaresetdone_out,
        gtpowergood_out,
        qpll0outclk_out,
        qpll0outrefclk_out
    );
        
    modport eth_side(
    input 	
        gtwiz_userclk_tx_srcclk_out,
        gtwiz_userclk_tx_usrclk_out,
        gtwiz_userclk_tx_usrclk2_out,
        gtwiz_userclk_tx_active_out,
        gtwiz_userclk_rx_srcclk_out,
        gtwiz_userclk_rx_usrclk_out,
        gtwiz_userclk_rx_usrclk2_out,
        gtwiz_userclk_rx_active_out,
        gtwiz_reset_tx_done_out,
        gtwiz_reset_rx_done_out,
        gtwiz_reset_rx_cdr_stable_out,
        gtwiz_userdata_rx_out,
        rxpmaresetdone_out,
        txpmaresetdone_out,
        gtpowergood_out,
        qpll0outclk_out,
        qpll0outrefclk_out,
        
    output
        gtwiz_userclk_tx_reset_in,
        gtwiz_userclk_rx_reset_in,
        gtwiz_userdata_tx_in
    );
endinterface
