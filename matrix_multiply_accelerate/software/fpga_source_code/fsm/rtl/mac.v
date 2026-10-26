`timescale 1ns/1ps
`default_nettype none

module mac (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               clear,
    input  wire               enable,
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [34:0] acc
);
    wire signed [31:0] product;
    wire signed [34:0] extended_product;

    assign product = a * b;
    assign extended_product = {{3{product[31]}}, product};

    always @(posedge clk) begin
        if (!rst_n)
            acc <= 35'sd0;
        else if (clear)
            acc <= 35'sd0;
        else if (enable)
            acc <= acc + extended_product;
    end
endmodule

`default_nettype wire
