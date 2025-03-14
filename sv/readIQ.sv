module read_iq (
    input  logic         clock,
    input  logic         reset,

    // FIFO in
    output logic         inA_rd_en,      
    input  logic         inA_empty,      
    input  logic [31:0]  inA_dout,

    // FIFO out #1
    output logic         out_wr_en,     
    input  logic         out_full,       
    output logic signed [31:0] out_din,  

    // FIFO out #2
    output logic         out_wr_en_2,     
    input  logic         out_full_2,       
    output logic signed [31:0] out_din_2
);

   // Simple FSM states
   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   // Latched I, Q
   logic signed [31:0] I, I_c;
   logic signed [31:0] Q, Q_c;

   // State & data registers
   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state <= S0;
         I     <= 32'sd0;
         Q     <= 32'sd0;
      end else begin
         state <= state_c;
         I     <= I_c;
         Q     <= Q_c;
      end
   end

   // Byte slices for I & Q
   logic signed  [7:0] I_1;
   logic signed [7:0] I_2;
   logic signed [7:0] Q_1;
   logic  signed [7:0] Q_2;
   logic signed [31:0] tmpI;
   logic signed [31:0] tmpQ;
   always_comb begin
      // Defaults
      inA_rd_en   = 1'b0;

      out_wr_en   = 1'b0;
      out_din     = 32'sd0;

      out_wr_en_2 = 1'b0;
      out_din_2   = 32'sd0;

      state_c     = state;
      I_c         = I;
      Q_c         = Q;
      Q_1 = 8'sd0;
      Q_2 = 8'sd0;
      I_1 = 8'sd0;
      I_2 = 8'sd0;
      tmpI = 32'sd0;
      tmpQ = 32'sd0;

      case (state)
         S0: begin
            // Wait for input FIFO to have data
            if (!inA_empty) begin
               inA_rd_en = 1'b1;

               // According to the C code layout:
               //   IQ[i*4+0] => inA_dout[ 7: 0]  (LSB of I)
               //   IQ[i*4+1] => inA_dout[15: 8] (MSB of I)
               //   IQ[i*4+2] => inA_dout[23:16] (LSB of Q)
               //   IQ[i*4+3] => inA_dout[31:24] (MSB of Q)

               Q_1 = inA_dout[7:0];     // LSB for I
               Q_2 = inA_dout[15:8];    // MSB for I
               I_1 = inA_dout[23:16];   // LSB for Q
               I_2 = inA_dout[31:24];   // MSB for Q
               tmpI = $signed({I_1, I_2});
               tmpQ =  $signed({Q_1, Q_2});
               // Convert to 16-bit signed, then quantize
               // Must do {MSB, LSB} for correct endianness:
               Q_c = GLOBALS::QUANTIZE_I( tmpQ);
               I_c = GLOBALS::QUANTIZE_I( tmpI);

               state_c = S1;
            end

         end

         S1: begin
            // Wait for output FIFO to be ready (not full)
            if (!out_full && !out_full_2) begin
               out_din   = I;
               out_wr_en = 1'b1;

               out_din_2   = Q;
               out_wr_en_2 = 1'b1;
               $display("writing out i=%d", I);
               $display("writing out q=%d", Q);
               state_c = S0;
            end
         end

         default: begin
            state_c = S0;
            I_c     = 32'sd0;
            Q_c     = 32'sd0;

         end
      endcase
   end
endmodule
