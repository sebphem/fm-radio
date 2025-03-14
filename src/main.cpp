

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <io.h>
#include <unistd.h>

#include "fm_radio.h"
// #include "audio.h"

using namespace std;

int main(int argc, char **argv)
{
    static unsigned char IQ[SAMPLES*4];
    static int left_audio[AUDIO_SAMPLES];
    static int right_audio[AUDIO_SAMPLES];

    if ( argc < 2 )
    {
        printf("Missing input file.\n");
        return -1;
    }
    
    // initialize the audio output
    // int audio_fd = audio_init( AUDIO_RATE );
    // if ( audio_fd < 0 )
    // {
    //     printf("Failed to initialize audio!\n");
    //     return -1;
    // }

    FILE * usrp_file = fopen(argv[1], "rb");
    if ( usrp_file == NULL )
    {
        printf("Unable to open file.\n");
        return -1;
    }    
    /* Open all the test files to empty them */
    FILE* fp1 = fopen("../test/readIQ/a.txt", "w");
    FILE* fp2 = fopen("../test/readIQ/cmpI.txt", "w");
    FILE* fp3 = fopen("../test/readIQ/cmpQ.txt", "w");
    FILE* fp4 = fopen("../test/add/a.txt", "w");
    FILE* fp5 = fopen("../test/add/b.txt", "w");
    FILE* fp6 = fopen("../test/add/cmp.txt", "w");
    FILE* fp7 = fopen("../test/sub/a.txt", "w");
    FILE* fp8 = fopen("../test/sub/b.txt", "w");
    FILE* fp9 = fopen("../test/sub/cmp.txt", "w");
    FILE* fp10 = fopen("../test/qarctan/a.txt", "w");
    FILE* fp11 = fopen("../test/qarctan/b.txt", "w");
    FILE* fp12 = fopen("../test/qarctan/cmp.txt", "w");
    FILE* fp13 = fopen("../test/demodulate/a.txt", "w");
    FILE* fp14 = fopen("../test/demodulate/b.txt", "w");
    FILE* fp15 = fopen("../test/demodulate/cmp.txt", "w");
    FILE* fp16 = fopen("../test/gain/a.txt", "w");
    FILE* fp17 = fopen("../test/gain/cmp.txt", "w");
    FILE* fp18 = fopen("../test/divide/a.txt", "w");   
    FILE* fp19 = fopen("../test/divide/b.txt", "w");  
    FILE* fp20 = fopen("../test/divide/cmp.txt", "w");
    FILE* fp21 = fopen("../test/multiply/a.txt", "w"); 
    FILE* fp22 = fopen("../test/multiply/b.txt", "w");
    FILE* fp23 = fopen("../test/multiply/cmp.txt", "w");
    /* close all files */
    fclose(fp1);
    fclose(fp2);
    fclose(fp3);
    fclose(fp4);
    fclose(fp5);
    fclose(fp6);
    fclose(fp7);
    fclose(fp8);
    fclose(fp9);
    fclose(fp10);
    fclose(fp11);
    fclose(fp12);
    fclose(fp13);
    fclose(fp14);
    fclose(fp15);
    fclose(fp16);
    fclose(fp17);
    fclose(fp18);
    fclose(fp19);
    fclose(fp20);
    fclose(fp21);
    fclose(fp22);
    fclose(fp23);

    // run the FM receiver 
    int i = 0;
    while( !feof(usrp_file) && i < 1)
    {
        // get I/Q from data file
        fread( IQ, sizeof(char), SAMPLES*4, usrp_file );

        // fm radio in mono
        fm_radio_stereo( IQ, left_audio, right_audio );
        i++;
        // write to audio output
        // audio_tx( audio_fd, AUDIO_RATE, left_audio, right_audio, AUDIO_SAMPLES );
    }

    fclose( usrp_file );
    // close( audio_fd );

    return 0;
}

