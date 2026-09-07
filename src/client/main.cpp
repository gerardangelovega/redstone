#include <cstdint>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include "shared/io.h"
#include "shared/error.h"

static int32_t query(int fd, const char* text) {
    uint32_t len = (uint32_t)strlen(text);
    if (len > K_MAX_MSG) {
        return -1;
    }

    char wbuf[4 + K_MAX_MSG];
    mempcpy(wbuf, &len, 4);
    mempcpy(&wbuf[4], text, len);
    if (int32_t err = write_all(fd, wbuf, 4 + len)) {
        return err;
    }

    char rbuf[4 + K_MAX_MSG + 1];
    errno = 0;
    int32_t err = read_full(fd, rbuf, 4);
    if (err) {
        msg(err == 0 ? "EOF" : "read() error");
        return err;
    }
    mempcpy(&len, rbuf, 4);
    if (len > K_MAX_MSG) {
        msg("too long");
        return -1;
    }
    err = read_full(fd, &rbuf[4], len);
    if (err) {
        msg("read() error");
        return err;
    }
    printf("server says: %.*s\n", len, &rbuf[4]);
    return 0;
};

int main (int argc, char *argv[]) {
    if (argc < 2) {
        die("not enough arguments");
    }
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

    int32_t err = query(fd, argv[1]);
    if (err) {
        goto L_DONE;
    }
L_DONE:
    close(fd);
    return 0;
}
