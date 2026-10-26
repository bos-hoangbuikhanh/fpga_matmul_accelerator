`timescale 1ns/1ps
`default_nettype none

module matrix_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output wire       busy,
    output wire       done,
    output wire       pe_clear,
    output wire       pe_enable,
    output wire       operand_read_enable,
    output wire [4:0] a_read_address,
    output wire [4:0] b_read_address,
    output wire       result_write_enable,
    output wire [3:0] result_write_address
);
    localparam [2:0] IDLE  = 3'd0,
                     INIT  = 3'd1,
                     LOAD  = 3'd2,
                     MAC   = 3'd3,
                     STORE = 3'd4,
                     DONE  = 3'd5;

    reg [2:0] state;
    reg [1:0] tile_row;
    reg [1:0] tile_col;
    reg [2:0] k;

    assign busy = (state == INIT) || (state == LOAD) ||
                  (state == MAC) || (state == STORE);
    assign done = (state == DONE);
    assign pe_clear = rst_n && (state == INIT);
    assign pe_enable = rst_n && (state == MAC);
    assign operand_read_enable = rst_n && (state == LOAD);
    assign result_write_enable = rst_n && (state == STORE);
    assign a_read_address = {tile_row, k};
    assign b_read_address = {k, tile_col};
    assign result_write_address = {tile_row, tile_col};

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            tile_row <= 2'd0;
            tile_col <= 2'd0;
            k <= 3'd0;
        end else begin
            case (state)
                IDLE, DONE: begin
                    if (start) begin
                        state <= INIT;
                        tile_row <= 2'd0;
                        tile_col <= 2'd0;
                        k <= 3'd0;
                    end
                end
                INIT: begin
                    k <= 3'd0;
                    state <= LOAD;
                end
                LOAD: begin
                    // RAM outputs register here; MAC consumes them next edge.
                    state <= MAC;
                end
                MAC: begin
                    if (k == 3'd7)
                        state <= STORE;
                    else begin
                        k <= k + 3'd1;
                        state <= LOAD;
                    end
                end
                STORE: begin
                    // The eighth MAC has already updated all accumulators.
                    if ((tile_row == 2'd3) && (tile_col == 2'd3))
                        state <= DONE;
                    else begin
                        if (tile_col == 2'd3) begin
                            tile_row <= tile_row + 2'd1;
                            tile_col <= 2'd0;
                        end else begin
                            tile_col <= tile_col + 2'd1;
                        end
                        state <= INIT;
                    end
                end
                default: begin
                    state <= IDLE;
                    tile_row <= 2'd0;
                    tile_col <= 2'd0;
                    k <= 3'd0;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
