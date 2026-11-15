cmake_minimum_required(VERSION 3.4.1)

# Enable 16KB page size support for Android (required for Google Play)
add_link_options(-Wl,-z,max-page-size=16384)
add_link_options(-Wl,-z,common-page-size=16384)

file(GLOB_RECURSE cppPaths "../ios/Stockfish/src/*.cpp")
add_library(
  stockfish
  SHARED
  ../ios/FlutterStockfish/ffi.cpp
  ${cppPaths}
)

if(ANDROID_ABI STREQUAL arm64-v8a)
  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(stockfish PRIVATE -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8)
  else()
    target_compile_options(stockfish PRIVATE -fno-exceptions -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8)
  endif()
else()
  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(stockfish PRIVATE -DUSE_PTHREADS)
  else()
    target_compile_options(stockfish PRIVATE -fno-exceptions -DUSE_PTHREADS -DNDEBUG -O3)
  endif()
endif()


# Isolate each engine’s UCI streams from the other engine and Flutter.
target_compile_options(stockfish PRIVATE -include "${CMAKE_CURRENT_SOURCE_DIR}/../ios/FlutterStockfish/still_streams.h" -O3)

set(MODEL_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../networks/nn-c288c895ea92.nnue")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../networks")
if(NOT EXISTS "${MODEL_PATH}")
  file(DOWNLOAD "https://tests.stockfishchess.org/api/nn/nn-c288c895ea92.nnue" "${MODEL_PATH}"
    EXPECTED_HASH SHA256=c288c895ea924429ea9092e3f36b2b3c1f00f2a3a4c759ff7e57e79e3b43e4a7 TLS_VERIFY ON STATUS MODEL_STATUS)
  list(GET MODEL_STATUS 0 MODEL_RESULT)
  if(NOT MODEL_RESULT EQUAL 0)
    message(FATAL_ERROR "Unable to download nn-c288c895ea92.nnue: ${MODEL_STATUS}")
  endif()
endif()
file(SHA256 "${MODEL_PATH}" MODEL_HASH)
if(NOT MODEL_HASH STREQUAL "c288c895ea924429ea9092e3f36b2b3c1f00f2a3a4c759ff7e57e79e3b43e4a7")
  message(FATAL_ERROR "Corrupt Stockfish network: nn-c288c895ea92.nnue")
endif()
configure_file("${MODEL_PATH}" "${CMAKE_BINARY_DIR}/nn-c288c895ea92.nnue" COPYONLY)

set(MODEL_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../networks/nn-37f18f62d772.nnue")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../networks")
if(NOT EXISTS "${MODEL_PATH}")
  file(DOWNLOAD "https://tests.stockfishchess.org/api/nn/nn-37f18f62d772.nnue" "${MODEL_PATH}"
    EXPECTED_HASH SHA256=37f18f62d772f3107e1d6aaca3898c130c3c86f2ab63e6555fbbca20635a899d TLS_VERIFY ON STATUS MODEL_STATUS)
  list(GET MODEL_STATUS 0 MODEL_RESULT)
  if(NOT MODEL_RESULT EQUAL 0)
    message(FATAL_ERROR "Unable to download nn-37f18f62d772.nnue: ${MODEL_STATUS}")
  endif()
endif()
file(SHA256 "${MODEL_PATH}" MODEL_HASH)
if(NOT MODEL_HASH STREQUAL "37f18f62d772f3107e1d6aaca3898c130c3c86f2ab63e6555fbbca20635a899d")
  message(FATAL_ERROR "Corrupt Stockfish network: nn-37f18f62d772.nnue")
endif()
configure_file("${MODEL_PATH}" "${CMAKE_BINARY_DIR}/nn-37f18f62d772.nnue" COPYONLY)
