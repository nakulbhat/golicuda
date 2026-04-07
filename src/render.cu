#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <stdio.h>

#include "../include/main.h"
#include "../include/state.h"

// To use time library of C
#include <time.h>

void delay(int number_of_seconds) {
    // Converting time into milli_seconds
    int milli_seconds = 1000 * number_of_seconds;

    // Storing start time
    clock_t start_time = clock();

    // looping till required time is not achieved
    while (clock() < start_time + milli_seconds)
        ;
}

typedef struct {
    float r;
    float g;
    float b;
    float a;
} Color;

float lerp(float a, float b, float t) { return a + t * (b - a); }

Color lerp_color(Color a, Color b, float t) {
    Color result;
    result.r = lerp(a.r, b.r, t);
    result.g = lerp(a.g, b.g, t);
    result.b = lerp(a.b, b.b, t);
    result.a = lerp(a.a, b.a, t);
    return result;
}

void test_gl_functions(AppState *state) {

    if (!glfwInit())
        FATAL("GLFW init failed");

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    // create a window
    GLFWwindow *window = glfwCreateWindow(state->grid.x, state->grid.y,
                                          "Conway Game of Life", NULL, NULL);

    if (!window) {
        glfwTerminate();
        FATAL("GLFW Window failed to load");
    }

    // mark the context as active
    glfwMakeContextCurrent(window);

    glViewport(0, 0, state->grid.x, state->grid.y);

    if (glewInit() != GLEW_OK)
        FATAL("GLEW init failed");

    const char *vertexShaderSource = "#version 330 core\n"
        "layout (location = 0) in vec3 aPos;\n"
        "void main()\n"
        "{\n"
        "   gl_Position = vec4(aPos, 1.0);\n"
        "}\0";

    const char *fragmentShaderSource =
        "#version 330 core\n"
        "out vec4 FragColor;\n"
        "void main()\n"
        "{\n"
        "   FragColor = vec4(1.0, 0.5, 0.2, 1.0);\n"
        "}\n\0";
    float vertices[] = {-0.5f, -0.5f, 0.0f, 0.5f,  -0.5f, 0.0f,
        0.5f,  0.5f,  0.0f, -0.5f, 0.5f,  0.0f};
    unsigned int indices[] = {0, 1, 2, 2, 3, 0};

    GLuint VAO, VBO, EBO;

    glGenBuffers(1, &VBO);
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices,
                 GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), NULL);
    glEnableVertexAttribArray(0);
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    int success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        printf("Vertex shader error:\n%s\n", infoLog);
    }

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        printf("Fragment shader error:\n%s\n", infoLog);
    }

    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        printf("Shader linking error:\n%s\n", infoLog);
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    Color test = {0.0f, 0.0f, 0.0f, 1.0f};
    Color test2 = {1.0f, 1.0f, 1.0f, 1.0f};

float t = 0.0f;
float speed = 0.5f;
int direction = 1;

double lastTime = glfwGetTime();

while (!glfwWindowShouldClose(window)) {

    double currentTime = glfwGetTime();
    float deltaTime = currentTime - lastTime;
    lastTime = currentTime;

    t += direction * speed * deltaTime;

    if (t >= 1.0f) {
        t = 1.0f;
        direction = -1;
    }

    if (t <= 0.0f) {
        t = 0.0f;
        direction = 1;
    }

    Color clr = lerp_color(test, test2, t);

    glClearColor(clr.r, clr.g, clr.b, clr.a);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(shaderProgram);
    glBindVertexArray(VAO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

    glfwSwapBuffers(window);
    glfwPollEvents();
}

    glfwDestroyWindow(window);
    glfwTerminate();
}
