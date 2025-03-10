module multiply_two_inputs (
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
      inB_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;

      state_c = state;
      multiply_c   = multiply;

      case (state)
         S0: begin
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;

               multiply_c = GLOBALS::DEQUANTIZE_I(inA_dout * inB_dout);

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
