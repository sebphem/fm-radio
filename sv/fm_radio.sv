module fm_radio (
    input  logic         clock,
    input  logic         reset,

    output logic         iq_sample_rd_en,      
    input  logic         iq_sample_empty,      
    input  logic signed [31:0] iq_sample,

    output logic         left_audio_out_wr_en,     
    input  logic         left_audio_out_full,       
    output logic signed [31:0] left_audio_out,
    
    output logic         right_audio_out_wr_en,
    input  logic         right_audio_out_full,
    output logic signed [31:0] right_audio_out
);

    logic signed [31:0] read_iq_out_i;
    logic signed [31:0] read_iq_out_q;
    logic read_iq_out_i_full;
    logic read_iq_out_q_full;
    logic read_iq_out_i_empty;
    logic read_iq_out_q_empty;
    logic read_iq_out_i_wr_en;
    logic read_iq_out_q_wr_en;
    logic read_iq_out_i_rd_en;
    logic read_iq_out_q_rd_en;

    logic signed [31:0] iq_sample_i;
    logic signed [31:0] iq_sample_q;

    fifo#(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(32)
    ) i_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(read_iq_out_i_wr_en),
        .din(read_iq_out_i),
        .full(read_iq_out_i_full),
        .rd_clk(clock),
        .rd_en(read_iq_out_i_rd_en),
        .dout(iq_sample_i),
        .empty(read_iq_out_i_empty)
    );

    fifo#(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(32)
    ) q_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(read_iq_out_q_wr_en),
        .din(read_iq_out_q),
        .full(read_iq_out_q_full),
        .rd_clk(clock),
        .rd_en(read_iq_out_q_rd_en),
        .dout(iq_sample_q),
        .empty(read_iq_out_q_empty)
    );
    read_iq read_iq_inst (
        .clock(clock),
        .reset(reset),

        .inA_rd_en(iq_sample_rd_en),      
        .inA_empty(iq_sample_empty),      
        .inA_dout(iq_sample),

        .out_wr_en(read_iq_out_i_wr_en),     
        .out_full(read_iq_out_i_full),       
        .out_din(read_iq_out_i),  

        .out_wr_en_2(read_iq_out_q_wr_en),     
        .out_full_2(read_iq_out_q_full),       
        .out_din_2(read_iq_out_q)
    );
    
endmodule;