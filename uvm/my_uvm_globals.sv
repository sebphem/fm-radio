`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam int CLOCK_PERIOD = 10;
localparam int DATA_WIDTH = 32;
localparam string DATA_IN_NAME  = "IQ.bin";
localparam string LEFT_AUDIO_FILE = "left_audio_sv.bin";
localparam string RIGHT_AUDIO_FILE = "right_audio_sv.bin";
localparam string LEFT_CMP_FILE = "left_audio.bin";
localparam string RIGHT_CMP_FILE = "right_audio.bin";
localparam int F_ELEMS = 3200;
localparam int BYTES_PER_ELEMENT = 4;

`endif
