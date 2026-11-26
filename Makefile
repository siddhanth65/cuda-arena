NVCC ?= nvcc
NVCC_FLAGS ?= -O3 -std=c++17 -lineinfo

TOURNAMENT_TARGET = cuda_tournament
DUEL_TARGET = cuda_arena_duel
TOURNAMENT_SOURCE = src/cuda_tournament.cu
DUEL_SOURCE = src/cuda_arena.cu

.PHONY: all clean run benchmark duel

all: $(TOURNAMENT_TARGET) $(DUEL_TARGET)

$(TOURNAMENT_TARGET): $(TOURNAMENT_SOURCE)
	$(NVCC) $(NVCC_FLAGS) $< -o $@

$(DUEL_TARGET): $(DUEL_SOURCE)
	$(NVCC) $(NVCC_FLAGS) $< -o $@

run: $(TOURNAMENT_TARGET)
	./$(TOURNAMENT_TARGET)

benchmark: $(TOURNAMENT_TARGET)
	./$(TOURNAMENT_TARGET) --games 1048576 --iterations 5

duel: $(DUEL_TARGET)
	./$(DUEL_TARGET) --games 3

clean:
	rm -f $(TOURNAMENT_TARGET) $(DUEL_TARGET)
