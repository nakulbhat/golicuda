#include "../include/main.h"
#include "../include/args.h"
#include "../include/state.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    AppState state;
    init_default_state(&state);

    parse_args(&state, argc, argv);

    printf("=== Parsed Arguments ===\n");
    printf("Grid size:    %d x %d\n", state.grid.x, state.grid.y);
    printf("Generations:  %d\n", state.generations);
    printf("Fill %%:       %d%%\n", state.random_fill_percentage);

    if (state.fill_cell_count > 0) {
        printf("Fill cells:   %d\n", state.fill_cell_count);
        for (int i = 0; i < state.fill_cell_count; i++)
            printf("  [%d]         %d, %d\n",
                   i,
                   state.fill_cell_arr[i].x,
                   state.fill_cell_arr[i].y);
    } else {
        printf("Fill cells:   none\n");
    }

    printf("\n=== Flags ===\n");
    printf("Verbose:      %s\n", (state.flags & VERBOSE_FLAG) ? "yes" : "no");
    printf("Grid set:     %s\n", (state.flags & GRID_SIZE_FLAG) ? "yes" : "no");
    printf("Rowwise:      %s\n", (state.flags & ROWWISE_CUDA_FLAG) ? "yes" : "no");
    printf("Colwise:      %s\n", (state.flags & COLWISE_CUDA_FLAG) ? "yes" : "no");
    printf("Elementwise:  %s\n", (state.flags & ELEWISE_CUDA_FLAG) ? "yes" : "no");
    printf("Random fill:  %s\n", (state.flags & RANDOM_CELL_FILL_FLAG) ? "yes" : "no");
    printf("Gens set:     %s\n", (state.flags & GENERATIONS_FLAG) ? "yes" : "no");

    printf("\n=== CUDA Mode ===\n");
    if (state.flags & ROWWISE_CUDA_FLAG)
        printf("Mode:         rowwise\n");
    else if (state.flags & COLWISE_CUDA_FLAG)
        printf("Mode:         colwise\n");
    else if (state.flags & ELEWISE_CUDA_FLAG)
        printf("Mode:         elementwise\n");
    free_state(&state);

    return 0;
}
