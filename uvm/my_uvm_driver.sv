//significant changes because of what sequencer is now sending
import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(input_uvm_transaction);

    `uvm_component_utils(my_uvm_driver)

    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        drive();
    endtask: run_phase

   virtual task drive();
        input_uvm_transaction tx;

        @(posedge vif.reset)
        @(negedge vif.reset)

        vif.iq_sample = 32'b0;
        vif.iq_sample_wr_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.iq_sample_full == 1'b0) begin
                    seq_item_port.get_next_item(tx);
                    vif.iq_sample = tx.iq;
                    vif.iq_sample_wr_en = 1'b1;
                    seq_item_port.item_done();
                end else begin
                    vif.iq_sample_wr_en = 1'b0;
                    vif.iq_sample = 32'b0;
                end
            end
        end
    endtask: drive

endclass
