#pragma once

#include <stdint.h>
#include <vector>

// Represents the length of the byte stream's header.
constexpr uint32_t CONN_HEADER_LEN = 4;

// Represents the offset from the start of the byte stream where the body starts. Has the same value as `CONN_HEADER_LEN`.
constexpr uint32_t CONN_MSG_OFFSET = CONN_HEADER_LEN;

struct Conn {
    int fd = -1;

    bool want_read = false;  // indicates if a connection is ready to read
    bool want_write = false; // indicates if a connection is ready to write
    bool want_close = false; // indicates if a connection should be closed

    std::vector<uint8_t> incoming;  // buffer for incoming bytes from the socket
    std::vector<uint8_t> outgoing; // buffer for outgoing bytes to the socket
};

Conn* handle_accept(int fd);

void handle_read(Conn* conn);

void handle_write(Conn* conn);
