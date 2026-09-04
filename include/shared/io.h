#pragma once

#include <sys/types.h>

constexpr size_t K_MAX_MSG = 4096;

int32_t read_full(int fd, char* buf, size_t n);

int32_t write_all(int fd, const char* buf, size_t n);
