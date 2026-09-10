#include "shared/buffer.h"

// Appends bytes to the end of a `std::vector` based buffer.
void buf_append(std::vector<uint8_t>& buf, const uint8_t* data, size_t len) {
    buf.insert(buf.end(), data, data + len);
}

// Deletes bytes from a `std::vector` based buffer via a start-end range.
void buf_consume(std::vector<uint8_t>& buf, size_t n) {
    buf.erase(buf.begin(), buf.begin() + n);
}
