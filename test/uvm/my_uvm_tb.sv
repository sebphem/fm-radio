import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

my_uvm_if vif();

   fm_radio fm_radio_instance (
    .clock(vif.clock),
    .reset(vif.reset),
    .iq_sample_wr_en(vif.),
    .iq_sample(iq_sample),
    .iq_sample_full(iq_sample_full),
    .left_audio_out_rd_en(left_audio_out_rd_en),
    .left_audio_out_empty(left_audio_out_empty),
    .left_audio_out(left_audio_out),
    .right_audio_out_rd_en(right_audio_out_rd_en),
    .right_audio_out_empty(right_audio_out_empty),
    .right_audio_out(right_audio_out)
  );

    initial begin
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));

        run_test("my_uvm_test");
    end

    // reset
    initial begin
        vif.clock <= 1'b1;
        vif.reset <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // 10ns clock
    always
        #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;
endmodule






