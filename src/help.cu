#include <stdio.h>

#define OPT(fmt, desc) fprintf(stderr, "  %-22s %s\n", fmt, desc)

void emit_help(const char *prog) {
    fprintf(stderr,
        "golicuda — CUDA Conway's Game of Life\n\n"
        "USAGE:\n"
        "  %s [OPTIONS] [CELLS...]\n\n",
        prog);

    fprintf(stderr, "OPTIONS:\n");
    OPT("-h, --help", "Show this help");
    OPT("-v, --verbose", "Verbose logging");
    OPT("-s, --size <WxH|preset>", "Grid size (100x100 default)");
    OPT("-r, --rowwise", "Row-wise CUDA");
    OPT("-c, --colwise", "Column-wise CUDA");
    OPT("-e, --element", "Element-wise CUDA (default)");
    OPT("-f, --fill <0-100>", "Random fill (default: 8)");
    OPT("-n, --gens <num>", "Generations (-1 infinite)");
    OPT("-i, --input-rle <file>", "Load RLE pattern");
    OPT("-V, --no-vsync", "Disable vsync");
    fprintf(stderr, "\n");

    fprintf(stderr,
        "SIZE PRESETS:\n"
        "  480p  854x480   720p  1280x720\n"
        "  1080p 1920x1080 2k    2560x1440\n"
        "  4k    3840x2160\n\n");

    fprintf(stderr,
        "CELLS:\n"
        "  X,Y coordinates (zero-based)\n"
        "  Example: %s 10,10 10,11 10,12\n\n",
        prog);

    fprintf(stderr,
        "CONTROLS:\n"
        "  Space  Start/pause/resume\n"
        "  Wheel  Zoom\n"
        "  Drag   Pan\n"
        "  R      Reset view\n\n");

    fprintf(stderr,
        "EXAMPLES:\n"
        "  Defaults          %s\n"
        "  Custom grid       %s -s 200,200\n"
        "  Random fill       %s -f 25\n"
        "  Infinite          %s -n -1\n"
        "  Load RLE          %s -i glider.rle\n"
        "  Disable vsync     %s -V\n"
        "  Row-wise CUDA     %s -r\n\n",
        prog, prog, prog, prog, prog, prog, prog);
}
