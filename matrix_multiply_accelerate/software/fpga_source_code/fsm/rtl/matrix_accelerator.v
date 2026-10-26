`timescale 1ns/1ps
`default_nettype none

module matrix_accelerator (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    input  wire               input_write_enable,
    input  wire               input_matrix_select,
    input  wire        [5:0] input_address,
    input  wire signed [15:0] input_data,
    input  wire               output_read_enable,
    input  wire        [5:0] output_address,
    output wire signed [34:0] output_data,
    output wire               output_read_valid,
    output wire               busy,
    output wire               done
);
    wire pe_clear;
    wire pe_enable;
    wire operand_read_enable;
    wire [4:0] a_read_address;
    wire [4:0] b_read_address;
    wire result_write_enable;
    wire [3:0] result_write_address;
    wire signed [15:0] a0;
    wire signed [15:0] a1;
    wire signed [15:0] b0;
    wire signed [15:0] b1;
    wire signed [34:0] c00;
    wire signed [34:0] c01;
    wire signed [34:0] c10;
    wire signed [34:0] c11;
    wire accepted_input_write;
    wire accepted_output_read;

    // START takes priority over host memory access on its acceptance edge.
    assign accepted_input_write = rst_n && !busy && !start && input_write_enable;
    assign accepted_output_read = rst_n && done && !start && output_read_enable;

    matrix_controller controller (
        .clk(clk), .rst_n(rst_n), .start(start),
        .busy(busy), .done(done),
        .pe_clear(pe_clear), .pe_enable(pe_enable),
        .operand_read_enable(operand_read_enable),
        .a_read_address(a_read_address), .b_read_address(b_read_address),
        .result_write_enable(result_write_enable),
        .result_write_address(result_write_address)
    );

    matrix_buffer buffers (
        .clk(clk), .rst_n(rst_n),
        .input_write_enable(accepted_input_write),
        .input_matrix_select(input_matrix_select),
        .input_address(input_address), .input_data(input_data),
        .operand_read_enable(operand_read_enable),
        .a_read_address(a_read_address), .b_read_address(b_read_address),
        .a0(a0), .a1(a1), .b0(b0), .b1(b1),
        .result_write_enable(result_write_enable),
        .result_write_address(result_write_address),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11),
        .output_read_enable(accepted_output_read),
        .output_address(output_address), .output_data(output_data),
        .output_read_valid(output_read_valid)
    );

    pe_array datapath (
        .clk(clk), .rst_n(rst_n), .clear(pe_clear), .enable(pe_enable),
        .a0(a0), .a1(a1), .b0(b0), .b1(b1),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );
endmodule

`default_nettype wire
