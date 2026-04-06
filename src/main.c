#include "../include/main.h"
#include "../include/args.h"
#include <stdio.h>

Cell grid = {100, 100};
int flags = 0;
int random_fill_percentage = 0;
int generations = 100;
Cell *fill_cell_arr = NULL;
int fill_cell_count = 0;

int main(int argc, char **argv) {
    parse_args(argc, argv);

    printf("=== Parsed Arguments ===\n");
    printf("Grid size:    %d x %d\n", grid.x, grid.y);
    printf("Generations:  %d\n", generations);
    printf("Fill %%:       %d%%\n", random_fill_percentage);

    if (fill_cell_count > 0) {
        printf("Fill cells:   %d\n", fill_cell_count);
        for (int i = 0; i < fill_cell_count; i++)
            printf("  [%d]         %d, %d\n", i, fill_cell_arr[i].x, fill_cell_arr[i].y);
    } else {
        printf("Fill cells:   none\n");
    }

    printf("\n=== Flags ===\n");
    printf("Verbose:      %s\n", (flags & VERBOSE_FLAG)          ? "yes" : "no");
    printf("Grid set:     %s\n", (flags & GRID_SIZE_FLAG)        ? "yes" : "no");
    printf("Rowwise:      %s\n", (flags & ROWWISE_CUDA_FLAG)     ? "yes" : "no");
    printf("Colwise:      %s\n", (flags & COLWISE_CUDA_FLAG)     ? "yes" : "no");
    printf("Elementwise:  %s\n", (flags & ELEWISE_CUDA_FLAG)     ? "yes" : "no");
    printf("Random fill:  %s\n", (flags & RANDOM_CELL_FILL_FLAG) ? "yes" : "no");
    printf("Gens set:     %s\n", (flags & GENERATIONS_FLAG)      ? "yes" : "no");

    printf("\n=== CUDA Mode ===\n");
    if (flags & ROWWISE_CUDA_FLAG)       printf("Mode:         rowwise\n");
    else if (flags & COLWISE_CUDA_FLAG)  printf("Mode:         colwise\n");
    else if (flags & ELEWISE_CUDA_FLAG)  printf("Mode:         elementwise%s\n",
                                             (flags & GENERATIONS_FLAG) ? "" : " (default)");

    return 0;
}
