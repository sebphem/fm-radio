module divider #(
    parameter int DIVIDEND_WIDTH = 8,
    parameter int DIVISOR_WIDTH = 4
)(
    input logic start,
    input logic [DIVIDEND_WIDTH - 1:0] dividend,
    input logic [DIVISOR_WIDTH - 1:0] divisor,
    output logic [DIVIDEND_WIDTH - 1:0] quotient,
    output logic [DIVISOR_WIDTH - 1:0] remainder,
    output logic overflow
);

    // // Comparator module
    // module comparator #(
    //     parameter int DATA_WIDTH = DIVISOR_WIDTH
    // )(
    //     input logic [DATA_WIDTH:0] DINL,
    //     input logic [DATA_WIDTH-1:0] DINR,
    //     output logic [DATA_WIDTH-1:0] DOUT,
    //     output logic isGreaterEq
    // );
    //     always_comb begin
    //         isGreaterEq = (DINL >= {1'b0, DINR});
    //         DOUT = isGreaterEq ? (DINL - {1'b0, DINR}) : DINL[DATA_WIDTH-1:0];
    //     end
    // endmodule

    module comparator #(
        parameter int DATA_WIDTH = 4
    )(
        // Inputs
        input  logic [DATA_WIDTH:0] DINL,
        input  logic [DATA_WIDTH-1:0] DINR,
        // Outputs
        output logic [DATA_WIDTH-1:0] DOUT,
        output logic isGreaterEq
    );

        // Internal signals for signed arithmetic
        logic signed [DATA_WIDTH:0] DINL_signed;
        logic signed [DATA_WIDTH:0] DINR_extended;
        logic signed [DATA_WIDTH:0] diff;

        always_comb begin
            // Convert to signed values
            DINL_signed = signed'(DINL);
            DINR_extended = signed'({1'b0, DINR}); // Extend DINR to match width

            // Compute difference
            if (DINL_signed >= DINR_extended)
                diff = DINL_signed - DINR_extended;
            else
                diff = DINL_signed;

            // Comparator output
            isGreaterEq = (DINL_signed >= DINR_extended) ? 1'b1 : 1'b0;

            // Assign result
            DOUT = diff[DATA_WIDTH-1:0]; // Extract lower DATA_WIDTH bits
        end

    endmodule


    // Define arrays for intermediate stages
    logic [DIVISOR_WIDTH:0] dividend_stages [0:DIVIDEND_WIDTH-1];
    logic [DIVIDEND_WIDTH-1:0] internal_quotient;
    logic [DIVISOR_WIDTH-1:0] tmp_dout [0:DIVIDEND_WIDTH-1];
    logic [DIVIDEND_WIDTH-1:0] ge_flags;

    // Generate stages
    genvar i;
    generate
        for (i = 0; i < DIVIDEND_WIDTH; i++) begin : gen_stages
            comparator #(.DATA_WIDTH(DIVISOR_WIDTH)) comp (
                .DINL(dividend_stages[i]),
                .DINR(divisor),
                .DOUT(tmp_dout[i]),
                .isGreaterEq(ge_flags[i])
            );
        end
    endgenerate

    // Connect intermediate stages
    generate
        for (i = 0; i < DIVIDEND_WIDTH-1; i++) begin : gen_connectors
            always_comb begin
                dividend_stages[i+1] = {tmp_dout[i], dividend[(DIVIDEND_WIDTH-2)-i]};
            end
        end
    endgenerate

    // Generate quotient bits
    generate
        for (i = 0; i < DIVIDEND_WIDTH; i++) begin : gen_quotient
            assign quotient[i] = ge_flags[DIVIDEND_WIDTH - 1 - i];
        end
    endgenerate

    // Initialize the first stage
    always_comb begin
        dividend_stages[0] = {DIVISOR_WIDTH{1'b0}, dividend[DIVIDEND_WIDTH-1]};
    end

    // Process logic for overflow and remainder
    always_comb begin
        if (start) begin
            if (divisor == 0)
                overflow = 1'b1;
            else
                overflow = 1'b0;

            remainder = tmp_dout[DIVIDEND_WIDTH - 1];
        end else begin
            overflow = 1'b0;
        end
    end

endmodule
