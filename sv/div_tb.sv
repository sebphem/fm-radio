`timescale 1ns / 1ps

import divider_const::*;

module divider_tb;
    localparam DIVIDEND_WIDTH = 16;
    localparam DIVISOR_WIDTH = 16;
    // DUT Signals
    logic start_tb = 0;
    logic [DIVIDEND_WIDTH - 1:0] dividend_tb;
    logic [DIVISOR_WIDTH - 1:0] divisor_tb;
    logic [DIVIDEND_WIDTH - 1:0] quotient_tb;
    logic [DIVISOR_WIDTH - 1:0] remainder_tb;
    logic overflow_tb;

    // Instantiate DUT
    divider uut#(
        .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
        .DIVISOR_WIDTH(DIVISOR_WIDTH)
    )(
        .start(start_tb),
        .dividend(dividend_tb),
        .divisor(divisor_tb),
        .quotient(quotient_tb),
        .remainder(remainder_tb),
        .overflow(overflow_tb)
    );

    // File handling
    int input_file, output_file;
    string input_filename, output_filename;
    int dividend_val, divisor_val, quotient_val, remainder_val;
    
    // Convert integer to logic vector
    function automatic logic [DIVIDEND_WIDTH-1:0] to_logic_vector(int val, int len);
        return logic'(val);
    endfunction

    initial begin
        // Select input/output file based on width
        if (DIVIDEND_WIDTH == 16) begin
            input_filename = "divider16.in";
            output_filename = "divider16.out";
        end else begin
            input_filename = "divider32.in";
            output_filename = "divider32.out";
        end

        // Open files
        input_file = $fopen(input_filename, "r");
        output_file = $fopen(output_filename, "w");

        if (input_file == 0 || output_file == 0) begin
            $display("Error: Could not open input or output file.");
            $finish;
        end

        while (!$feof(input_file)) begin
            // Read dividend
            if ($fscanf(input_file, "%d\n", dividend_val) != 1) break;
            dividend_tb = to_logic_vector(dividend_val, DIVIDEND_WIDTH);

            // Read divisor
            if ($fscanf(input_file, "%d\n", divisor_val) != 1) break;
            divisor_tb = to_logic_vector(divisor_val, DIVISOR_WIDTH);

            // Start division
            start_tb = 1;
            #10;
            start_tb = 0;
            #10;

            // Compute expected quotient and remainder
            if (divisor_val != 0) begin
                quotient_val = dividend_val / divisor_val;
                remainder_val = dividend_val % divisor_val;
            end else begin
                quotient_val = 0;
                remainder_val = dividend_val;
            end

            // Write to output file
            $fwrite(output_file, "%d / %d = %d -- %d\n",
                    dividend_val, divisor_val, quotient_tb, remainder_tb);

            // Check correctness
            if (quotient_tb !== quotient_val || remainder_tb !== remainder_val) begin
                $display("Test case failed: %d / %d = %d -- %d (Expected: %d -- %d)",
                         dividend_val, divisor_val, quotient_tb, remainder_tb,
                         quotient_val, remainder_val);
            end

            #10;
        end

        // Close files
        $fclose(input_file);
        $fclose(output_file);

        $finish;
    end

endmodule