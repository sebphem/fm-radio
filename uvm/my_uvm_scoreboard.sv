//changes due to new transaction data from the sequencer
import uvm_pkg::*;

`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export #(output_uvm_transaction) sb_export_output;
    uvm_analysis_export #(output_uvm_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo #(output_uvm_transaction) output_fifo;
    uvm_tlm_analysis_fifo #(output_uvm_transaction) compare_fifo;

    output_uvm_transaction tx_out;
    output_uvm_transaction tx_cmp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out    = new("tx_out");
        tx_cmp = new("tx_cmp");
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sb_export_output    = new("sb_export_output", this);
        sb_export_compare   = new("sb_export_compare", this);

           output_fifo        = new("output_fifo", this);
        compare_fifo    = new("compare_fifo", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run();
        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);
            comparison();
        end
    endtask: run
    int left_line = 0;
    int right_line = 0;
    virtual function void comparison();
        
        if (tx_out.l_out != tx_cmp.l_out) begin
            left_line += 1;
            `uvm_info("SB_CMP", tx_out.sprint(), UVM_LOW);
            `uvm_info("SB_CMP", tx_cmp.sprint(), UVM_LOW);
            `uvm_error("SB_CMP", $sformatf("Test Failed on Left Audio\nExpecting: %d, Received: %d", tx_cmp.l_out, tx_out.l_out));
            `uvm_info("SB_CMP", $sformatf("index cmp %d index out %d left line %d tx cmp l+r: %x %x tx out L+r: %x, %x", tx_cmp.index, tx_out.index, left_line, tx_cmp.l_out, tx_cmp.r_out, tx_out.l_out,tx_out.r_out),UVM_LOW);
        end

        if (tx_out.r_out != tx_cmp.r_out) begin
            right_line += 1;
            `uvm_info("SB_CMP", tx_out.sprint(), UVM_LOW);
            `uvm_info("SB_CMP", tx_cmp.sprint(), UVM_LOW);
            `uvm_error("SB_CMP", $sformatf("Test Failed on Right Audio\nExpecting: %d, Received: %d", tx_cmp.r_out, tx_out.r_out));
            `uvm_info("SB_CMP", $sformatf("index cmp %d index out %d right line %d tx cmp l+r: %x %x tx out L+r: %x, %x", tx_cmp.index, tx_out.index, right_line, tx_cmp.l_out, tx_cmp.r_out, tx_out.l_out,tx_out.r_out),UVM_LOW);
        end
    endfunction: comparison
endclass: my_uvm_scoreboard
