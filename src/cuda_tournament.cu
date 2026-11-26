#include <cuda_runtime.h>
#include <cerrno>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <system_error>
#include <vector>

namespace {
constexpr int kEmpty = 0;
constexpr int kX = 1;
constexpr int kO = 2;
constexpr int kBoardCells = 9;
constexpr int kDefaultGames = 262144;
constexpr int kDefaultIterations = 5;
constexpr int kMaxGames = 20000000;
constexpr int kMaxIterations = 100;

struct GameResult {
  int winner;
  int moves;
};
struct Options {
  int games = kDefaultGames;
  int iterations = kDefaultIterations;
  std::uint32_t seed = 2026U;
  std::string csv_path = "results/tournament_results.csv";
};

#define CUDA_CHECK(call)                                                       \
  do {                                                                         \
    const cudaError_t error = (call);                                          \
    if (error != cudaSuccess) {                                                \
      std::cerr << "CUDA error: " << cudaGetErrorString(error) << " at "       \
                << __FILE__ << ":" << __LINE__ << '\n';                       \
      std::exit(EXIT_FAILURE);                                                 \
    }                                                                          \
  } while (0)

__host__ __device__ std::uint32_t mix_bits(std::uint32_t value) {
  value ^= value >> 16;
  value *= 0x7feb352dU;
  value ^= value >> 15;
  value *= 0x846ca68bU;
  value ^= value >> 16;
  return value;
}

__host__ __device__ bool is_winning_move(const int* board, int cell,
                                       int player) {
  if (board[cell] != kEmpty) return false;
  const int row = cell / 3;
  const int column = cell % 3;
  bool wins = true;
  for (int index = 0; index < 3; ++index) {
    if (index != column && board[row * 3 + index] != player) wins = false;
  }
  if (wins) return true;
  wins = true;
  for (int index = 0; index < 3; ++index) {
    if (index != row && board[index * 3 + column] != player) wins = false;
  }
  if (wins) return true;
  if (row == column) {
    wins = true;
    for (int index = 0; index < 3; ++index) {
      if (index != row && board[index * 3 + index] != player) wins = false;
    }
    if (wins) return true;
  }
  if (row + column == 2) {
    wins = true;
    for (int index = 0; index < 3; ++index) {
      const int diagonal_cell = index * 3 + (2 - index);
      if (diagonal_cell != cell && board[diagonal_cell] != player) wins = false;
    }
    if (wins) return true;
  }
  return false;
}

__host__ __device__ bool has_won(const int* board, int player) {
  for (int index = 0; index < 3; ++index) {
    if (board[index * 3] == player && board[index * 3 + 1] == player &&
        board[index * 3 + 2] == player) return true;
    if (board[index] == player && board[index + 3] == player &&
        board[index + 6] == player) return true;
  }
  return (board[0] == player && board[4] == player && board[8] == player) ||
         (board[2] == player && board[4] == player && board[6] == player);
}

__host__ __device__ int score_move(const int* board, int cell, int player,
                                  int turn, std::uint32_t game_id,
                                  std::uint32_t seed) {
  if (board[cell] != kEmpty) return -1000000;
  const int opponent = (player == kX) ? kO : kX;
  const int strategy = (player == kX) ? 0 : 1;
  int score = 0;
  if (is_winning_move(board, cell, player)) score += 10000;
  if (is_winning_move(board, cell, opponent)) {
    score += (strategy == 1) ? 9500 : 8000;
  }
  if (cell == 4) score += (strategy == 0) ? 450 : 600;
  const bool is_corner = cell == 0 || cell == 2 || cell == 6 || cell == 8;
  if (is_corner) score += (strategy == 0) ? 500 : 300;
  const bool is_edge = cell == 1 || cell == 3 || cell == 5 || cell == 7;
  if (is_edge) score += (strategy == 0) ? 100 : 200;
  const std::uint32_t random_key =
      seed ^ (game_id * 0x9e3779b9U) ^
      (static_cast<std::uint32_t>(turn) * 0x85ebca6bU) ^
      (static_cast<std::uint32_t>(cell) * 0xc2b2ae35U);
  score += static_cast<int>(mix_bits(random_key) & 7U);
  return score;
}

__host__ __device__ GameResult simulate_one_game(std::uint32_t game_id,
                                                std::uint32_t seed) {
  int board[kBoardCells] = {kEmpty, kEmpty, kEmpty, kEmpty, kEmpty,
                            kEmpty, kEmpty, kEmpty, kEmpty};
  int player = kX;
  for (int turn = 0; turn < kBoardCells; ++turn) {
    int best_cell = -1;
    int best_score = -1000001;
    for (int cell = 0; cell < kBoardCells; ++cell) {
      const int score = score_move(board, cell, player, turn, game_id, seed);
      if (score > best_score) {
        best_score = score;
        best_cell = cell;
      }
    }
    if (best_cell < 0) return {kEmpty, turn};
    board[best_cell] = player;
    if (has_won(board, player)) return {player, turn + 1};
    if (turn == kBoardCells - 1) return {kEmpty, kBoardCells};
    player = (player == kX) ? kO : kX;
  }
  return {kEmpty, kBoardCells};
}

__global__ void simulate_tournament_kernel(int num_games, std::uint32_t seed,
                                         int* results) {
  const int game_id = blockIdx.x * blockDim.x + threadIdx.x;
  if (game_id >= num_games) return;
  const GameResult result =
      simulate_one_game(static_cast<std::uint32_t>(game_id), seed);
  results[2ULL * static_cast<unsigned int>(game_id)] = result.winner;
  results[2ULL * static_cast<unsigned int>(game_id) + 1ULL] = result.moves;
}

bool parse_unsigned(const std::string& text, unsigned long long max_value,
                   unsigned long long* value) {
  errno = 0;
  char* end = nullptr;
  const unsigned long long parsed = std::strtoull(text.c_str(), &end, 10);
  if (errno != 0 || end == text.c_str() || *end != '\0' ||
      parsed > max_value) return false;
  *value = parsed;
  return true;
}

bool parse_options(int argc, char** argv, Options* options) {
  for (int index = 1; index < argc; ++index) {
    const std::string argument(argv[index]);
    if (argument == "--help") {
      std::cout << "Usage: " << argv[0] << " [options]\n"
                << "  --games N        Independent games to simulate (1-"
                << kMaxGames << ")\n"
                << "  --iterations N   GPU timing iterations (1-"
                << kMaxIterations << ")\n"
                << "  --seed N         Reproducible 32-bit seed\n"
                << "  --csv PATH       Write per-game results to PATH\n"
                << "  --no-csv         Disable CSV output\n";
      return false;
    }
    if (argument == "--no-csv") {
      options->csv_path.clear();
      continue;
    }
    if (index + 1 >= argc) {
      std::cerr << "Missing value for " << argument << '\n';
      return false;
    }
    const std::string value(argv[++index]);
    unsigned long long parsed = 0;
    if (argument == "--games") {
      if (!parse_unsigned(value, kMaxGames, &parsed) || parsed < 1) {
        std::cerr << "Invalid --games value: " << value << '\n';
        return false;
      }
      options->games = static_cast<int>(parsed);
    } else if (argument == "--iterations") {
      if (!parse_unsigned(value, kMaxIterations, &parsed) || parsed < 1) {
        std::cerr << "Invalid --iterations value: " << value << '\n';
        return false;
      }
      options->iterations = static_cast<int>(parsed);
    } else if (argument == "--seed") {
      if (!parse_unsigned(value, 0xffffffffULL, &parsed)) {
        std::cerr << "Invalid --seed value: " << value << '\n';
        return false;
      }
      options->seed = static_cast<std::uint32_t>(parsed);
    } else if (argument == "--csv") {
      options->csv_path = value;
    } else {
      std::cerr << "Unknown argument: " << argument << '\n';
      return false;
    }
  }
  return true;
}

const char* winner_name(int winner) {
  if (winner == kX) return "X";
  if (winner == kO) return "O";
  return "DRAW";
}

bool write_csv(const Options& options, std::uint32_t final_seed,
              const std::vector<int>& results) {
  if (options.csv_path.empty()) return true;
  const std::filesystem::path output_path(options.csv_path);
  if (output_path.has_parent_path()) {
    std::error_code error;
    std::filesystem::create_directories(output_path.parent_path(), error);
    if (error) {
      std::cerr << "Could not create output directory: " << error.message()
                << '\n';
      return false;
    }
  }
  std::ofstream output(options.csv_path);
  if (!output) {
    std::cerr << "Could not open CSV output: " << options.csv_path << '\n';
    return false;
  }
  output << "game_id,winner,moves,seed\n";
  for (int game = 0; game < options.games; ++game) {
    output << game << ',' << winner_name(results[2ULL * game]) << ','
           << results[2ULL * game + 1ULL] << ',' << final_seed << '\n';
  }
  if (!output.good()) {
    std::cerr << "Failed while writing CSV output.\n";
    return false;
  }
  return true;
}
}  // namespace

int main(int argc, char** argv) {
  Options options;
  if (!parse_options(argc, argv, &options)) {
    return (argc > 1 && std::string(argv[1]) == "--help") ? EXIT_SUCCESS
                                                          : EXIT_FAILURE;
  }

  int device_count = 0;
  CUDA_CHECK(cudaGetDeviceCount(&device_count));
  if (device_count == 0) {
    std::cerr << "No CUDA-capable GPU was detected.\n";
    return EXIT_FAILURE;
  }
  CUDA_CHECK(cudaSetDevice(0));
  cudaDeviceProp device_properties{};
  CUDA_CHECK(cudaGetDeviceProperties(&device_properties, 0));

  std::cout << "CUDA Arena: massively parallel Tic-Tac-Toe tournament\n"
            << "GPU: " << device_properties.name << '\n'
            << "Games per execution: " << options.games << '\n'
            << "Timing iterations: " << options.iterations << '\n'
            << "Base seed: " << options.seed << '\n'
            << "Execution model: one CUDA thread simulates one independent game\n";

  int* device_results = nullptr;
  const std::size_t result_count =
      2ULL * static_cast<std::size_t>(options.games);
  CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&device_results),
                        result_count * sizeof(int)));

  constexpr int kThreadsPerBlock = 256;
  const int blocks =
      (options.games + kThreadsPerBlock - 1) / kThreadsPerBlock;
  simulate_tournament_kernel<<<blocks, kThreadsPerBlock>>>(
      options.games, options.seed, device_results);
  CUDA_CHECK(cudaGetLastError());
  CUDA_CHECK(cudaDeviceSynchronize());

  cudaEvent_t start_event;
  cudaEvent_t stop_event;
  CUDA_CHECK(cudaEventCreate(&start_event));
  CUDA_CHECK(cudaEventCreate(&stop_event));
  float total_kernel_ms = 0.0F;
  std::uint32_t final_seed = options.seed;

  for (int iteration = 0; iteration < options.iterations; ++iteration) {
    final_seed = options.seed + static_cast<std::uint32_t>(iteration);
    CUDA_CHECK(cudaEventRecord(start_event));
    simulate_tournament_kernel<<<blocks, kThreadsPerBlock>>>(
        options.games, final_seed, device_results);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaEventRecord(stop_event));
    CUDA_CHECK(cudaEventSynchronize(stop_event));
    float iteration_ms = 0.0F;
    CUDA_CHECK(cudaEventElapsedTime(&iteration_ms, start_event, stop_event));
    total_kernel_ms += iteration_ms;
  }

  const float average_kernel_ms =
      total_kernel_ms / static_cast<float>(options.iterations);
  std::vector<int> gpu_results(result_count);
  CUDA_CHECK(cudaMemcpy(gpu_results.data(), device_results,
                        result_count * sizeof(int), cudaMemcpyDeviceToHost));

  std::vector<int> cpu_results(result_count);
  const auto cpu_start = std::chrono::steady_clock::now();
  for (int game = 0; game < options.games; ++game) {
    const GameResult result =
        simulate_one_game(static_cast<std::uint32_t>(game), final_seed);
    cpu_results[2ULL * game] = result.winner;
    cpu_results[2ULL * game + 1ULL] = result.moves;
  }
  const auto cpu_end = std::chrono::steady_clock::now();
  const double cpu_ms =
      std::chrono::duration<double, std::milli>(cpu_end - cpu_start).count();

  int mismatches = 0;
  for (int game = 0; game < options.games; ++game) {
    if (gpu_results[2ULL * game] != cpu_results[2ULL * game] ||
        gpu_results[2ULL * game + 1ULL] != cpu_results[2ULL * game + 1ULL]) {
      if (mismatches == 0) {
        std::cerr << "First mismatch at game " << game << ": GPU=("
                  << gpu_results[2ULL * game] << ","
                  << gpu_results[2ULL * game + 1ULL] << "), CPU=("
                  << cpu_results[2ULL * game] << ","
                  << cpu_results[2ULL * game + 1ULL] << ")\n";
      }
      ++mismatches;
    }
  }

  if (mismatches != 0) {
    std::cerr << "CPU/GPU consistency check failed for " << mismatches
              << " games.\n";
    CUDA_CHECK(cudaEventDestroy(start_event));
    CUDA_CHECK(cudaEventDestroy(stop_event));
    CUDA_CHECK(cudaFree(device_results));
    return EXIT_FAILURE;
  }

  unsigned long long x_wins = 0;
  unsigned long long o_wins = 0;
  unsigned long long draws = 0;
  unsigned long long total_moves = 0;
  for (int game = 0; game < options.games; ++game) {
    const int winner = gpu_results[2ULL * game];
    const int moves = gpu_results[2ULL * game + 1ULL];
    if (winner == kX) ++x_wins;
    else if (winner == kO) ++o_wins;
    else ++draws;
    total_moves += static_cast<unsigned long long>(moves);
  }

  const double throughput =
      static_cast<double>(options.games) /
      (static_cast<double>(average_kernel_ms) * 1000.0);

  std::cout << std::fixed << std::setprecision(4)
            << "\n========== TOURNAMENT RESULTS ==========\n"
            << "Agent X wins: " << x_wins << '\n'
            << "Agent O wins: " << o_wins << '\n'
            << "Draws: " << draws << '\n'
            << "Average moves per game: "
            << static_cast<double>(total_moves) / options.games << '\n'
            << "CPU/GPU consistency: PASS (" << options.games
            << " games checked)\n"
            << "Average GPU kernel time: " << average_kernel_ms << " ms\n"
            << "GPU throughput: " << throughput << " million games/s\n"
            << "CPU reference time: " << cpu_ms << " ms\n"
            << "Timing note: GPU time is kernel-only; CPU time is host simulation.\n";

  const bool csv_written = write_csv(options, final_seed, gpu_results);
  CUDA_CHECK(cudaEventDestroy(start_event));
  CUDA_CHECK(cudaEventDestroy(stop_event));
  CUDA_CHECK(cudaFree(device_results));
  if (!csv_written) return EXIT_FAILURE;
  if (!options.csv_path.empty()) {
    std::cout << "Per-game results written to: " << options.csv_path << '\n';
  }
  return EXIT_SUCCESS;
}
