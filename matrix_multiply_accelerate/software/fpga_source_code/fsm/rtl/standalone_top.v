`timescale 1ns/1ps
`default_nettype none

module standalone_top #(
    parameter A_INIT_FILE = "memory/matrix_a.hex",
    parameter B_INIT_FILE = "memory/matrix_b.hex",
    parameter C_INIT_FILE = "memory/c_expected.hex"
) (
    input wire clk,
    input wire rst_n,
    output reg pass,
    output reg fail,
    output reg done
);
    localparam [2:0] LOAD_READ = 3'd0,
                     LOAD_A = 3'd1,
                     LOAD_B = 3'd2,
                     START = 3'd3,
                     WAIT_DONE = 3'd4,
                     CHECK_READ = 3'd5,
                     CHECK_COMPARE = 3'd6,
                     FINISHED = 3'd7;

    reg [2:0] state;
    reg [5:0] address;
    reg signed [15:0] a_rom [0:63];
    reg signed [15:0] b_rom [0:63];
    reg signed [34:0] c_rom [0:63];
    reg signed [15:0] a_value;
    reg signed [15:0] b_value;
    reg signed [34:0] expected_value;
    wire signed [34:0] result;
    wire result_valid;
    wire accelerator_busy;
    wire accelerator_done;
    wire start;
    wire write_enable;
    wire read_enable;

    // Initialization belongs only to this standalone ROM wrapper.
    initial begin
        $readmemh(A_INIT_FILE, a_rom);
        $readmemh(B_INIT_FILE, b_rom);
        $readmemh(C_INIT_FILE, c_rom);
    end

    // Keep ROM output registers free of reset to allow memory inference.
    always @(posedge clk) begin
        if (rst_n && state == LOAD_READ) begin
            a_value <= a_rom[address];
            b_value <= b_rom[address];
        end
        if (rst_n && state == CHECK_READ)
            expected_value <= c_rom[address];
    end

    assign start = rst_n && state == START;
    assign write_enable = rst_n && (state == LOAD_A || state == LOAD_B);
    assign read_enable = rst_n && state == CHECK_READ;

    matrix_accelerator accelerator (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .input_write_enable(write_enable),
        .input_matrix_select(state == LOAD_B),
        .input_address(address),
        .input_data(state == LOAD_B ? b_value : a_value),
        .output_read_enable(read_enable),
        .output_address(address),
        .output_data(result),
        .output_read_valid(result_valid),
        .busy(accelerator_busy),
        .done(accelerator_done)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= LOAD_READ;
            address <= 6'd0;
            pass <= 1'b0;
            fail <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                LOAD_READ: state <= LOAD_A;
                LOAD_A: state <= LOAD_B;
                LOAD_B: begin
                    if (address == 6'd63) begin
                        address <= 6'd0;
                        state <= START;
                    end else begin
                        address <= address + 6'd1;
                        state <= LOAD_READ;
                    end
                end
                START: state <= WAIT_DONE;
                WAIT_DONE: begin
                    if (accelerator_done)
                        state <= CHECK_READ;
                end
                CHECK_READ: state <= CHECK_COMPARE;
                CHECK_COMPARE: begin
                    // A valid matching response is the only success path.
                    if (result_valid && result == expected_value) begin
                        if (address == 6'd63 && !fail)
                            pass <= 1'b1;
                    end else begin
                        fail <= 1'b1;
                    end
                    if (address == 6'd63) begin
                        done <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        address <= address + 6'd1;
                        state <= CHECK_READ;
                    end
                end
                FINISHED: state <= FINISHED;
                default: begin
                    pass <= 1'b0;
                    fail <= 1'b1;
                    done <= 1'b1;
                    state <= FINISHED;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
