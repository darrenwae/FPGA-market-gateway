// Tracks whether regular market hours are active

module market_hours_tracker (
    input logic clk,
    input logic rst,

    input logic session_status_valid,
    input logic [2:0] session_state,
    input logic full_reset_all,

    output logic market_hours_active
);

  localparam logic [2:0] START_OF_MARKET_HOURS = 3'd3;

  always_ff @(posedge clk) begin
    if (rst) begin
      market_hours_active <= 1'b0;
    end
    else if (full_reset_all) begin
      market_hours_active <= 1'b0;
    end
    else if (session_status_valid) begin
      market_hours_active <= session_state == START_OF_MARKET_HOURS;
    end
  end

endmodule
