`ifndef _FMRADIO_
`define _FMRADIO_

`include "global.sv"
`include "add.sv"
`include "sub.sv"
`include "multiply.sv"
`include "qarctan.sv"
`include "demodulate.sv"
`include "fir.sv"
`include "fir_cmplx.sv"
`include "readIQ.sv"
`include "gain.sv"
`include "iir.sv"

module fm_radio (
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
);

localparam TAPS = 20;
localparam DATA_WIDTH = 32;
parameter logic signed [0:19][DATA_WIDTH-1:0] h_real = '{
	32'h00000001, 32'h00000008, 32'hfffffff3, 32'h00000009, 32'h0000000b, 32'hffffffd3, 32'h00000045, 32'hffffffd3, 
	32'hffffffb1, 32'h00000257, 32'h00000257, 32'hffffffb1, 32'hffffffd3, 32'h00000045, 32'hffffffd3, 32'h0000000b, 
	32'h00000009, 32'hfffffff3, 32'h00000008, 32'h00000001
};

parameter logic signed [0:19][DATA_WIDTH-1:0] h_imag = '{
	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 
	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 
	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000
};
parameter logic signed [0:31] [DATA_WIDTH-1:0] BP_PILOT_COEFFS = '{
    32'h0000000e, 32'h0000001f, 32'h00000034, 32'h00000048, 32'h0000004e, 32'h00000036, 32'hfffffff8, 32'hffffff98, 
    32'hffffff2d, 32'hfffffeda, 32'hfffffec3, 32'hfffffefe, 32'hffffff8a, 32'h0000004a, 32'h0000010f, 32'h000001a1, 
    32'h000001a1, 32'h0000010f, 32'h0000004a, 32'hffffff8a, 32'hfffffefe, 32'hfffffec3, 32'hfffffeda, 32'hffffff2d, 
    32'hffffff98, 32'hfffffff8, 32'h00000036, 32'h0000004e, 32'h00000048, 32'h00000034, 32'h0000001f, 32'h0000000e
};
parameter logic signed [0:31] [DATA_WIDTH-1:0] BP_LMR_COEFFS = '{
    32'h00000000, 32'h00000000, 32'hfffffffc, 32'hfffffff9, 32'hfffffffe, 32'h00000008, 32'h0000000c, 32'h00000002, 
    32'h00000003, 32'h0000001e, 32'h00000030, 32'hfffffffc, 32'hffffff8c, 32'hffffff58, 32'hffffffc3, 32'h0000008a, 
    32'h0000008a, 32'hffffffc3, 32'hffffff58, 32'hffffff8c, 32'hfffffffc, 32'h00000030, 32'h0000001e, 32'h00000003, 
    32'h00000002, 32'h0000000c, 32'h00000008, 32'hfffffffe, 32'hfffffff9, 32'hfffffffc, 32'h00000000, 32'h00000000
};
parameter logic signed [0:31] [DATA_WIDTH-1:0] AUDIO_LMR_COEFFS = '{
    32'hfffffffd, 32'hfffffffa, 32'hfffffff4, 32'hffffffed, 32'hffffffe5, 32'hffffffdf, 32'hffffffe2, 32'hfffffff3, 
    32'h00000015, 32'h0000004e, 32'h0000009b, 32'h000000f9, 32'h0000015d, 32'h000001be, 32'h0000020e, 32'h00000243, 
    32'h00000243, 32'h0000020e, 32'h000001be, 32'h0000015d, 32'h000000f9, 32'h0000009b, 32'h0000004e, 32'h00000015, 
    32'hfffffff3, 32'hffffffe2, 32'hffffffdf, 32'hffffffe5, 32'hffffffed, 32'hfffffff4, 32'hfffffffa, 32'hfffffffd
};
parameter logic signed [0:31] [DATA_WIDTH-1:0] AUDIO_LPR_COEFFS = '{
    32'hfffffffd, 32'hfffffffa, 32'hfffffff4, 32'hffffffed, 32'hffffffe5, 32'hffffffdf, 32'hffffffe2, 32'hfffffff3, 
    32'h00000015, 32'h0000004e, 32'h0000009b, 32'h000000f9, 32'h0000015d, 32'h000001be, 32'h0000020e, 32'h00000243, 
    32'h00000243, 32'h0000020e, 32'h000001be, 32'h0000015d, 32'h000000f9, 32'h0000009b, 32'h0000004e, 32'h00000015, 
    32'hfffffff3, 32'hffffffe2, 32'hffffffdf, 32'hffffffe5, 32'hffffffed, 32'hfffffff4, 32'hfffffffa, 32'hfffffffd
};
parameter logic signed [0:31] [DATA_WIDTH-1:0] HP_COEFFS = '{
    32'hffffffff, 32'h00000000, 32'h00000000, 32'h00000002, 32'h00000004, 32'h00000008, 32'h0000000b, 32'h0000000c, 
    32'h00000008, 32'hffffffff, 32'hffffffee, 32'hffffffd7, 32'hffffffbb, 32'hffffff9f, 32'hffffff87, 32'hffffff76, 
    32'hffffff76, 32'hffffff87, 32'hffffff9f, 32'hffffffbb, 32'hffffffd7, 32'hffffffee, 32'hffffffff, 32'h00000008, 
    32'h0000000c, 32'h0000000b, 32'h00000008, 32'h00000004, 32'h00000002, 32'h00000000, 32'h00000000, 32'hffffffff
};


    logic [31:0] iq_sample_dout;
    logic iq_sample_rd_en;
    logic iq_sample_empty;

    // IQ sample FIFO
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) iq_sample_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(iq_sample_wr_en),
        .din(iq_sample),
        .full(iq_sample_full),
        .rd_clk(clock),
        .rd_en(iq_sample_rd_en),
        .dout(iq_sample_dout),
        .empty(iq_sample_empty)
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
        .FIFO_BUFFER_SIZE(2),
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
        .FIFO_BUFFER_SIZE(2),
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
        .inA_dout(iq_sample_dout),

        .out_wr_en(read_iq_out_i_wr_en),     
        .out_full(read_iq_out_i_full),       
        .out_din(read_iq_out_i),  

        .out_wr_en_2(read_iq_out_q_wr_en),     
        .out_full_2(read_iq_out_q_full),       
        .out_din_2(read_iq_out_q)
    );

    // Next FIR complx 2 int -> 2 int
    // 2 FIFOs for real and imag
    logic signed [31:0] cmplx_fir_out_i;
    logic signed [31:0] cmplx_fir_out_q;
    logic signed [31:0] fir_out_i;
    logic signed [31:0] fir_out_q;
    logic fir_out_i_full;
    logic fir_out_q_full;
    logic fir_out_i_empty;
    logic fir_out_q_empty;
    logic fir_out_i_wr_en;
    logic fir_out_q_wr_en;
    logic fir_out_i_rd_en;
    logic fir_out_q_rd_en;
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) fir_i_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(fir_out_i_wr_en),
        .din(fir_out_i),
        .full(fir_out_i_full),
        .rd_clk(clock),
        .rd_en(fir_out_i_rd_en),
        .dout(cmplx_fir_out_i),
        .empty(fir_out_i_empty)
    );
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) fir_q_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(fir_out_q_wr_en),
        .din(fir_out_q),
        .full(fir_out_q_full),
        .rd_clk(clock),
        .rd_en(fir_out_q_rd_en),
        .dout(cmplx_fir_out_q),
        .empty(fir_out_q_empty)
    );
    fir_cmplx  #(
        .TAPS(TAPS),
        .h_real(h_real),
        .h_imag(h_imag),
        .DATA_WIDTH(DATA_WIDTH)
    ) fir_cmplx_inst(
        .clk(clock),
        .rst(reset),
        .x_real_rd_en(read_iq_out_i_rd_en),
        .x_imag_rd_en(read_iq_out_q_rd_en),
        .x_real_empty(read_iq_out_i_empty),
        .x_imag_empty(read_iq_out_q_empty),
        .x_real_in(iq_sample_i),
        .x_imag_in(iq_sample_q),
        .y_real_out(fir_out_i),
        .y_imag_out(fir_out_q),
        .y_real_wr_en(fir_out_i_wr_en),
        .y_imag_wr_en(fir_out_q_wr_en),
        .y_real_full(fir_out_i_full),
        .y_imag_full(fir_out_q_full)
    );

    // Next is Demodulation
    // 2 int32 -> 1 int32 -> 3 int32 (copies)
    logic signed [31:0] demod_out;
    logic demod_out_full;
    logic demod_out_empty;
    logic demod_out_wr_en;

    logic demod_out_full1;
    logic demod_out_empty1;
    logic demod_out_wr_en1;
    logic demod_out_rd_en1;

    logic demod_out_full2;
    logic demod_out_empty2;
    logic demod_out_wr_en2;
    logic demod_out_rd_en2;

    logic demod_out_full3;
    logic demod_out_empty3;
    logic demod_out_wr_en3;
    logic demod_out_rd_en3;

    logic signed [31:0] demod_out_dout1;
    logic signed [31:0] demod_out_dout2;
    logic signed [31:0] demod_out_dout3;

    assign demod_out_wr_en1 = demod_out_wr_en;
    assign demod_out_wr_en2 = demod_out_wr_en;
    assign demod_out_wr_en3 = demod_out_wr_en;

    assign demod_out_empty = demod_out_empty1 && demod_out_empty2 && demod_out_empty3;
    assign demod_out_full = demod_out_full1 || demod_out_full2 || demod_out_full3;
    
    demodulate_two_inputs demodulate_inst (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(fir_out_i_rd_en),
        .inA_empty(fir_out_i_empty),
        .inA_dout(cmplx_fir_out_i),
        .inB_rd_en(fir_out_q_rd_en),
        .inB_empty(fir_out_q_empty),
        .inB_dout(cmplx_fir_out_q),
        .out_wr_en(demod_out_wr_en),
        .out_full(demod_out_full),
        .out_din(demod_out)
    );
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) demod_out_fifo1 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(demod_out_wr_en1),
        .din(demod_out),
        .full(demod_out_full1),
        .rd_clk(clock),
        .rd_en(demod_out_rd_en1),
        .dout(demod_out_dout1),
        .empty(demod_out_empty1)
    );
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) demod_out_fifo2 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(demod_out_wr_en2),
        .din(demod_out),
        .full(demod_out_full2),
        .rd_clk(clock),
        .rd_en(demod_out_rd_en2),
        .dout(demod_out_dout2),
        .empty(demod_out_empty2)
    );
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) demod_out_fifo3 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(demod_out_wr_en3),
        .din(demod_out),
        .full(demod_out_full3),
        .rd_clk(clock),
        .rd_en(demod_out_rd_en3),
        .dout(demod_out_dout3),
        .empty(demod_out_empty3)
    );

    // Next is bp_pilot_fir
    // 1 int32 -> 1 int32 -> 2 int32 (copies)
    // FIFO 3-> bp_pilot
    logic signed [31:0] bp_pilot_out;
    logic bp_pilot_out_full;
    logic bp_pilot_out_empty;
    logic bp_pilot_out_wr_en;
    logic bp_pilot_out_rd_en;

    logic bp_pilot_out_full_1;
    logic bp_pilot_out_empty_1;
    logic bp_pilot_out_wr_en_1;
    logic bp_pilot_out_rd_en_1;

    logic bp_pilot_out_full_2;
    logic bp_pilot_out_empty_2;
    logic bp_pilot_out_wr_en_2;
    logic bp_pilot_out_rd_en_2;

    logic signed [31:0] bp_pilot_out_dout1;
    logic signed [31:0] bp_pilot_out_dout2;

    assign bp_pilot_out_wr_en_1 = bp_pilot_out_wr_en;
    assign bp_pilot_out_wr_en_2 = bp_pilot_out_wr_en;
    assign bp_pilot_out_empty = bp_pilot_out_empty_1 && bp_pilot_out_empty_2;
    assign bp_pilot_out_full = bp_pilot_out_full_1 || bp_pilot_out_full_2;
    fir #(
        .DECIMATION(1),
        .TAPS(32),
        .coeff(BP_PILOT_COEFFS),
        .DATA_WIDTH(DATA_WIDTH)
    ) bp_pilot_fir (
        .clk(clock),
        .rst(reset),
        .x_in_rd_en(demod_out_rd_en3),
        .x_in_empty(demod_out_empty3),
        .x_in(demod_out_dout3),
        .y_out(bp_pilot_out),
        .y_out_wr_en(bp_pilot_out_wr_en),
        .y_out_full(bp_pilot_out_full)
    );
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) bp_pilot_out_fifo1 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(bp_pilot_out_wr_en_1),
        .din(bp_pilot_out),
        .full(bp_pilot_out_full_1),
        .rd_clk(clock),
        .rd_en(bp_pilot_out_rd_en_1),
        .dout(bp_pilot_out_dout1),
        .empty(bp_pilot_out_empty_1)
    );
    fifo#(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) bp_pilot_out_fifo2 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(bp_pilot_out_wr_en_2),
        .din(bp_pilot_out),
        .full(bp_pilot_out_full_2),
        .rd_clk(clock),
        .rd_en(bp_pilot_out_rd_en_2),
        .dout(bp_pilot_out_dout2),
        .empty(bp_pilot_out_empty_2)
    );

    // Take the two inputs multiply
    // 2 int32 -> 1 int32
    logic signed [31:0] multiply_out;
    logic multiply_out_full;
    logic multiply_out_empty;
    logic multiply_out_wr_en;
    logic multiply_out_rd_en;
    logic signed [31:0] multiply_out_dout;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) multiply_out_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(multiply_out_wr_en),
        .din(multiply_out),
        .full(multiply_out_full),
        .rd_clk(clock),
        .rd_en(multiply_out_rd_en),
        .dout(multiply_out_dout),
        .empty(multiply_out_empty)
    );
    multiply_two_inputs multiply_inst (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(bp_pilot_out_rd_en_1),      
        .inA_empty(bp_pilot_out_empty_1),    
        .inA_dout(bp_pilot_out_dout1),

        .inB_rd_en(bp_pilot_out_rd_en_2),
        .inB_empty(bp_pilot_out_empty_2),   
        .inB_dout(bp_pilot_out_dout2),

        .out_wr_en(multiply_out_wr_en),     
        .out_full(multiply_out_full),       
        .out_din(multiply_out)
    );

    // hp_pilot_filter 
    // 1 int32 -> 1 int32

    logic signed [31:0] hp_pilot_out;
    logic hp_pilot_out_full;
    logic hp_pilot_out_empty;
    logic hp_pilot_out_wr_en;
    logic hp_pilot_out_rd_en;
    logic signed [31:0] hp_pilot_out_dout;

    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) hp_pilot_out_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(hp_pilot_out_wr_en),
        .din(hp_pilot_out),
        .full(hp_pilot_out_full),
        .rd_clk(clock),
        .rd_en(hp_pilot_out_rd_en),
        .dout(hp_pilot_out_dout),
        .empty(hp_pilot_out_empty)
    );
    fir #(
        .DECIMATION(1),
        .TAPS(32),
        .coeff(HP_COEFFS),
        .DATA_WIDTH(DATA_WIDTH)
    ) hp_pilot_fir (
        .clk(clock),
        .rst(reset),
        .x_in_rd_en(multiply_out_rd_en),
        .x_in_empty(multiply_out_empty),
        .x_in(multiply_out_dout),
        .y_out(hp_pilot_out),
        .y_out_wr_en(hp_pilot_out_wr_en),
        .y_out_full(hp_pilot_out_full)
    );
    // bp_lmr_filter
    // 1 int32 -> 1 int32
    logic signed [31:0] bp_lmr_out;
    logic bp_lmr_out_full;
    logic bp_lmr_out_empty;
    logic bp_lmr_out_wr_en;
    logic bp_lmr_out_rd_en;
    logic signed [31:0] bp_lmr_out_dout;

    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) bp_lmr_out_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(bp_lmr_out_wr_en),
        .din(bp_lmr_out),
        .full(bp_lmr_out_full),
        .rd_clk(clock),
        .rd_en(bp_lmr_out_rd_en),
        .dout(bp_lmr_out_dout),
        .empty(bp_lmr_out_empty)
    );

    fir #(
        .DECIMATION(1),
        .TAPS(32),
        .coeff(BP_LMR_COEFFS),
        .DATA_WIDTH(DATA_WIDTH)
    ) bp_lmr_fir (
        .clk(clock),
        .rst(reset),
        .x_in_rd_en(demod_out_rd_en1),
        .x_in_empty(demod_out_empty1),
        .x_in(demod_out_dout1),
        .y_out(bp_lmr_out),
        .y_out_wr_en(bp_lmr_out_wr_en),
        .y_out_full(bp_lmr_out_full)
    );

    // multiply hp_pilot and bp_lmr
    // 2 int32 -> 1 int32
    logic signed [31:0] multiply_out2;
    logic multiply_out2_full;
    logic multiply_out2_empty;
    logic multiply_out2_wr_en;
    logic multiply_out2_rd_en;
    logic signed [31:0] multiply_out2_dout;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) multiply_out2_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(multiply_out2_wr_en),
        .din(multiply_out2),
        .full(multiply_out2_full),
        .rd_clk(clock),
        .rd_en(multiply_out2_rd_en),
        .dout(multiply_out2_dout),
        .empty(multiply_out2_empty)
    );
    multiply_two_inputs multiply_inst2 (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(hp_pilot_out_rd_en),      
        .inA_empty(hp_pilot_out_empty),      
        .inA_dout(hp_pilot_out_dout),

        .inB_rd_en(bp_lmr_out_rd_en),      
        .inB_empty(bp_lmr_out_empty),      
        .inB_dout(bp_lmr_out_dout),

        .out_wr_en(multiply_out2_wr_en),     
        .out_full(multiply_out2_full),       
        .out_din(multiply_out2)
    );
    // audio_lmr_filter
    // 1 int32 -> 1 int32 -> 2 int32 (copied)
    logic signed [31:0] audio_lmr_out;
    logic audio_lmr_out_full;
    logic audio_lmr_out_empty;
    logic audio_lmr_out_wr_en;
    logic audio_lmr_out_rd_en;

    logic audio_lmr_out_full1;
    logic audio_lmr_out_empty1;
    logic audio_lmr_out_wr_en1;
    logic audio_lmr_out_rd_en1;
    logic audio_lmr_out_full2;
    logic audio_lmr_out_empty2;
    logic audio_lmr_out_wr_en2;
    logic audio_lmr_out_rd_en2;
    assign audio_lmr_out_wr_en1 = audio_lmr_out_wr_en;
    assign audio_lmr_out_wr_en2 = audio_lmr_out_wr_en;
    assign audio_lmr_out_empty = audio_lmr_out_empty1 && audio_lmr_out_empty2;
    assign audio_lmr_out_full = audio_lmr_out_full1 || audio_lmr_out_full2;

    logic signed [31:0] audio_lmr_out_dout1;
    logic signed [31:0] audio_lmr_out_dout2;

    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) audio_lmr_out_fifo1 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(audio_lmr_out_wr_en1),
        .din(audio_lmr_out),
        .full(audio_lmr_out_full1),
        .rd_clk(clock),
        .rd_en(audio_lmr_out_rd_en1),
        .dout(audio_lmr_out_dout1),
        .empty(audio_lmr_out_empty1)
    );
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) audio_lmr_out_fifo2 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(audio_lmr_out_wr_en2),
        .din(audio_lmr_out),
        .full(audio_lmr_out_full2),
        .rd_clk(clock),
        .rd_en(audio_lmr_out_rd_en2),
        .dout(audio_lmr_out_dout2),
        .empty(audio_lmr_out_empty2)
    );

    fir #(
        .DECIMATION(8),
        .TAPS(32),
        .coeff(AUDIO_LMR_COEFFS),
        .DATA_WIDTH(DATA_WIDTH)
    ) audio_lmr_fir (
        .clk(clock),
        .rst(reset),
        .x_in_rd_en(multiply_out2_rd_en),
        .x_in_empty(multiply_out2_empty),
        .x_in(multiply_out2_dout),
        .y_out_wr_en(audio_lmr_out_wr_en),
        .y_out_full(audio_lmr_out_full),
        .y_out(audio_lmr_out)
    );


    // audio_lpr_filter
    // 1 int32 -> 1 int32 -> 2 int32 (copied)
    logic signed [31:0] audio_lpr_out;
    logic audio_lpr_out_full;
    logic audio_lpr_out_empty;
    logic audio_lpr_out_wr_en;
    logic audio_lpr_out_rd_en;
    logic audio_lpr_out_full1;
    logic audio_lpr_out_empty1;
    logic audio_lpr_out_wr_en1;
    logic audio_lpr_out_rd_en1;
    logic audio_lpr_out_full2;
    logic audio_lpr_out_empty2;
    logic audio_lpr_out_wr_en2;
    logic audio_lpr_out_rd_en2;
    assign audio_lpr_out_wr_en1 = audio_lpr_out_wr_en;
    assign audio_lpr_out_wr_en2 = audio_lpr_out_wr_en;
    assign audio_lpr_out_empty = audio_lpr_out_empty1 && audio_lpr_out_empty2;
    assign audio_lpr_out_full = audio_lpr_out_full1 || audio_lpr_out_full2;
    logic signed [31:0] audio_lpr_out_dout1;
    logic signed [31:0] audio_lpr_out_dout2;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) audio_lpr_out_fifo1 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(audio_lpr_out_wr_en1),
        .din(audio_lpr_out),
        .full(audio_lpr_out_full1),
        .rd_clk(clock),
        .rd_en(audio_lpr_out_rd_en1),
        .dout(audio_lpr_out_dout1),
        .empty(audio_lpr_out_empty1)
    );
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) audio_lpr_out_fifo2 (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(audio_lpr_out_wr_en2),
        .din(audio_lpr_out),
        .full(audio_lpr_out_full2),
        .rd_clk(clock),
        .rd_en(audio_lpr_out_rd_en2),
        .dout(audio_lpr_out_dout2),
        .empty(audio_lpr_out_empty2)
    );

    fir #(
        .DECIMATION(8),
        .TAPS(32),
        .coeff(AUDIO_LPR_COEFFS),
        .DATA_WIDTH(DATA_WIDTH)
    ) audio_lpr_fir (
        .clk(clock),
        .rst(reset),
        .x_in_rd_en(demod_out_rd_en2),
        .x_in_empty(demod_out_empty2),
        .x_in(demod_out_dout2),
        .y_out_wr_en(audio_lpr_out_wr_en),
        .y_out_full(audio_lpr_out_full),
        .y_out(audio_lpr_out)
    );

    // add audio_lpr_filter FIFO 1 and audio_lmr_filter FIFO 1
    // 2 int -> 1 int
    logic signed [31:0] left_audio_filtered;
    logic left_audio_filtered_full;
    logic left_audio_filtered_empty;
    logic left_audio_filtered_wr_en;
    logic left_audio_filtered_rd_en;
    logic signed [31:0] left_audio_filtered_dout;
    

    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) left_audio_filtered_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(left_audio_filtered_wr_en),
        .din(left_audio_filtered_dout),
        .full(left_audio_filtered_full),
        .rd_clk(clock),
        .rd_en(left_audio_filtered_rd_en),
        .dout(left_audio_filtered), 
        .empty(left_audio_filtered_empty)
    );
    add_two_inputs add_inst (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(audio_lpr_out_rd_en1),      
        .inA_empty(audio_lpr_out_empty1),      
        .inA_dout(audio_lpr_out_dout1),

        .inB_rd_en(audio_lmr_out_rd_en1),      
        .inB_empty(audio_lmr_out_empty1),      
        .inB_dout(audio_lmr_out_dout1),

        .out_wr_en(left_audio_filtered_wr_en),     
        .out_full(left_audio_filtered_full),       
        .out_din(left_audio_filtered_dout)
    );
    // Deemphasis on left_audio_filtered_dout
    // 1 int32 -> 1 int32
    logic signed [31:0] deemph_out_left;
    logic deemph_out_left_full;
    logic deemph_out_left_empty;
    logic deemph_out_left_wr_en;
    logic deemph_out_left_rd_en;
    logic signed [31:0] deemph_out_left_dout;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) deemph_out_left_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(deemph_out_left_wr_en),
        .din(deemph_out_left),
        .full(deemph_out_left_full),
        .rd_clk(clock),
        .rd_en(deemph_out_left_rd_en),
        .dout(deemph_out_left_dout), 
        .empty(deemph_out_left_empty)
    );
    iir left_deemphasis (
        .clk(clock),
        .rst(reset),
        .x_in_rd_en(left_audio_filtered_rd_en),      
        .x_in_empty(left_audio_filtered_empty),      
        .x_in(left_audio_filtered),
        .y_out(deemph_out_left),
        .y_out_wr_en(deemph_out_left_wr_en),
        .y_out_full(deemph_out_left_full)
    );

    // sub audio_lpr_filter FIFO 2 and audio_lmr_filter FIFO 2
    // 2 int -> 1 int
    logic signed [31:0] right_audio_filtered;
    logic right_audio_filtered_full;
    logic right_audio_filtered_empty;
    logic right_audio_filtered_wr_en;
    logic right_audio_filtered_rd_en;
    logic signed [31:0] right_audio_filtered_dout;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) right_audio_filtered_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(right_audio_filtered_wr_en),
        .din(right_audio_filtered_dout),
        .full(right_audio_filtered_full),
        .rd_clk(clock),
        .rd_en(right_audio_filtered_rd_en),
        .dout(right_audio_filtered), 
        .empty(right_audio_filtered_empty)
    );
    sub_two_inputs sub_inst (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(audio_lpr_out_rd_en2),      
        .inA_empty(audio_lpr_out_empty2),      
        .inA_dout(audio_lpr_out_dout2),

        .inB_rd_en(audio_lmr_out_rd_en2),      
        .inB_empty(audio_lmr_out_empty2),      
        .inB_dout(audio_lmr_out_dout2),

        .out_wr_en(right_audio_filtered_wr_en),     
        .out_full(right_audio_filtered_full),       
        .out_din(right_audio_filtered_dout)
    );

    // Deemphasis on right_audio_filtered_dout
    // 1 int32 -> 1 int32
    logic signed [31:0] deemph_out_right;
    logic deemph_out_right_full;
    logic deemph_out_right_empty;
    logic deemph_out_right_wr_en;
    logic deemph_out_right_rd_en;
    logic signed [31:0] deemph_out_right_dout;

    iir right_deemphasis (
    .clk(clock),
    .rst(reset),
    .x_in_rd_en(right_audio_filtered_rd_en),
    .x_in_empty(right_audio_filtered_empty),
    .x_in(right_audio_filtered),
    .y_out(deemph_out_right),          // Use a distinct net here
    .y_out_wr_en(deemph_out_right_wr_en),
    .y_out_full(deemph_out_right_full)
    );

    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) deemph_out_right_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(deemph_out_right_wr_en),
    .din(deemph_out_right),            // FIFO input is the IIR output
    .full(deemph_out_right_full),
    .rd_clk(clock),
    .rd_en(deemph_out_right_rd_en),
    .dout(deemph_out_right_dout),      // FIFO output
    .empty(deemph_out_right_empty)
    );
    // Gain on left deemphasized audio
    // 1 int32 -> 1 int32
    logic left_audio_out_full;
    logic left_audio_out_wr_en;
    logic signed [31:0] left_audio_out_dout;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) left_audio_out_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(left_audio_out_wr_en),
        .din(left_audio_out_dout),
        .full(left_audio_out_full),
        .rd_clk(clock),
        .rd_en(left_audio_out_rd_en),
        .dout(left_audio_out), 
        .empty(left_audio_out_empty)
    );

    gain_one_input gain_left (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(deemph_out_left_rd_en),      
        .inA_empty(deemph_out_left_empty),      
        .inA_dout(deemph_out_left_dout),
        .out_wr_en(left_audio_out_wr_en),     
        .out_full(left_audio_out_full),       
        .out_din(left_audio_out_dout)
    );
    // Gain on right deemphasized audio
    // 1 int32 -> 1 int32
    logic right_audio_out_wr_en;
    logic signed [31:0] right_audio_out_dout;
    fifo #(
        .FIFO_BUFFER_SIZE(2),
        .FIFO_DATA_WIDTH(32)
    ) right_audio_out_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(right_audio_out_wr_en),
        .din(right_audio_out_dout),
        .full(right_audio_out_full),
        .rd_clk(clock),
        .rd_en(right_audio_out_rd_en),
        .dout(right_audio_out), 
        .empty(right_audio_out_empty)
    );

    gain_one_input gain_right (
        .clock(clock),
        .reset(reset),
        .inA_rd_en(deemph_out_right_rd_en),      
        .inA_empty(deemph_out_right_empty),      
        .inA_dout(deemph_out_right_dout),
        .out_wr_en(right_audio_out_wr_en),     
        .out_full(right_audio_out_full),       
        .out_din(right_audio_out_dout)
    );
endmodule;
`endif