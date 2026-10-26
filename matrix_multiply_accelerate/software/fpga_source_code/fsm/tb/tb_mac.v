`timescale 1ns/1ps
`default_nettype none

module tb_mac;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg clear = 1'b0;
    reg enable = 1'b0;
    reg signed [15:0] a = 16'sd0;
    reg signed [15:0] b = 16'sd0;
    wire signed [34:0] acc;
    reg signed [63:0] expected = 64'sd0;
    integer checks = 0;
    integer i;

    always #5 clk = ~clk;
    mac dut (.clk(clk), .rst_n(rst_n), .clear(clear), .enable(enable), .a(a), .b(b), .acc(acc));

    task step;
        input do_clear;
        input do_enable;
        input signed [15:0] operand_a;
        input signed [15:0] operand_b;
        reg signed [63:0] wide_a;
        reg signed [63:0] wide_b;
        begin
            @(negedge clk);
            clear = do_clear;
            enable = do_enable;
            a = operand_a;
            b = operand_b;
            wide_a = operand_a;
            wide_b = operand_b;
            if (do_clear)
                expected = 64'sd0;
            else if (do_enable)
                expected = expected + wide_a * wide_b;
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (acc !== expected[34:0]) begin
                $display("FAIL: MAC check %0d expected=%0d actual=%0d", checks, expected, acc);
                $finish_and_return(1);
            end
        end
    endtask

    initial begin
        @(posedge clk);
        #1;
        if (acc !== 35'sd0) begin
            $display("FAIL: MAC reset did not clear accumulator");
            $finish_and_return(1);
        end
        @(negedge clk);
        rst_n = 1'b1;
        step(1'b0, 1'b1, 16'sd7, 16'sd9);
        step(1'b0, 1'b1, -16'sd5, 16'sd13);
        step(1'b0, 1'b1, -16'sd11, -16'sd3);
        step(1'b0, 1'b1, 16'sd0, -16'sd32767);
        step(1'b0, 1'b1, -16'sd32767, 16'sd0);
        step(1'b0, 1'b0, 16'sd30000, 16'sd30000);
        step(1'b1, 1'b1, 16'sd32767, 16'sd32767);
        for (i = 0; i < 8; i = i + 1)
            step(1'b0, 1'b1, 16'sh8000, 16'sh8000);
        step(1'b1, 1'b0, 16'sd0, 16'sd0);
        for (i = 0; i < 8; i = i + 1)
            step(1'b0, 1'b1, 16'sh8000, 16'sh7fff);
        step(1'b1, 1'b0, 16'sd0, 16'sd0);
        step(1'b0, 1'b1, 16'sh7fff, 16'sh7fff);
        step(1'b0, 1'b1, 16'sh8000, -16'sd1);
        @(negedge clk);
        rst_n = 1'b0;
        enable = 1'b1;
        @(posedge clk);
        #1;
        if (acc !== 35'sd0) begin
            $display("FAIL: MAC reset priority");
            $finish_and_return(1);
        end
        $display("MAC Testbench: PASS (%0d arithmetic/hold/clear checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
