#include <cuda_runtime.h>
#include <curand_kernel.h>

#include <stdlib.h>

#include "../include/cuda_functions.h"

size_t grid_bytes(int width, int height, int bitpacked) {
    if (bitpacked)
        return ((size_t)width * height + 31) / 32 * sizeof(uint32_t);
    return (size_t)width * height * sizeof(uint8_t);
}

__global__ void init_random_kernel(uint8_t *grid, int width, int height,
                                   float fill_pct, unsigned long long seed) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int idx = y * width + x;

    curandState state;
    curand_init(seed, idx, 0, &state);

    grid[idx] = (curand_uniform(&state) < fill_pct) ? 1 : 0;
}

__global__ void init_random_bitpacked_kernel(uint32_t *grid, int width,
                                             int height, float fill_pct,
                                             unsigned long long seed) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int idx = y * width + x;

    curandState state;
    curand_init(seed, idx, 0, &state);

    if (curand_uniform(&state) < fill_pct)
        atomicOr(&grid[idx >> 5], 1u << (idx & 31));
}

__global__ void game_of_life_elewise_kernel(const uint8_t *src, uint8_t *dst,
                                            int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int neighbours = 0;

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {

            if (dx == 0 && dy == 0)
                continue;

            int nx = (x + dx + width) % width;
            int ny = (y + dy + height) % height;

            neighbours += src[ny * width + nx];
        }
    }

    uint8_t cell = src[y * width + x];

    dst[y * width + x] =
        cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
}

__global__ void game_of_life_rowwise_kernel(const uint8_t *src, uint8_t *dst,
                                            int width, int height) {
    int y = blockIdx.x * blockDim.x + threadIdx.x;

    if (y >= height)
        return;

    for (int x = 0; x < width; x++) {

        int neighbours = 0;

        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {

                if (dx == 0 && dy == 0)
                    continue;

                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;

                neighbours += src[ny * width + nx];
            }
        }

        uint8_t cell = src[y * width + x];

        dst[y * width + x] =
            cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
    }
}

__global__ void game_of_life_colwise_kernel(const uint8_t *src, uint8_t *dst,
                                            int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;

    if (x >= width)
        return;

    for (int y = 0; y < height; y++) {

        int neighbours = 0;

        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {

                if (dx == 0 && dy == 0)
                    continue;

                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;

                neighbours += src[ny * width + nx];
            }
        }

        uint8_t cell = src[y * width + x];

        dst[y * width + x] =
            cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
    }
}

__device__ static inline int bp_read(const uint32_t *src, int width, int x,
                                     int y) {
    int i = y * width + x;
    return (src[i >> 5] >> (i & 31)) & 1;
}

__global__ void game_of_life_bitpacked_elewise_kernel(const uint32_t *src,
                                                      uint32_t *dst, int width,
                                                      int height) {
    int word_x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int words_per_row = (width + 31) / 32;
    if (word_x >= words_per_row || y >= height)
        return;

    uint32_t result = 0;

    for (int bit = 0; bit < 32; bit++) {
        int x = word_x * 32 + bit;
        if (x >= width)
            break;

        int neighbours = 0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0)
                    continue;
                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;
                neighbours += bp_read(src, width, nx, ny);
            }
        }

        int cell = bp_read(src, width, x, y);
        int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
        result |= ((uint32_t)alive << bit);
    }

    dst[word_x + y * words_per_row] = result;
}

__global__ void game_of_life_bitpacked_rowwise_kernel(const uint32_t *src,
                                                      uint32_t *dst, int width,
                                                      int height) {
    int y = blockIdx.x * blockDim.x + threadIdx.x;

    if (y >= height)
        return;

    int words_per_row = (width + 31) / 32;

    for (int word_x = 0; word_x < words_per_row; word_x++) {
        uint32_t result = 0;

        for (int bit = 0; bit < 32; bit++) {
            int x = word_x * 32 + bit;
            if (x >= width)
                break;

            int neighbours = 0;
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0)
                        continue;
                    int nx = (x + dx + width) % width;
                    int ny = (y + dy + height) % height;
                    neighbours += bp_read(src, width, nx, ny);
                }
            }

            int cell = bp_read(src, width, x, y);
            int alive =
                cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
            result |= ((uint32_t)alive << bit);
        }

        dst[word_x + y * words_per_row] = result;
    }
}

__global__ void game_of_life_bitpacked_colwise_kernel(const uint32_t *src,
                                                      uint32_t *dst, int width,
                                                      int height) {
    int word_x = blockIdx.x * blockDim.x + threadIdx.x;

    int words_per_row = (width + 31) / 32;
    if (word_x >= words_per_row)
        return;

    for (int y = 0; y < height; y++) {
        uint32_t result = 0;

        for (int bit = 0; bit < 32; bit++) {
            int x = word_x * 32 + bit;
            if (x >= width)
                break;

            int neighbours = 0;
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0)
                        continue;
                    int nx = (x + dx + width) % width;
                    int ny = (y + dy + height) % height;
                    neighbours += bp_read(src, width, nx, ny);
                }
            }

            int cell = bp_read(src, width, x, y);
            int alive =
                cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
            result |= ((uint32_t)alive << bit);
        }

        dst[word_x + y * words_per_row] = result;
    }
}

__global__ void
game_of_life_bitpacked_atomic_elewise_kernel(const uint32_t *src, uint32_t *dst,
                                             int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int neighbours = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0)
                continue;
            int nx = (x + dx + width) % width;
            int ny = (y + dy + height) % height;
            neighbours += bp_read(src, width, nx, ny);
        }
    }

    int cell = bp_read(src, width, x, y);
    int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);

    int idx = y * width + x;
    uint32_t bit = 1u << (idx & 31);

    if (alive)
        atomicOr(&dst[idx >> 5], bit);
    else
        atomicAnd(&dst[idx >> 5], ~bit);
}

__global__ void
game_of_life_bitpacked_atomic_rowwise_kernel(const uint32_t *src, uint32_t *dst,
                                             int width, int height) {
    int y = blockIdx.x * blockDim.x + threadIdx.x;

    if (y >= height)
        return;

    for (int x = 0; x < width; x++) {
        int neighbours = 0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0)
                    continue;
                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;
                neighbours += bp_read(src, width, nx, ny);
            }
        }

        int cell = bp_read(src, width, x, y);
        int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);

        int idx = y * width + x;
        uint32_t bit = 1u << (idx & 31);

        if (alive)
            atomicOr(&dst[idx >> 5], bit);
        else
            atomicAnd(&dst[idx >> 5], ~bit);
    }
}

__global__ void
game_of_life_bitpacked_atomic_colwise_kernel(const uint32_t *src, uint32_t *dst,
                                             int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;

    if (x >= width)
        return;

    for (int y = 0; y < height; y++) {
        int neighbours = 0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0)
                    continue;
                int nx = (x + dx + width) % width;
                int ny = (y + dy + height) % height;
                neighbours += bp_read(src, width, nx, ny);
            }
        }

        int cell = bp_read(src, width, x, y);
        int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);

        int idx = y * width + x;
        uint32_t bit = 1u << (idx & 31);

        if (alive)
            atomicOr(&dst[idx >> 5], bit);
        else
            atomicAnd(&dst[idx >> 5], ~bit);
    }
}

#define TILE 16

__global__ void game_of_life_tiled_kernel(const uint8_t *src, uint8_t *dst,
                                          int width, int height) {
    __shared__ uint8_t smem[TILE + 2][TILE + 2];

    const int tx = threadIdx.x;
    const int ty = threadIdx.y;

    const int gx = blockIdx.x * TILE + tx;
    const int gy = blockIdx.y * TILE + ty;

    const int sx = tx + 1;
    const int sy = ty + 1;

    if (gx < width && gy < height)
        smem[sy][sx] = src[gy * width + gx];
    else
        smem[sy][sx] = 0;

    if (tx == 0) {
        int nx = (gx - 1 + width) % width;
        smem[sy][0] = (gy < height) ? src[gy * width + nx] : 0;
    }
    if (tx == TILE - 1) {
        int nx = (gx + 1) % width;
        smem[sy][TILE + 1] = (gy < height) ? src[gy * width + nx] : 0;
    }
    if (ty == 0) {
        int ny = (gy - 1 + height) % height;
        smem[0][sx] = (gx < width) ? src[ny * width + gx] : 0;
    }
    if (ty == TILE - 1) {
        int ny = (gy + 1) % height;
        smem[TILE + 1][sx] = (gx < width) ? src[ny * width + gx] : 0;
    }
    if (tx == 0 && ty == 0) {
        int nx = (gx - 1 + width) % width, ny = (gy - 1 + height) % height;
        smem[0][0] = src[ny * width + nx];
    }
    if (tx == TILE - 1 && ty == 0) {
        int nx = (gx + 1) % width, ny = (gy - 1 + height) % height;
        smem[0][TILE + 1] = src[ny * width + nx];
    }
    if (tx == 0 && ty == TILE - 1) {
        int nx = (gx - 1 + width) % width, ny = (gy + 1) % height;
        smem[TILE + 1][0] = src[ny * width + nx];
    }
    if (tx == TILE - 1 && ty == TILE - 1) {
        int nx = (gx + 1) % width, ny = (gy + 1) % height;
        smem[TILE + 1][TILE + 1] = src[ny * width + nx];
    }

    __syncthreads();

    if (gx >= width || gy >= height)
        return;

    int neighbours = smem[sy - 1][sx - 1] + smem[sy - 1][sx] +
        smem[sy - 1][sx + 1] + smem[sy][sx - 1] + smem[sy][sx + 1] +
        smem[sy + 1][sx - 1] + smem[sy + 1][sx] +
        smem[sy + 1][sx + 1];

    uint8_t cell = smem[sy][sx];
    dst[gy * width + gx] =
        cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
}

__global__ void game_of_life_tiled_rowwise_kernel(const uint8_t *src,
                                                  uint8_t *dst, int width,
                                                  int height) {
    __shared__ uint8_t smem[TILE + 2][TILE + 2];

    const int ty = threadIdx.x;
    const int gy = blockIdx.x * TILE + ty;

    for (int tile_x = 0; tile_x < (width + TILE - 1) / TILE; tile_x++) {
        const int gx_base = tile_x * TILE;

        for (int tx = 0; tx < TILE; tx++) {
            const int gx = gx_base + tx;
            const int sx = tx + 1;
            const int sy = ty + 1;

            if (gx < width && gy < height)
                smem[sy][sx] = src[gy * width + gx];
            else
                smem[sy][sx] = 0;

            if (tx == 0) {
                int nx = (gx - 1 + width) % width;
                smem[sy][0] = (gy < height) ? src[gy * width + nx] : 0;
            }
            if (tx == TILE - 1) {
                int nx = (gx + 1) % width;
                smem[sy][TILE + 1] = (gy < height) ? src[gy * width + nx] : 0;
            }
            if (ty == 0) {
                int ny = (gy - 1 + height) % height;
                smem[0][sx] = (gx < width) ? src[ny * width + gx] : 0;
            }
            if (ty == TILE - 1) {
                int ny = (gy + 1) % height;
                smem[TILE + 1][sx] = (gx < width) ? src[ny * width + gx] : 0;
            }
        }

        {
            int nx0 = (gx_base - 1 + width) % width;
            int nx1 = (gx_base + TILE) % width;
            if (ty == 0) {
                int ny = (gy - 1 + height) % height;
                smem[0][0] = src[ny * width + nx0];
                smem[0][TILE + 1] = src[ny * width + nx1];
            }
            if (ty == TILE - 1) {
                int ny = (gy + 1) % height;
                smem[TILE + 1][0] = src[ny * width + nx0];
                smem[TILE + 1][TILE + 1] = src[ny * width + nx1];
            }
        }

        __syncthreads();

        if (gy < height) {
            for (int tx = 0; tx < TILE; tx++) {
                int gx = gx_base + tx;
                if (gx >= width)
                    break;
                const int sx = tx + 1;
                const int sy = ty + 1;

                int neighbours = smem[sy - 1][sx - 1] + smem[sy - 1][sx] +
                    smem[sy - 1][sx + 1] + smem[sy][sx - 1] + smem[sy][sx + 1] +
                    smem[sy + 1][sx - 1] + smem[sy + 1][sx] +
                    smem[sy + 1][sx + 1];

                uint8_t cell = smem[sy][sx];
                dst[gy * width + gx] =
                    cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
            }
        }

        __syncthreads();
    }
}

__global__ void game_of_life_tiled_colwise_kernel(const uint8_t *src,
                                                  uint8_t *dst, int width,
                                                  int height) {
    __shared__ uint8_t smem[TILE + 2][TILE + 2];

    const int tx = threadIdx.x;
    const int gx = blockIdx.x * TILE + tx;

    for (int tile_y = 0; tile_y < (height + TILE - 1) / TILE; tile_y++) {
        const int gy_base = tile_y * TILE;

        for (int ty = 0; ty < TILE; ty++) {
            const int gy = gy_base + ty;
            const int sx = tx + 1;
            const int sy = ty + 1;

            if (gx < width && gy < height)
                smem[sy][sx] = src[gy * width + gx];
            else
                smem[sy][sx] = 0;

            if (tx == 0) {
                int nx = (gx - 1 + width) % width;
                smem[sy][0] = (gy < height) ? src[gy * width + nx] : 0;
            }
            if (tx == TILE - 1) {
                int nx = (gx + 1) % width;
                smem[sy][TILE + 1] = (gy < height) ? src[gy * width + nx] : 0;
            }
            if (ty == 0) {
                int ny = (gy - 1 + height) % height;
                smem[0][sx] = (gx < width) ? src[ny * width + gx] : 0;
            }
            if (ty == TILE - 1) {
                int ny = (gy + 1) % height;
                smem[TILE + 1][sx] = (gx < width) ? src[ny * width + gx] : 0;
            }
        }

        {
            int ny0 = (gy_base - 1 + height) % height;
            int ny1 = (gy_base + TILE) % height;
            if (tx == 0) {
                int nx = (gx - 1 + width) % width;
                smem[0][0] = src[ny0 * width + nx];
                smem[TILE + 1][0] = src[ny1 * width + nx];
            }
            if (tx == TILE - 1) {
                int nx = (gx + 1) % width;
                smem[0][TILE + 1] = src[ny0 * width + nx];
                smem[TILE + 1][TILE + 1] = src[ny1 * width + nx];
            }
        }

        __syncthreads();

        if (gx < width) {
            for (int ty = 0; ty < TILE; ty++) {
                int gy = gy_base + ty;
                if (gy >= height)
                    break;
                const int sx = tx + 1;
                const int sy = ty + 1;

                int neighbours = smem[sy - 1][sx - 1] + smem[sy - 1][sx] +
                    smem[sy - 1][sx + 1] + smem[sy][sx - 1] + smem[sy][sx + 1] +
                    smem[sy + 1][sx - 1] + smem[sy + 1][sx] +
                    smem[sy + 1][sx + 1];

                uint8_t cell = smem[sy][sx];
                dst[gy * width + gx] =
                    cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);
            }
        }

        __syncthreads();
    }
}

__global__ void game_of_life_tiled_bitpacked_kernel(const uint32_t *src,
                                                    uint32_t *dst, int width,
                                                    int height) {
    __shared__ uint8_t smem[TILE + 2][TILE + 2];

    const int tx = threadIdx.x;
    const int ty = threadIdx.y;
    const int gx = blockIdx.x * TILE + tx;
    const int gy = blockIdx.y * TILE + ty;
    const int sx = tx + 1;
    const int sy = ty + 1;

#define BP_READ(X, Y)                                                          \
    ({                                                                           \
        int _i = (Y) * width + (X);                                                \
        (src[_i >> 5] >> (_i & 31)) & 1u;                                          \
    })

    if (gx < width && gy < height)
        smem[sy][sx] = (uint8_t)BP_READ(gx, gy);
    else
        smem[sy][sx] = 0;

    if (tx == 0) {
        int nx = (gx - 1 + width) % width;
        smem[sy][0] = (gy < height) ? (uint8_t)BP_READ(nx, gy) : 0;
    }
    if (tx == TILE - 1) {
        int nx = (gx + 1) % width;
        smem[sy][TILE + 1] = (gy < height) ? (uint8_t)BP_READ(nx, gy) : 0;
    }
    if (ty == 0) {
        int ny = (gy - 1 + height) % height;
        smem[0][sx] = (gx < width) ? (uint8_t)BP_READ(gx, ny) : 0;
    }
    if (ty == TILE - 1) {
        int ny = (gy + 1) % height;
        smem[TILE + 1][sx] = (gx < width) ? (uint8_t)BP_READ(gx, ny) : 0;
    }
    if (tx == 0 && ty == 0) {
        int nx = (gx - 1 + width) % width, ny = (gy - 1 + height) % height;
        smem[0][0] = (uint8_t)BP_READ(nx, ny);
    }
    if (tx == TILE - 1 && ty == 0) {
        int nx = (gx + 1) % width, ny = (gy - 1 + height) % height;
        smem[0][TILE + 1] = (uint8_t)BP_READ(nx, ny);
    }
    if (tx == 0 && ty == TILE - 1) {
        int nx = (gx - 1 + width) % width, ny = (gy + 1) % height;
        smem[TILE + 1][0] = (uint8_t)BP_READ(nx, ny);
    }
    if (tx == TILE - 1 && ty == TILE - 1) {
        int nx = (gx + 1) % width, ny = (gy + 1) % height;
        smem[TILE + 1][TILE + 1] = (uint8_t)BP_READ(nx, ny);
    }

    #undef BP_READ

    __syncthreads();

    if (gx >= width || gy >= height)
        return;

    int neighbours = smem[sy - 1][sx - 1] + smem[sy - 1][sx] +
        smem[sy - 1][sx + 1] + smem[sy][sx - 1] + smem[sy][sx + 1] +
        smem[sy + 1][sx - 1] + smem[sy + 1][sx] +
        smem[sy + 1][sx + 1];

    int cell = smem[sy][sx];
    int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);

    int idx = gy * width + gx;
    uint32_t bit = 1u << (idx & 31);
    if (alive)
        atomicOr(&dst[idx >> 5], bit);
    else
        atomicAnd(&dst[idx >> 5], ~bit);
}

__global__ void game_of_life_tiled_bitpacked_rowwise_kernel(const uint32_t *src,
                                                            uint32_t *dst,
                                                            int width,
                                                            int height) {
    __shared__ uint8_t smem[TILE + 2][TILE + 2];

    const int ty = threadIdx.x;
    const int gy = blockIdx.x * TILE + ty;

#define BP_READ_S(X, Y)                                                        \
    ({                                                                           \
        int _i = (Y) * width + (X);                                                \
        (int)((src[_i >> 5] >> (_i & 31)) & 1u);                                   \
    })

    for (int tile_x = 0; tile_x < (width + TILE - 1) / TILE; tile_x++) {
        const int gx_base = tile_x * TILE;

        for (int tx = 0; tx < TILE; tx++) {
            const int gx = gx_base + tx;
            const int sx = tx + 1;
            const int sy = ty + 1;

            if (gx < width && gy < height)
                smem[sy][sx] = (uint8_t)BP_READ_S(gx, gy);
            else
                smem[sy][sx] = 0;

            if (tx == 0) {
                int nx = (gx - 1 + width) % width;
                smem[sy][0] = (gy < height) ? (uint8_t)BP_READ_S(nx, gy) : 0;
            }
            if (tx == TILE - 1) {
                int nx = (gx + 1) % width;
                smem[sy][TILE + 1] = (gy < height) ? (uint8_t)BP_READ_S(nx, gy) : 0;
            }
            if (ty == 0) {
                int ny = (gy - 1 + height) % height;
                smem[0][sx] = (gx < width) ? (uint8_t)BP_READ_S(gx, ny) : 0;
            }
            if (ty == TILE - 1) {
                int ny = (gy + 1) % height;
                smem[TILE + 1][sx] = (gx < width) ? (uint8_t)BP_READ_S(gx, ny) : 0;
            }
        }

        {
            int nx0 = (gx_base - 1 + width) % width;
            int nx1 = (gx_base + TILE) % width;
            if (ty == 0) {
                int ny = (gy - 1 + height) % height;
                smem[0][0] = (uint8_t)BP_READ_S(nx0, ny);
                smem[0][TILE + 1] = (uint8_t)BP_READ_S(nx1, ny);
            }
            if (ty == TILE - 1) {
                int ny = (gy + 1) % height;
                smem[TILE + 1][0] = (uint8_t)BP_READ_S(nx0, ny);
                smem[TILE + 1][TILE + 1] = (uint8_t)BP_READ_S(nx1, ny);
            }
        }

        __syncthreads();

        if (gy < height) {
            for (int tx = 0; tx < TILE; tx++) {
                int gx = gx_base + tx;
                if (gx >= width)
                    break;
                const int sx = tx + 1;
                const int sy = ty + 1;

                int neighbours = smem[sy - 1][sx - 1] + smem[sy - 1][sx] +
                    smem[sy - 1][sx + 1] + smem[sy][sx - 1] + smem[sy][sx + 1] +
                    smem[sy + 1][sx - 1] + smem[sy + 1][sx] +
                    smem[sy + 1][sx + 1];

                int cell = smem[sy][sx];
                int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);

                int idx = gy * width + gx;
                uint32_t bit = 1u << (idx & 31);
                if (alive)
                    atomicOr(&dst[idx >> 5], bit);
                else
                    atomicAnd(&dst[idx >> 5], ~bit);
            }
        }

        __syncthreads();
    }

#undef BP_READ_S
}

__global__ void game_of_life_tiled_bitpacked_colwise_kernel(const uint32_t *src,
                                                            uint32_t *dst,
                                                            int width,
                                                            int height) {
    __shared__ uint8_t smem[TILE + 2][TILE + 2];

    const int tx = threadIdx.x;
    const int gx = blockIdx.x * TILE + tx;

#define BP_READ_S(X, Y)                                                        \
    ({                                                                           \
        int _i = (Y) * width + (X);                                                \
        (int)((src[_i >> 5] >> (_i & 31)) & 1u);                                   \
    })

    for (int tile_y = 0; tile_y < (height + TILE - 1) / TILE; tile_y++) {
        const int gy_base = tile_y * TILE;

        for (int ty = 0; ty < TILE; ty++) {
            const int gy = gy_base + ty;
            const int sx = tx + 1;
            const int sy = ty + 1;

            if (gx < width && gy < height)
                smem[sy][sx] = (uint8_t)BP_READ_S(gx, gy);
            else
                smem[sy][sx] = 0;

            if (tx == 0) {
                int nx = (gx - 1 + width) % width;
                smem[sy][0] = (gy < height) ? (uint8_t)BP_READ_S(nx, gy) : 0;
            }
            if (tx == TILE - 1) {
                int nx = (gx + 1) % width;
                smem[sy][TILE + 1] = (gy < height) ? (uint8_t)BP_READ_S(nx, gy) : 0;
            }
            if (ty == 0) {
                int ny = (gy - 1 + height) % height;
                smem[0][sx] = (gx < width) ? (uint8_t)BP_READ_S(gx, ny) : 0;
            }
            if (ty == TILE - 1) {
                int ny = (gy + 1) % height;
                smem[TILE + 1][sx] = (gx < width) ? (uint8_t)BP_READ_S(gx, ny) : 0;
            }
        }

        {
            int ny0 = (gy_base - 1 + height) % height;
            int ny1 = (gy_base + TILE) % height;
            if (tx == 0) {
                int nx = (gx - 1 + width) % width;
                smem[0][0] = (uint8_t)BP_READ_S(nx, ny0);
                smem[TILE + 1][0] = (uint8_t)BP_READ_S(nx, ny1);
            }
            if (tx == TILE - 1) {
                int nx = (gx + 1) % width;
                smem[0][TILE + 1] = (uint8_t)BP_READ_S(nx, ny0);
                smem[TILE + 1][TILE + 1] = (uint8_t)BP_READ_S(nx, ny1);
            }
        }

        __syncthreads();

        if (gx < width) {
            for (int ty = 0; ty < TILE; ty++) {
                int gy = gy_base + ty;
                if (gy >= height)
                    break;
                const int sx = tx + 1;
                const int sy = ty + 1;

                int neighbours = smem[sy - 1][sx - 1] + smem[sy - 1][sx] +
                    smem[sy - 1][sx + 1] + smem[sy][sx - 1] + smem[sy][sx + 1] +
                    smem[sy + 1][sx - 1] + smem[sy + 1][sx] +
                    smem[sy + 1][sx + 1];

                int cell = smem[sy][sx];
                int alive = cell ? (neighbours == 2 || neighbours == 3) : (neighbours == 3);

                int idx = gy * width + gx;
                uint32_t bit = 1u << (idx & 31);
                if (alive)
                    atomicOr(&dst[idx >> 5], bit);
                else
                    atomicAnd(&dst[idx >> 5], ~bit);
            }
        }

        __syncthreads();
    }

#undef BP_READ_S
}

void cuda_game_of_life(const void *src, void *dst, int width, int height,
                       const AppState *state) {

    int words_per_row = (width + 31) / 32;

    if (state->flags & TILED_FLAG) {
        int bp = (state->flags & (BITPACKED_FLAG | BITPACKED_ATOMIC_FLAG)) != 0;

        if (state->flags & ROWWISE_CUDA_FLAG) {
            int threads = TILE;
            int blocks = (height + TILE - 1) / TILE;
            if (bp) {
                game_of_life_tiled_bitpacked_rowwise_kernel<<<blocks, threads>>>(
                    (const uint32_t *)src, (uint32_t *)dst, width, height);
            } else {
                game_of_life_tiled_rowwise_kernel<<<blocks, threads>>>(
                    (const uint8_t *)src, (uint8_t *)dst, width, height);
            }
        } else if (state->flags & COLWISE_CUDA_FLAG) {
            int threads = TILE;
            int blocks = (width + TILE - 1) / TILE;
            if (bp) {
                game_of_life_tiled_bitpacked_colwise_kernel<<<blocks, threads>>>(
                    (const uint32_t *)src, (uint32_t *)dst, width, height);
            } else {
                game_of_life_tiled_colwise_kernel<<<blocks, threads>>>(
                    (const uint8_t *)src, (uint8_t *)dst, width, height);
            }
        } else {
            dim3 block(TILE, TILE);
            dim3 grid_dim((width + TILE - 1) / TILE, (height + TILE - 1) / TILE);
            if (bp) {
                game_of_life_tiled_bitpacked_kernel<<<grid_dim, block>>>(
                    (const uint32_t *)src, (uint32_t *)dst, width, height);
            } else {
                game_of_life_tiled_kernel<<<grid_dim, block>>>(
                    (const uint8_t *)src, (uint8_t *)dst, width, height);
            }
        }
        CUDA_CHECK(cudaGetLastError());
        return;
    }

    if (state->flags & BITPACKED_FLAG) {

        dim3 block(16, 16);
        dim3 grid_dim((words_per_row + 15) / 16, (height + 15) / 16);

        if (state->flags & ROWWISE_CUDA_FLAG) {
            int threads = 256;
            int blocks = (height + threads - 1) / threads;
            game_of_life_bitpacked_rowwise_kernel<<<blocks, threads>>>(
                (const uint32_t *)src, (uint32_t *)dst, width, height);

        } else if (state->flags & COLWISE_CUDA_FLAG) {
            int threads = 256;
            int blocks = (words_per_row + threads - 1) / threads;
            game_of_life_bitpacked_colwise_kernel<<<blocks, threads>>>(
                (const uint32_t *)src, (uint32_t *)dst, width, height);

        } else {
            game_of_life_bitpacked_elewise_kernel<<<grid_dim, block>>>(
                (const uint32_t *)src, (uint32_t *)dst, width, height);
        }

    } else if (state->flags & BITPACKED_ATOMIC_FLAG) {

        dim3 block = cuda_default_block();
        dim3 grid_dim = cuda_default_grid(width, height);

        if (state->flags & ROWWISE_CUDA_FLAG) {
            int threads = 256;
            int blocks = (height + threads - 1) / threads;
            game_of_life_bitpacked_atomic_rowwise_kernel<<<blocks, threads>>>(
                (const uint32_t *)src, (uint32_t *)dst, width, height);

        } else if (state->flags & COLWISE_CUDA_FLAG) {
            int threads = 256;
            int blocks = (width + threads - 1) / threads;
            game_of_life_bitpacked_atomic_colwise_kernel<<<blocks, threads>>>(
                (const uint32_t *)src, (uint32_t *)dst, width, height);

        } else {
            game_of_life_bitpacked_atomic_elewise_kernel<<<grid_dim, block>>>(
                (const uint32_t *)src, (uint32_t *)dst, width, height);
        }

    } else if (state->flags & ROWWISE_CUDA_FLAG) {
        int threads = 256;
        int blocks = (height + threads - 1) / threads;
        game_of_life_rowwise_kernel<<<blocks, threads>>>(
            (const uint8_t *)src, (uint8_t *)dst, width, height);

    } else if (state->flags & COLWISE_CUDA_FLAG) {
        int threads = 256;
        int blocks = (width + threads - 1) / threads;
        game_of_life_colwise_kernel<<<blocks, threads>>>(
            (const uint8_t *)src, (uint8_t *)dst, width, height);

    } else {
        dim3 block = cuda_default_block();
        dim3 grid_dim = cuda_default_grid(width, height);
        game_of_life_elewise_kernel<<<grid_dim, block>>>(
            (const uint8_t *)src, (uint8_t *)dst, width, height);
    }

    CUDA_CHECK(cudaGetLastError());
}

__global__ void render_kernel(const uint8_t *grid, float4 *buffer, int width,
                              int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int idx = y * width + x;
    float v = grid[idx] ? 1.0f : 0.0f;

    buffer[idx] = make_float4(v, v, v, 1.0f);
}

__global__ void render_bitpacked_kernel(const uint32_t *grid, float4 *buffer,
                                        int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int idx = y * width + x;
    float v = (grid[idx >> 5] >> (idx & 31)) & 1 ? 1.0f : 0.0f;

    buffer[idx] = make_float4(v, v, v, 1.0f);
}

__global__ void fill_cells_kernel(uint8_t *grid, int width, int height,
                                  const Cell *cells, int count) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx >= count)
        return;

    Cell c = cells[idx];

    if (c.x < 0 || c.x >= width || c.y < 0 || c.y >= height)
        return;

    grid[c.y * width + c.x] = 1;
}

__global__ void fill_cells_bitpacked_kernel(uint32_t *grid, int width,
                                            int height, const Cell *cells,
                                            int count) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx >= count)
        return;

    Cell c = cells[idx];

    if (c.x < 0 || c.x >= width || c.y < 0 || c.y >= height)
        return;

    int i = c.y * width + c.x;
    atomicOr(&grid[i >> 5], 1u << (i & 31));
}

dim3 cuda_default_block() { return dim3(16, 16); }

dim3 cuda_default_grid(int width, int height) {
    return dim3((width + 15) / 16, (height + 15) / 16);
}

void cuda_init_random(void *grid, int width, int height, float fill_pct,
                      unsigned long long seed, int bitpacked) {
    dim3 block = cuda_default_block();
    dim3 grid_dim = cuda_default_grid(width, height);

    if (bitpacked) {
        CUDA_CHECK(cudaMemset(grid, 0, grid_bytes(width, height, 1)));
        init_random_bitpacked_kernel<<<grid_dim, block>>>((uint32_t *)grid, width,
                                                          height, fill_pct, seed);
    } else {
        init_random_kernel<<<grid_dim, block>>>((uint8_t *)grid, width, height,
                                                fill_pct, seed);
    }

    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
}

void cuda_render(const void *grid, float4 *buffer, int width, int height,
                 int bitpacked) {
    dim3 block = cuda_default_block();
    dim3 grid_dim = cuda_default_grid(width, height);

    if (bitpacked) {
        render_bitpacked_kernel<<<grid_dim, block>>>((const uint32_t *)grid, buffer,
                                                     width, height);
    } else {
        render_kernel<<<grid_dim, block>>>((const uint8_t *)grid, buffer, width,
                                           height);
    }

    CUDA_CHECK(cudaGetLastError());
}

void cuda_fill_cells(void *d_grid, int width, int height, const Cell *cells,
                     int count, int bitpacked) {
    if (!cells || count <= 0)
        return;

    Cell *d_cells;
    size_t bytes = count * sizeof(Cell);

    cudaMalloc(&d_cells, bytes);
    cudaMemcpy(d_cells, cells, bytes, cudaMemcpyHostToDevice);

    int block = 256;
    int grid = (count + block - 1) / block;

    if (bitpacked) {
        fill_cells_bitpacked_kernel<<<grid, block>>>((uint32_t *)d_grid, width,
                                                     height, d_cells, count);
    } else {
        fill_cells_kernel<<<grid, block>>>((uint8_t *)d_grid, width, height,
                                           d_cells, count);
    }

    cudaDeviceSynchronize();
    cudaFree(d_cells);
}

void run_headless(const AppState *state) {
    int width = state->grid.x;
    int height = state->grid.y;

    int bp = (state->flags & (BITPACKED_FLAG | BITPACKED_ATOMIC_FLAG)) != 0;
    int needs_memset = (state->flags & BITPACKED_ATOMIC_FLAG) != 0;

    size_t gbytes = grid_bytes(width, height, bp);

    void *d_front, *d_back;
    cudaMalloc(&d_front, gbytes);
    cudaMalloc(&d_back, gbytes);

    cuda_init_random(d_front, width, height,
                     state->random_fill_percentage / 100.0f, 42ULL, bp);
    cudaDeviceSynchronize();

    cuda_fill_cells(d_front, width, height, state->fill_cell_arr,
                    state->fill_cell_count, bp);

    if (needs_memset)
        CUDA_CHECK(cudaMemset(d_back, 0, gbytes));

    int gens = (state->generations > 0) ? state->generations : 1000;
    double total_ms = 0.0;
    double min_ms = 1e9;
    double max_ms = 0.0;

    cudaEvent_t t0, t1;
    cudaEventCreate(&t0);
    cudaEventCreate(&t1);

    for (int g = 0; g < gens; g++) {
        if (needs_memset)
            CUDA_CHECK(cudaMemset(d_back, 0, gbytes));

        cudaEventRecord(t0);
        cuda_game_of_life(d_front, d_back, width, height, state);
        cudaEventRecord(t1);
        cudaEventSynchronize(t1);

        float ms = 0.0f;
        cudaEventElapsedTime(&ms, t0, t1);

        total_ms += ms;
        if (ms < min_ms)
            min_ms = ms;
        if (ms > max_ms)
            max_ms = ms;

        void *tmp = d_front;
        d_front = d_back;
        d_back = tmp;
    }

    cudaEventDestroy(t0);
    cudaEventDestroy(t1);
    cudaFree(d_front);
    cudaFree(d_back);

    double avg_ms = total_ms / gens;
    double avg_fps = 1000.0 / avg_ms;
    long cells = (long)width * height;

    const char *mode =
        (state->flags & BITPACKED_ATOMIC_FLAG) ? "bitpacked-atomic (cell/thread)"
        : (state->flags & BITPACKED_FLAG) ? "bitpacked-wordwise (word/thread)"
        : "byte-per-cell";
    const char *parallelism =
        (state->flags & TILED_FLAG) ?
            ((state->flags & ROWWISE_CUDA_FLAG) ? "rowwise (tiled)" :
             (state->flags & COLWISE_CUDA_FLAG) ? "colwise (tiled)" :
             "elewise (tiled)") :
        (state->flags & ROWWISE_CUDA_FLAG) ? "rowwise" :
        (state->flags & COLWISE_CUDA_FLAG) ? "colwise" :
        "elewise (no tiling)";

    fprintf(stdout, "\n=== Headless Perf Report ===\n");
    fprintf(stdout, "Grid        : %d x %d  (%ld cells)\n", width, height, cells);
    fprintf(stdout, "Mode        : %s / %s\n", mode, parallelism);
    fprintf(stdout, "Generations : %d\n", gens);
    fprintf(stdout, "Avg         : %.3f ms  (%.0f gen/s)\n", avg_ms, avg_fps);
    fprintf(stdout, "Min         : %.3f ms\n", min_ms);
    fprintf(stdout, "Max         : %.3f ms\n", max_ms);
    fprintf(stdout, "Total       : %.1f ms\n", total_ms);
    fprintf(stdout, "Cell-steps/s: %.3e\n", (double)cells * avg_fps);
}
