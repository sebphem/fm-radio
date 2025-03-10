module qarctan #(
   parameter DATA_WIDTH = 32
) (
    input logic clock;
    input logic reset;
    input logic avail_in;
    input logic signed [(DATA_WIDTH-1):0] x;
    input logic [(DATA_WIDTH-1):0] y;
    output logic avail_out;
    output logic [(DATA_WIDTH-1):0] dout;
);

    import synth_vars::*;

    logic enum {} state_defs;

    state_defs state, state_c;
    always_ff @( posedge clk or posedge reset ) begin : ff
        if(!reset) begin
            avail_out = 0;
            dout = 0;
        end else begin
            
        end
    end

    logic [(DATA_WIDTH-1):0] abs_y;
    logic [(DATA_WIDTH-1):0] x_minus_abs_y;
    logic [(DATA_WIDTH-1):0] x_plus_abs_y;
    logic [(DATA_WIDTH-1):0] x_minus_abs_y_quant_i;
    logic [(DATA_WIDTH-1):0] x_plus_abs_y_quant_i;
    logic [(DATA_WIDTH-1):0] quad1 = 32'h00000324;
    logic [(DATA_WIDTH-1):0] quad3 = 32'h0000096c;
    always_comb begin : logic_block
        
        case (state)
            SETUP: begin
                abs_y = $signed(y) < 0 ? -$signed(y) : abs_y;
                x_minus_abs_y = x - abs_y;
                x_minus_abs_y_quant_i = QUANTIZE_I(x_minus_abs_y);
                x_plus_abs_y = x + abs_y;
                x_plus_abs_y_quant_i = QUANTIZE_I(x_plus_abs_y);
                
            end

        endcase

        if (x>=0) begin

        end else begin
        
        end
    end

endmodule