#pragma once

#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int x;
    int y;
} Cell;

typedef enum {
    VERBOSE_FLAG = 1 << 0,          // -v
    GRID_SIZE_FLAG = 1 << 1,        // -s <int>,<int>
    ROWWISE_CUDA_FLAG = 1 << 2,     // -r
    COLWISE_CUDA_FLAG = 1 << 3,     // -c
    ELEWISE_CUDA_FLAG = 1 << 4,     // -e
    RANDOM_CELL_FILL_FLAG = 1 << 5, // -f <int>
    GENERATIONS_FLAG = 1 << 6,      // -n <int>
    RLE_FILE_FLAG = 1 << 7,         // -l <rlefile>
    NO_VSYNC_FLAG = 1 << 8,         // -V
    HEADLESS_FLAG = 1 << 9,         // -H
} flags_t;

// mutually exclusive CUDA flags
#define CUDA_FLAGS (ROWWISE_CUDA_FLAG | COLWISE_CUDA_FLAG | ELEWISE_CUDA_FLAG)

#define DEFAULT_CUDA_FLAG ELEWISE_CUDA_FLAG

#define FATAL(...)                                                             \
do {                                                                         \
    fprintf(stderr, "ERROR:\t" __VA_ARGS__);                                   \
    fprintf(stderr, "\n");                                                     \
    exit(EXIT_FAILURE);                                                        \
} while (0)
