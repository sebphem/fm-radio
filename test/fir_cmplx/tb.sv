`timescale 1 ns / 1 ns

module fir_cmplx_tb;

localparam string X_REAL_IN_FILE = "../test/fir_cmplx/x_real_in.txt";
localparam string X_IMAG_IN_FILE = "../test/fir_cmplx/x_imag_in.txt";
localparam string Y_REAL_CMP_FILE = "../test/fir_cmplx/y_real_cmp.txt";
localparam string Y_IMAG_CMP_FILE = "../test/fir_cmplx/y_imag_cmp.txt";
localparam string Y_REAL_OUT_FILE = "../test/fir_cmplx/y_real_out.txt";
localparam string Y_IMAG_OUT_FILE = "../test/fir_cmplx/y_imag_out.txt";

localparam CLOCK_PERIOD = 10;
localparam TAPS = 20; // Example TAPS
localparam DATA_WIDTH = 32;

logic clock = 1'b1;
logic reset = '0;

logic x_real_in_rd_en;
logic x_imag_in_rd_en;
logic x_real_in_full;
logic x_imag_in_full;
logic x_real_in_empty;
logic x_imag_in_empty;
logic signed [DATA_WIDTH-1:0] x_real_in;
logic signed [DATA_WIDTH-1:0] x_imag_in;

logic y_real_out_wr_en;
logic y_imag_out_wr_en;
logic y_real_out_full;
logic y_imag_out_full;
logic signed [DATA_WIDTH-1:0] y_real_out;
logic signed [DATA_WIDTH-1:0] y_imag_out;

logic x_real_in_wr_en = '0;
logic x_imag_in_wr_en = '0;
logic y_real_out_rd_en;
logic y_imag_out_rd_en;
logic y_real_out_empty;
logic y_imag_out_empty;

logic signed [DATA_WIDTH-1:0] x_real_in_dout;
logic signed [DATA_WIDTH-1:0] x_imag_in_dout;
logic signed [DATA_WIDTH-1:0] y_real_out_dout;
logic signed [DATA_WIDTH-1:0] y_imag_out_dout;

logic in_write_done = '0;
logic out_read_done = '0;
integer out_real_errors = '0;
integer out_imag_errors = '0;

parameter logic signed [0:TAPS-1][DATA_WIDTH-1:0] h_real = '{20{32'h0}}; // Example coefficients (all 0)
parameter logic signed [0:TAPS-1][DATA_WIDTH-1:0] h_imag = '{20{32'h0}}; // Example coefficients (all 0)

fifo #(
    .FIFO_BUFFER_SIZE(512),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) x_real_in_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(x_real_in_wr_en),
    .din(x_real_in),
    .full(x_real_in_full),
    .rd_clk(clock),
    .rd_en(x_real_in_rd_en),
    .dout(x_real_in_dout),
    .empty(x_real_in_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(512),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) x_imag_in_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(x_imag_in_wr_en),
    .din(x_imag_in),
    .full(x_imag_in_full),
    .rd_clk(clock),
    .rd_en(x_imag_in_rd_en),
    .dout(x_imag_in_dout),
    .empty(x_imag_in_empty)
);

fir_cmplx #(
    .TAPS(TAPS),
    .h_real(h_real),
    .h_imag(h_imag),
    .DATA_WIDTH(DATA_WIDTH)
) fir_cmplx_inst (
    .clk(clock),
    .rst(reset),
    .x_real_rd_en(x_real_in_rd_en),
    .x_imag_rd_en(x_imag_in_rd_en),
    .x_real_empty(x_real_in_empty),
    .x_imag_empty(x_imag_in_empty),
    .x_real_in(x_real_in_dout),
    .x_imag_in(x_imag_in_dout),
    .y_real_out(y_real_out),
    .y_imag_out(y_imag_out),
    .y_real_wr_en(y_real_out_wr_en),
    .y_imag_wr_en(y_imag_out_wr_en),
    .y_real_full(y_real_out_full),
    .y_imag_full(y_imag_out_full)
);

fifo #(
    .FIFO_BUFFER_SIZE(512),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) y_real_out_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(y_real_out_wr_en),
    .din(y_real_out),
    .full(y_real_out_full),
    .rd_clk(clock),
    .rd_en(y_real_out_rd_en),
    .dout(y_real_out_dout),
    .empty(y_real_out_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(512),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) y_imag_out_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(y_imag_out_wr_en),
    .din(y_imag_out),
    .full(y_imag_out_full),
    .rd_clk(clock),
    .rd_en(y_imag_out_rd_en),
    .dout(y_imag_out_dout),
    .empty(y_imag_out_empty)
);

always begin
    clock = 1'b1;
    #(CLOCK_PERIOD/2);
    clock = 1'b0;
    #(CLOCK_PERIOD/2);
end

initial begin
    @(posedge clock);
    reset = 1'b1;
    @(posedge clock);
    reset = 1'b0;
end

always begin
    @(posedge clock);
    #1000000;
    @(posedge clock);
    $finish;
end

initial begin : tb_process
    longint unsigned start_time, end_time;

    @(negedge reset);
    @(posedge clock);
    start_time = $time;
    
    $display("@ %0t: Beginning simulation...", start_time);

    wait(out_read_done);
    end_time = $time;
    
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    $display("Total real error count: %0d", out_real_errors);
    $display("Total imaginary error count: %0d", out_imag_errors);

    $finish;
end

initial begin : write_fir_data
    int r;
    int x_real_file, x_imag_file;

    @(negedge reset);
    $display("@ %0t: Loading in file %s...", $time, X_REAL_IN_FILE);
    x_real_file = $fopen(X_REAL_IN_FILE, "r");
    if (x_real_file == 0) begin
        $display("Error: Could not open file %s", X_REAL_IN_FILE);
        $finish;
    end

    $display("@ %0t: Loading in file %s...", $time, X_IMAG_IN_FILE);
    x_imag_file = $fopen(X_IMAG_IN_FILE, "r");
    if (x_imag_file == 0) begin
        $display("Error: Could not open file %s", X_IMAG_IN_FILE);
        $finish;
    end

    while (!$feof(x_real_file) && !$feof(x_imag_file)) begin
        @(negedge clock);
        x_real_in_wr_en = 1'b0;
        x_imag_in_wr_en = 1'b0;
        if(!x_real_in_full && !x_imag_in_full) begin
            r = $fscanf(x_real_file, "%d\n", x_real_in);
            r = $fscanf(x_imag_file, "%d\n", x_imag_in);
            x_real_in_wr_en = 1'b1;
            x_imag_in_wr_en = 1'b1;
        end
    end
    
    @(negedge clock);
    $fclose(x_real_file);
    $fclose(x_imag_file);
    in_write_done = 1'b1;
    $display("input done");
end

initial begin : cmp_write_fir_data
    int r;
    int real_out_file, imag_out_file;
    int real_cmp_file, imag_cmp_file;
    int real_cmp_value, imag_cmp_value;
    int real_y_value, imag_y_value;

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, Y_REAL_OUT_FILE);
    real_out_file = $fopen(Y_REAL_OUT_FILE, "w");
    real_cmp_file = $fopen(Y_REAL_CMP_FILE, "r");
    y_real_out_rd_en = 1'b0;

    $display("@ %0t: Comparing file %s...", $time, Y_IMAG_OUT_FILE);
    imag_out_file = $fopen(Y_IMAG_OUT_FILE, "w");
    imag_cmp_file = $fopen(Y_IMAG_CMP_FILE, "r");
    y_imag_out_rd_en = 1'b0;

    while (!$feof(real_cmp_file) && !$feof(imag_cmp_file)) begin
        @(negedge clock);
        y_real_out_rd_en = 1'b0;
        y_imag_out_rd_en = 1'b0;

        if (y_real_out_empty == 1'b0 && y_imag_out_empty == 1'b0) begin
            y_real_out_rd_en = 1'b1;
            y_imag_out_rd_en = 1'b1;
            r = $fscanf(real_cmp_file, "%d\n", real_cmp_value);
            r = $fscanf(imag_cmp_file, "%d\n", imag_cmp_value);
            real_y_value = y_real_out_dout;
            imag_y_value = y_imag_out_dout;
            $fwrite(real_out_file, "%d\n", real_y_value);
            $fwrite(imag_out_file, "%d\n", imag_y_value);
            if (real_y_value != real_cmp_value) begin
                out_real_errors += 1;
                $display("@ %0t: ERROR: Real Mismatch: Expected %d, Got %d", $time, real_cmp_value, real_y_value);
            end
            if (imag_y_value != imag_cmp_value) begin
                out_imag_errors += 1;
                $display("@ %0t: ERROR: Imag Mismatch: Expected %d, Got %d", $time, imag_cmp_value, imag_y_value);
            end
        end
    end
    y_real_out_rd_en = 1'b0;
    y_imag_out_rd_en = 1'b0;
    @(negedge clock);
    $fclose(real_out_file);
    $fclose(imag_out_file);
    $fclose(real_cmp_file);
    $fclose(imag_cmp_file);
    out_read_done = 1'b1;
    $display("checker + writer done");
end

endmodule