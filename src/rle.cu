#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#include "../include/rle.h"
#include "../include/main.h"

static void push_cell(AppState *state, int x, int y) {
    state->fill_cell_arr = (Cell *) realloc(
        state->fill_cell_arr,
        sizeof(Cell) * (state->fill_cell_count + 1));

    state->fill_cell_arr[state->fill_cell_count++] = (Cell){x, y};
}

RLEInfo load_rle(AppState *state, const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f)
        FATAL("Failed to open RLE file: %s", filename);

    char line[1024];
    int x = 0, y = 0, count = 0;
    RLEInfo info = {0, 0};

    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '#')
            continue;

        // Parse header: x = W, y = H, ...
        if (strstr(line, "x =")) {
            sscanf(line, " x = %d , y = %d", &info.pattern_width, &info.pattern_height);
            continue;
        }

        for (char *c = line; *c; c++) {
            if (isdigit(*c)) {
                count = count * 10 + (*c - '0');
                continue;
            }
            int n = count ? count : 1;
            count = 0;

            switch (*c) {
            case 'o':
                for (int i = 0; i < n; i++)
                    push_cell(state, x++, y);
                break;
            case 'b':
                x += n;
                break;
            case '$':
                y += n;
                x = 0;
                break;
            case '!':
                goto done;
            }
        }
    }
done:
    fclose(f);

    // Offset all cells to center the pattern on the grid
    int off_x = (state->grid.x - info.pattern_width)  / 2;
    int off_y = (state->grid.y - info.pattern_height) / 2;
    for (int i = 0; i < state->fill_cell_count; i++) {
        state->fill_cell_arr[i].x += off_x;
        state->fill_cell_arr[i].y += off_y;
    }

    return info;
}
