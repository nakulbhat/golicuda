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

__global__ void game_of_life_elewise_kernel(
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

    dst[y * width + x] =
        cell ? (neighbours == 2 || neighbours == 3)
             : (neighbours == 3);
}

__global__ void game_of_life_rowwise_kernel(
    const uint8_t *src,
    uint8_t *dst,
    int width,
    int height)
{
    int y = blockIdx.x * blockDim.x + threadIdx.x;

    if (y >= height) return;

    for (int x = 0; x < width; x++) {

        int neighbours = 0;

        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {

                if (dx == 0 && dy == 0) continue;

                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;

                neighbours += src[ny * width + nx];
            }
        }

        uint8_t cell = src[y * width + x];

        dst[y * width + x] =
            cell ? (neighbours == 2 || neighbours == 3)
                 : (neighbours == 3);
    }
}

__global__ void game_of_life_colwise_kernel(
    const uint8_t *src,
    uint8_t *dst,
    int width,
    int height)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;

    if (x >= width) return;

    for (int y = 0; y < height; y++) {

        int neighbours = 0;

        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {

                if (dx == 0 && dy == 0) continue;

                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;

                neighbours += src[ny * width + nx];
            }
        }

        uint8_t cell = src[y * width + x];

        dst[y * width + x] =
            cell ? (neighbours == 2 || neighbours == 3)
                 : (neighbours == 3);
    }
}

void cuda_game_of_life(
    const uint8_t *src,
    uint8_t *dst,
    int width,
    int height,
    const AppState *state)
{
    if (state->flags & ROWWISE_CUDA_FLAG) {

        int threads = 256;
        int blocks = (height + threads - 1) / threads;

        game_of_life_rowwise_kernel<<<blocks, threads>>>(
            src, dst, width, height);

    } else if (state->flags & COLWISE_CUDA_FLAG) {

        int threads = 256;
        int blocks = (width + threads - 1) / threads;

        game_of_life_colwise_kernel<<<blocks, threads>>>(
            src, dst, width, height);

    } else { // ELEWISE (default)

        dim3 block = cuda_default_block();
        dim3 grid_dim = cuda_default_grid(width, height);

        game_of_life_elewise_kernel<<<grid_dim, block>>>(
            src, dst, width, height);
    }

    CUDA_CHECK(cudaGetLastError());
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

__global__ void fill_cells_kernel(
    uint8_t *grid,
    int width,
    int height,
    const Cell *cells,
    int count
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx >= count) return;

    Cell c = cells[idx];

    if (c.x < 0 || c.x >= width || c.y < 0 || c.y >= height)
        return;

    grid[c.y * width + c.x] = 1;
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

void cuda_fill_cells(
    uint8_t *d_grid,
    int width,
    int height,
    const Cell *cells,
    int count
) {
    if (!cells || count <= 0) return;

    Cell *d_cells;

    size_t bytes = count * sizeof(Cell);

    cudaMalloc(&d_cells, bytes);
    cudaMemcpy(d_cells, cells, bytes, cudaMemcpyHostToDevice);

    int block = 256;
    int grid = (count + block - 1) / block;

    fill_cells_kernel<<<grid, block>>>(
        d_grid,
        width,
        height,
        d_cells,
        count
    );

    cudaDeviceSynchronize();

    cudaFree(d_cells);
}
