module fir #(
    parameter int DECIMATION = 2,     // Decimation factor
    parameter int TAPS = 32,
    parameter logic signed [0:TAPS][DATA_WIDTH-1:0] coeff = '{default: '{default: 0}}, // Coefficients
    parameter int DATA_WIDTH = 32     // Data bit width
) (
    input logic clk,
    input logic rst_n,
    output logic x_in_rd_en,
    input logic x_in_empty,
    input logic signed [DATA_WIDTH-1:0] x_in,  // Input data
    output logic valid_out,            // Output valid signal
    output logic signed [DATA_WIDTH-1:0] y_out // Filtered output
    output logic y_out_wr_en,
    input logic y_out_full
);

    // FSM State Definition
    typedef enum logic [1:0] {
        LOAD_SHIFT,    // Load new sample and shift register
        MULT_ACCUM,    // Multiply and accumulate
        OUTPUT_READY   // Store final result and manage decimation
    } fir_state_t;

    fir_state_t state, state_c;

    // Registers for pipeline stages
    logic signed [DATA_WIDTH-1:0] shift_reg [TAPS-1:0];   // Shift register for input samples
    logic signed [DATA_WIDTH-1:0] mult_out;
    logic signed [DATA_WIDTH-1:0] sum_mult;             // Accumulated sum
    logic signed [DATA_WIDTH-1:0] sum_result;            // Final summation result
    logic valid_next;
    logic [6:0] dec_c, dec;
    logic [6:0] taps_c, taps;
    logic [6:0] mult_c, mult;


    // **Sequential Block: State Transitions & Output Updates**
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sample_counter <= 0;
            valid_out <= 0;
            y_out <= 0;
            mult <= 0;
            dec <= 0;
            taps <= 0;
            // Initialize shift registers
            for (int j = 0; j < TAPS; j++) begin
                shift_reg[j] <= 0;
            end
        end else begin
            state <= state_c;
            valid_out <= valid_next;
            mult <= mult_c;
            dec <= dec_c;
            taps <= taps_c;
            sum_mult <= sum_mult_c;
        end
    end


    // **Combinational Block: FSM Next State Logic & Computation**
    always_comb begin
        // Default assignments
        state_c = state;
        valid_next = 0;
        dec_c = dec;
        taps_c = taps;
        sum_mult_c = sum_mult;

        case (state)
            LOAD_SHIFT: begin
                if(!x_in_empty) begin
                    x_in_rd_en = 1'b1;
                    shift_reg[1:TAPS-1] = shift_reg[0:TAPS-2];
                    shift_reg[0] = x_in;
                    dec_c+=1;
                    // if we have obliterated the extra samples
                    if(dec_c == DECIMATION) begin
                        state_c = MULT_ACCUM;
                        mult_c = 0;
                    end
                end
            end

            MULT_ACCUM: begin
                //first case (dont add)
                if(mult_c == 0) begin
                    mult_out = $signed(shift_reg[mult_c]) * $signed(coeff[TAPS-mult_c-1]);
                    mult_c += 1;
                    sum_mult_c = mult_out;
                end
                // end (waste a cycle)
                else if (mult_c == TAPS) begin
                    state_c = OUTPUT_READY;
                end
                // normal case (macc)
                else begin
                    mult_out = $signed(shift_reg[mult_c]) * $signed(coeff[TAPS-mult_c-1]);
                    mult_c += 1;
                    sum_mult_c += mult_out;
                end
            end
            OUTPUT_READY: begin
                if(!y_out_full) begin
                    y_out_wr_en = 1'b1;
                    y_out = sum_mult_c;
                    state_c = LOAD_SHIFT;
                    dec_c = 0;
                end
            end
        endcase
    end

endmodule
