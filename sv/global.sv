`ifndef _GLOBALS_
`define _GLOBALS_

package GLOBALS;
    localparam BITS = 10;
    localparam QUANT_VAL = (1 << BITS);
    localparam DATA_WIDTH = 32;
    function logic signed [DATA_WIDTH-1:0] DEQUANTIZE_I(logic signed [DATA_WIDTH-1:0] i);
        if (i < 0) 
            DEQUANTIZE_I = DATA_WIDTH'(-(-i >>> BITS));
        else 
            DEQUANTIZE_I = DATA_WIDTH'(i >>> BITS);
    endfunction

    function logic signed [DATA_WIDTH-1:0] QUANTIZE_I(logic signed [DATA_WIDTH-1:0] i);
        QUANTIZE_I = DATA_WIDTH'(i << BITS);
    endfunction
    localparam PI_REAL = 3.1415926535897932384626433832795;
    localparam PI = 1610612736;
    localparam VOLUME_LEVEL = 1024;
    localparam AUDIO_DECIM = 8;
    localparam SAMPLES = 65536*4;
    localparam AUDIO_SAMPLES = SAMPLES/AUDIO_DECIM;
    localparam MAX_TAPS = 32;
    localparam IIR_COEFF_TAPS = 2;
    localparam IIR_COEFF_TAP_BITS = 1;

    localparam ADC_RATE = 64000000;
    localparam USRP_DECIM = 250;
    localparam MAX_DEV = 55000.0;
    localparam QUAD_RATE = 256000;
    localparam FM_DEMOD_GAIN = 758;
endpackage
`endif