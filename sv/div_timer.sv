module div_timer #(
    parameter DATA_WIDTH=32,
    paremeter STAGES=16
) (
    input clock,
    input reset,
    input [(DATA_WIDTH-1):0]din,
    input valid_in,
    output [(DATA_WIDTH-1):0]dout,
    output valid_out
);
    logic [4:0] counter;
    
    always_ff (posedge clock or negedge reset) begin :

    end
endmodule