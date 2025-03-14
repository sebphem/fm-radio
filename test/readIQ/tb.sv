
`timescale 1 ns / 1 ns

module read_iq_tb;

localparam string A_IN  = "../a.bin";
localparam string CMP_IN = "../cmpI.txt";
localparam string CMP_IN2 = "../cmpQ.txt";
localparam string OUT_NAME = "../outI.txt";
localparam string OUT_NAME2 = "../outQ.txt";

localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

logic        in_wr_en  = '0;
logic [23:0] in_din    = '0;

logic   hold_clock    = '0;
logic   in_write_done = '0;
logic   out_read_done = '0;
integer out_errors    = '0;

logic [31:0] a_in;
logic signed [31:0] sum_in;
logic signed [31:0] sum_in2;
 
logic a_in_wr_en = '0;
logic sum_in_wr_en;
logic sum_in_wr_en2;

logic a_in_full;
logic sum_in_full;
logic sum_in_full2;

logic a_in_rd_en;
logic sum_in_rd_en;
logic sum_in_rd_en2;

logic [31:0] a_in_dout;
logic signed [31:0] sum_in_dout;
logic signed [31:0] sum_in_dout2;

logic a_in_empty;
logic sum_in_empty;
logic sum_in_empty2;


logic in_full;
assign in_full = a_in_full;

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

read_iq read_iq_inst (
    .clock(clock),
    .reset(reset),
    .inA_rd_en(a_in_rd_en),
    .inA_empty(a_in_empty),
    .inA_dout(a_in_dout),
    .out_wr_en(sum_in_wr_en),
    .out_full(sum_in_full),
    .out_din(sum_in),
    .out_wr_en_2(sum_in_wr_en2),
    .out_full_2(sum_in_full2),
    .out_din_2(sum_in2)
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

fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(32)
) sum_in_fifo2 (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(sum_in_wr_en2),
    .din(sum_in2),
    .full(sum_in_full2),
    .rd_clk(clock),
    .rd_en(sum_in_rd_en2),
    .dout(sum_in_dout2),
    .empty(sum_in_empty2)
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

    // Read A and B line by line until EOF (1 integer each line)
    // and write to the FIFOs
    i = 0;
    while (!$feof(a_file)) begin
        @(negedge clock);
        a_in_wr_en = 1'b0;
        if(!a_in_full) begin
            r = $fread(a_in, a_file, i*4, 4);
            a_in_wr_en = 1'b1;
            i++;
        end
    end

    @(negedge clock);
    in_wr_en = 1'b0;
    $fclose(a_file);
    in_write_done = 1'b1;
end

initial begin : img_write_process
    int i, r;
    int out_file;
    int out_file2;
    int cmp_file;
    int cmp_file2;
    int cmp_value;
    int cmp_value2;
    int sum_value;
    int sum_value2;

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, OUT_NAME);
    
    out_file = $fopen(OUT_NAME, "w");
    out_file2 = $fopen(OUT_NAME2, "w");
    cmp_file = $fopen(CMP_IN, "r");
    cmp_file2 = $fopen(CMP_IN2, "r");
    sum_in_rd_en = 1'b0;
    sum_in_rd_en2 = 1'b0;

    i = 0;
    while (!$feof(cmp_file)) begin
        @(negedge clock);
        sum_in_rd_en = 1'b0;
        sum_in_rd_en2 = 1'b0;
        // Read from the sum FIFO if it's not empty
        if (sum_in_empty == 1'b0 && sum_in_empty2 == 1'b0) begin
            sum_in_rd_en = 1'b1;
            sum_in_rd_en2 = 1'b1;
            r = $fscanf(cmp_file, "%d\n", cmp_value);
            r = $fscanf(cmp_file2, "%d\n", cmp_value2);
            sum_value2 = sum_in_dout2;
            sum_value = sum_in_dout;
            $fwrite(out_file, "%d\n", sum_value); 
            $fwrite(out_file2, "%d\n", sum_value2);
            if (sum_value != cmp_value) begin
                out_errors += 1;
                $display("@ %0t: ERROR: Mismatch at line %0d: Expected %d, Got %d", $time, i+1, cmp_value, sum_value);
            end
            if (sum_value2 != cmp_value2) begin
                out_errors += 1;
                $display("@ %0t: ERROR: Mismatch at line %0d: Expected %d, Got %d", $time, i+1, cmp_value2, sum_value2);
            end
            i += 1;
        end
    end
    sum_in_rd_en = 1'b0;
    sum_in_rd_en2 = 1'b0;
    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    $fclose(out_file2);
    $fclose(cmp_file2);
    out_read_done = 1'b1;
end

endmodule
