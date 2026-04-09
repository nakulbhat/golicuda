#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include <cstdlib>
#include <cuda_gl_interop.h>
#include <cuda_runtime.h>

#include <curand_kernel.h>

#include <math.h>
#include <stdio.h>
#include <sys/types.h>

#include "../include/cuda_functions.h"
#include "../include/main.h"
#include "../include/render.h"
#include "../include/state.h"

static void scroll_callback(GLFWwindow *window, double xoffset, double yoffset) {
    GLContext *ctx = (GLContext *)glfwGetWindowUserPointer(window);

    // Get cursor position in [0,1] UV space
    double mx, my;
    glfwGetCursorPos(window, &mx, &my);
    float uvX = (float)mx / ctx->width;
    float uvY = 1.0f - (float)my / ctx->height; // flip Y to match GL

    // World point under cursor before zoom
    float worldX = (uvX - 0.5f) / ctx->zoom + 0.5f + ctx->offsetX;
    float worldY = (uvY - 0.5f) / ctx->zoom + 0.5f + ctx->offsetY;

    // Apply zoom
    ctx->zoom += yoffset * 0.5f * (ctx->zoom * 0.2f); // optional: scale speed with zoom level
    float minzoom = 1.0f, maxzoom = 100.0f;
    if (ctx->zoom < minzoom) ctx->zoom = minzoom;
    if (ctx->zoom > maxzoom) ctx->zoom = maxzoom;

    // Adjust offset so the same world point stays under the cursor
    ctx->offsetX = worldX - (uvX - 0.5f) / ctx->zoom - 0.5f;
    ctx->offsetY = worldY - (uvY - 0.5f) / ctx->zoom - 0.5f;
}

static void mouse_button_callback(GLFWwindow *window, int button, int action,
                                  int mods) {

    GLContext *ctx = (GLContext *)glfwGetWindowUserPointer(window);

    if (button == GLFW_MOUSE_BUTTON_LEFT) {
        ctx->dragging = (action == GLFW_PRESS);
    }
}

static void cursor_position_callback(GLFWwindow *window, double xpos,
                                     double ypos) {

    GLContext *ctx = (GLContext *)glfwGetWindowUserPointer(window);

    if (!ctx->dragging) {
        ctx->lastMouseX = xpos;
        ctx->lastMouseY = ypos;
        return;
    }

    float dx = xpos - ctx->lastMouseX;
    float dy = ypos - ctx->lastMouseY;

    ctx->lastMouseX = xpos;
    ctx->lastMouseY = ypos;

    ctx->offsetX -= dx / 1000.0f / ctx->zoom;
    ctx->offsetY += dy / 1000.0f / ctx->zoom;
}

static void key_callback(GLFWwindow *window, int key, int scancode, int action, int mods) {
    GLContext *ctx = (GLContext *)glfwGetWindowUserPointer(window);
    if (key == GLFW_KEY_SPACE && action == GLFW_PRESS) {
        ctx->paused = !ctx->paused;
    }
    if (key == GLFW_KEY_R && action == GLFW_PRESS) {
    ctx->zoom = 1.0f;
    ctx->offsetX = 0.0f;
    ctx->offsetY = 0.0f;
    }
}

static const char *vertexShaderSource = "#version 330 core\n"
    "layout (location = 0) in vec2 aPos;\n"
    "out vec2 uv;\n"
    "void main()\n"
    "{\n"
    "   uv = (aPos + 1.0) * 0.5;\n"
    "   gl_Position = vec4(aPos,0,1);\n"
    "}";

static const char *fragmentShaderSource =
    "#version 330 core\n"
    "in vec2 uv;\n"
    "out vec4 FragColor;\n"
    "uniform sampler2D tex;\n"
    "uniform float zoom;\n"
    "uniform vec2 offset;\n"
    "void main()\n"
    "{\n"
    "   vec2 scaled = (uv - 0.5) / zoom + 0.5 + offset;\n"
    "   FragColor = texture(tex, scaled);\n"
    "}";

static void gl_init(GLContext *ctx, const AppState *state) {

    ctx->width = state->grid.x;
    ctx->height = state->grid.y;
    ctx->generations = 0;
    ctx->paused = 1;
    ctx->no_vsync = state->flags & NO_VSYNC_FLAG;

    ctx->zoom = 1.0f;
    if ((state->flags & RLE_FILE_FLAG) && state->pattern_width > 0) {
        // Zoom so the pattern spans ~70% of the smaller screen dimension
        float fit_w = (ctx->width  * 0.7f) / state->pattern_width;
        float fit_h = (ctx->height * 0.7f) / state->pattern_height;
        ctx->zoom = fit_w < fit_h ? fit_w : fit_h;
        if (ctx->zoom < 1.0f) ctx->zoom = 1.0f;
    }
    ctx->offsetX = 0.0f;
    ctx->offsetY = 0.0f;
    ctx->dragging = 0;

    if (!glfwInit())
        FATAL("GLFW init failed");

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    ctx->window =
        glfwCreateWindow(ctx->width, ctx->height, "CUDA Conway", NULL, NULL);

    if (!ctx->window) {
        glfwTerminate();
        FATAL("Window failed");
    }

    glfwMakeContextCurrent(ctx->window);

    if (ctx->no_vsync) glfwSwapInterval(0);

    glfwSetWindowUserPointer(ctx->window, ctx);

    glfwSetScrollCallback(ctx->window, scroll_callback);
    glfwSetCursorPosCallback(ctx->window, cursor_position_callback);
    glfwSetMouseButtonCallback(ctx->window, mouse_button_callback);
    glfwSetKeyCallback(ctx->window, key_callback);

    if (glewInit() != GLEW_OK)
        FATAL("GLEW failed");

    glViewport(0, 0, ctx->width, ctx->height);

    
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    ctx->shaderProgram = glCreateProgram();

    glAttachShader(ctx->shaderProgram, vertexShader);
    glAttachShader(ctx->shaderProgram, fragmentShader);
    glLinkProgram(ctx->shaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    ctx->zoomLoc = glGetUniformLocation(ctx->shaderProgram, "zoom");
    ctx->offsetLoc = glGetUniformLocation(ctx->shaderProgram, "offset");

    
    float quad[] = {-1.f, -1.f, 1.f, -1.f, 1.f, 1.f, -1.f, 1.f};

    unsigned int indices[] = {0, 1, 2, 2, 3, 0};

    glGenVertexArrays(1, &ctx->VAO);
    glGenBuffers(1, &ctx->VBO);
    glGenBuffers(1, &ctx->EBO);

    glBindVertexArray(ctx->VAO);

    glBindBuffer(GL_ARRAY_BUFFER, ctx->VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ctx->EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices,
                 GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), NULL);

    glEnableVertexAttribArray(0);

    
    glGenTextures(1, &ctx->texture);
    glBindTexture(GL_TEXTURE_2D, ctx->texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, ctx->width, ctx->height, 0,
                 GL_RGBA, GL_FLOAT, NULL);

    
    glGenBuffers(1, &ctx->pbo);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, ctx->pbo);

    glBufferData(GL_PIXEL_UNPACK_BUFFER,
                 ctx->width * ctx->height * sizeof(float4), NULL,
                 GL_DYNAMIC_DRAW);

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

    cudaGraphicsGLRegisterBuffer(&ctx->cuda_pbo, ctx->pbo,
                                 cudaGraphicsMapFlagsWriteDiscard);

    
    int    bp     = (state->flags & BITPACKED_FLAG) != 0;
    size_t gbytes = grid_bytes(ctx->width, ctx->height, bp);

    void *d_a, *d_b;
    cudaMalloc(&d_a, gbytes);
    cudaMalloc(&d_b, gbytes);
    if (bp) cudaMemset(d_b, 0, gbytes);  

    cuda_init_random(d_a, ctx->width, ctx->height,
                     ((float)state->random_fill_percentage) / 100.0f, 42ULL, bp);
    cudaDeviceSynchronize();

    cuda_fill_cells(d_a, ctx->width, ctx->height,
                    state->fill_cell_arr, state->fill_cell_count, bp);
    ctx->d_front = d_a;
    ctx->d_back = d_b;
}
static void gl_render(GLContext *ctx) {

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, ctx->pbo);
    glBindTexture(GL_TEXTURE_2D, ctx->texture);

    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ctx->width, ctx->height, GL_RGBA,
                    GL_FLOAT, 0);

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(ctx->shaderProgram);

    glUniform1f(ctx->zoomLoc, ctx->zoom);
    glUniform2f(ctx->offsetLoc, ctx->offsetX, ctx->offsetY);

    glBindVertexArray(ctx->VAO);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

static void gl_cleanup(GLContext *ctx) {

    cudaFree(ctx->d_front);
    cudaFree(ctx->d_back);

    cudaGraphicsUnregisterResource(ctx->cuda_pbo);

    glfwDestroyWindow(ctx->window);
    glfwTerminate();
}

static void gl_update(GLContext *ctx, const AppState *state) {

    float4 *dptr;
    size_t num_bytes;

    cudaGraphicsMapResources(1, &ctx->cuda_pbo, 0);

    cudaGraphicsResourceGetMappedPointer((void **)&dptr, &num_bytes,
                                         ctx->cuda_pbo);

    int bp = (state->flags & BITPACKED_FLAG) != 0;
    if (bp) cudaMemset(ctx->d_back, 0, grid_bytes(ctx->width, ctx->height, 1));

    cuda_game_of_life(ctx->d_front, ctx->d_back, ctx->width, ctx->height, state);
    cuda_render(ctx->d_back, dptr, ctx->width, ctx->height, bp);

    cudaGraphicsUnmapResources(1, &ctx->cuda_pbo, 0);

    // ping-pong swap
    void *tmp = ctx->d_front;
    ctx->d_front = ctx->d_back;
    ctx->d_back = tmp;

    ctx->generations++;
}

void start_simulation(const AppState *state) {
    GLContext ctx = {0};

    gl_init(&ctx, state);

    // render initial state
    float4 *dptr;
    size_t num_bytes;
    cudaGraphicsMapResources(1, &ctx.cuda_pbo, 0);
    cudaGraphicsResourceGetMappedPointer((void **)&dptr, &num_bytes, ctx.cuda_pbo);
    int bp = (state->flags & BITPACKED_FLAG) != 0;
    cuda_render(ctx.d_front, dptr, ctx.width, ctx.height, bp);
    cudaGraphicsUnmapResources(1, &ctx.cuda_pbo, 0);

    double last_time = glfwGetTime();
    while (!glfwWindowShouldClose(ctx.window)) {
        if (state->generations != -1 && ctx.generations >= state->generations){
            LOG(state, "%d generations simulated. Exiting.", state->generations);
            exit(EXIT_SUCCESS);
        }
        if (!ctx.paused)
            gl_update(&ctx, state);
        gl_render(&ctx);


        if (state->flags & VERBOSE_FLAG) {
            double now = glfwGetTime();
            double dt = now - last_time;
            last_time = now;

            static double avg = 0.0;
            avg = avg * 0.9 + dt * 0.1;

            double fps = 1.0 / avg;

            LOG(state, "FPS: %.0f | frametime: %.3f ms", fps, dt * 1000.0);
            
        }

        glfwSwapBuffers(ctx.window);
        glfwPollEvents();
    }

    gl_cleanup(&ctx);
}
