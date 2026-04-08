#include <cuda_runtime.h>
#include <curand_kernel.h>

#include <stdlib.h>

#include "../include/cuda_functions.h"

__global__ void init_random_kernel(
    uint8_t *grid,
    int width,
    int height,
    float fill_pct,
    unsigned long long seed)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int idx = y * width + x;

    curandState state;
    curand_init(seed, idx, 0, &state);

    grid[idx] = (curand_uniform(&state) < fill_pct) ? 1 : 0;
}

__global__ void game_of_life_kernel(
    const uint8_t *src,
    uint8_t *dst,
    int width,
    int height)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int neighbours = 0;

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {

            if (dx == 0 && dy == 0) continue;

            int nx = (x + dx + width)  % width;
            int ny = (y + dy + height) % height;

            neighbours += src[ny * width + nx];
        }
    }

    uint8_t cell = src[y * width + x];

    if (cell) {
        dst[y * width + x] =
            (neighbours == 2 || neighbours == 3) ? 1 : 0;
    } else {
        dst[y * width + x] =
            (neighbours == 3) ? 1 : 0;
    }
}

__global__ void render_kernel(
    const uint8_t *grid,
    float4 *buffer,
    int width,
    int height)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int idx = y * width + x;
    float v = grid[idx] ? 1.0f : 0.0f;

    buffer[idx] = make_float4(v, v, v, 1.0f);
}

dim3 cuda_default_block()
{
    return dim3(16, 16);
}

dim3 cuda_default_grid(int width, int height)
{
    return dim3(
        (width + 15) / 16,
        (height + 15) / 16);
}

void cuda_init_random(
    uint8_t *grid,
    int width,
    int height,
    float fill_pct,
    unsigned long long seed)
{
    dim3 block = cuda_default_block();
    dim3 grid_dim = cuda_default_grid(width, height);

    init_random_kernel<<<grid_dim, block>>>(
        grid,
        width,
        height,
        fill_pct,
        seed);

    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
}

void cuda_game_of_life(
    const uint8_t *src,
    uint8_t *dst,
    int width,
    int height)
{
    dim3 block = cuda_default_block();
    dim3 grid_dim = cuda_default_grid(width, height);

    game_of_life_kernel<<<grid_dim, block>>>(
        src,
        dst,
        width,
        height);

    CUDA_CHECK(cudaGetLastError());
}

void cuda_render(
    const uint8_t *grid,
    float4 *buffer,
    int width,
    int height)
{
    dim3 block = cuda_default_block();
    dim3 grid_dim = cuda_default_grid(width, height);

    render_kernel<<<grid_dim, block>>>(
        grid,
        buffer,
        width,
        height);

    CUDA_CHECK(cudaGetLastError());
}
