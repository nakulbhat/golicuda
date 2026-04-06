#pragma once

typedef struct {
    int x;
    int y;
} Cell;

extern Cell grid;

typedef enum {
    VERBOSE_FLAG = 1 << 0, // -v
    GRID_SIZE_FLAG = 1 << 1, // -s <int>,<int>
    ROWWISE_CUDA_FLAG = 1 << 2, // -r
    COLWISE_CUDA_FLAG = 1 << 3, // -c
    ELEWISE_CUDA_FLAG = 1 << 4, // -e
    RANDOM_CELL_FILL_FLAG = 1 << 5, // -f <int>
    GENERATIONS_FLAG = 1 << 6 // -n <int>
} flags_t;

// define mutex cuda flags. Will be used for checking later.
#define CUDA_FLAGS (ROWWISE_CUDA_FLAG | COLWISE_CUDA_FLAG | ELEWISE_CUDA_FLAG)
#define DEFAULT_CUDA_FLAG ELEWISE_CUDA_FLAG

extern int flags;

#define FATAL(...) do { fprintf(stderr, "ERROR:\t" __VA_ARGS__); fprintf(stderr, "\n"); exit(EXIT_FAILURE);} while(0)
#define LOG(...) do { if (flags & VERBOSE_FLAG) {fprintf(stderr, "LOG:\t" __VA_ARGS__); fprintf(stderr, "\n");} } while(0)

extern int random_fill_percentage;
extern int generations;
extern Cell *fill_cell_arr;
extern int fill_cell_count;
