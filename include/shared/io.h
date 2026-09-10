#pragma once

#include <cstdint>
#include <fcntl.h>
#include <sys/types.h>
#include <stdint.h>

constexpr size_t K_MAX_MSG = 32 << 20;

/* DEPRECATED */
int32_t read_full(int fd, uint8_t* buf, size_t n);

/* DEPRECATED */
int32_t write_all(int fd, const uint8_t* buf, size_t n);

void fd_set_nb(int fd);
