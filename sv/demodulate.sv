module demodulate_two_inputs (
    input  logic         clock,
    input  logic         reset,

    output logic         inA_rd_en,      
    input  logic         inA_empty,      
    input  logic signed [31:0] inA_dout,

    output logic         inB_rd_en,      
    input  logic         inB_empty,     
    input  logic signed [31:0] inB_dout,

    output logic         out_real_wr_en,     
    input  logic         out_real_full,       
    output logic signed [31:0] out_real_din,

    output logic         out_imag_wr_en,
    input  logic         out_imag_full,
    output logic signed [31:0] out_imag_din    
);

   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   logic signed [31:0] reali, reali_c;
   logic signed [31:0] imag, imag_c;

   logic signed [31:0] real_prev, imag_prev;

   logic out_full;
   assign out_full = out_real_full || out_imag_full;

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state <= S0;
         reali   <= 32'sd0;
         imag   <= 32'sd0;
         real_prev <= 0;
         imag_prev <= 0;
      end else begin
         state <= state_c;
         imag   <= imag_c;
         reali <= reali_c;
         if(state_c == S1) begin
            real_prev <= reali;
            imag_prev <= imag;
         end
      end
   end

   always_comb begin
      inA_rd_en  = 1'b0;
      inB_rd_en  = 1'b0;
      out_real_wr_en  = 1'b0;
      out_imag_wr_en  = 1'b0;
      out_real_din    = 32'sd0;
      out_imag_din    = 32'sd0;

      state_c = state;
      reali_c   = reali;
      imag_c   = imag;

      case (state)
         S0: begin
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;

               reali_c = GLOBALS::DEQUANTIZE_I(inA_dout * inB_dout);
               imag_c = GLOBALS::DEQUANTIZE_I(inA_dout * inB_dout);
               state_c = S1;
            end
         end

         S1: begin
            if (!out_full) begin
               out_real_din = reali;
               out_imag_din = imag;
               out_real_wr_en = 1'b1;
               out_imag_wr_en = 1'b1;
               state_c = S0;
            end
         end

         default: begin
            state_c = S0;
            imag_c   = 32'sd0;
            reali_c   = 32'sd0;
         end
      endcase
   end
endmodule
