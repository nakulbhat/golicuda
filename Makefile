TARGET = golicuda

CC = nvcc
CFLAGS = -lGL -lGLEW -lglfw -Wno-deprecated-gpu-targets

SRC = $(wildcard src/*.cu)
OBJ = $(patsubst src/%.cu, obj/%.o, $(SRC))
INCLUDE = $(wildcard include/*.h)


.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) $^ -o $@

obj/%.o: src/%.c $(INCLUDE)
	mkdir -p obj
	$(CC) $(CFLAGS) -I include -c $< -o $@

clean:
	rm -f $(TARGET) $(OBJ)
	rm -rf obj/
