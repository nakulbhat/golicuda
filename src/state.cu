#include <stdlib.h>
#include "../include/state.h"

void init_default_state(AppState *state) {
    state->grid = (Cell){100, 100};
    state->flags = 0;
    state->random_fill_percentage = 8;
    state->generations = 100;
    state->fill_cell_arr = NULL;
    state->fill_cell_count = 0;
    state->rle_file = NULL;
    state->pattern_width  = 0;
    state->pattern_height = 0;
}

void free_state(AppState *state) {
    free(state->fill_cell_arr);
    state->fill_cell_arr = NULL;   
    free(state->rle_file);        
    state->rle_file = NULL;
}
