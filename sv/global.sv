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
    function automatic real DEQUANTIZE_F(input int i);
        return real'(i) / real'(QUANT_VAL);
    endfunction
    localparam PI_REAL = 3.1415926535897932385;
    localparam PI = QUANTIZE_F(PI_REAL);
    localparam VOLUME_LEVEL = QUANTIZE_F(1.0);
    localparam ADUIO_DECIM = 8;
    localparam SAMPLES = 65536*4;
    localparam AUDIO_SAMPLES = SAMPLES/ADUIO_DECIM;
    localparam MAX_TAPS = 32;
    localparam IIR_COEFF_TAPS = 2;
    localparam IIR_COEFF_TAP_BITS = 1;

    localparam ADC_RATE = 64000000;
    localparam USRP_DECIM = 250;
    localparam MAX_DEV = 55000.0;
    localparam QUAD_RATE = int'(ADC_RATE / USRP_DECIM);
    localparam FM_DEMOD_GAIN = QUANTIZE_F(QUAD_RATE / (2.0 * PI_REAL * MAX_DEV));
endpackage