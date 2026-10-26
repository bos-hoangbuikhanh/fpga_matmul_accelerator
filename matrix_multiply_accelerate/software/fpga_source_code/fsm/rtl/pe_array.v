`timescale 1ns/1ps
`default_nettype none

module pe_array (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               clear,
    input  wire               enable,
    input  wire signed [15:0] a0,
    input  wire signed [15:0] a1,
    input  wire signed [15:0] b0,
    input  wire signed [15:0] b1,
    output wire signed [34:0] c00,
    output wire signed [34:0] c01,
    output wire signed [34:0] c10,
    output wire signed [34:0] c11
);
    mac pe00 (
        .clk(clk), .rst_n(rst_n), .clear(clear), .enable(enable),
        .a(a0), .b(b0), .acc(c00)
    );
    mac pe01 (
        .clk(clk), .rst_n(rst_n), .clear(clear), .enable(enable),
        .a(a0), .b(b1), .acc(c01)
    );
    mac pe10 (
        .clk(clk), .rst_n(rst_n), .clear(clear), .enable(enable),
        .a(a1), .b(b0), .acc(c10)
    );
    mac pe11 (
        .clk(clk), .rst_n(rst_n), .clear(clear), .enable(enable),
        .a(a1), .b(b1), .acc(c11)
    );
endmodule

`default_nettype wire
