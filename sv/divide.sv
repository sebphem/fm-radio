module divide_two_inputs (
    input  logic                    clock,
    input  logic                    reset,

    // Dividend input port
    output logic                    inA_rd_en,      
    input  logic                    inA_empty,      
    input  logic signed [31:0]      inA_dout,     // dividend

    // Divisor input port
    output logic                    inB_rd_en,      
    input  logic                    inB_empty,     
    input  logic signed [31:0]      inB_dout,     // divisor

    // Quotient output port
    output logic                    out_wr_en,     
    input  logic                    out_full,       
    output logic signed [31:0]      out_din       // quotient
);

   // FSM states for controlling the pipeline operation.
   typedef enum logic [1:0] {S0, S_PIPE, S1} state_t;
   state_t state, state_c;

   // Parameters: WIDTH is the bit‐width and STAGES is how many pipeline iterations (cycles)
   parameter WIDTH  = 32;
   parameter STAGES = 32;  // maximum iterations (you might optimize this)

   // Pipeline registers (one operation at a time)
   // a_pipe holds the “working remainder” and q_pipe the accumulated quotient.
   logic [WIDTH-1:0] a_pipe, q_pipe, b_reg;
   logic             valid;   // indicates if more subtraction is needed
   logic             sign;    // computed sign (1 if the result should be negative)

   // A simple counter to count pipeline iterations
   logic [5:0]       pipe_cnt;

   //=====================================================================
   // Function: msb
   // Returns the index (0 to WIDTH-1) of the most-significant 1-bit.
   // (Note: many synthesis tools support a priority encoder or clz operator.)
   //=====================================================================
   function automatic int msb(input logic [WIDTH-1:0] x);
      int i;
      begin
         msb = 0;
         for (i = WIDTH-1; i >= 0; i--) begin
            if (x[i]) begin
               msb = i;
               break;
            end
         end
      end
   endfunction

   //=====================================================================
   // Sequential block: FSM state update and pipeline register updates
   //=====================================================================
   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state    <= S0;
         a_pipe   <= '0;
         q_pipe   <= '0;
         b_reg    <= '0;
         valid    <= 1'b0;
         sign     <= 1'b0;
         pipe_cnt <= '0;
      end else begin
         state <= state_c;
         case (state)
            S0: begin
               // When valid inputs are available, load the pipeline registers.
               if (!inA_empty && !inB_empty) begin
                  // Convert dividend and divisor to absolute values.
                  logic [WIDTH-1:0] abs_dividend;
                  logic [WIDTH-1:0] abs_divisor;
                  abs_dividend = (inA_dout[WIDTH-1]) ? -inA_dout : inA_dout;
                  abs_divisor  = (inB_dout[WIDTH-1]) ? -inB_dout : inB_dout;

                  b_reg    <= abs_divisor;
                  sign     <= inA_dout[WIDTH-1] ^ inB_dout[WIDTH-1];
                  pipe_cnt <= 0;

                  // Special-case: if divisor==1 then the quotient is just the dividend.
                  if (abs_divisor == 1) begin
                     q_pipe <= abs_dividend;
                     a_pipe <= 0;
                     valid  <= 1'b0;
                  end else begin
                     q_pipe <= 0;
                     a_pipe <= abs_dividend;
                     valid  <= (abs_dividend >= abs_divisor);
                  end
               end
            end

            S_PIPE: begin
               // One pipeline iteration per clock cycle:
               if (valid) begin
                  int msb_a, msb_b, p;
                  msb_a = msb(a_pipe);
                  msb_b = msb(b_reg);
                  p = msb_a - msb_b;
                  // Adjust p if shifting b by p overshoots a.
                  if ((b_reg << p) > a_pipe)
                     p = p - 1;
                  // Update quotient and remainder.
                  q_pipe <= q_pipe + (1 << p);
                  a_pipe <= a_pipe - (b_reg << p);
                  // Check if another subtraction is needed.
                  valid  <= ((a_pipe - (b_reg << p)) >= b_reg);
               end
               pipe_cnt <= pipe_cnt + 1;
            end

            S1: begin
               // No pipeline update here; we wait for the result to be consumed.
            end

            default: ; 
         endcase
      end
   end

   //=====================================================================
   // Next-State / Output Combinational Logic
   //=====================================================================
   always_comb begin
      // Default assignments for handshaking signals and next state.
      state_c    = state;
      inA_rd_en  = 1'b0;
      inB_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;

      case (state)
         S0: begin
            // In S0, if inputs are available, assert read enables.
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;
               state_c   = S_PIPE;
            end
         end

         S_PIPE: begin
            // Stay in S_PIPE until we have executed STAGES iterations.
            if (pipe_cnt == STAGES)
               state_c = S1;
         end

         S1: begin
            // When the output FIFO is not full, send the result.
            if (!out_full) begin
               out_wr_en = 1'b1;
               // Apply sign correction to the computed quotient.
               out_din   = sign ? -q_pipe : q_pipe;
               state_c   = S0;
            end
         end

         default: state_c = S0;
      endcase
   end

endmodule
