
`timescale 1 ns / 1 ns

module divide_tb;

localparam string A_IN  = "../a.txt";
localparam string B_IN = "../b.txt";
localparam string CMP_IN = "../cmp.txt";
localparam string OUT_NAME = "../out.txt";

localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

logic        in_wr_en  = '0;
logic [23:0] in_din    = '0;
logic        out_rd_en;
logic        out_empty;
logic  [7:0] out_dout;

logic   hold_clock    = '0;
logic   in_write_done = '0;
logic   out_read_done = '0;
integer out_errors    = '0;

logic signed [31:0] a_in;
logic signed [31:0] b_in;
logic signed [31:0] sum_in;
 
logic a_in_wr_en = '0;
logic b_in_wr_en = '0;
logic sum_in_wr_en;

logic a_in_full;
logic b_in_full;
logic sum_in_full;

logic a_in_rd_en;
logic b_in_rd_en;
logic sum_in_rd_en;

logic signed [31:0] a_in_dout;
logic signed [31:0] b_in_dout;
logic signed [31:0] sum_in_dout;

logic a_in_empty;
logic b_in_empty;
logic sum_in_empty;

logic in_full;
assign in_full = a_in_full || b_in_full;

fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(32)
) a_in_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(a_in_wr_en),
    .din(a_in),
    .full(a_in_full),
    .rd_clk(clock),
    .rd_en(a_in_rd_en),
    .dout(a_in_dout),
    .empty(a_in_empty)
);

fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(32)
) b_in_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(b_in_wr_en),
    .din(b_in),
    .full(b_in_full),
    .rd_clk(clock),
    .rd_en(b_in_rd_en),
    .dout(b_in_dout),
    .empty(b_in_empty)
);

divide_two_inputs divide_inst (
    .clock(clock),
    .reset(reset),
    .inA_rd_en(a_in_rd_en),
    .inA_empty(a_in_empty),
    .inA_dout(a_in_dout),
    .inB_rd_en(b_in_rd_en),
    .inB_empty(b_in_empty),
    .inB_dout(b_in_dout),
    .out_wr_en(sum_in_wr_en),
    .out_full(sum_in_full),
    .out_din(sum_in)
);

fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(32)
) sum_in_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(sum_in_wr_en),
    .din(sum_in),
    .full(sum_in_full),
    .rd_clk(clock),
    .rd_en(sum_in_rd_en),
    .dout(sum_in_dout),
    .empty(sum_in_empty)
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

initial begin : tb_process
    longint unsigned start_time, end_time;

    @(negedge reset);
    @(posedge clock);
    start_time = $time;

    // start
    $display("@ %0t: Beginning simulation...", start_time);
    start = 1'b1;
    @(posedge clock);
    start = 1'b0;

    wait(out_read_done);
    end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    $display("Total error count: %0d", out_errors);

    // end the simulation
    $finish;
end

initial begin : img_read_process
    int i, r;
    int a_file, b_file;

    @(negedge reset);
    $display("@ %0t: Loading in file %s...", $time, A_IN);
    a_file = $fopen(A_IN, "r");
    if (a_file == 0) begin
        $display("Error: Could not open file %s", A_IN);
        $finish;
    end

    $display("@ %0t: Loading in file %s...", $time, B_IN);
    b_file = $fopen(B_IN, "r");
    if (b_file == 0) begin
        $display("Error: Could not open file %s", B_IN);
        $finish;
    end

    // Read A and B line by line until EOF (1 integer each line)
    // and write to the FIFOs
    while (!$feof(a_file) && !$feof(b_file)) begin
        r = $fscanf(a_file, "%d\n", a_in);
        r = $fscanf(b_file, "%d\n", b_in);

        while (a_in_full || b_in_full) begin
            @(posedge clock);
        end

        a_in_wr_en = 1'b1;
        b_in_wr_en = 1'b1;
        a_in = a_in;
        b_in = b_in;
        @(posedge clock);
        a_in_wr_en = 1'b0;
        b_in_wr_en = 1'b0;
    end

    @(negedge clock);
    in_wr_en = 1'b0;
    $fclose(a_file);
    $fclose(b_file);
    in_write_done = 1'b1;
end

initial begin : img_write_process
    int i, r;
    int out_file;
    int cmp_file;
    int cmp_value;
    int sum_value;

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, OUT_NAME);
    
    out_file = $fopen(OUT_NAME, "w");
    cmp_file = $fopen(CMP_IN, "r");
    sum_in_rd_en = 1'b0;

    i = 0;
    while (!$feof(cmp_file)) begin
        @(negedge clock);
        sum_in_rd_en = 1'b0;

        // Read from the sum FIFO if it's not empty
        if (sum_in_empty == 1'b0) begin
            sum_in_rd_en = 1'b1;
            r = $fscanf(cmp_file, "%d\n", cmp_value);
            sum_value = sum_in_dout;
            $fwrite(out_file, "%d\n", sum_value); 
            if (sum_value != cmp_value) begin
                out_errors += 1;
                $display("@ %0t: ERROR: Mismatch at line %0d: Expected %d, Got %d", $time, i+1, cmp_value, sum_value);
            end
            i += 1;
        end
    end
    sum_in_rd_en = 1'b0;
    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    out_read_done = 1'b1;
end

endmodule
