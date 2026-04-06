#include <getopt.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../include/main.h"
#include "bits/getopt_core.h"

static struct option long_options[] = {
    {"verbose", no_argument, 0, 'v'},    {"size", required_argument, 0, 's'},
    {"rowwise", no_argument, 0, 'r'},    {"colwise", no_argument, 0, 'c'},
    {"element", no_argument, 0, 'e'},    {"fill", required_argument, 0, 'f'},
    {"gens", required_argument, 0, 'n'}, {0, 0, 0, 0}};

void parse_cell(Cell *cell, char *format) {
    char *xend, *yend;

    long x = strtol(format, &xend, 10);
    if (xend == format || *xend != ',')
        FATAL("Invalid cell size format. Expected: X,Y (e.g. 10,20)");

    long y = strtol(xend + 1, &yend, 10);
    if (yend == xend + 1 || *yend != '\0')
        FATAL("Invalid cell size format. Expected: X,Y (e.g. --size 10,20)");
    if (x <= 0 || x > INT_MAX || y <= 0 || y > INT_MAX)
        FATAL("Cell dimensions must be positive. Got X=%ld, Y=%ld", x, y);

    cell->x = x;
    cell->y = y;
}
void set_grid_size(char *preset_or_size) {
    if (flags & GRID_SIZE_FLAG)
        FATAL("Cannot specify Grid Size multiple times");
    flags |= GRID_SIZE_FLAG;
    if (strcmp("4k", preset_or_size) == 0)
        grid = (Cell){3840, 2160};
    else if (strcmp("1080p", preset_or_size) == 0)
        grid = (Cell){1920, 1080};
    else if (strcmp("720p", preset_or_size) == 0)
        grid = (Cell){1280, 720};
    else
        parse_cell(&grid, preset_or_size);
}

void set_random_fill(char *percentage) {
    if (flags & RANDOM_CELL_FILL_FLAG)
        FATAL("Cannot specify Random Fill multiple times");
    flags |= RANDOM_CELL_FILL_FLAG;
    char *end;
    long val = strtol(percentage, &end, 10);
    if (end == percentage || *end != '\0')
        FATAL("Invalid fill percentage. Expected an integer (e.g. --fill 30)");
    if (val < 0 || val > 100)
        FATAL("Fill percentage should lie in between 0 and 100. Got %ld", val);
    random_fill_percentage = (int)val;
}

void set_generations(char *natural_num) {
    if (flags & GENERATIONS_FLAG)
        FATAL("Cannot specify Generations multiple times");
    flags |= GENERATIONS_FLAG;
    char *end;
    long val = strtol(natural_num, &end, 10);
    if (end == natural_num || *end != '\0')
        FATAL("Invalid generations value. Expected an integer (e.g. --gens 100)");
    if (val <= 0 || val > INT_MAX)
        FATAL("Generations should be a natural number (>0). Got %ld", val);
    generations = (int)val;
}

void construct_fill_cell_arr(int optind, int argc, char **argv) {
    fill_cell_count = argc - optind;
    fill_cell_arr = (Cell *)malloc(sizeof(Cell) * fill_cell_count);

    if (!fill_cell_arr)
        FATAL("Memory allocation failed for fill_cell_arr");

    for (int i = 0; i < fill_cell_count; i++) {
        parse_cell(&fill_cell_arr[i], argv[i + optind]);
    }
}

void parse_args(int argc, char **argv) {
    int opt;

    while ((opt = getopt_long(argc, argv, "vs:rcef:n:", long_options, NULL)) !=
        -1) {
        switch (opt) {
            case 'v':
                flags |= VERBOSE_FLAG;
                break;

            case 's':
                set_grid_size(optarg);
                break;

            case 'r':
                if (flags & CUDA_FLAGS)
                    FATAL("Conflicting flags: cannot combine or repeat -r, -c, -e.");
                flags |= ROWWISE_CUDA_FLAG;
                break;

            case 'c':
                if (flags & CUDA_FLAGS)
                    FATAL("Conflicting flags: cannot combine or repeat -r, -c, -e.");
                flags |= COLWISE_CUDA_FLAG;
                break;

            case 'e':
                if (flags & CUDA_FLAGS)
                    FATAL("Conflicting flags: cannot combine or repeat -r, -c, -e.");
                flags |= ELEWISE_CUDA_FLAG;
                break;

            case 'f':
                set_random_fill(optarg);
                break;

            case 'n':
                set_generations(optarg);
                break;

            default:
                fprintf(stderr, "Invalid option\n");
                exit(EXIT_FAILURE);
        }
    }

    // default cuda mode if none specified
    if ((flags & CUDA_FLAGS) == 0){
        LOG("Using default value for CUDA mode: Element-wise");
        flags |= DEFAULT_CUDA_FLAG;
    }

    // if more args are passed, they are cells to be filled
    if (argc > optind) {
        construct_fill_cell_arr(optind, argc, argv);
    }
}
