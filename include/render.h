#pragma once 

#include "state.h"
#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include <cuda_gl_interop.h>


typedef struct {
    GLFWwindow *window;

    int width;
    int height;

    GLuint shaderProgram;
    GLuint VAO, VBO, EBO;
    GLuint texture;
    GLuint pbo;

    cudaGraphicsResource *cuda_pbo;

    uint8_t *d_front;
    uint8_t *d_back;

    GLuint zoomLoc;
    GLuint offsetLoc;

    float zoom;
    float offsetX;
    float offsetY;

    double lastMouseX;
    double lastMouseY;
    int dragging;
} GLContext;

static void gl_init(GLContext *ctx, AppState *state);
static void gl_update(GLContext *ctx);
static void gl_render(GLContext *ctx);
static void gl_cleanup(GLContext *ctx);

static void scroll_callback(GLFWwindow *window, double xoffset, double yoffset);
static void mouse_button_callback(GLFWwindow *window, int button, int action, int mods);
static void cursor_position_callback(GLFWwindow *window, double xpos, double ypos);

void start_simulation(AppState *state);

