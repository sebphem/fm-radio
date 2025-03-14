`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam int CLOCK_PERIOD = 10;
localparam int DATA_WIDTH = 32;
localparam string DATA_IN_NAME  = "in.bin";
localparam string LEFT_AUDIO_FILE = "outL.txt";
localparam string RIGHT_AUDIO_FILE = "outR.txt";
localparam string LEFT_CMP_FILE = "cmpL.txt";
localparam string RIGHT_CMP_FILE = "cmpR.txt";
localparam int F_ELEMS = 200;
localparam int BYTES_PER_ELEMENT = 4;

`endif
