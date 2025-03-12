// also called the deemphasis module
module iir #(
    parameter DATA_WIDTH = 32        // Bit-DATA_WIDTH of input/output
)(
    input logic clk,
    input logic rst,
    // x in fifo
    output logic x_in_rd_en,
    input logic x_in_empty,
    input logic signed [DATA_WIDTH-1:0] x_in,
    // y out fifo
    output logic signed [DATA_WIDTH-1:0] y_out,
    output logic y_out_wr_en,
    input logic y_out_full
);

    // Deemphasis IIR Filter Coefficients:
    logic [0:(IIR_COEFF_TAP_BITS-1)][DATA_WIDTH-1:0] IIR_Y_COEFFS = {32'h0, 32'hfffffd66};
    logic [0:(IIR_COEFF_TAP_BITS-1)][DATA_WIDTH-1:0] IIR_X_COEFFS = {32'h000000b2, 32'h000000b2};

    logic signed [0:(IIR_COEFF_TAP_BITS-1)][DATA_WIDTH-1:0] x;
    logic signed [0:(IIR_COEFF_TAP_BITS-1)][DATA_WIDTH-1:0] y;
    logic signed [DATA_WIDTH-1:0] y1, y2;

    typedef enum logic [1:0] state_type {SHIFT_X,SHIFT_Y,GEN_NEW_Y0,WRITEBACK_Y};
    state_type state, state_c;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < IIR_COEFF_TAPS; i++) begin
                x[i] <= 0;
                y[i] <= 0;
            end
            y1 <= 0;
            y2 <= 0;
            y_out <= 0;
            state <= SHIFT_X;
        end else begin
            state <= state_c;
            y1 <= y1_c;
            y2 <= y2_c;
        end
    end

    always_comb begin : logic
        state_c = state;
        y1_c = y1;
        y2_c = y2;
        case(state)
            SHIFT_X: begin
                if (!x_in_empty) begin
                    //async read
                    x_in_rd_en = 1'b1;
                    x[1] = x[0];
                    x[0] = x_in;
                    state_c = SHIFT_Y;
                end
            end
            SHIFT_Y: begin
                y[1] = y[0];
                state_c = GEN_NEW_Y0;
            end
            GEN_NEW_Y0: begin
                //def the bottleneck
                for(integer i = 0; i < IIR_COEFF_TAPS; i++) begin
                    y1_c = y1 + DEQUANTIZE_I(IIR_X_COEFFS[i]*x[i]);
                    y2_c = y2 + DEQUANTIZE_I(IIR_Y_COEFFS[i]*y[i]);
                end
                y[0] = y1_c + y1_c;
                state_c = WRITEBACK_Y;
            end
            WRITEBACK_Y: begin
                if(!y_out_full) begin
                    y_out_wr_en = 1'b1;
                    //the index is just one
                    y_out = y[IIR_COEFF_TAPS-1];
                    state_c = SHIFT_X;
                end
            end
            default: begin
                x_in_rd_en  = 1'b0;
                y_out_wr_en = 1'b0;
                state_c = SHIFT_X;
            end
        endcase
    end
endmodule
