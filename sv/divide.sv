`ifndef _DIVIDE_
`define _DIVIDE_

`include "global.sv"

module divide_two_inputs (
    input  logic                   clock,
    input  logic                   reset,

    // Dividend input port
    output logic                   inA_rd_en,      
    input  logic                   inA_empty,      
    input  logic signed [31:0]     inA_dout,     

    // Divisor input port
    output logic                   inB_rd_en,      
    input  logic                   inB_empty,     
    input  logic signed [31:0]     inB_dout,     

    // Quotient output port
    output logic                   out_wr_en,     
    input  logic                   out_full,       
    output logic signed [31:0]     out_din        
);

   // Pipeline states
   typedef enum logic [3:0] {
       S0, 
       S_FINDMSB_A,
       S_FINDMSB_B,
       S_ADJUST,
       S_ADDQ,
       S_SUBA,
       S_CHECK,
       S1
   } state_t;
   state_t state, state_next;

   parameter WIDTH  = 32;
   parameter STAGES = 32;  // # of bit iterations

   // Pipeline registers
   logic [WIDTH-1:0] a_pipe, q_pipe, b_reg;
   logic             sign; 
   logic             valid;       // keep iterating?
   logic [5:0]       pipe_cnt;    // iteration counter
   logic [31:0]      p_reg;       // shift amount
   // These hold the msb(...) results for an iteration
   int               msb_a_reg;
   int               msb_b_reg;

   // “Most‐Significant Bit” function
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
   logic [WIDTH-1:0] next_a;
   // Synchronous update of registers & FSM
   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state      <= S0;
         a_pipe     <= '0;
         q_pipe     <= '0;
         b_reg      <= '0;
         sign       <= 1'b0;
         valid      <= 1'b0;
         pipe_cnt   <= '0;
         p_reg      <= '0;
         msb_a_reg  <= 0;
         msb_b_reg  <= 0;
         next_a    <= '0;
      end 
      else begin
         state <= state_next;

         case (state)

           //======================================================
           S0: begin
               // If data present on both inputs, latch them
               if (!inA_empty && !inB_empty) begin
                  // Take absolute values, figure out sign
                  logic [WIDTH-1:0] absA;
                  logic [WIDTH-1:0] absB;
                  absA = inA_dout[31] ? -inA_dout : inA_dout;
                  absB = inB_dout[31] ? -inB_dout : inB_dout;

                  sign     <= inA_dout[31] ^ inB_dout[31];
                  a_pipe   <= absA;
                  b_reg    <= absB;
                  q_pipe   <= 0;
                  pipe_cnt <= 0;
                  // “valid” means we still have more sub cycles to do
                  valid    <= (absA >= absB);
               end
           end

           //======================================================
           S_FINDMSB_A: begin
               // Compute msb of a_pipe, store in msb_a_reg
               msb_a_reg <= msb(a_pipe);
           end

           //======================================================
           S_FINDMSB_B: begin
               // Compute msb of b_reg, store in msb_b_reg
               msb_b_reg <= msb(b_reg);
           end

           //======================================================
           S_ADJUST: begin
               // Compare msb_a_reg, msb_b_reg => figure out p
               int tmp_p;
               tmp_p = msb_a_reg - msb_b_reg;
               if ((b_reg << tmp_p) > a_pipe)
                  tmp_p = tmp_p - 1;
               p_reg <= tmp_p;
           end

           //======================================================
           S_ADDQ: begin
               // Update the quotient
               q_pipe <= q_pipe + (1 << p_reg);
           end

           //======================================================
           S_SUBA: begin
               // Subtract from the remainder
               a_pipe <= a_pipe - (b_reg << p_reg);
           end

           //======================================================
           S_CHECK: begin
               // Check if we still can subtract more
               // or if we have completed STAGES
               next_a = a_pipe - (b_reg << p_reg);
               valid     <= (next_a >= b_reg);
               pipe_cnt  <= pipe_cnt + 1;
           end

           //======================================================
           S1: begin
               // wait for out_full to go low
           end

         endcase
      end
   end

   // Next-state & output logic
   always_comb begin
      state_next = state;
      inA_rd_en  = 1'b0;
      inB_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;

      case (state)
         //-------------------------------------------------------
         S0: begin
            // If both inputs present, read them and go to S_FINDMSB_A
            if (!inA_empty && !inB_empty) begin
               inA_rd_en  = 1'b1;
               inB_rd_en  = 1'b1;
               state_next = S_FINDMSB_A;
            end
         end

         //-------------------------------------------------------
         S_FINDMSB_A: begin
            // Next, find msb_b
            state_next = S_FINDMSB_B;
         end

         //-------------------------------------------------------
         S_FINDMSB_B: begin
            // Next, compute shift p
            state_next = S_ADJUST;
         end

         //-------------------------------------------------------
         S_ADJUST: begin
            // Next, add to quotient
            state_next = S_ADDQ;
         end

         //-------------------------------------------------------
         S_ADDQ: begin
            // Next, subtract from remainder
            state_next = S_SUBA;
         end

         //-------------------------------------------------------
         S_SUBA: begin
            // Next, check iteration conditions
            state_next = S_CHECK;
         end

         //-------------------------------------------------------
         S_CHECK: begin
            // If done, go to S1, else keep iterating
            if (pipe_cnt >= STAGES || !valid)
               state_next = S1;
            else
               state_next = S_FINDMSB_A; 
         end

         //-------------------------------------------------------
         S1: begin
            // If out_full=0, we can send out the result
            if (!out_full) begin
               out_wr_en  = 1'b1;
               out_din    = sign ? -q_pipe : q_pipe;
               state_next = S0;
            end
         end
      endcase
   end

endmodule

`endif
