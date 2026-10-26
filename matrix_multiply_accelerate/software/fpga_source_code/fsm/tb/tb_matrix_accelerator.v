`timescale 1ns/1ps
`default_nettype none

module tb_matrix_accelerator;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    reg input_write_enable = 1'b0;
    reg input_matrix_select = 1'b0;
    reg [5:0] input_address = 6'd0;
    reg signed [15:0] input_data = 16'sd0;
    reg output_read_enable = 1'b0;
    reg [5:0] output_address = 6'd0;
    wire signed [34:0] output_data;
    wire output_read_valid;
    wire busy;
    wire done;

    reg signed [15:0] matrix_a [0:63];
    reg signed [15:0] matrix_b [0:63];
    reg signed [34:0] expected_c [0:63];
    integer completed_runs = 0;
    integer compared_outputs = 0;

    always #5 clk = ~clk;
    matrix_accelerator dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .input_write_enable(input_write_enable), .input_matrix_select(input_matrix_select),
        .input_address(input_address), .input_data(input_data),
        .output_read_enable(output_read_enable), .output_address(output_address),
        .output_data(output_data), .output_read_valid(output_read_valid), .busy(busy), .done(done)
    );

    task fail;
        input [8*160-1:0] message;
        begin
            $display("FAIL: %0s", message);
            $finish_and_return(1);
        end
    endtask

    task load_case;
        input [8*16-1:0] name;
        reg [8*160-1:0] file_name;
        integer address;
        begin
            // A missing/truncated file must not reuse a previous case's vectors.
            for (address = 0; address < 64; address = address + 1) begin
                matrix_a[address] = 16'bx;
                matrix_b[address] = 16'bx;
                expected_c[address] = 35'bx;
            end
            $sformat(file_name, "build/vectors/%0s_a.hex", name);
            $readmemh(file_name, matrix_a);
            $sformat(file_name, "build/vectors/%0s_b.hex", name);
            $readmemh(file_name, matrix_b);
            $sformat(file_name, "build/vectors/%0s_c.hex", name);
            $readmemh(file_name, expected_c);
            for (address = 0; address < 64; address = address + 1) begin
                if ((^matrix_a[address]) === 1'bx || (^matrix_b[address]) === 1'bx ||
                    (^expected_c[address]) === 1'bx)
                    fail("Missing or invalid golden-model vector");
            end
            for (address = 0; address < 128; address = address + 1) begin
                @(negedge clk);
                input_write_enable = 1'b1;
                input_matrix_select = address >= 64;
                input_address = address % 64;
                input_data = address < 64 ? matrix_a[address] : matrix_b[address-64];
                @(posedge clk);
                #1;
                if (busy !== 1'b0)
                    fail("Accelerator became busy while loading inputs");
            end
            @(negedge clk);
            input_write_enable = 1'b0;
        end
    endtask

    task launch;
        begin
            @(negedge clk);
            start = 1'b1;
            // START takes priority over a simultaneous input write or result read.
            input_write_enable = 1'b1;
            input_matrix_select = 1'b0;
            input_address = 6'd0;
            input_data = 16'sh1234;
            output_read_enable = 1'b1;
            output_address = 6'd0;
            @(posedge clk);
            #1;
            if (busy !== 1'b1 || done !== 1'b0 || output_read_valid !== 1'b0)
                fail("Accepted START must assert BUSY, clear DONE, and reject concurrent read");
        end
    endtask

    task await_completion;
        input inject_busy_requests;
        integer cycles;
        begin
            cycles = 0;
            while (done !== 1'b1 && cycles < 320) begin
                @(negedge clk);
                start = inject_busy_requests && cycles == 39;
                input_write_enable = inject_busy_requests && (cycles == 24 || cycles == 99);
                input_matrix_select = cycles == 99;
                input_address = 6'd63;
                input_data = 16'sh5678;
                output_read_enable = 1'b1;
                output_address = cycles % 64;
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (output_read_valid !== 1'b0)
                    fail("Result read was accepted while computing");
                if (cycles < 288 && (busy !== 1'b1 || done !== 1'b0))
                    fail("BUSY or DONE changed before all output tiles were stored");
            end
            if (done !== 1'b1)
                fail("Timed out waiting for DONE");
            if (cycles != 288 || busy !== 1'b0)
                fail("Expected exactly 288 compute cycles and BUSY low at DONE");
            @(negedge clk);
            start = 1'b0;
            input_write_enable = 1'b0;
            output_read_enable = 1'b0;
        end
    endtask

    task check_outputs;
        input [8*16-1:0] name;
        integer address;
        reg signed [34:0] held_data;
        begin
            // Consecutive requests check the one-edge synchronous read interface.
            for (address = 0; address < 64; address = address + 1) begin
                @(negedge clk);
                output_read_enable = 1'b1;
                output_address = address;
                @(posedge clk);
                #1;
                if (output_read_valid !== 1'b1 || busy !== 1'b0 || done !== 1'b1)
                    fail("Invalid result read handshake or non-sticky DONE");
                if (output_data !== expected_c[address]) begin
                    $display("FAIL: %0s C[%0d][%0d]", name, address / 8, address % 8);
                    $display("Expected: %0d", expected_c[address]);
                    $display("Actual:   %0d", output_data);
                    $finish_and_return(1);
                end
                compared_outputs = compared_outputs + 1;
            end
            held_data = output_data;
            @(negedge clk);
            output_read_enable = 1'b0;
            output_address = 6'd0;
            repeat (3) begin
                @(posedge clk);
                #1;
                if (done !== 1'b1 || busy !== 1'b0 || output_read_valid !== 1'b0 ||
                    output_data !== held_data)
                    fail("DONE/result hold/read-valid behavior is incorrect after completion");
            end
            completed_runs = completed_runs + 1;
            $display("%0s: PASS (64 outputs, 288 compute cycles)", name);
        end
    endtask

    task run_case;
        input [8*16-1:0] name;
        input inject_busy_requests;
        begin
            load_case(name);
            launch;
            await_completion(inject_busy_requests);
            check_outputs(name);
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        #1;
        if (busy !== 1'b0 || done !== 1'b0 || output_read_valid !== 1'b0)
            fail("Reset did not clear status");
        @(negedge clk);
        rst_n = 1'b1;
        output_read_enable = 1'b1;
        @(posedge clk);
        #1;
        if (output_read_valid !== 1'b0)
            fail("Results must not be readable before the first completion");
        @(negedge clk);
        output_read_enable = 1'b0;

        run_case("tc01", 1'b0);
        run_case("tc02", 1'b0);
        run_case("tc03", 1'b0);
        run_case("tc04", 1'b1);
        run_case("tc05", 1'b0);
        run_case("tc06", 1'b1);
        run_case("tc07a", 1'b0);
        run_case("tc07b", 1'b1);
        $display("Repeated START: PASS (different inputs, no intervening reset)");

        // Abort a partially completed matrix and verify deterministic recovery.
        load_case("tc06");
        launch;
        @(negedge clk);
        start = 1'b0;
        input_write_enable = 1'b0;
        output_read_enable = 1'b0;
        repeat (37) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b0;
        start = 1'b1;
        input_write_enable = 1'b1;
        output_read_enable = 1'b1;
        @(posedge clk);
        #1;
        if (busy !== 1'b0 || done !== 1'b0 || output_read_valid !== 1'b0)
            fail("Reset during computation did not clear status");
        @(negedge clk);
        rst_n = 1'b1;
        start = 1'b0;
        input_write_enable = 1'b0;
        output_read_enable = 1'b0;
        run_case("tc04", 1'b0);
        $display("Control interface/reset recovery: PASS");
        $display("Matrix Accelerator: PASS (%0d completed runs)", completed_runs);
        $display("All 64 Output Values: PASS (%0d total comparisons)", compared_outputs);
        $finish;
    end

    initial begin
        #1000000;
        fail("Global testbench watchdog expired");
    end
endmodule

`default_nettype wire
