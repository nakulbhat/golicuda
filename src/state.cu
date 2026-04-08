#include <stdlib.h>
#include "../include/state.h"

void init_default_state(AppState *state) {
    state->grid = (Cell){100, 100};
    state->flags = 0;
    state->random_fill_percentage = 8;
    state->generations = 100;
    state->fill_cell_arr = NULL;
    state->fill_cell_count = 0;
}

void free_state(AppState *state) {
    free(state->fill_cell_arr);
}
