import uvm_pkg::*;

interface my_uvm_if;
    logic         clock;
    logic         reset;

    logic         iq_sample_wr_en;
    logic [31:0]  iq_sample;
    logic         iq_sample_full;

    logic         left_audio_out_rd_en;
    logic         left_audio_out_empty;
    logic signed [31:0]  left_audio_out; // signed should follow [31:0]

    logic         right_audio_out_rd_en;
    logic         right_audio_out_empty;
    logic signed [31:0]  right_audio_out; // signed should follow [31:0]
endinterface
