#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>

#include "shared/conn.h"
#include "shared/io.h"
#include "shared/buffer.h"

// Populates the Conn object's outgoing buffer only if the incoming payload is
// complete (i.e. payload contains a header and a body matching the length 
// specified in the header).
static bool try_one_request(Conn *conn) {
    if (conn->incoming.size() < CONN_HEADER_LEN) {
        return false;
    }

    uint32_t msg_len = 0;
    memcpy(&msg_len, conn->incoming.data(), CONN_HEADER_LEN);
    if (msg_len > K_MAX_MSG) {
        conn->want_close = true;
        return false;
    }

    const uint32_t conn_request_len = CONN_HEADER_LEN + msg_len;
    if (conn_request_len > conn->incoming.size()) {
        return false;
    }

    printf("client says: %.*s\n", msg_len, &conn->incoming[CONN_MSG_OFFSET]);

    const uint8_t* request = &conn->incoming[CONN_MSG_OFFSET];

    buf_append(conn->outgoing, (const uint8_t*)&msg_len, CONN_HEADER_LEN);
    buf_append(conn->outgoing, request, msg_len);
    buf_consume(conn->incoming, CONN_HEADER_LEN + msg_len);

    return true;
}

// Accepts a client connection and returns a Conn object encapsulating the
// connection's file descriptor, readiness, and read/write buffers.
Conn* handle_accept(int fd) {
    struct sockaddr_in client_addr = {};
    socklen_t socklen = sizeof(client_addr);

    int connfd = accept(fd, (struct sockaddr*)&client_addr, &socklen);
    if (connfd < 0) {
        return NULL;
    }

    fd_set_nb(connfd);

    Conn* conn = new Conn();
    conn->fd = connfd;
    conn->want_read = true;

    return conn;
}

// Reads bytes from the operating systems receive buffer into the `Conn`
// object's incoming buffer and attempts to populate the `Conn` object's 
// outgoing buffer via `try_one_request()`.
void handle_read(Conn* conn) {
    uint8_t buf[64 * 1024];
    ssize_t rv = read(conn->fd, buf, sizeof(buf));
    if (rv <= 0) {
        conn->want_close = true;
        return;
    }

    buf_append(conn->incoming, buf, (size_t)rv);

    while(try_one_request(conn)) {}

    if (conn->outgoing.size() > 0) {
        conn->want_read = false;
        conn->want_write = true;
    }
}

// Writes bytes into the operating system send buffer from the `Conn` 
// object's outgoing buffer.
void handle_write(Conn* conn) {
    assert(conn->outgoing.size() > 0);
    ssize_t rv = write(conn->fd, conn->outgoing.data(), conn->outgoing.size());
    if (rv < 0) {
        conn->want_close = true;
        return;
    }

    buf_consume(conn->outgoing, (size_t)rv);

    if (conn->outgoing.size() == 0) {
        conn->want_read = true;
        conn->want_write = false;
    }
}
