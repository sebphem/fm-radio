package GLOBALS;
    localparam BITS = 10;
    localparam QUANT_VAL = (1 << BITS);
    function int QUANTIZE_I(int i);
        return i * QUANT_VAL;
    endfunction
    function int DEQUANTIZE_I(int i);
        return i / QUANT_VAL;
    endfunction
    function automatic int QUANTIZE_F(input real f);
        return int'(f * QUANT_VAL);
    endfunction
    localparam VOLUME_LEVEL = QUANTIZE_F(1.0);
endpackage