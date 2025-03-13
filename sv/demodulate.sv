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
           .FIFO_BUFFER_SIZE(256),
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
           .FIFO_BUFFER_SIZE(256),
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
           .FIFO_BUFFER_SIZE(256),
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
   
   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   logic signed [31:0] real_prev, real_prev_c;
   logic signed [31:0] imag_prev, imag_prev_c;

   logic signed [31:0] r, r_c;
   logic signed [31:0] i, i_c;

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state <= S0;
         r   <= 32'sd0;
         i   <= 32'sd0;
         real_prev <= 32'sd0;
         imag_prev <= 32'sd0;
      end else begin
         state <= state_c;
         r   <= r_c;
         i <= i_c;
         real_prev <= real_prev_c;
         imag_prev <= imag_prev_c;
      end
   end

   always_comb begin
      inA_rd_en  = 1'b0;
      inB_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;
      out2_wr_en  = 1'b0;
      out2_din    = 32'sd0;

      state_c = state;
      r_c   = r;
      i_c   = i;
      real_prev_c = real_prev;
      imag_prev_c = imag_prev;
      
      case (state)
         S0: begin
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;
               r_c = GLOBALS::DEQUANTIZE_I(real_prev * inA_dout) - GLOBALS::DEQUANTIZE_I(-imag_prev * inB_dout);
               i_c = GLOBALS::DEQUANTIZE_I(real_prev * inB_dout) + GLOBALS::DEQUANTIZE_I(-imag_prev * inA_dout);
               real_prev_c = inA_dout;
               imag_prev_c = inB_dout;
               state_c = S1;
            end
         end

         S1: begin
            if (!out_full && !out2_full) begin
               out_din   = r;
               out_wr_en = 1'b1;
               out2_din = i;
               out2_wr_en = 1'b1;
               state_c = S0;
            end
         end

         default: begin
            state_c = S0;
            r_c   = 32'sd0;
            i_c =  32'sd0;
            real_prev_c = 32'sd0;
            imag_prev_c = 32'sd0;
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

   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   logic signed [31:0] multiply, multiply_c;

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state <= S0;
         multiply   <= 32'sd0;
      end else begin
         state <= state_c;
         multiply   <= multiply_c;
      end
   end

   always_comb begin
      inA_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;

      state_c = state;
      multiply_c   = multiply;

      case (state)
         S0: begin
            if (!inA_empty) begin
               inA_rd_en = 1'b1;
               //*demod_out = DEQUANTIZE(gain * qarctan(i, r));
               multiply_c = GLOBALS::DEQUANTIZE_I(GLOBALS::FM_DEMOD_GAIN * inA_dout);
               state_c = S1;
            end
         end

         S1: begin
            if (!out_full) begin
               out_din   = multiply;
               out_wr_en = 1'b1;
               state_c = S0;
            end
         end

         default: begin
            state_c = S0;
            multiply_c   = 32'sd0;
         end
      endcase
   end
endmodule
