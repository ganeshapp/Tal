#include <iostream>
#include <stdio.h>
#include <unistd.h>

#include "../Stockfish/src/bitboard.h"
#include "../Stockfish/src/misc.h"
#include "../Stockfish/src/position.h"
#include "../Stockfish/src/types.h"
#include "../Stockfish/src/uci.h"
#include "../Stockfish/src/tune.h"

#include "ffi.h"
#include "still_streams.h"
#include <streambuf>
#include <algorithm>
#include <cerrno>

// https://jineshkj.wordpress.com/2006/12/22/how-to-capture-stdin-stdout-and-stderr-of-child-program/
#define NUM_PIPES 2
#define PARENT_WRITE_PIPE 0
#define PARENT_READ_PIPE 1
#define READ_FD 0
#define WRITE_FD 1
#define PARENT_READ_FD (pipes[PARENT_READ_PIPE][READ_FD])
#define PARENT_WRITE_FD (pipes[PARENT_WRITE_PIPE][WRITE_FD])
#define CHILD_READ_FD (pipes[PARENT_WRITE_PIPE][READ_FD])
#define CHILD_WRITE_FD (pipes[PARENT_READ_PIPE][WRITE_FD])

int main(int, char **);

const char *QUITOK = "quitok\n";
int pipes[NUM_PIPES][2];
char buffer[80];


// Dedicated engine streams: never redirect the process-wide stdin/stdout.
// Both native engines run concurrently in the same Flutter process.
namespace still_stockfish {
class InputBuffer final : public std::streambuf {
  char bytes_[4096];
  int_type underflow() override {
    if (gptr() < egptr()) return traits_type::to_int_type(*gptr());
    ssize_t count;
    do { count = ::read(CHILD_READ_FD, bytes_, sizeof(bytes_)); }
    while (count < 0 && errno == EINTR);
    if (count <= 0) return traits_type::eof();
    setg(bytes_, bytes_, bytes_ + count);
    return traits_type::to_int_type(*gptr());
  }
};
class OutputBuffer final : public std::streambuf {
  std::streamsize xsputn(const char* data, std::streamsize length) override {
    std::streamsize written = 0;
    while (written < length) {
      const auto count = ::write(CHILD_WRITE_FD, data + written, length - written);
      if (count < 0 && errno == EINTR) continue;
      if (count <= 0) break;
      written += count;
    }
    return written;
  }
  int_type overflow(int_type ch) override {
    if (traits_type::eq_int_type(ch, traits_type::eof())) return traits_type::not_eof(ch);
    const char c = traits_type::to_char_type(ch);
    return xsputn(&c, 1) == 1 ? ch : traits_type::eof();
  }
  int sync() override { return 0; }
};
std::istream& input() { static InputBuffer buffer; static std::istream stream(&buffer); return stream; }
std::ostream& output() { static OutputBuffer buffer; static std::ostream stream(&buffer); return stream; }
}

int stockfish_init()
{
  pipe(pipes[PARENT_READ_PIPE]);
  pipe(pipes[PARENT_WRITE_PIPE]);

  return 0;
}

int stockfish_main()
{
  int argc = 1;
  char *argv[] = {""};
  int exitCode = main(argc, argv);

  still_stockfish::output() << QUITOK << std::flush;

  return exitCode;
}

ssize_t stockfish_stdin_write(char *data)
{
  return write(PARENT_WRITE_FD, data, strlen(data));
}

char *stockfish_stdout_read()
{
  ssize_t count = read(PARENT_READ_FD, buffer, sizeof(buffer) - 1);
  if (count <= 0)
  {
    return NULL;
  }

  buffer[count] = 0;
  if (strcmp(buffer, QUITOK) == 0)
  {
    return NULL;
  }

  return buffer;
}
