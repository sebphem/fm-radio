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
   localparam logic signed [31:0] quad1 = 804;
   localparam logic signed [31:0] quad3 = 2412;
   
   typedef enum logic [0:0] {S0, S1} state_t;
   state_t state, state_c;

   logic signed [31:0] multiply, multiply_c;
   
   
   logic signed [31:0] abs_y;
   logic signed [31:0] angle;
   logic signed [31:0] r;

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
      
      assign abs_y = ((inA_dout < 0) ? -inA_dout : inA_dout) + 1;
      r = 0;
      angle = 0;

      case (state)
         S0: begin
            if (!inA_empty && !inB_empty) begin
               inA_rd_en = 1'b1;
               inB_rd_en = 1'b1;
               if(inB_dout >= 0) begin
                  r = GLOBALS::QUANTIZE_I(inB_dout - abs_y) / (inB_dout + abs_y);
                  angle = quad1 - GLOBALS::DEQUANTIZE_I(quad1 * r);
               end else begin
                  r = GLOBALS::QUANTIZE_I(inB_dout + abs_y) / (abs_y - inB_dout);
                  angle = quad3 - GLOBALS::DEQUANTIZE_I(quad1 * r);
               end
               
               multiply_c = (inA_dout < 0) ? -angle : angle;
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