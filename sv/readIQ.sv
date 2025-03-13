module read_iq (
    input  logic         clock,
    input  logic         reset,

    output logic         inA_rd_en,      
    input  logic         inA_empty,      
    input  logic    [63:0] inA_dout,

    output logic         out_wr_en,     
    input  logic         out_full,       
    output logic signed [31:0] out_din,  

    output logic         out_wr_en_2,     
    input  logic         out_full_2,       
    output logic signed [31:0] out_din_2
);

   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   logic signed [31:0] I, I_c;
   logic signed [31:0] Q, Q_c;

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         state <= S0;
         I   <= 32'sd0;
         Q   <= 32'sd0;
      end else begin
         state <= state_c;
         I   <= I_c;
         Q  <= Q_c;
      end
   end
   logic signed [15:0] I_1;
   logic signed [15:0] I_2;
    logic signed [15:0] Q_1;
    logic signed [15:0] Q_2;
   always_comb begin
      inA_rd_en  = 1'b0;
      out_wr_en  = 1'b0;
      out_din    = 32'sd0;
      out_wr_en_2  = 1'b0;
      out_din_2    = 32'sd0;
      state_c = state;
      I_c   = I;
      Q_c   = Q;
      case (state)
         S0: begin
            if (!inA_empty) begin
               inA_rd_en = 1'b1;
               I_1 = inA_dout[63:48];
               I_2 = inA_dout[47:32];
               Q_1 = inA_dout[31:16];
               Q_2 = inA_dout[15:0];
               I_c = GLOBALS::QUANTIZE_I({I_2, I_1});
               Q_c = GLOBALS::QUANTIZE_I({Q_2, Q_1});
               state_c = S1;
            end
         end

         S1: begin
            if (!out_full) begin
               out_din   = I;
               out_wr_en = 1'b1;
               out_din_2   = Q;
               out_wr_en_2 = 1'b1;
               state_c = S0;
            end
         end

         default: begin
            state_c = S0;
            I_c   = 32'sd0;
            Q_c   = 32'sd0;
         end
      endcase
   end
endmodule
