# golicuda

A GPU-accelerated Conway's Game of Life using CUDA and OpenGL, with real-time interactive rendering.

![CUDA](https://img.shields.io/badge/CUDA-parallel-76b900?logo=nvidia&logoColor=white)
![OpenGL](https://img.shields.io/badge/OpenGL-3.3-5586a4?logo=opengl&logoColor=white)

---

## Features

- **Three CUDA parallelisation modes** — element-wise (default), row-wise, and column-wise
- **CUDA–OpenGL PBO interop** — rendered pixels written directly to GPU memory, no host round-trips
- **Ping-pong double buffering** — correct parallel read/write semantics across generations
- **GPU-side random init** via `curand`
- **RLE pattern loading** — compatible with standard Game of Life pattern files
- **Interactive viewport** — zoom (cursor-anchored) and pan via mouse, pause/resume via spacebar
- **Configurable grid sizes** with named presets up to 4K
- **VSync toggle** for uncapped framerate benchmarking

---

## Requirements

- CUDA-capable GPU (sm_50+)
- CUDA Toolkit
- OpenGL 3.3+
- GLFW3
- GLEW

---

## Building

The Makefile compiles for `arch=sm_86` by default. Modify `nvcc` flags to 
compile for other architectures.

```bash
make
```

---

## Usage

```
golicuda [OPTIONS] [CELLS...]
```

### Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-h` | `--help` | Show help |
| `-v` | `--verbose` | Verbose logging + FPS counter |
| `-s <size>` | `--size` | Grid size as `W,H` or a preset (see below) |
| `-r` | `--rowwise` | Row-wise CUDA kernel |
| `-c` | `--colwise` | Column-wise CUDA kernel |
| `-e` | `--element` | Element-wise CUDA kernel (default) |
| `-f <0-100>` | `--fill` | Random fill percentage (default: 8) |
| `-n <num>` | `--gens` | Generations to simulate (`-1` for infinite) |
| `-i <file>` | `--input-rle` | Load a `.rle` pattern file |
| `-V` | `--no-vsync` | Disable VSync |

### Size Presets

| Preset | Resolution |
|--------|------------|
| `480p` | 854 × 480 |
| `720p` | 1280 × 720 |
| `1080p` | 1920 × 1080 |
| `2k` | 2560 × 1440 |
| `4k` | 3840 × 2160 |

### Controls

| Input | Action |
|-------|--------|
| `Space` | Pause / resume |
| `Scroll` | Zoom (anchored to cursor) |
| `Left drag` | Pan |
| `R` | Reset view |

---

## Examples

```bash
# Run with defaults (100×100, 8% fill, element-wise, 100 generations)
./golicuda

# 1080p grid, 30% fill, infinite generations
./golicuda -s 1080p -f 30 -n -1

# Load a Gosper glider gun pattern
./golicuda -i gosper.rle -s 200,200

# Benchmark row-wise vs element-wise with vsync off
./golicuda -r -s 4k -V -v
./golicuda -e -s 4k -V -v

# Place specific cells manually
./golicuda 10,10 10,11 10,12

# Custom grid size, column-wise CUDA, verbose output
./golicuda -s 500,500 -c -v
```

---

## CUDA Kernel Modes

The simulation step can be parallelised at three granularities, selectable at runtime:

**Element-wise** (`-e`, default): one thread per cell, launched as a 2D grid of 16×16 blocks. Maximum parallelism; best throughput on large grids.

**Row-wise** (`-r`): one thread per row, each iterating across all columns. Useful for comparing coarser parallelism against the element-wise baseline.

**Column-wise** (`-c`): one thread per column, symmetric to row-wise.

All modes use toroidal (wrap-around) boundaries.

---

## RLE Format

Standard `.rle` files from the [LifeWiki](https://conwaylife.com/wiki/) pattern library are supported. Pass the file path with `-i`:

```bash
./golicuda -i glider.rle -s 100,100
```

---

## License

MIT
