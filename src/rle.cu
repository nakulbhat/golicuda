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

void load_rle(AppState *state, const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f)
        FATAL("Failed to open RLE file: %s", filename);

    char line[1024];

    int x = 0;
    int y = 0;
    int count = 0;

    while (fgets(line, sizeof(line), f)) {

        // skip comments
        if (line[0] == '#')
            continue;

        // skip header
        if (strstr(line, "x ="))
            continue;

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
                fclose(f);
                return;
            }
        }
    }

    fclose(f);
}
