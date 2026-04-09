#pragma once

#pragma once

#include <stdint.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include "state.h"   

size_t grid_bytes(int width, int height, int bitpacked);

void cuda_init_random(void *grid, int width, int height,
                      float fill_pct, unsigned long long seed,
                      int bitpacked);

void cuda_render(const void *grid, float4 *buffer,
                 int width, int height, int bitpacked);

void cuda_fill_cells(void *d_grid, int width, int height,
                     const Cell *cells, int count, int bitpacked);


void cuda_game_of_life(
    const void *src,
    void *dst,
    int width,
    int height,
    const AppState *state);   

void run_headless(const AppState *state);

dim3 cuda_default_block();
dim3 cuda_default_grid(int width, int height);

#define CUDA_CHECK(x) \
    do { \
        cudaError_t err = x; \
        if (err != cudaSuccess) { \
            printf("CUDA Error: %s\n", cudaGetErrorString(err)); \
            exit(1); \
        } \
    } while(0)
