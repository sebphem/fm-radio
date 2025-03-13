`timescale 1 ns / 1 ns

module fir_tb;

localparam string X_IN     = "../x.txt";
localparam string CMP_IN   = "../cmp.txt";
localparam string OUT_NAME = "../out.txt";

localparam CLOCK_PERIOD = 10;
localparam DECIMATION = 2;
localparam TAPS = 32;
localparam DATA_WIDTH = 32;

logic clock = 1'b1;
logic reset = '0;

logic x_in_rd_en;
logic x_in_full;
logic x_in_empty;
logic signed [DATA_WIDTH-1:0] x_in;

logic signed [DATA_WIDTH-1:0] y_out;
logic y_out_wr_en;
logic y_out_full;

logic x_in_wr_en = '0;
logic y_out_rd_en;
logic y_out_empty;

logic signed [DATA_WIDTH-1:0] x_in_dout;
logic signed [DATA_WIDTH-1:0] y_out_dout;

logic in_write_done = '0;
logic out_read_done = '0;
integer out_errors = '0;

logic signed [0:TAPS][DATA_WIDTH-1:0] coeff = '{
    32'hFFFFFFFD, 32'hFFFFFFFA, 32'hFFFFFF4, 32'hFFFFFFED, 32'hFFFFFFE5, 32'hFFFFFFDF, 32'hFFFFFFE2, 32'hFFFFFF93,
    32'h00000015, 32'h0000004E, 32'h0000009B, 32'h000000F9, 32'h0000015D, 32'h000001BE, 32'h0000020E, 32'h00000243,
    32'h00000243, 32'h0000020E, 32'h000001BE, 32'h0000015D, 32'h000000F9, 32'h0000009B, 32'h0000004E, 32'h00000015,
    32'hFFFFFF93, 32'hFFFFFFE2, 32'hFFFFFFDF, 32'hFFFFFFE5, 32'hFFFFFFED, 32'hFFFFFF4, 32'hFFFFFFFA, 32'hFFFFFFFD
};

fifo #(
    .FIFO_BUFFER_SIZE(512),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) x_in_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(x_in_wr_en),
    .din(x_in),
    .full(x_in_full),
    .rd_clk(clock),
    .rd_en(x_in_rd_en),
    .dout(x_in_dout),
    .empty(x_in_empty)
);

fir #(
    .DECIMATION(DECIMATION),
    .TAPS(TAPS),
    .coeff(coeff),
    .DATA_WIDTH(DATA_WIDTH)
) fir_inst (
    .clk(clock),
    .rst_n(~reset),
    .x_in_rd_en(x_in_rd_en),
    .x_in_empty(x_in_empty),
    .x_in(x_in_dout),
    .valid_out(), // not used in this testbench
    .y_out(y_out),
    .y_out_wr_en(y_out_wr_en),
    .y_out_full(y_out_full)
);

fifo #(
    .FIFO_BUFFER_SIZE(512),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) y_out_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(y_out_wr_en),
    .din(y_out),
    .full(y_out_full),
    .rd_clk(clock),
    .rd_en(y_out_rd_en),
    .dout(y_out_dout),
    .empty(y_out_empty)
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
    #100000;
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
    $display("Total error count: %0d", out_errors);

    $finish;
end

initial begin : write_fir_data
    int r;
    int x_file;

    @(negedge reset);
    $display("@ %0t: Loading in file %s...", $time, X_IN);
    x_file = $fopen(X_IN, "r");
    if (x_file == 0) begin
        $display("Error: Could not open file %s", X_IN);
        $finish;
    end

    while (!$feof(x_file)) begin
        r = $fscanf(x_file, "%d\n", x_in);
        while (x_in_full) begin
            @(posedge clock);
        end
        x_in_wr_en = 1'b1;
        @(posedge clock);
        x_in_wr_en = 1'b0;
    end
    
    @(negedge clock);
    $fclose(x_file);
    in_write_done = 1'b1;
    $display("input done");
end

initial begin : cmp_write_fir_data
    int r;
    int out_file;
    int cmp_file;
    int cmp_value;
    int y_value;

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, OUT_NAME);
    out_file = $fopen(OUT_NAME, "w");
    cmp_file = $fopen(CMP_IN, "r");
    y_out_rd_en = 1'b0;

    while (!$feof(cmp_file)) begin
        @(negedge clock);
        y_out_rd_en = 1'b0;

        if (y_out_empty == 1'b0) begin
            y_out_rd_en = 1'b1;
            r = $fscanf(cmp_file, "%d\n", cmp_value);
            y_value = y_out_dout;
            $fwrite(out_file, "%d\n", y_value); 
            if (y_value != cmp_value) begin
                out_errors += 1;
                $display("@ %0t: ERROR: Mismatch: Expected %d, Got %d", $time, cmp_value, y_value);
            end
        end
    end
    y_out_rd_en = 1'b0;
    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    out_read_done = 1'b1;
    $display("checker + writer done");
end

endmodule