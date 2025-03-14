import uvm_pkg::*;


class input_uvm_transaction extends uvm_sequence_item;
    logic [31:0] iq;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(input_uvm_transaction)
        `uvm_field_int(iq, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: input_uvm_transaction


class output_uvm_transaction extends uvm_sequence_item;
    int l_out;
    int r_out;
    int index;
    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(output_uvm_transaction)
        `uvm_field_int(l_out, UVM_ALL_ON)
        `uvm_field_int(r_out, UVM_ALL_ON)
        `uvm_field_int(index, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: output_uvm_transaction



class my_uvm_sequence extends uvm_sequence#(input_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        input_uvm_transaction tx;
        int in_file, n_bytes=0, i=0;
        logic [31:0] d_in;

        `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", DATA_IN_NAME), UVM_LOW);

        in_file = $fopen(DATA_IN_NAME, "rb");
        if ( !in_file ) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", DATA_IN_NAME));
        end

        while ( !$feof(in_file) ) begin
            tx = input_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
            start_item(tx);
            n_bytes = $fread(d_in, in_file, i, BYTES_PER_ELEMENT);
            tx.iq = d_in;
            finish_item(tx);
            i += BYTES_PER_ELEMENT;
        end

        `uvm_info("SEQ_RUN", $sformatf("Closing file %s...", DATA_IN_NAME), UVM_LOW);
        $fclose(in_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(input_uvm_transaction) my_uvm_sequencer;
