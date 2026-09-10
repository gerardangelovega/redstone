#include <cstddef>
#include <cstdint>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>

#include "shared/conn.h"
#include "shared/io.h"
#include "shared/error.h"
#include "shared/buffer.h"

static int32_t send_req(int fd, const uint8_t* text, size_t len) {
    if (len > K_MAX_MSG) {
        return -1;
    }

    std::vector<uint8_t> wbuf;
    buf_append(wbuf, (const uint8_t*)&len, CONN_HEADER_LEN);
    buf_append(wbuf, text, len);
    return write_all(fd, wbuf.data(), wbuf.size());
}

static int32_t read_res(int fd) {
    std::vector<uint8_t> rbuf;
    rbuf.resize(CONN_HEADER_LEN);
    errno = 0;
    int32_t err = read_full(fd, &rbuf[0], CONN_HEADER_LEN);
    if (err) {
        if (errno == 0) {
            msg("EOF");
        } else {
            msg("read() error");
        }
        return err;
    }

    uint32_t len = 0;
    memcpy(&len, rbuf.data(), CONN_HEADER_LEN);
    if (len > K_MAX_MSG) {
        msg("too long");
        return -1;
    }

    rbuf.resize(CONN_HEADER_LEN + len);
    err = read_full(fd, &rbuf[4], len);
    if (err) {
        msg("read() error");
        return err;
    }

    printf("len:%u data:%.*s\n", len, len < 100 ? len : 100, &rbuf[4]);
    return 0;
}

int main () {
    /* Source: man socket.2
     * AF_INET      use IPv4 internet protocols
     *
     * SOCK_STREAM  use sequenced, reliable, two-way, connection-based streams
     *
     * socket()     creates a communication endpoint and a file descriptor that refers
     *              to said communication endpoint
     */
    int fd = socket(AF_INET, SOCK_STREAM, 0); // AF_INET + SOCK_STREAM = TCP
    if (fd < 0) {
        die("socket()");
    }

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;                     // IPv4 Internet Protocol
    addr.sin_port = ntohs(1234);                   // Port 1234
    addr.sin_addr.s_addr = ntohl(INADDR_LOOPBACK); // IP 127.0.0.1

    /* Source: man connect.2
     * connect()    connects the file descriptor to an address
     */
    if (connect(fd, (const struct sockaddr*)&addr, sizeof(addr)) != 0) {
        die("connect()");
    }

    std::vector<std::string> query_list = {
        "hello1",
        "hello2",
        "hello3",
        std::string(K_MAX_MSG, 'z'),
        "hello5"
    };
    for (const std::string &s : query_list) {
        int32_t err = send_req(fd, (uint8_t*)s.data(), s.size());
        if (err) {
            goto L_DONE;
        }
    }
    for (size_t i = 0; i < query_list.size(); i++) {
        int32_t err = read_res(fd);
        if (err) {
            goto L_DONE;
        }
    }

L_DONE:
    close(fd);
    return 0;
}
