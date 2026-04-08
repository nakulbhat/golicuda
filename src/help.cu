#include <stdio.h>

#define OPT(fmt, desc) fprintf(stderr, "  %-26s %s\n", fmt, desc)

void emit_help(const char *prog_name) {
    fprintf(stderr,
            "golicuda --- Conway's Game of Life (CUDA accelerated)\n"
            "\n"
            "USAGE:\n"
            "  %s [OPTIONS] [CELLS...]\n"
            "\n",
            prog_name);

    fprintf(stderr, "DESCRIPTION:\n");
    fprintf(stderr,
            "  Simulates Conway's Game of Life using CUDA acceleration.\n"
            "  You can specify grid size, initial fill, CUDA execution mode,\n"
            "  number of generations, or load patterns from RLE files.\n"
            "\n");

    fprintf(stderr, "OPTIONS:\n");
    OPT("-h, --help", "Show this help message");
    OPT("-v, --verbose", "Enable verbose logging");
    OPT("-s, --size <WxH|preset>", "Grid size (e.g. 50,50 | 720p | 1080p | 4k)");
    OPT("-r, --rowwise", "Row-wise CUDA execution");
    OPT("-c, --colwise", "Column-wise CUDA execution");
    OPT("-e, --element", "Element-wise CUDA execution (default)");
    OPT("-f, --fill <0-100>", "Random fill percentage");
    OPT("-n, --gens <num>", "Number of generations");
    OPT("-l, --rle <file>", "Load pattern from RLE file");
    fprintf(stderr, "\n");

    fprintf(stderr, "CUDA MODES:\n");
    fprintf(stderr,
            "  Only one CUDA mode may be specified:\n"
            "\n"
            "    -r  Row-wise parallelism\n"
            "    -c  Column-wise parallelism\n"
            "    -e  Element-wise parallelism (default)\n"
            "\n");

    fprintf(stderr, "GRID SIZE:\n");
    fprintf(stderr,
            "  Grid size may be specified using:\n"
            "\n"
            "  Presets:\n"
            "    720p      1280x720\n"
            "    1080p     1920x1080\n"
            "    4k        3840x2160\n"
            "\n"
            "  Custom:\n"
            "    WIDTH,HEIGHT\n"
            "    Example: 100,100\n"
            "\n");

    fprintf(stderr, "CELLS:\n");
    fprintf(stderr,
            "  You may provide initial live cells as coordinates:\n"
            "\n"
            "    X,Y\n"
            "\n"
            "  Example:\n"
            "    %s 10,10 10,11 10,12\n"
            "\n",
            prog_name);

    fprintf(stderr, "EXAMPLES:\n");
    fprintf(stderr,
            "  Run with default settings\n"
            "    %s\n"
            "\n"
            "  Custom grid size\n"
            "    %s -s 100,100\n"
            "\n"
            "  Random fill\n"
            "    %s -f 30\n"
            "\n"
            "  Run for fixed generations\n"
            "    %s -n 500\n"
            "\n"
            "  Load RLE pattern\n"
            "    %s -l glider.rle\n"
            "\n"
            "  CUDA row-wise mode\n"
            "    %s -r\n"
            "\n",
            prog_name,
            prog_name,
            prog_name,
            prog_name,
            prog_name,
            prog_name);

    fprintf(stderr,
            "NOTES:\n"
            "  + If no CUDA mode is specified, element-wise is used\n"
            "  + Cell coordinates are zero-based\n"
            "  + Multiple cells may be specified\n"
            "\n");
}
