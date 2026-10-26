`timescale 1ns/1ps
`default_nettype none

module tb_standalone_top;
    reg clk;
    reg rst_n;
    wire pass_good, fail_good, done_good;
    wire pass_bad, fail_bad, done_bad;
    integer cycles;
    integer run;

    standalone_top good (
        .clk(clk), .rst_n(rst_n),
        .pass(pass_good), .fail(fail_good), .done(done_good)
    );

    // Corrupt only the last expected word to exercise the complete checker.
    standalone_top #(
        .C_INIT_FILE("build/vectors/standalone_bad_expected.hex")
    ) bad (
        .clk(clk), .rst_n(rst_n),
        .pass(pass_bad), .fail(fail_bad), .done(done_bad)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        for (run = 0; run < 2; run = run + 1) begin
            @(negedge clk);
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if ({pass_good, fail_good, done_good,
                 pass_bad, fail_bad, done_bad} !== 6'b000000) begin
                $display("FAIL: standalone status was not cleared by reset");
                $finish_and_return(1);
            end
            @(negedge clk);
            rst_n = 1'b1;
            cycles = 0;
            while ((done_good !== 1'b1 || done_bad !== 1'b1) && cycles < 1000) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (done_good !== 1'b1 && pass_good !== 1'b0) begin
                    $display("FAIL: standalone asserted PASS before completing all reads");
                    $finish_and_return(1);
                end
                if (done_bad !== 1'b1 && fail_bad !== 1'b0) begin
                    $display("FAIL: last-word corruption was detected before the last check");
                    $finish_and_return(1);
                end
            end
            if ({pass_good, fail_good, done_good} !== 3'b101 ||
                {pass_bad, fail_bad, done_bad} !== 3'b011) begin
                $display("FAIL: standalone statuses good=%b%b%b bad=%b%b%b cycles=%0d",
                         pass_good, fail_good, done_good, pass_bad, fail_bad, done_bad, cycles);
                $finish_and_return(1);
            end
            if (cycles != 610) begin
                $display("FAIL: standalone latency expected 610 cycles, actual %0d", cycles);
                $finish_and_return(1);
            end
            repeat (5) begin
                @(posedge clk);
                #1;
                if ({pass_good, fail_good, done_good,
                     pass_bad, fail_bad, done_bad} !== 6'b101011) begin
                    $display("FAIL: standalone terminal status is not sticky");
                    $finish_and_return(1);
                end
            end
            $display("Standalone run %0d: PASS (610 cycles; correct and corrupted expectations)", run + 1);
        end
        $display("Standalone Top: PASS");
        $finish;
    end
endmodule

`default_nettype wire
