
`timescale 1 ns / 1 ns

module fm_radio_tb;

localparam string A_IN  = "../a.bin";
localparam string CMP_IN = "../cmpL.bin";
localparam string CMP_IN2 = "../cmpR.bin";
localparam string OUT_NAME = "../outL.bin";
localparam string OUT_NAME2 = "../outR.bin";

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
/*module fm_radio (
    input  logic         clock,
    input  logic         reset,

    input logic         iq_sample_wr_en,      
    input  logic [31:0]        iq_sample,      
    output logic          iq_sample_full,

    input  logic         left_audio_out_rd_en,    
    output logic          left_audio_out_empty,   
    output logic signed [31:0] left_audio_out,
    
    input  logic         right_audio_out_rd_en,
    output  logic         right_audio_out_empty,
    output logic signed [31:0] right_audio_out
);*/

logic fm_radio_in_wr_en = '0;
logic [31:0] fm_radio_in_din = '0;
logic fm_radio_in_full;

logic fm_radio_out_left_rd_en = '0;
logic fm_radio_out_left_empty;
logic signed [31:0] fm_radio_out_left;

logic fm_radio_out_right_rd_en = '0;
logic fm_radio_out_right_empty;
logic signed [31:0] fm_radio_out_right;

fm_radio fm_radio_inst (
    .clock(clock),
    .reset(reset),
    .iq_sample_wr_en(fm_radio_in_wr_en),
    .iq_sample(fm_radio_in_din),
    .iq_sample_full(fm_radio_in_full),
    .left_audio_out_rd_en(fm_radio_out_left_rd_en),
    .left_audio_out_empty(fm_radio_out_left_empty),
    .left_audio_out(fm_radio_out_left),
    .right_audio_out_rd_en(fm_radio_out_right_rd_en),
    .right_audio_out_empty(fm_radio_out_right_empty),
    .right_audio_out(fm_radio_out_right)
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
        fm_radio_in_wr_en = 1'b0;
        if(!fm_radio_in_full) begin
            r = $fread(fm_radio_in_din, a_file, i*4, 4);
            fm_radio_in_wr_en = 1'b1;
            i++;
        end
    end

    @(negedge clock);
    fm_radio_in_wr_en = 1'b0;
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
    fm_radio_out_left_rd_en = 1'b0;
    fm_radio_out_right_rd_en = 1'b0;

    i = 0;
    while (!$feof(cmp_file) && !$feof(cmp_file2)) begin
        @(negedge clock);
        fm_radio_out_left_rd_en = 1'b0;
        fm_radio_out_right_rd_en = 1'b0;
        // Read from the sum FIFO if it's not empty
        if (fm_radio_out_left_empty == 1'b0 && fm_radio_out_right_empty == 1'b0) begin
            fm_radio_out_left_rd_en = 1'b1;
            fm_radio_out_right_rd_en = 1'b1;
            r = $fread(cmp_value, cmp_file, i*4, 4);
            r = $fread(cmp_value2, cmp_file2, i*4, 4);
            sum_value2 = fm_radio_out_right;
            sum_value = fm_radio_out_left;
            $fwrite(out_file, "%c", sum_value); 
            $fwrite(out_file2, "%c", sum_value2);
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
    fm_radio_out_left_rd_en = 1'b0;
    fm_radio_out_right_rd_en = 1'b0;
    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    $fclose(out_file2);
    $fclose(cmp_file2);
    out_read_done = 1'b1;
end

endmodule
