`ifndef _DEMODULATE_
`define _DEMODULATE_
`include "global.sv"
`include "fifo.sv"
`include "qarctan.sv"
// Module 1:
// state 0 => waiting for input / if get input write
//        int r = DEQUANTIZE(*real_prev * real) - DEQUANTIZE(-*imag_prev * imag);
//        int i = DEQUANTIZE(*real_prev * imag) + DEQUANTIZE(-*imag_prev * real);
//        update r_prev, i_prev
// state 1 => write r,i inputs to arctan FIFO, go to state 0

// Module 2:
// qarctan module

// Module 3:
// state 0 => read from arctan FIFO, go to state 1
// state 1 => write to output FIFO, go to state 0
module demodulate_two_inputs (
   input logic         clock,
   input logic         reset,

   output logic         inA_rd_en,
   input  logic         inA_empty,
   input  logic signed [31:0] inA_dout,

   output logic         inB_rd_en,
   input  logic         inB_empty,
   input  logic signed [31:0] inB_dout,

   output logic         out_wr_en,
   input  logic         out_full,
   output logic signed [31:0] out_din
);
   logic stage_1_out_full1;
   logic stage_1_out_wr_en1;
   logic signed [31:0] stage_1_out_din1;
   logic stage_1_out_rd_en1;
   logic stage_1_out_empty1;
   logic signed [31:0] stage_1_out_dout1;
   logic stage_1_out_full2;
   logic stage_1_out_wr_en2;
   logic signed [31:0] stage_1_out_din2;
   logic stage_1_out_rd_en2;
   logic stage_1_out_empty2;
   logic signed [31:0] stage_1_out_dout2;

   fifo #(
           .FIFO_BUFFER_SIZE(16),
           .FIFO_DATA_WIDTH(32)
   ) stage_1_out_fifo1 (
       .reset(reset),
       .wr_clk(clock),
       .wr_en(stage_1_out_wr_en1),
       .din(stage_1_out_din1),
       .full(stage_1_out_full1),
       .rd_clk(clock),
       .rd_en(stage_1_out_rd_en1),
       .dout(stage_1_out_dout1),
       .empty(stage_1_out_empty1)
   );

   fifo #(
           .FIFO_BUFFER_SIZE(16),
           .FIFO_DATA_WIDTH(32)
   ) stage_1_out_fifo2 (
       .reset(reset),
       .wr_clk(clock),
       .wr_en(stage_1_out_wr_en2),
       .din(stage_1_out_din2),
       .full(stage_1_out_full2),
       .rd_clk(clock),
       .rd_en(stage_1_out_rd_en2),
       .dout(stage_1_out_dout2),
       .empty(stage_1_out_empty2)
   );

   demodulate_stage_1 stage_1_inst (
       .clock(clock),
       .reset(reset),
       .inA_rd_en(inA_rd_en),
       .inA_empty(inA_empty),
       .inA_dout(inA_dout),
       .inB_rd_en(inB_rd_en),
       .inB_empty(inB_empty),
       .inB_dout(inB_dout),
       .out_wr_en(stage_1_out_wr_en1),
       .out_full(stage_1_out_full1),
       .out_din(stage_1_out_din1),
       .out2_wr_en(stage_1_out_wr_en2),
       .out2_full(stage_1_out_full2),
       .out2_din(stage_1_out_din2)
   ); 

   logic qarctan_out_full;
   logic qarctan_out_wr_en;
   logic signed [31:0] qarctan_out_din;
   logic qarctan_out_rd_en;
   logic qarctan_out_empty;
   logic signed [31:0] qarctan_out_dout;

   fifo #(
           .FIFO_BUFFER_SIZE(16),
           .FIFO_DATA_WIDTH(32)
   ) qarctan_out_fifo (
       .reset(reset),
       .wr_clk(clock),
       .wr_en(qarctan_out_wr_en),
       .din(qarctan_out_din),
       .full(qarctan_out_full),
       .rd_clk(clock),
       .rd_en(qarctan_out_rd_en),
       .dout(qarctan_out_dout),
       .empty(qarctan_out_empty)
   );

   qarctan_two_inputs qarctan_inst (
       .clock(clock),
       .reset(reset),
       .inA_rd_en(stage_1_out_rd_en1),
       .inA_empty(stage_1_out_empty1),
       .inA_dout(stage_1_out_dout1),
       .inB_rd_en(stage_1_out_rd_en2),
       .inB_empty(stage_1_out_empty2),
       .inB_dout(stage_1_out_dout2),
       .out_wr_en(qarctan_out_wr_en),
       .out_full(qarctan_out_full),
       .out_din(qarctan_out_din)
   );

   demodulate_stage_2 stage_2_inst (
       .clock(clock),
       .reset(reset),
       .inA_rd_en(qarctan_out_rd_en),
       .inA_empty(qarctan_out_empty),
       .inA_dout(qarctan_out_dout),
       .out_wr_en(out_wr_en),
       .out_full(out_full),
       .out_din(out_din)
   );
endmodule

module demodulate_stage_1 (
    input  logic         clock,
    input  logic         reset,

    output logic         inA_rd_en,      
    input  logic         inA_empty,      
    input  logic signed [31:0] inA_dout,

    output logic         inB_rd_en,      
    input  logic         inB_empty,     
    input  logic signed [31:0] inB_dout,

    output logic         out_wr_en,     
    input  logic         out_full,       
    output logic signed [31:0] out_din,

    output logic         out2_wr_en,     
    input  logic         out2_full,       
    output logic signed [31:0] out2_din    
);

   // Extend the state machine to three states.
   typedef enum logic [1:0] { S0, S1, S2 } state_t;
   state_t state, state_c;

   // Registers holding the previous values (used in the multiplication)
   // and temporary storage for the newly read inputs.
   logic signed [31:0] real_prev, real_prev_c;
   logic signed [31:0] imag_prev, imag_prev_c;
   logic signed [31:0] curr_A,    curr_A_c;
   logic signed [31:0] curr_B,    curr_B_c;

   // Intermediate multiplication results.
   logic signed [31:0] mult_A,  mult_A_c;
   logic signed [31:0] mult_B,  mult_B_c;
   logic signed [31:0] mult_C,  mult_C_c;
   logic signed [31:0] mult_D,  mult_D_c;

   // Final computed outputs.
   logic signed [31:0] r, r_c;
   logic signed [31:0] i, i_c;

   // Sequential block: update state and registers.
   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state       <= S0;
         r           <= 32'sd0;
         i           <= 32'sd0;
         real_prev   <= 32'sd0;
         imag_prev   <= 32'sd0;
         curr_A      <= 32'sd0;
         curr_B      <= 32'sd0;
         mult_A      <= 32'sd0;
         mult_B      <= 32'sd0;
         mult_C      <= 32'sd0;
         mult_D      <= 32'sd0;
      end else begin
         state       <= state_c;
         r           <= r_c;
         i           <= i_c;
         real_prev   <= real_prev_c;
         imag_prev   <= imag_prev_c;
         curr_A      <= curr_A_c;
         curr_B      <= curr_B_c;
         mult_A      <= mult_A_c;
         mult_B      <= mult_B_c;
         mult_C      <= mult_C_c;
         mult_D      <= mult_D_c;
      end
   end

   // Combinational block for next-state logic and computation.
   always_comb begin
      // Default assignments for outputs.
      inA_rd_en   = 1'b0;
      inB_rd_en   = 1'b0;
      out_wr_en   = 1'b0;
      out_din     = 32'sd0;
      out2_wr_en  = 1'b0;
      out2_din    = 32'sd0;

      // Default next-state assignments (hold current values).
      state_c       = state;
      r_c           = r;
      i_c           = i;
      real_prev_c   = real_prev;
      imag_prev_c   = imag_prev;
      curr_A_c      = curr_A;
      curr_B_c      = curr_B;
      mult_A_c      = mult_A;
      mult_B_c      = mult_B;
      mult_C_c      = mult_C;
      mult_D_c      = mult_D;

      case (state)
         S0: begin
            // When both inputs are available, read them.
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;
               // Latch the new inputs into temporary registers.
               curr_A_c = inA_dout;
               curr_B_c = inB_dout;
               // Do not update the "old" values yet; they will be used for multiplication.
               state_c  = S1;
            end
         end

         S1: begin
            // Perform the multiplications using the stored previous values and
            // the newly latched inputs:
            //   mult_A = real_prev   * curr_A
            //   mult_B = -imag_prev  * curr_B
            //   mult_C = real_prev   * curr_B
            //   mult_D = -imag_prev  * curr_A
            mult_A_c = real_prev * curr_A;
            mult_B_c = -imag_prev * curr_B;
            mult_C_c = real_prev * curr_B;
            mult_D_c = -imag_prev * curr_A;
            state_c  = S2;
         end

         S2: begin
            // Perform dequantization and compute the final outputs:
            //   r = DEQUANTIZE_I(mult_A) - DEQUANTIZE_I(mult_B)
            //   i = DEQUANTIZE_I(mult_C) + DEQUANTIZE_I(mult_D)
            r_c = GLOBALS::DEQUANTIZE_I(mult_A) - GLOBALS::DEQUANTIZE_I(mult_B);
            i_c = GLOBALS::DEQUANTIZE_I(mult_C) + GLOBALS::DEQUANTIZE_I(mult_D);
            // If both output FIFOs are ready, drive the outputs and update the stored previous values.
            if (!out_full && !out2_full) begin
               out_din    = i;
               out_wr_en  = 1'b1;
               out2_din   = r;
               out2_wr_en = 1'b1;
               // Update the previous values with the newly read inputs so that they are used in the next computation.
               real_prev_c = curr_A;
               imag_prev_c = curr_B;
               state_c = S0;
            end
         end

         default: begin
            state_c       = S0;
            r_c           = 32'sd0;
            i_c           = 32'sd0;
            real_prev_c   = 32'sd0;
            imag_prev_c   = 32'sd0;
            curr_A_c      = 32'sd0;
            curr_B_c      = 32'sd0;
            mult_A_c      = 32'sd0;
            mult_B_c      = 32'sd0;
            mult_C_c      = 32'sd0;
            mult_D_c      = 32'sd0;
         end
      endcase
   end

endmodule


module demodulate_stage_2 (
    input  logic         clock,
    input  logic         reset,

    output logic         inA_rd_en,      
    input  logic         inA_empty,      
    input  logic signed [31:0] inA_dout,

    output logic         out_wr_en,     
    input  logic         out_full,       
    output logic signed [31:0] out_din    
);

   // Change state encoding to 2 bits for three states.
   typedef enum logic [1:0] {S0, S1, S2} state_t;
   state_t state, state_c;

   // Intermediate registers:
   // 'multiplied' holds the raw product from multiplication.
   // 'mult_result' holds the dequantized result.
   logic signed [31:0] multiplied, multiplied_c;
   logic signed [31:0] mult_result, mult_result_c;

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state       <= S0;
         multiplied  <= 32'sd0;
         mult_result <= 32'sd0;
      end else begin
         state       <= state_c;
         multiplied  <= multiplied_c;
         mult_result <= mult_result_c;
      end
   end

   always_comb begin
      // Default output and next-state assignments.
      inA_rd_en       = 1'b0;
      out_wr_en       = 1'b0;
      out_din         = 32'sd0;
      state_c         = state;
      multiplied_c    = multiplied;
      mult_result_c   = mult_result;

      case (state)
         S0: begin
            // Read input when available.
            if (!inA_empty) begin
               inA_rd_en = 1'b1;
               // Multiply the gain with the input.
               multiplied_c = GLOBALS::FM_DEMOD_GAIN * inA_dout;
               state_c = S1;
            end
         end

         S1: begin
            // Dequantize the multiplication result.
            mult_result_c = GLOBALS::DEQUANTIZE_I(multiplied);
            state_c = S2;
         end

         S2: begin
            // Write the dequantized result when output is available.
            if (!out_full) begin
               out_din   = mult_result;
               out_wr_en = 1'b1;
               state_c = S0;
            end
         end

         default: begin
            state_c         = S0;
            multiplied_c    = 32'sd0;
            mult_result_c   = 32'sd0;
         end
      endcase
   end
endmodule
`endif
