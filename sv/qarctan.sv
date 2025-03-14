`ifndef _QARC_
`define _QARC_

`include "global.sv"
`include "fifo.sv"
`include "divide.sv"
/*
int qarctan(int y, int x)
{
    const int quad1 = QUANTIZE_F(PI / 4.0);
    const int quad3 = QUANTIZE_F(3.0 * PI / 4.0);

    int abs_y = abs(y) + 1;
    int angle = 0; 
    int r = 0;

    if ( x >= 0 ) 
    {
        r = QUANTIZE_I(x - abs_y) / (x + abs_y);
        angle = quad1 - DEQUANTIZE(quad1 * r);
    } 
    else 
    {
        r = QUANTIZE_I(x + abs_y) / (abs_y - x);
        angle = quad3 - DEQUANTIZE(quad1 * r);
    }

    return ((y < 0) ? -angle : angle);     // negate if in quad III or IV
}
*/
module qarctan_two_inputs (
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
   // and FIFOs 3/4 for 1 bit signals
   logic stage_1_out_full3;
   logic stage_1_out_wr_en3;
   logic stage_1_out_rd_en3;
   logic stage_1_out_empty3;
   logic stage_1_out_full4;
   logic stage_1_out_wr_en4;
   logic stage_1_out_rd_en4;
   logic stage_1_out_empty4;
   logic stage_1_out_din3;
   logic stage_1_out_dout3;
   logic stage_1_out_din4;
   logic stage_1_out_dout4;

   fifo #(
           .FIFO_BUFFER_SIZE(32),
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
           .FIFO_BUFFER_SIZE(32),
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

   fifo #(
           .FIFO_BUFFER_SIZE(32),
           .FIFO_DATA_WIDTH(1)
   ) stage_1_out_fifo3 (
       .reset(reset),
       .wr_clk(clock),
       .wr_en(stage_1_out_wr_en3),
       .din(stage_1_out_din3),
       .full(stage_1_out_full3),
       .rd_clk(clock),
       .rd_en(stage_1_out_rd_en3),
       .dout(stage_1_out_dout3),
       .empty(stage_1_out_empty3)
   );

   fifo #(
           .FIFO_BUFFER_SIZE(32),
           .FIFO_DATA_WIDTH(1)
   ) stage_1_out_fifo4 (
       .reset(reset),
       .wr_clk(clock),
       .wr_en(stage_1_out_wr_en4),
       .din(stage_1_out_din4),
       .full(stage_1_out_full4),
       .rd_clk(clock),
       .rd_en(stage_1_out_rd_en4),
       .dout(stage_1_out_dout4),
       .empty(stage_1_out_empty4)
   );

   qarctan_stage_1 stage_1_inst (
       .clock(clock),
       .reset(reset),
       .inA_rd_en(inA_rd_en),
       .inA_empty(inA_empty),
       .inA_dout(inA_dout),
       .inB_rd_en(inB_rd_en),
       .inB_empty(inB_empty),
       .inB_dout(inB_dout),
       .out_wr_en(stage_1_out_wr_en1),
       .out_full(stage_1_out_full1 || stage_1_out_full2 || stage_1_out_full3 || stage_1_out_full4),
       .out_din(stage_1_out_din1),
       .out_wr_en2(stage_1_out_wr_en2),
       .out_full2(stage_1_out_full2),
       .out_din2(stage_1_out_din2),
         .out_b_greater_0_en(stage_1_out_wr_en3),
         .out_b_greater_0_full(stage_1_out_full3),
         .out_b_greater_0_din(stage_1_out_din3),
         .out_a_less_0_en(stage_1_out_wr_en4),
         .out_a_less_0_full(stage_1_out_full4),
         .out_a_less_0_din(stage_1_out_din4)
   ); 

   logic qarctan_out_full;
   logic qarctan_out_wr_en;
   logic signed [31:0] qarctan_out_din;
   logic qarctan_out_rd_en;
   logic qarctan_out_empty;
   logic signed [31:0] divide_out_dout;

   fifo #(
           .FIFO_BUFFER_SIZE(32),
           .FIFO_DATA_WIDTH(32)
   ) qarctan_out_fifo (
       .reset(reset),
       .wr_clk(clock),
       .wr_en(qarctan_out_wr_en),
       .din(qarctan_out_din),
       .full(qarctan_out_full),
       .rd_clk(clock),
       .rd_en(qarctan_out_rd_en),
       .dout(divide_out_dout),
       .empty(qarctan_out_empty)
   );

   divide_two_inputs qarctan_inst (
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

   qarctan_stage_3 stage_2_inst (
       .clock(clock),
       .reset(reset),
       .inA_rd_en(qarctan_out_rd_en),
       .inA_empty(qarctan_out_empty),
       .inA_dout(divide_out_dout),
         .inB_rd_en(stage_1_out_rd_en3),
         .inB_empty(stage_1_out_empty3),
         .inB_dout(stage_1_out_dout3),
         .inC_rd_en(stage_1_out_rd_en4),
         .inC_empty(stage_1_out_empty4),
         .inC_dout(stage_1_out_dout4),
       .out_wr_en(out_wr_en),
       .out_full(out_full),
       .out_din(out_din)
   );
endmodule


module qarctan_stage_1 (
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

    output logic         out_wr_en2,     
    input  logic         out_full2,       
    output logic signed [31:0] out_din2,

    output logic         out_b_greater_0_en,     
    input  logic         out_b_greater_0_full,    
    output logic  out_b_greater_0_din,

      output logic         out_a_less_0_en,
      input  logic         out_a_less_0_full,
      output logic  out_a_less_0_din
);
   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   logic signed [31:0] multiply, multiply_c;
   logic signed [31:0] multiply2, multiply2_c;
    logic  multiply3, multiply3_c;
 logic  multiply4, multiply4_c;
   logic signed [31:0] abs_y;
   logic signed [31:0] angle;
   logic signed [31:0] r;

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state <= S0;
         multiply   <= 32'sd0;
         multiply2   <= 32'sd0;
         multiply3   <= 1'b0;
         multiply4   <= 1'b0;
      end else begin
         state <= state_c;
         multiply   <= multiply_c;
         multiply2   <= multiply2_c;
         multiply3   <= multiply3_c;
         multiply4   <= multiply4_c;
      end
   end
   always_comb begin
      inA_rd_en  = 1'b0;
      inB_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_wr_en2 = 1'b0;
      out_din    = 32'sd0;
      out_din2    = 32'sd0;
      out_b_greater_0_en = 1'b0;
      out_a_less_0_en = 1'b0;
      out_b_greater_0_din = 0;
      out_a_less_0_din = 32'sd0;
      state_c = state;
      multiply_c   = multiply;
      multiply2_c   = multiply2;
      multiply3_c   = multiply3;
      multiply4_c   = multiply4;

      abs_y = ((inA_dout < 0) ? -inA_dout : inA_dout) + 1;
      r = 0;
      angle = 0;

      case (state)
         S0: begin
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;
               if(inB_dout >= 0) begin
                  multiply_c = GLOBALS::QUANTIZE_I(inB_dout - abs_y);
                  multiply2_c = (inB_dout + abs_y);
                  multiply3_c = 1'b1;
               end else begin
                  multiply_c = GLOBALS::QUANTIZE_I(inB_dout + abs_y);
                  multiply2_c = (abs_y - inB_dout);
                  multiply3_c = 1'b0;
               end
               if(inA_dout < 0) begin 
                  multiply4_c = 1'b1;
               end
               else 
                  multiply4_c = 1'b0;
               state_c = S1;
            end
         end

         S1: begin
            if (!out_full) begin
               out_din   = multiply;
               out_wr_en = 1'b1;
               out_din2   = multiply2;
               out_wr_en2 = 1'b1;
               out_b_greater_0_din = multiply3;
               out_b_greater_0_en = 1'b1;
               out_a_less_0_din = multiply4;
               out_a_less_0_en = 1'b1;
               state_c = S0;
            end
         end

         default: begin
            state_c = S0;
            multiply_c   = 32'sd0;
            multiply2_c   = 32'sd0;
            multiply3_c   = 1'b0;
            multiply4_c   = 1'b0;
         end
      endcase
   end
endmodule
module qarctan_stage_3 (
    input  logic         clock,
    input  logic         reset,

    output logic         inA_rd_en,      
    input  logic         inA_empty,      
    input  logic signed [31:0] inA_dout,

    output logic         inB_rd_en,      
    input  logic         inB_empty,     
    input  logic         inB_dout,

    output logic         inC_rd_en,      
    input  logic         inC_empty,      
    input  logic         inC_dout,

    output logic         out_wr_en,     
    input  logic         out_full,       
    output logic signed [31:0] out_din    
);
   // Parameters for quadrant values
   localparam logic signed [31:0] quad1 = 804;
   localparam logic signed [31:0] quad3 = 2412;
   
   // With three states we need 2 bits for the enum.
   typedef enum logic [1:0] {S0, S1, S2} state_t;
   state_t state, state_c;

   // The result of the multiplication, which is passed along the pipeline.
   logic signed [31:0] multiply, multiply_c;
   
   // Intermediate value computed in S0
   logic signed [31:0] angle;
   // Register the angle so it is available in S1
   logic signed [31:0] angle_reg;
   // Register inC_dout to hold its value from S0 into S1
   logic              inC_dout_reg;

   // Synchronous state and pipeline registers update.
   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state         <= S0;
         multiply      <= 32'sd0;
         angle_reg     <= 32'sd0;
         inC_dout_reg  <= 1'b0;
      end else begin
         state         <= state_c;
         multiply      <= multiply_c;
         // When in S0 we sample the inputs and register the computed angle
         if (state == S0 && !inA_empty && !inB_empty && !inC_empty) begin
            angle_reg    <= angle;
            inC_dout_reg <= inC_dout;
         end
      end
   end

   // Combinational logic for the state machine
   always_comb begin
      // Default assignments for outputs and next state values.
      inA_rd_en  = 1'b0;
      inB_rd_en  = 1'b0;
      inC_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;

      state_c    = state;
      multiply_c = multiply;
      
      // Default value for angle
      angle = 32'sd0;

      case (state)
         S0: begin
            // Check if all inputs are available.
            if (!inA_empty && !inB_empty && !inC_empty) begin
               // Read inputs.
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;
               inC_rd_en = 1'b1;
               // Compute the angle based on the quadrant indicated by inB_dout.
               if (inB_dout == 1'b1) begin
                  angle = quad1 - GLOBALS::DEQUANTIZE_I(quad1 * inA_dout);
               end else begin
                  angle = quad3 - GLOBALS::DEQUANTIZE_I(quad1 * inA_dout);
               end
               // Transition to the multiplication state.
               state_c = S1;
            end
         end

         S1: begin
            // Use the registered angle and inC_dout value to perform the multiplication.
            multiply_c = (inC_dout_reg == 1'b1) ? -angle_reg : angle_reg;
            // Transition to the output state.
            state_c = S2;
         end

         S2: begin
            // If the output FIFO is not full, write the multiplication result.
            if (!out_full) begin
               out_din   = multiply;
               out_wr_en = 1'b1;
               state_c   = S0;
            end
         end

         default: begin
            state_c    = S0;
            multiply_c = 32'sd0;
         end
      endcase
   end
endmodule
`endif
