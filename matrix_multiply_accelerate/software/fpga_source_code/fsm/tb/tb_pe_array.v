`timescale 1ns/1ps
`default_nettype none

module tb_pe_array;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg clear = 1'b0;
    reg enable = 1'b0;
    reg signed [15:0] a0 = 16'sd0;
    reg signed [15:0] a1 = 16'sd0;
    reg signed [15:0] b0 = 16'sd0;
    reg signed [15:0] b1 = 16'sd0;
    wire signed [34:0] c00, c01, c10, c11;
    reg signed [63:0] expected00 = 64'sd0;
    reg signed [63:0] expected01 = 64'sd0;
    reg signed [63:0] expected10 = 64'sd0;
    reg signed [63:0] expected11 = 64'sd0;
    integer checks = 0;
    integer i;

    always #5 clk = ~clk;
    pe_array dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .enable(enable),
        .a0(a0), .a1(a1), .b0(b0), .b1(b1),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    task check;
        begin
            checks = checks + 1;
            if (c00 !== expected00[34:0] || c01 !== expected01[34:0] ||
                c10 !== expected10[34:0] || c11 !== expected11[34:0]) begin
                $display("FAIL: PE check %0d", checks);
                $display("Expected: [%0d %0d; %0d %0d]", expected00, expected01, expected10, expected11);
                $display("Actual:   [%0d %0d; %0d %0d]", c00, c01, c10, c11);
                $finish_and_return(1);
            end
        end
    endtask

    task step;
        input do_clear;
        input do_enable;
        input signed [15:0] operand_a0, operand_a1, operand_b0, operand_b1;
        reg signed [63:0] wide_a0, wide_a1, wide_b0, wide_b1;
        begin
            @(negedge clk);
            clear = do_clear;
            enable = do_enable;
            a0 = operand_a0;
            a1 = operand_a1;
            b0 = operand_b0;
            b1 = operand_b1;
            wide_a0 = operand_a0;
            wide_a1 = operand_a1;
            wide_b0 = operand_b0;
            wide_b1 = operand_b1;
            if (do_clear) begin
                expected00 = 64'sd0;
                expected01 = 64'sd0;
                expected10 = 64'sd0;
                expected11 = 64'sd0;
            end else if (do_enable) begin
                expected00 = expected00 + wide_a0 * wide_b0;
                expected01 = expected01 + wide_a0 * wide_b1;
                expected10 = expected10 + wide_a1 * wide_b0;
                expected11 = expected11 + wide_a1 * wide_b1;
            end
            @(posedge clk);
            #1;
            check;
        end
    endtask

    initial begin
        @(posedge clk);
        #1;
        check;
        @(negedge clk);
        rst_n = 1'b1;
        step(1'b0, 1'b1, 16'sd2, -16'sd3, 16'sd5, -16'sd7);
        step(1'b0, 1'b1, -16'sd11, 16'sd13, -16'sd17, 16'sd19);
        step(1'b0, 1'b1, 16'sd0, 16'sd23, 16'sd29, 16'sd0);
        step(1'b0, 1'b0, 16'sh8000, 16'sh7fff, 16'sh8000, 16'sh7fff);
        step(1'b1, 1'b1, 16'sd3, 16'sd4, 16'sd5, 16'sd6);
        for (i = 0; i < 8; i = i + 1)
            step(1'b0, 1'b1, 16'sh8000, 16'sh7fff, 16'sh8000, 16'sh7fff);
        step(1'b1, 1'b0, 16'sd0, 16'sd0, 16'sd0, 16'sd0);
        step(1'b0, 1'b1, -16'sd2, 16'sd4, 16'sd9, -16'sd6);
        $display("PE Array Testbench: PASS (%0d four-output checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
