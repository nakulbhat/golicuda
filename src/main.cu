#include "../include/main.h"
#include "../include/args.h"
#include "../include/state.h"
#include "../include/render.h"
#include "../include/cuda_functions.h"
#include <stdlib.h>

int main(int argc, char **argv) {
    AppState state;
    init_default_state(&state);

    parse_args(&state, argc, argv);
    if (state.flags & HEADLESS_FLAG)
        run_headless(&state);
    else
        start_simulation(&state);
    free_state(&state);

    return 0;
}
