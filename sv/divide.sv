module divide_two_inputs (
    input  logic                    clock,
    input  logic                    reset,

    // Input FIFO interface
    output logic                    inA_rd_en,      
    input  logic                    inA_empty,      
    input  logic signed [31:0]      inA_dout,  

    output logic                    inB_rd_en,      
    input  logic                    inB_empty,     
    input  logic signed [31:0]      inB_dout, 

    // Output FIFO interface
    output logic                    out_wr_en,     
    input  logic                    out_full,       
    output logic signed [31:0]      out_din   
);

   parameter WIDTH  = 32;
   parameter STAGES = 32;

   //-------------------------------------------------------------------------
   // Latch input operands and compute absolute values and sign.
   // A new operation is launched when both input FIFOs have data and the output
   // FIFO is not full.
   //-------------------------------------------------------------------------
   logic [WIDTH-1:0] dividend_abs, divisor_abs;
   logic             op_sign;
   logic             op_valid;

   assign inA_rd_en = (!inA_empty && !inB_empty && !out_full);
   assign inB_rd_en = (!inA_empty && !inB_empty && !out_full);

   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         dividend_abs <= '0;
         divisor_abs  <= '0;
         op_sign      <= 1'b0;
         op_valid     <= 1'b0;
      end else begin
         if (inA_rd_en) begin
            // Compute absolute values.
            dividend_abs <= (inA_dout[WIDTH-1]) ? -inA_dout : inA_dout;
            divisor_abs  <= (inB_dout[WIDTH-1]) ? -inB_dout : inB_dout;
            op_sign      <= inA_dout[WIDTH-1] ^ inB_dout[WIDTH-1];
            op_valid     <= 1'b1;
         end else begin
            op_valid <= 1'b0;
         end
      end
   end

   //-------------------------------------------------------------------------
   // Pipeline op_valid so that the final result is output after a fixed latency.
   //-------------------------------------------------------------------------
   logic op_pipe [0:STAGES];
   always_ff @(posedge clock or posedge reset) begin
      if (reset)
         op_pipe[0] <= 1'b0;
      else
         op_pipe[0] <= op_valid;
   end

   genvar j;
   generate
     for (j = 0; j < STAGES; j = j + 1) begin : op_pipe_gen
       always_ff @(posedge clock or posedge reset) begin
          if (reset)
             op_pipe[j+1] <= 1'b0;
          else
             op_pipe[j+1] <= op_pipe[j];
       end
     end
   endgenerate

   //-------------------------------------------------------------------------
   // Pipeline the op_sign so that the sign correction is aligned with the result.
   //-------------------------------------------------------------------------
   logic op_sign_pipe [0:STAGES];
   always_ff @(posedge clock or posedge reset) begin
      if (reset)
         op_sign_pipe[0] <= 1'b0;
      else if (op_valid)
         op_sign_pipe[0] <= op_sign;
      // else: if no new op, we inject a bubble (the value won’t be used because op_pipe will be 0)
   end

   generate
     for (j = 0; j < STAGES; j = j + 1) begin : sign_pipe
       always_ff @(posedge clock or posedge reset) begin
          if (reset)
             op_sign_pipe[j+1] <= 1'b0;
          else
             op_sign_pipe[j+1] <= op_sign_pipe[j];
       end
     end
   endgenerate

   //-------------------------------------------------------------------------
   // Arithmetic pipeline arrays.
   // These hold the running remainder, quotient, and an arithmetic valid flag.
   // Every operation flows through the same pipeline.
   //-------------------------------------------------------------------------
   logic [WIDTH-1:0] rem_pipe  [0:STAGES];
   logic [WIDTH-1:0] quot_pipe [0:STAGES];
   logic             valid_pipe[0:STAGES];

   //-------------------------------------------------------------------------
   // Stage 0: Always update with new inputs if available; otherwise, inject a bubble.
   // This avoids holding a previous value that would collide with later operations.
   //-------------------------------------------------------------------------
   always_ff @(posedge clock or posedge reset) begin
      if (reset) begin
         rem_pipe[0]   <= '0;
         quot_pipe[0]  <= '0;
         valid_pipe[0] <= 1'b0;
      end else begin
         if (op_valid) begin
            // Special-case: if divisor==1, simply set quotient to the dividend.
            if (divisor_abs == 1) begin
               quot_pipe[0]  <= dividend_abs;
               rem_pipe[0]   <= '0;
               valid_pipe[0] <= 1'b0;
            end else begin
               rem_pipe[0]   <= dividend_abs;
               quot_pipe[0]  <= '0;
               valid_pipe[0] <= (dividend_abs >= divisor_abs);
            end
         end else begin
            // Inject a bubble.
            rem_pipe[0]   <= '0;
            quot_pipe[0]  <= '0;
            valid_pipe[0] <= 1'b0;
         end
      end
   end

   //-------------------------------------------------------------------------
   // Helper function: returns the index of the most-significant 1 in x.
   // (Some synthesis tools support a CLZ operator instead.)
   //-------------------------------------------------------------------------
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

   //-------------------------------------------------------------------------
   // Pipeline stages for the iterative division.
   // When valid_pipe is true, perform one subtraction iteration;
   // once the arithmetic is complete (valid becomes false), simply propagate the values.
   //-------------------------------------------------------------------------
   genvar i;
   generate
     for (i = 0; i < STAGES; i = i + 1) begin : div_stage
       always_ff @(posedge clock or posedge reset) begin
          if (reset) begin
             quot_pipe[i+1]  <= '0;
             rem_pipe[i+1]   <= '0;
             valid_pipe[i+1] <= 1'b0;
          end else if (valid_pipe[i]) begin
             int msb_rem_val;
             int msb_div_val;
             int p_temp;
             int p;
             msb_rem_val = msb(rem_pipe[i]);
             msb_div_val = msb(divisor_abs);
             p_temp = msb_rem_val - msb_div_val;
             if (p_temp > 0) begin
                if ((divisor_abs << p_temp) > rem_pipe[i])
                   p = p_temp - 1;
                else
                   p = p_temp;
             end else begin
                p = 0;
             end
             quot_pipe[i+1]  <= quot_pipe[i] + (1 << p);
             rem_pipe[i+1]   <= rem_pipe[i] - (divisor_abs << p);
             valid_pipe[i+1] <= ((rem_pipe[i] - (divisor_abs << p)) >= divisor_abs);
          end else begin
             // Propagate bubble.
             quot_pipe[i+1]  <= quot_pipe[i];
             rem_pipe[i+1]   <= rem_pipe[i];
             valid_pipe[i+1] <= 1'b0;
          end
       end
     end
   endgenerate

   //-------------------------------------------------------------------------
   // Final quotient selection and sign correction.
   //-------------------------------------------------------------------------
   logic [WIDTH-1:0] final_quot;
   assign final_quot = quot_pipe[STAGES];
   assign out_din    = op_pipe[STAGES] ? (op_sign_pipe[STAGES] ? -final_quot : final_quot) : '0;

   //-------------------------------------------------------------------------
   // Output handshake.
   // The result is released when the operation pipeline (op_pipe) indicates an active operation.
   //-------------------------------------------------------------------------
   assign out_wr_en = (!out_full) && op_pipe[STAGES];

endmodule