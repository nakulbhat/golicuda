#pragma once
#include "state.h"

typedef struct {
    int pattern_width;
    int pattern_height;
} RLEInfo;


RLEInfo load_rle(AppState *state, const char *filename);
