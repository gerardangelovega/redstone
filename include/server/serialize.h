#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

#include "server/buffer.h"

void out_nil(Buffer& out);
void out_str(Buffer& out, const char* s, size_t size);
void out_int(Buffer& out, int64_t val);
void out_dbl(Buffer& out, double val);
void out_err(Buffer& out, uint32_t code, const std::string& msg);
void out_arr(Buffer& out, uint32_t n);
