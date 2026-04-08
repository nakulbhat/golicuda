#include <getopt.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../include/main.h"
#include "../include/state.h"
#include "../include/args.h"
#include "bits/getopt_core.h"

static struct option long_options[] = {
    {"verbose", no_argument, 0, 'v'},
    {"size", required_argument, 0, 's'},
    {"rowwise", no_argument, 0, 'r'},
    {"colwise", no_argument, 0, 'c'},
    {"element", no_argument, 0, 'e'},
    {"fill", required_argument, 0, 'f'},
    {"gens", required_argument, 0, 'n'},
    {0, 0, 0, 0}
};

static void parse_cell(Cell *cell, const char *format) {
    char *xend, *yend;

    long x = strtol(format, &xend, 10);
    long y = strtol(xend + 1, &yend, 10);
    if (xend == format || *xend != ',' || yend == xend + 1 || *yend != '\0')
        FATAL("Invalid cell size format. Expected: X,Y (e.g. 10,20)");

    if (x < 0 || x > INT_MAX || y < 0 || y > INT_MAX)
        FATAL("Cell dimensions must be positive. Got X=%ld, Y=%ld", x, y);

    cell->x = x;
    cell->y = y;
}

static void set_grid_size(AppState *state, const char *preset_or_size) {
    if (state->flags & GRID_SIZE_FLAG)
        FATAL("Cannot specify Grid Size multiple times");

    state->flags |= GRID_SIZE_FLAG;

    if (strcmp("4k", preset_or_size) == 0)
        state->grid = (Cell){3840, 2160};
    else if (strcmp("1080p", preset_or_size) == 0)
        state->grid = (Cell){1920, 1080};
    else if (strcmp("720p", preset_or_size) == 0)
        state->grid = (Cell){1280, 720};
    else
        parse_cell(&state->grid, preset_or_size);
}

static void set_random_fill(AppState *state, const char *percentage) {
    if (state->flags & RANDOM_CELL_FILL_FLAG)
        FATAL("Cannot specify Random Fill multiple times");

    state->flags |= RANDOM_CELL_FILL_FLAG;

    char *end;
    long val = strtol(percentage, &end, 10);

    if (end == percentage || *end != '\0')
        FATAL("Invalid fill percentage. Expected an integer (e.g. --fill 30)");

    if (val < 0 || val > 100)
        FATAL("Fill percentage should lie in between 0 and 100. Got %ld", val);

    state->random_fill_percentage = (int)val;
}

static void set_generations(AppState *state, const char *natural_num) {
    if (state->flags & GENERATIONS_FLAG)
        FATAL("Cannot specify Generations multiple times");

    state->flags |= GENERATIONS_FLAG;

    char *end;
    long val = strtol(natural_num, &end, 10);

    if (end == natural_num || *end != '\0')
        FATAL("Invalid generations value. Expected an integer (e.g. --gens 100)");

    if (val <= 0 || val > INT_MAX)
        FATAL("Generations should be a natural number (>0). Got %ld", val);

    state->generations = (int)val;
}

static void construct_fill_cell_arr(AppState *state, int optind, int argc, char **argv) {
    state->fill_cell_count = argc - optind;

    state->fill_cell_arr =
        (Cell *)malloc(sizeof(Cell) * state->fill_cell_count);

    if (!state->fill_cell_arr)
        FATAL("Memory allocation failed for fill_cell_arr");

    for (int i = 0; i < state->fill_cell_count; i++) {
        parse_cell(&state->fill_cell_arr[i], argv[i + optind]);
    }

    LOG(state, "Found %d cells to be filled", state->fill_cell_count);
}

void parse_args(AppState *state, int argc, char **argv) {
    int opt;

    while ((opt = getopt_long(argc, argv, "vs:rcef:n:", long_options, NULL)) != -1) {
        switch (opt) {
        case 'v':
            state->flags |= VERBOSE_FLAG;
            break;

        case 's':
            set_grid_size(state, optarg);
            break;

        case 'r':
            if (state->flags & CUDA_FLAGS)
                FATAL("Conflicting flags: cannot combine or repeat -r, -c, -e.");
            state->flags |= ROWWISE_CUDA_FLAG;
            break;

        case 'c':
            if (state->flags & CUDA_FLAGS)
                FATAL("Conflicting flags: cannot combine or repeat -r, -c, -e.");
            state->flags |= COLWISE_CUDA_FLAG;
            break;

        case 'e':
            if (state->flags & CUDA_FLAGS)
                FATAL("Conflicting flags: cannot combine or repeat -r, -c, -e.");
            state->flags |= ELEWISE_CUDA_FLAG;
            break;

        case 'f':
            set_random_fill(state, optarg);
            break;

        case 'n':
            set_generations(state, optarg);
            break;

        default:
            fprintf(stderr, "Invalid option\n");
            exit(EXIT_FAILURE);
        }
    }

    // default cuda mode
    if ((state->flags & CUDA_FLAGS) == 0) {
        LOG(state, "Using default value for CUDA mode: Element-wise");
        state->flags |= DEFAULT_CUDA_FLAG;
    }

    if (argc > optind) {
        construct_fill_cell_arr(state, optind, argc, argv);
    }
}
