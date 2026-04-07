TARGET = golicuda
NVCC = nvcc
NVCC_FLAGS = -Xcompiler -fPIE -lGL -lGLEW -lglfw -Wno-deprecated-gpu-targets

SRC = $(wildcard src/*.cu)
OBJ = $(patsubst src/%.cu, obj/%.o, $(SRC))
INCLUDE = $(wildcard include/*.h)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJ)
	$(NVCC) $(NVCC_FLAGS) $^ -o $@

obj/%.o: src/%.cu $(INCLUDE)    # ← .cu not .c
	mkdir -p obj
	$(NVCC) $(NVCC_FLAGS) -I include -c $< -o $@

clean:
	rm -f $(TARGET) $(OBJ)
	rm -rf obj/
