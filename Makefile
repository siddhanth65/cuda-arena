NVCC ?= nvcc
NVCC_FLAGS ?= -O2 -std=c++17
TARGET = cuda_arena
SOURCE = src/cuda_arena.cu

.PHONY: all clean run
all: $(TARGET)
$(TARGET): $(SOURCE)
	$(NVCC) $(NVCC_FLAGS) $(SOURCE) -o $(TARGET)
run: $(TARGET)
	./$(TARGET)
clean:
	rm -f $(TARGET)
