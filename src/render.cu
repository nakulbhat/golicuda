#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include <cuda_runtime.h>
#include <cuda_gl_interop.h>

#include <stdio.h>
#include <math.h>

#include "../include/main.h"
#include "../include/state.h"

////////////////////////////////////////////////////////////////////////////////
// GLOBAL CAMERA STATE
////////////////////////////////////////////////////////////////////////////////

float zoom = 8.0f;
float offsetX = 0.0f;
float offsetY = 0.0f;

double lastMouseX = 0;
double lastMouseY = 0;
int dragging = 0;

////////////////////////////////////////////////////////////////////////////////
// MOUSE CONTROLS
////////////////////////////////////////////////////////////////////////////////

void scroll_callback(GLFWwindow *window, double xoffset, double yoffset) {
    zoom += yoffset * 0.5f;

    if (zoom < 1.0f)
        zoom = 1.0f;

    if (zoom > 200.0f)
        zoom = 200.0f;
}

void mouse_button_callback(GLFWwindow *window, int button, int action,
                           int mods) {
    if (button == GLFW_MOUSE_BUTTON_LEFT) {
        if (action == GLFW_PRESS)
            dragging = 1;
        else
            dragging = 0;
    }
}

void cursor_position_callback(GLFWwindow *window, double xpos, double ypos) {

    if (!dragging) {
        lastMouseX = xpos;
        lastMouseY = ypos;
        return;
    }

    float dx = xpos - lastMouseX;
    float dy = ypos - lastMouseY;

    lastMouseX = xpos;
    lastMouseY = ypos;

    offsetX -= dx / 1000.0f / zoom;
    offsetY += dy / 1000.0f / zoom;
}

////////////////////////////////////////////////////////////////////////////////
// CUDA KERNEL
////////////////////////////////////////////////////////////////////////////////

__global__ void checkerboard_kernel(float4 *buffer, int width, int height,
                                    float t) {

    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    int idx = y * width + x;

    int checker = (x + y) % 2;
    int inverted = !checker;

    float fade = (sin(t) + 1.0f) * 0.5f;

    float value = checker * (1.0f - fade) + inverted * fade;

    buffer[idx] = make_float4(value, value, value, 1.0f);
}

////////////////////////////////////////////////////////////////////////////////
// SHADERS
////////////////////////////////////////////////////////////////////////////////

static const char *vertexShaderSource =
    "#version 330 core\n"
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

////////////////////////////////////////////////////////////////////////////////
// MAIN FUNCTION
////////////////////////////////////////////////////////////////////////////////

void test_gl_functions(AppState *state) {

    int width = state->grid.x;
    int height = state->grid.y;

    if (!glfwInit())
        FATAL("GLFW init failed");

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window =
        glfwCreateWindow(width, height, "CUDA Conway", NULL, NULL);

    if (!window) {
        glfwTerminate();
        FATAL("Window failed");
    }

    glfwMakeContextCurrent(window);

    glfwSetScrollCallback(window, scroll_callback);
    glfwSetCursorPosCallback(window, cursor_position_callback);
    glfwSetMouseButtonCallback(window, mouse_button_callback);

    if (glewInit() != GLEW_OK)
        FATAL("GLEW failed");

    glViewport(0, 0, width, height);

    ////////////////////////////////////////////////////////////////////////////
    // SHADERS
    ////////////////////////////////////////////////////////////////////////////

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    GLuint shaderProgram = glCreateProgram();

    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    GLuint zoomLoc = glGetUniformLocation(shaderProgram, "zoom");
    GLuint offsetLoc = glGetUniformLocation(shaderProgram, "offset");

    ////////////////////////////////////////////////////////////////////////////
    // FULLSCREEN QUAD
    ////////////////////////////////////////////////////////////////////////////

    float quad[] = {-1.f, -1.f, 1.f, -1.f, 1.f, 1.f, -1.f, 1.f};

    unsigned int indices[] = {0, 1, 2, 2, 3, 0};

    GLuint VAO, VBO, EBO;

    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices,
                 GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), NULL);

    glEnableVertexAttribArray(0);

    ////////////////////////////////////////////////////////////////////////////
    // TEXTURE
    ////////////////////////////////////////////////////////////////////////////

    GLuint texture;

    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA,
                 GL_FLOAT, NULL);

    ////////////////////////////////////////////////////////////////////////////
    // CUDA PBO
    ////////////////////////////////////////////////////////////////////////////

    GLuint pbo;
    cudaGraphicsResource *cuda_pbo;

    glGenBuffers(1, &pbo);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);

    glBufferData(GL_PIXEL_UNPACK_BUFFER,
                 width * height * sizeof(float4),
                 NULL,
                 GL_DYNAMIC_DRAW);

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

    cudaGraphicsGLRegisterBuffer(&cuda_pbo, pbo,
                                 cudaGraphicsMapFlagsWriteDiscard);

    ////////////////////////////////////////////////////////////////////////////
    // LOOP
    ////////////////////////////////////////////////////////////////////////////

    float time = 0.0f;

    while (!glfwWindowShouldClose(window)) {

        time += 0.02f;

        float4 *dptr;
        size_t num_bytes;

        cudaGraphicsMapResources(1, &cuda_pbo, 0);

        cudaGraphicsResourceGetMappedPointer(
            (void **)&dptr,
            &num_bytes,
            cuda_pbo);

        dim3 block(16, 16);
        dim3 grid((width + 15) / 16, (height + 15) / 16);

        checkerboard_kernel<<<grid, block>>>(
            dptr,
            width,
            height,
            time);

        cudaGraphicsUnmapResources(1, &cuda_pbo, 0);

        ////////////////////////////////////////////////////////////////////////////
        // UPDATE TEXTURE
        ////////////////////////////////////////////////////////////////////////////

        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);

        glBindTexture(GL_TEXTURE_2D, texture);

        glTexSubImage2D(GL_TEXTURE_2D,
                        0,
                        0,
                        0,
                        width,
                        height,
                        GL_RGBA,
                        GL_FLOAT,
                        0);

        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

        ////////////////////////////////////////////////////////////////////////////
        // RENDER
        ////////////////////////////////////////////////////////////////////////////

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);

        glUniform1f(zoomLoc, zoom);
        glUniform2f(offsetLoc, offsetX, offsetY);

        glBindVertexArray(VAO);

        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    cudaGraphicsUnregisterResource(cuda_pbo);

    glfwDestroyWindow(window);
    glfwTerminate();
}
