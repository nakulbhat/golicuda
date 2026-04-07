#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <stdio.h>

#include "../include/state.h"
#include "../include/main.h"

// To use time library of C
#include <time.h>

void delay(int number_of_seconds)
{
	// Converting time into milli_seconds
	int milli_seconds = 1000 * number_of_seconds;

	// Storing start time
	clock_t start_time = clock();

	// looping till required time is not achieved
	while (clock() < start_time + milli_seconds)
		;
}

typedef struct{
    float r;
    float g;
    float b;
    float a;
} Color;


void test_gl_functions(AppState *state){

    if (!glfwInit()) 
        FATAL("GLFW init failed");

    // create a window
    GLFWwindow *window = glfwCreateWindow(
        state->grid.x,
        state->grid.y,
        "Conway Game of Life",
        NULL,
        NULL
    );

    if(!window) {
        glfwTerminate();
        FATAL("GLFW Window failed to load");
    }

    // mark the context as active
    glfwMakeContextCurrent(window);

    if (glewInit() != GLEW_OK)
        FATAL("GLEW init failed");

    Color test = {1.0f, 0.0f, 0.0f, 1.0f};
    Color test2 = {0.0f, 1.0f, 0.0f, 1.0f};
    Color clr = test;
    int mode = 0;
    while(!glfwWindowShouldClose(window)){
        delay(100);
        if(mode){
            mode = 0;
            clr = test2;
        }
        else{
            mode = 1;
            clr = test;
        }
        glClearColor(clr.r, clr.g, clr.b, clr.a);
        glClear(GL_COLOR_BUFFER_BIT);
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();
}
