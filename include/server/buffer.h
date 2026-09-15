#pragma once

#include <cstdint>
#include <stdint.h>
#include <vector>

typedef std::vector<uint8_t> Buffer;

void buf_append(Buffer& buf, const uint8_t* data, size_t len);
void buf_append_u8(Buffer& buf, uint8_t data);
void buf_append_u32(Buffer& buf, uint32_t data);
void buf_append_i64(Buffer& buf, int64_t data);
void buf_append_dbl(Buffer& buf, double data);

void buf_consume(Buffer& buf, size_t n);
