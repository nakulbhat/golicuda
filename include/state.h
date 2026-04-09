#pragma once

#include "main.h"

typedef struct {
    Cell grid;
    int flags;
    int random_fill_percentage;
    int generations;
    Cell *fill_cell_arr;
    int fill_cell_count;
    char *rle_file;
    int pattern_width;   
    int pattern_height; 
} AppState;

void init_default_state(AppState *state);
void free_state(AppState *state);

#define LOG(state, ...) \
do { \
    if ((state)->flags & VERBOSE_FLAG) { \
        fprintf(stderr, "LOG:\t" __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } \
} while(0)
