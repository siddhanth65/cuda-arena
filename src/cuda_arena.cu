#include <cuda_runtime.h>
#include <algorithm>
#include <array>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>

namespace {
constexpr int kBoardSize = 9;
constexpr int kEmpty = 0;
constexpr int kX = 1;
constexpr int kO = 2;
constexpr int kNoMove = -1;

#define CUDA_CHECK(call)                                                     \
  do {                                                                       \
    cudaError_t error = (call);                                              \
    if (error != cudaSuccess) {                                              \
      std::cerr << "CUDA error: " << cudaGetErrorString(error)               \
                << " at " << __FILE__ << ":" << __LINE__ << '\n';           \
      std::exit(EXIT_FAILURE);                                               \
    }                                                                        \
  } while (0)

__device__ bool is_winning_move(const int* board, int cell, int player) {
  const int lines[8][3] = {
      {0, 1, 2}, {3, 4, 5}, {6, 7, 8},
      {0, 3, 6}, {1, 4, 7}, {2, 5, 8},
      {0, 4, 8}, {2, 4, 6}};
  for (int line = 0; line < 8; ++line) {
    bool contains_cell = false;
    int player_count = 0;
    for (int offset = 0; offset < 3; ++offset) {
      const int position = lines[line][offset];
      if (position == cell) contains_cell = true;
      const int value = (position == cell) ? player : board[position];
      if (value == player) ++player_count;
    }
    if (contains_cell && player_count == 3) return true;
  }
  return false;
}

__global__ void evaluate_moves(const int* board, int player, int strategy,
                              int* scores) {
  const int cell = blockIdx.x * blockDim.x + threadIdx.x;
  if (cell >= kBoardSize) return;
  if (board[cell] != kEmpty) {
    scores[cell] = -1000000;
    return;
  }
  const int opponent = (player == kX) ? kO : kX;
  int score = 0;
  if (is_winning_move(board, cell, player)) score += 10000;
  if (is_winning_move(board, cell, opponent))
    score += (strategy == 1) ? 9500 : 8000;
  if (cell == 4) score += (strategy == 0) ? 450 : 600;
  const bool corner = cell == 0 || cell == 2 || cell == 6 || cell == 8;
  if (corner) score += (strategy == 0) ? 500 : 300;
  const bool edge = cell == 1 || cell == 3 || cell == 5 || cell == 7;
  if (edge) score += (strategy == 0) ? 100 : 200;
  score += 8 - cell;
  scores[cell] = score;
}

void print_board(const std::array<int, kBoardSize>& board) {
  const char symbols[] = {'.', 'X', 'O'};
  std::cout << '\n';
  for (int row = 0; row < 3; ++row) {
    std::cout << " ";
    for (int col = 0; col < 3; ++col) {
      std::cout << symbols[board[row * 3 + col]];
      if (col < 2) std::cout << " | ";
    }
    std::cout << '\n';
    if (row < 2) std::cout << "---+---+---\n";
  }
  std::cout << '\n';
}

bool has_won(const std::array<int, kBoardSize>& board, int player) {
  constexpr int lines[8][3] = {
      {0, 1, 2}, {3, 4, 5}, {6, 7, 8},
      {0, 3, 6}, {1, 4, 7}, {2, 5, 8},
      {0, 4, 8}, {2, 4, 6}};
  for (const auto& line : lines)
    if (board[line[0]] == player && board[line[1]] == player &&
        board[line[2]] == player) return true;
  return false;
}

int select_move(const std::array<int, kBoardSize>& board, int player,
               int strategy, cudaStream_t stream) {
  int* d_board = nullptr;
  int* d_scores = nullptr;
  std::array<int, kBoardSize> scores{};
  CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&d_board), sizeof(int) * kBoardSize));
  CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&d_scores), sizeof(int) * kBoardSize));
  CUDA_CHECK(cudaMemcpyAsync(d_board, board.data(), sizeof(int) * kBoardSize,
                             cudaMemcpyHostToDevice, stream));
  evaluate_moves<<<1, 32, 0, stream>>>(d_board, player, strategy, d_scores);
  CUDA_CHECK(cudaGetLastError());
  CUDA_CHECK(cudaMemcpyAsync(scores.data(), d_scores, sizeof(int) * kBoardSize,
                             cudaMemcpyDeviceToHost, stream));
  CUDA_CHECK(cudaStreamSynchronize(stream));
  CUDA_CHECK(cudaFree(d_board));
  CUDA_CHECK(cudaFree(d_scores));

  int best_move = kNoMove;
  int best_score = std::numeric_limits<int>::min();
  for (int cell = 0; cell < kBoardSize; ++cell)
    if (scores[cell] > best_score) {
      best_score = scores[cell];
      best_move = cell;
    }
  return best_move;
}
}  // namespace

int main(int argc, char** argv) {
  int games = 1;
  if (argc == 3 && std::string(argv[1]) == "--games")
    games = std::max(1, std::atoi(argv[2]));
  else if (argc != 1) {
    std::cerr << "Usage: " << argv[0] << " [--games COUNT]\n";
    return EXIT_FAILURE;
  }

  int device_count = 0;
  CUDA_CHECK(cudaGetDeviceCount(&device_count));
  if (device_count < 1) {
    std::cerr << "No CUDA-capable GPU was detected.\n";
    return EXIT_FAILURE;
  }
  CUDA_CHECK(cudaSetDevice(0));
  cudaStream_t x_stream, o_stream;
  CUDA_CHECK(cudaStreamCreate(&x_stream));
  CUDA_CHECK(cudaStreamCreate(&o_stream));

  int x_wins = 0, o_wins = 0, draws = 0;
  std::cout << "CUDA Arena: two CUDA agents competing on GPU 0\n"
            << "Agent X: aggressive | Agent O: defensive\n"
            << "Detected CUDA devices: " << device_count
            << " (both agents use device 0)\n";

  for (int game = 1; game <= games; ++game) {
    std::array<int, kBoardSize> board{};
    int player = kX;
    std::cout << "\n========== GAME " << game << " ==========\n";
    print_board(board);
    for (int turn = 0; turn < kBoardSize; ++turn) {
      const int strategy = player == kX ? 0 : 1;
      cudaStream_t stream = player == kX ? x_stream : o_stream;
      const int move = select_move(board, player, strategy, stream);
      if (move == kNoMove || board[move] != kEmpty) {
        std::cerr << "Agent returned an invalid move.\n";
        CUDA_CHECK(cudaStreamDestroy(x_stream));
        CUDA_CHECK(cudaStreamDestroy(o_stream));
        return EXIT_FAILURE;
      }
      board[move] = player;
      std::cout << "Agent " << (player == kX ? 'X' : 'O')
                << " selects cell " << move << " (row " << move / 3
                << ", column " << move % 3 << ")\n";
      print_board(board);
      if (has_won(board, player)) {
        if (player == kX) ++x_wins; else ++o_wins;
        std::cout << "Winner: Agent " << (player == kX ? 'X' : 'O') << '\n';
        break;
      }
      if (turn == kBoardSize - 1) {
        ++draws;
        std::cout << "Result: Draw\n";
        break;
      }
      player = player == kX ? kO : kX;
    }
  }
  std::cout << "\n========== MATCH SUMMARY ==========\n"
            << "Agent X wins: " << x_wins << '\n'
            << "Agent O wins: " << o_wins << '\n'
            << "Draws: " << draws << '\n';
  CUDA_CHECK(cudaStreamDestroy(x_stream));
  CUDA_CHECK(cudaStreamDestroy(o_stream));
  return EXIT_SUCCESS;
}
