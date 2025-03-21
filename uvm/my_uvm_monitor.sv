import uvm_pkg::*;

class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(output_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int l_audio_out_file, r_audio_out_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        l_audio_out_file = $fopen(LEFT_AUDIO_FILE, "w");
        if ( !l_audio_out_file ) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", LEFT_AUDIO_FILE));
        end

        r_audio_out_file = $fopen(RIGHT_AUDIO_FILE, "w");
        if ( !r_audio_out_file ) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", RIGHT_AUDIO_FILE));
        end
    endfunction: build_phase
    int sum_value;
    int i =0;
    int sum_value2;
    virtual task run_phase(uvm_phase phase);
        output_uvm_transaction tx_out;

        @(posedge vif.reset)
        @(negedge vif.reset)
  
        vif.right_audio_out_rd_en = 1'b0;
        vif.left_audio_out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            vif.right_audio_out_rd_en = 1'b0;
            vif.left_audio_out_rd_en = 1'b0;
            begin
                if ((vif.right_audio_out_empty == 1'b0) && (vif.left_audio_out_empty == 1'b0)) begin
                    tx_out = output_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));
                    tx_out.index = ++i;
                    vif.right_audio_out_rd_en = 1'b1;
                    vif.left_audio_out_rd_en = 1'b1;
                    sum_value = vif.left_audio_out;
                    sum_value2 = vif.right_audio_out;
                    $fwrite(l_audio_out_file, "%0d\n", sum_value);
                    tx_out.l_out = sum_value;
                    $fwrite(r_audio_out_file, "%0d\n", sum_value2);
                    tx_out.r_out = sum_value2;
                    mon_ap_output.write(tx_out);
                end 
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", LEFT_AUDIO_FILE), UVM_LOW);
        `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", RIGHT_AUDIO_FILE), UVM_LOW);

        $fclose(l_audio_out_file);
        $fclose(r_audio_out_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(output_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int l_cmp_file, r_cmp_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        l_cmp_file = $fopen(LEFT_CMP_FILE, "r");
        if ( !l_cmp_file ) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", LEFT_CMP_FILE));
        end

        r_cmp_file = $fopen(RIGHT_CMP_FILE, "r");
        if ( !r_cmp_file ) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", RIGHT_CMP_FILE));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int n_bytes=0, i=0;
        logic signed [31:0] d_l, d_r;
        output_uvm_transaction tx_cmp;

        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));
        phase.raise_objection(.obj(this));
        @(posedge vif.reset)
        @(negedge vif.reset)

        //decimates 7 inputs out of 8
        while (!$feof(l_cmp_file) && !$feof(r_cmp_file)) begin
            @(negedge vif.clock)
            begin
                tx_cmp = output_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));
                n_bytes= $fscanf(l_cmp_file, "%0d\n", d_l); 
                tx_cmp.l_out = d_l;
                n_bytes= $fscanf(r_cmp_file, "%0d\n", d_r);
                tx_cmp.r_out = d_r;
                tx_cmp.index = ++i;
                mon_ap_compare.write(tx_cmp);
            end
        end
        `uvm_info("MON_CMP_FINAL", $sformatf("Done writing file to buffer"), UVM_LOW);

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", LEFT_CMP_FILE), UVM_LOW);
        `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", RIGHT_CMP_FILE), UVM_LOW);

        $fclose(l_cmp_file);
        $fclose(r_cmp_file);

    endfunction: final_phase

endclass: my_uvm_monitor_compare
