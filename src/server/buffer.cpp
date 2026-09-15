#include <cstdint>
#include <vector>

#include "server/buffer.h"

// Appends bytes to the end of a `std::vector` based buffer.
void buf_append(Buffer& buf, const uint8_t* data, size_t len) {
    buf.insert(buf.end(), data, data + len);
}
void buf_append_u8(Buffer& buf, uint8_t data) {
    buf.push_back(data);
}
void buf_append_u32(Buffer& buf, uint32_t data) {
    buf_append(buf, (const uint8_t*)&data, 4);
}
void buf_append_i64(Buffer& buf, int64_t data) {
    buf_append(buf, (const uint8_t*)&data, 8);
}
void buf_append_dbl(Buffer& buf, double data) {
    buf_append(buf, (const uint8_t*)&data, 8);
}

// Deletes bytes from a `std::vector` based buffer via a start-end range.
void buf_consume(Buffer& buf, size_t n) {
    buf.erase(buf.begin(), buf.begin() + n);
}

