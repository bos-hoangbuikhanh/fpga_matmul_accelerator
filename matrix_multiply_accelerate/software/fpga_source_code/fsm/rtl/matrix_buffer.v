`timescale 1ns/1ps
`default_nettype none

module matrix_buffer (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               input_write_enable,
    input  wire               input_matrix_select,
    input  wire        [5:0] input_address,
    input  wire signed [15:0] input_data,
    input  wire               operand_read_enable,
    input  wire        [4:0] a_read_address,
    input  wire        [4:0] b_read_address,
    output reg  signed [15:0] a0,
    output reg  signed [15:0] a1,
    output reg  signed [15:0] b0,
    output reg  signed [15:0] b1,
    input  wire               result_write_enable,
    input  wire        [3:0] result_write_address,
    input  wire signed [34:0] c00,
    input  wire signed [34:0] c01,
    input  wire signed [34:0] c10,
    input  wire signed [34:0] c11,
    input  wire               output_read_enable,
    input  wire        [5:0] output_address,
    output reg  signed [34:0] output_data,
    output reg                output_read_valid
);
    reg signed [15:0] a_even [0:31];
    reg signed [15:0] a_odd  [0:31];
    reg signed [15:0] b_even [0:31];
    reg signed [15:0] b_odd  [0:31];
    reg signed [34:0] c_even_even [0:15];
    reg signed [34:0] c_even_odd  [0:15];
    reg signed [34:0] c_odd_even  [0:15];
    reg signed [34:0] c_odd_odd   [0:15];

    wire [4:0] a_write_address;
    wire [4:0] b_write_address;
    wire [3:0] c_read_address;
    reg [1:0] read_bank;
    reg signed [34:0] read_c00;
    reg signed [34:0] read_c01;
    reg signed [34:0] read_c10;
    reg signed [34:0] read_c11;

    // External addresses are row-major: {row[2:0], column[2:0]}.
    assign a_write_address = {input_address[5:4], input_address[2:0]};
    assign b_write_address = input_address[5:1];
    assign c_read_address = {output_address[5:4], output_address[2:1]};

    // No reset or initialization of RAM contents: load A and B before START.
    always @(posedge clk) begin
        if (input_write_enable && !input_matrix_select) begin
            if (!input_address[3])
                a_even[a_write_address] <= input_data;
            else
                a_odd[a_write_address] <= input_data;
        end
        if (input_write_enable && input_matrix_select) begin
            if (!input_address[0])
                b_even[b_write_address] <= input_data;
            else
                b_odd[b_write_address] <= input_data;
        end
        if (operand_read_enable) begin
            a0 <= a_even[a_read_address];
            a1 <= a_odd[a_read_address];
            b0 <= b_even[b_read_address];
            b1 <= b_odd[b_read_address];
        end
    end

    // Four independent banks each have one write and one synchronous read port.
    always @(posedge clk) begin
        if (result_write_enable) begin
            c_even_even[result_write_address] <= c00;
            c_even_odd[result_write_address] <= c01;
            c_odd_even[result_write_address] <= c10;
            c_odd_odd[result_write_address] <= c11;
        end
        if (output_read_enable) begin
            read_c00 <= c_even_even[c_read_address];
            read_c01 <= c_even_odd[c_read_address];
            read_c10 <= c_odd_even[c_read_address];
            read_c11 <= c_odd_odd[c_read_address];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            output_read_valid <= 1'b0;
            read_bank <= 2'd0;
        end else begin
            output_read_valid <= output_read_enable;
            if (output_read_enable)
                read_bank <= {output_address[3], output_address[0]};
        end
    end

    always @* begin
        case (read_bank)
            2'd0: output_data = read_c00;
            2'd1: output_data = read_c01;
            2'd2: output_data = read_c10;
            2'd3: output_data = read_c11;
            default: output_data = 35'sd0;
        endcase
    end
endmodule

`default_nettype wire
