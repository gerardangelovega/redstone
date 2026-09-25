#include <cassert>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <endian.h>
#include <netinet/in.h>
#include <string>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>

#include "server/dlist.h"
#include "server/serialize.h"
#include "server/time.h"
#include "shared/error.h"
#include "shared/io.h"
#include "shared/protocol.h"

#include "server/conn.h"
#include "server/data.h"
#include "server/buffer.h"

static bool read_u32(const uint8_t*& cur, const uint8_t* end, uint32_t& out) {
    if (cur + 4 > end) {
        return false;
    }
    memcpy(&out, cur, 4);
    cur = cur + 4;
    return true;
}

static bool read_str(
    const uint8_t*& cur,
    const uint8_t* end,
    size_t n,
    std::string &out
) {
    if (cur + n > end) {
        return false;
    }
    out.assign(cur, cur + n);
    cur = cur + n;
    return true;
}

static int32_t parse_req(
    const uint8_t* data,
    size_t size,
    std::vector<std::string>& out
) {
    const uint8_t* end = data + size;
    uint32_t nstr = 0; // number of items/arguments in the request
    if (!read_u32(data, end, nstr)) {
        return -1;
    }
    if(nstr > K_MAX_MSG) {
        return -1;
    }

    while (out.size() < nstr) {
        uint32_t len = 0;
        if (!read_u32(data, end, len)) {
            return -1;
        }
        out.push_back(std::string());
        if (!read_str(data, end, len, out.back())) {
            return -1;
        }
    }

    if (data != end) {
        return -1;
    }

    return 0;
}

static void response_begin(Buffer& out, size_t* header) {
    *header = out.size();
    buf_append_u32(out, 0);
}
static size_t response_size(Buffer& out, size_t header) {
    return out.size() - header - 4;
}
static void response_end(Buffer& out, size_t header) { 
    size_t msg_size = response_size(out, header);
    if (msg_size > K_MAX_MSG) {
        out.resize(header + 4);
        out_err(out, ERR_TOO_BIG, "response is too big.");
        msg_size = response_size(out, header);
    }
    uint32_t len = (uint32_t)msg_size;
    memcpy(&out[header], &len, 4);
}

static void do_request(std::vector<std::string>& cmd, Buffer& out) {
    if (cmd.size() == 2 && cmd[0] == "get") {
        printf("Executing get\n");
        return do_get(cmd, out);
    } else if (cmd.size() == 3 && cmd[0] == "set") {
        printf("Executing set\n");
        return do_set(cmd, out);
    } else if (cmd.size() == 2 && cmd[0] == "del") {
        printf("Executing del\n");
        return do_del(cmd, out);
    } else if (cmd.size() == 1 && cmd[0] == "keys") {
        printf("Executing keys\n");
        return do_keys(cmd, out);
    } else if (cmd.size() == 3 && cmd[0] == "pexpire") {
        return do_expire(cmd, out);
    } else if (cmd.size() == 2 && cmd[0] == "pttl") {
        return do_ttl(cmd, out);
    } else if (cmd.size() == 4 && cmd[0] == "zadd") {
        printf("Executing zadd\n");
        return do_zadd(cmd, out);
    } else if (cmd.size() == 3 && cmd[0] == "zrem") {
        printf("Executing zrem\n");
        return do_zrem(cmd, out);
    } else if (cmd.size() == 3 && cmd[0] == "zscore") {
        printf("Executing zscore\n");
        return do_zscore(cmd, out);
    } else if (cmd.size() == 6 && cmd[0] == "zquery") {
        printf("Executing zquery\n");
        return do_zquery(cmd, out);
    } else {
        return out_err(out, ERR_UNKNOWN, "unknown command");
    }
}

// static void make_response(
//     const Response& resp,
//     std::vector<uint8_t> &out
// ) {
//     uint32_t resp_len = 4 + (uint32_t)resp.data.size();
//     buf_append(out, (const uint8_t*)&resp_len, 4);
//     buf_append(out, (const uint8_t*)&resp.status, 4);
//     buf_append(out, resp.data.data(), resp.data.size());
// }

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
        msg("too long");
        conn->want_close = true;
        return false;
    }

    const uint32_t conn_request_len = CONN_HEADER_LEN + msg_len;
    if (conn_request_len > conn->incoming.size()) {
        return false;
    }

    const uint8_t* request = &conn->incoming[CONN_MSG_OFFSET];

    std::vector<std::string> cmd;
    if (parse_req(request, msg_len, cmd) < 0) {
        msg("bad request");
        conn->want_close = true;
        return false;
    }

    printf("client says:");
    for (const std::string& s : cmd) {
        printf(" %s", s.c_str()) ;
    }
    printf("\n");

    // TODO: New Implementation fo Response
    size_t header_pos = 0;
    response_begin(conn->outgoing, &header_pos);
    do_request(cmd, conn->outgoing);
    response_end(conn->outgoing, header_pos);

    // printf("\n");
    // Response resp;
    // do_request(cmd, resp);
    // make_response(resp, conn->outgoing);

    buf_consume(conn->incoming, 4 + msg_len);

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
    conn->last_active_ms = get_monotonic_ms();
    dlist_insert_before(&g_data.idle_list, &conn->idle_node);

    if (g_data.fd2conn.size() <= (size_t)conn->fd) {
        g_data.fd2conn.resize(conn->fd + 1);
    }
    assert(!g_data.fd2conn[conn->fd]);
    g_data.fd2conn[conn->fd] = conn;

    return conn;
}

// Reads bytes from the operating systems receive buffer into the `Conn`
// object's incoming buffer and attempts to populate the `Conn` object's 
// outgoing buffer via `try_one_request()`.
void handle_read(Conn* conn) {
    uint8_t buf[64 * 1024];
    ssize_t rv = read(conn->fd, buf, sizeof(buf));
    if (rv < 0 && errno == EAGAIN) {
        return;
    }
    if (rv < 0) {
        msg_errno("read() error");
        conn->want_close = true;
        return;
    }
    if (rv == 0) {
        if (conn->incoming.size() == 0) {
            msg("client closed");
        } else {
            msg("unexpected EOF");
        }
        conn->want_close = true;
        return;
    }

    buf_append(conn->incoming, buf, (size_t)rv);

    while(try_one_request(conn)) {}

    // Perform a non-blocking write so that we don't have to wait for the next iteration to write
    // when the data is already ready for writing
    if (conn->outgoing.size() > 0) {
        conn->want_read = false;
        conn->want_write = true;
        return handle_write(conn); // optimistic non-blocking write
    }
}

// Writes bytes into the operating system send buffer from the `Conn` 
// object's outgoing buffer.
void handle_write(Conn* conn) {
    assert(conn->outgoing.size() > 0);
    ssize_t rv = write(conn->fd, conn->outgoing.data(), conn->outgoing.size());
    // retry on another iteration to write into the kernel's send buffer
    if (rv < 0 && errno == EAGAIN) {
        return;
    }
    if (rv < 0) {
        msg_errno("write() error");
        conn->want_close = true;
        return;
    }

    buf_consume(conn->outgoing, (size_t)rv);

    if (conn->outgoing.size() == 0) {
        conn->want_read = true;
        conn->want_write = false;
    }
}

void conn_destroy(Conn* conn) {
    (void)close(conn->fd);
    g_data.fd2conn[conn->fd] = NULL;
    dlist_detach(&conn->idle_node);
    delete conn;
}
