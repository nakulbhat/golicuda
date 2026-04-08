#pragma once

#include <stdint.h>
#include <cuda_runtime.h>

void cuda_init_random(
    uint8_t *grid,
    int width,
    int height,
    float fill_pct,
    unsigned long long seed);

void cuda_game_of_life(
    const uint8_t *src,
    uint8_t *dst,
    int width,
    int height);

void cuda_render(
    const uint8_t *grid,
    float4 *buffer,
    int width,
    int height);

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
