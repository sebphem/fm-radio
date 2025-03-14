module fir_cmplx #(
    parameter int DECIMATION = 1,     // Decimation factor (always 1 in this case)
    parameter int TAPS = 20,
    parameter int MULT_WIDTH = 32,
    parameter int DATA_WIDTH = 32,     // Data bit width
    parameter logic signed [0:TAPS-1][DATA_WIDTH-1:0] h_real, // Real coefficients
    parameter logic signed [0:TAPS-1][DATA_WIDTH-1:0] h_imag // Imaginary coefficients
) (
    input logic clk,
    input logic rst,
    output logic x_real_rd_en,
    output logic x_imag_rd_en,
    input logic x_real_empty,
    input logic x_imag_empty,
    input logic signed [DATA_WIDTH-1:0] x_real_in,  // Input real data
    input logic signed [DATA_WIDTH-1:0] x_imag_in,  // Input imaginary data
    output logic signed [DATA_WIDTH-1:0] y_real_out, // Filtered real output
    output logic signed [DATA_WIDTH-1:0] y_imag_out, // Filtered imaginary output
    output logic y_real_wr_en,
    output logic y_imag_wr_en,
    input logic y_real_full,
    input logic y_imag_full
);

    // FSM State Definition
    typedef enum logic [3:0] {
        LOAD_SHIFT,    // Load new sample and shift register
        MULT_ACCUM,    // Multiply and accumulate for both real and imaginary parts
        OUTPUT_READY   // Store final result and manage decimation
    } fir_cmplx_state_t;

    fir_cmplx_state_t state, state_c;

    // Registers for pipeline stages
    logic signed [0:TAPS-1][DATA_WIDTH-1:0] shift_real_reg, shift_real_reg_c;   // Shift register for real input samples
    logic signed [0:TAPS-1][DATA_WIDTH-1:0] shift_imag_reg, shift_imag_reg_c;   // Shift register for imaginary input samples
    logic signed [MULT_WIDTH-1:0] extended_mult_real_reg;
    logic signed [MULT_WIDTH-1:0] extended_mult_imag_reg;
    logic signed [DATA_WIDTH-1:0] cur_h_real;
    logic signed [DATA_WIDTH-1:0] cur_h_imag;
    logic signed [DATA_WIDTH-1:0] mult_real_out;
    logic signed [DATA_WIDTH-1:0] mult_imag_out;
    logic signed [DATA_WIDTH-1:0] sum_real, sum_real_c;             // Accumulated real sum
    logic signed [DATA_WIDTH-1:0] sum_imag, sum_imag_c;             // Accumulated imaginary sum
    logic [6:0] taps_c, taps;
    logic [6:0] mult_c, mult;

    // **Sequential Block: State Transitions & Output Updates**
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= LOAD_SHIFT;
            mult <= 0;
            taps <= 0;
            sum_real <= 0;
            sum_imag <= 0;
            // Initialize shift registers
            for (int j = 0; j < TAPS; j++) begin
                shift_real_reg[j] <= 0;
                shift_imag_reg[j] <= 0;
            end
        end else begin
            state <= state_c;
            mult <= mult_c;
            taps <= taps_c;
            sum_real <= sum_real_c;
            sum_imag <= sum_imag_c;
            shift_real_reg <= shift_real_reg_c;
            shift_imag_reg <= shift_imag_reg_c;
        end
    end

    // **Combinational Block: FSM Next State Logic & Computation**
    always_comb begin
        // Default assignments
        state_c = state;
        mult_c = mult;
        taps_c = taps;
        shift_real_reg_c = shift_real_reg;
        shift_imag_reg_c = shift_imag_reg;
        sum_real_c = sum_real;
        sum_imag_c = sum_imag;
        x_real_rd_en = 1'b0;
        x_imag_rd_en = 1'b0;
        y_real_wr_en = 1'b0;
        y_imag_wr_en = 1'b0;
        y_real_out = 0;
        y_imag_out = 0;

        case (state)
            LOAD_SHIFT: begin
                if (!x_real_empty && !x_imag_empty) begin
                    x_real_rd_en = 1'b1;
                    x_imag_rd_en = 1'b1;
                    shift_real_reg_c[1:TAPS-1] = shift_real_reg[0:TAPS-2];
                    shift_real_reg_c[0] = x_real_in;
                    shift_imag_reg_c[1:TAPS-1] = shift_imag_reg[0:TAPS-2];
                    shift_imag_reg_c[0] = x_imag_in;
                    sum_real_c = 0;
                    sum_imag_c = 0;
                    state_c = MULT_ACCUM;
                    mult_c = 0;
                end
            end

            MULT_ACCUM: begin
                //first case (dont add)
                if(mult_c == 0) begin
                    cur_h_real = h_real[TAPS-mult_c-1];
                    cur_h_imag = h_imag[TAPS-mult_c-1];
                    extended_mult_real_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_real_reg[mult_c][DATA_WIDTH-1]}}, shift_real_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_real[DATA_WIDTH-1]}}, cur_h_real });
                    extended_mult_imag_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_imag_reg[mult_c][DATA_WIDTH-1]}}, shift_imag_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_imag[DATA_WIDTH-1]}}, cur_h_imag });
                    mult_real_out = GLOBALS::DEQUANTIZE_I(extended_mult_real_reg[DATA_WIDTH-1:0]) - GLOBALS::DEQUANTIZE_I(extended_mult_imag_reg[DATA_WIDTH-1:0]);

                    extended_mult_real_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_imag_reg[mult_c][DATA_WIDTH-1]}}, shift_imag_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_real[DATA_WIDTH-1]}}, cur_h_real });
                    extended_mult_imag_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_real_reg[mult_c][DATA_WIDTH-1]}}, shift_real_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_imag[DATA_WIDTH-1]}}, cur_h_imag });
                    mult_imag_out = GLOBALS::DEQUANTIZE_I(extended_mult_real_reg[DATA_WIDTH-1:0]) - GLOBALS::DEQUANTIZE_I(extended_mult_imag_reg[DATA_WIDTH-1:0]);

                    sum_real_c = mult_real_out;
                    sum_imag_c = mult_imag_out;

                    mult_c += 1;
                end
                // end (waste a cycle)
                else if (mult_c == TAPS) begin
                    state_c = OUTPUT_READY;
                end
                // normal case (macc)
                else begin
                    cur_h_real = h_real[TAPS-mult_c-1];
                    cur_h_imag = h_imag[TAPS-mult_c-1];
                    extended_mult_real_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_real_reg[mult_c][DATA_WIDTH-1]}}, shift_real_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_real[DATA_WIDTH-1]}}, cur_h_real });
                    extended_mult_imag_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_imag_reg[mult_c][DATA_WIDTH-1]}}, shift_imag_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_imag[DATA_WIDTH-1]}}, cur_h_imag });
                    mult_real_out = GLOBALS::DEQUANTIZE_I(extended_mult_real_reg[DATA_WIDTH-1:0]) - GLOBALS::DEQUANTIZE_I(extended_mult_imag_reg[DATA_WIDTH-1:0]);

                    extended_mult_real_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_imag_reg[mult_c][DATA_WIDTH-1]}}, shift_imag_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_real[DATA_WIDTH-1]}}, cur_h_real });
                    extended_mult_imag_reg = $signed({ {MULT_WIDTH-DATA_WIDTH{shift_real_reg[mult_c][DATA_WIDTH-1]}}, shift_real_reg[mult_c] }) *
                                        $signed({ {MULT_WIDTH-DATA_WIDTH{cur_h_imag[DATA_WIDTH-1]}}, cur_h_imag });
                    mult_imag_out = GLOBALS::DEQUANTIZE_I(extended_mult_real_reg[DATA_WIDTH-1:0]) - GLOBALS::DEQUANTIZE_I(extended_mult_imag_reg[DATA_WIDTH-1:0]);

                    sum_real_c += mult_real_out;
                    sum_imag_c += mult_imag_out;

                    mult_c += 1;
                end
            end

            OUTPUT_READY: begin
                if (!y_real_full && !y_imag_full) begin
                    y_real_wr_en = 1'b1;
                    y_imag_wr_en = 1'b1;
                    y_real_out = sum_real_c;
                    y_imag_out = sum_imag_c;
                    state_c = LOAD_SHIFT;
                end
            end
        endcase
    end

endmodule