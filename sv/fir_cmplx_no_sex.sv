module fir_cmplx #(
    parameter int DECIMATION = 1, // Decimation factor
    parameter int TAPS = 32,
    parameter logic signed [0:TAPS-1][DATA_WIDTH-1:0] h_real, // Real coefficients
    parameter logic signed [0:TAPS-1][DATA_WIDTH-1:0] h_imag, // Imaginary coefficients
    parameter int DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,
    output logic x_real_in_rd_en,
    output logic x_imag_in_rd_en,
    input logic x_real_in_empty,
    input logic x_imag_in_empty,
    input logic signed [DATA_WIDTH-1:0] x_real_in, // Input real data
    input logic signed [DATA_WIDTH-1:0] x_imag_in, // Input imaginary data
    output logic valid_out, // Output valid signal
    output logic signed [DATA_WIDTH-1:0] y_real_out, // Filtered real output
    output logic signed [DATA_WIDTH-1:0] y_imag_out, // Filtered imaginary output
    output logic y_real_out_wr_en,
    output logic y_imag_out_wr_en,
    input logic y_real_out_full,
    input logic y_imag_out_full
);

    // FSM State Definition
    typedef enum logic [1:0] {
        LOAD_SHIFT, // Load new samples and shift registers
        MULT_ACCUM, // Multiply and accumulate
        OUTPUT_READY // Store final results and manage decimation
    } fir_state_t;

    fir_state_t state, state_c;

    // Registers for pipeline stages
    logic signed [DATA_WIDTH-1:0] x_real_shift_reg [TAPS-1:0]; // Shift register for real input samples
    logic signed [DATA_WIDTH-1:0] x_imag_shift_reg [TAPS-1:0]; // Shift register for imaginary input samples
    logic signed [DATA_WIDTH-1:0] mult_real_out;
    logic signed [DATA_WIDTH-1:0] mult_imag_out;
    logic signed [DATA_WIDTH-1:0] sum_real_mult; // Accumulated real sum
    logic signed [DATA_WIDTH-1:0] sum_imag_mult; // Accumulated imaginary sum
    logic signed [DATA_WIDTH-1:0] sum_real_result; // Final real summation result
    logic signed [DATA_WIDTH-1:0] sum_imag_result; // Final imaginary summation result
    logic valid_next;
    logic [6:0] dec_c, dec;
    logic [6:0] mult_c, mult;

    // **Sequential Block: State Transitions & Output Updates**
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= LOAD_SHIFT;
            valid_out <= 0;
            y_real_out <= 0;
            y_imag_out <= 0;
            mult <= 0;
            dec <= 0;
            // Initialize shift registers
            for (int j = 0; j < TAPS; j++) begin
                x_real_shift_reg[j] <= 0;
                x_imag_shift_reg[j] <= 0;
            end
        end else begin
            state <= state_c;
            valid_out <= valid_next;
            mult <= mult_c;
            dec <= dec_c;
            sum_real_mult <= sum_real_mult_c;
            sum_imag_mult <= sum_imag_mult_c;
        end
    end

    // **Combinational Block: FSM Next State Logic & Computation**
    always_comb begin
        // Default assignments
        state_c = state;
        valid_next = 0;
        dec_c = dec;
        sum_real_mult_c = sum_real_mult;
        sum_imag_mult_c = sum_imag_mult;
        x_real_in_rd_en = 1'b0;
        x_imag_in_rd_en = 1'b0;
        y_real_out_wr_en = 1'b0;
        y_imag_out_wr_en = 1'b0;

        case (state)
            LOAD_SHIFT: begin
                if (!x_real_in_empty && !x_imag_in_empty) begin
                    x_real_in_rd_en = 1'b1;
                    x_imag_in_rd_en = 1'b1;
                    x_real_shift_reg[1:TAPS-1] = x_real_shift_reg[0:TAPS-2];
                    x_imag_shift_reg[1:TAPS-1] = x_imag_shift_reg[0:TAPS-2];
                    x_real_shift_reg[0] = x_real_in;
                    x_imag_shift_reg[0] = x_imag_in;
                    dec_c += 1;
                    if (dec_c == DECIMATION) begin
                        state_c = MULT_ACCUM;
                        mult_c = 0;
                    end
                end
            end

            MULT_ACCUM: begin
                if (mult_c == 0) begin
                    mult_real_out = $signed(h_real[mult_c]) * $signed(x_real_shift_reg[mult_c]) - $signed(h_imag[mult_c]) * $signed(x_imag_shift_reg[mult_c]);
                    mult_imag_out = $signed(h_real[mult_c]) * $signed(x_imag_shift_reg[mult_c]) + $signed(h_imag[mult_c]) * $signed(x_real_shift_reg[mult_c]);
                    mult_c += 1;
                    sum_real_mult_c = mult_real_out;
                    sum_imag_mult_c = mult_imag_out;
                end else if (mult_c == TAPS) begin
                    state_c = OUTPUT_READY;
                end else begin
                    mult_real_out = $signed(h_real[mult_c]) * $signed(x_real_shift_reg[mult_c]) - $signed(h_imag[mult_c]) * $signed(x_imag_shift_reg[mult_c]);
                    mult_imag_out = $signed(h_real[mult_c]) * $signed(x_imag_shift_reg[mult_c]) + $signed(h_imag[mult_c]) * $signed(x_real_shift_reg[mult_c]);
                    mult_c += 1;
                    sum_real_mult_c += mult_real_out;
                    sum_imag_mult_c += mult_imag_out;
                end
            end

            OUTPUT_READY: begin
                if (!y_real_out_full && !y_imag_out_full) begin
                    y_real_out_wr_en = 1'b1;
                    y_imag_out_wr_en = 1'b1;
                    y_real_out = sum_real_mult_c;
                    y_imag_out = sum_imag_mult_c;
                    state_c = LOAD_SHIFT;
                    dec_c = 0;
                end
            end
        endcase
    end

endmodule