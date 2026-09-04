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

static int32_t one_request(int connfd) {
    char rbuf[4 + K_MAX_MSG];
    errno = 0;
    int32_t err = read_full(connfd, rbuf, 4);
    if (err) {
        msg(errno == 0 ? "EOF" : "read() error");
        return err;
    }
    uint32_t len = 0;
    memcpy(&len, rbuf, 4);
    if (len > K_MAX_MSG) {
        msg("too long");
        return -1;
    }
    err = read_full(connfd, &rbuf[4], len);
    if (err) {
        msg("read() error");
        return err;
    }

    printf("client says: %.*s\n", len, &rbuf[4]);
    const char reply[] = "world";
    char wbuf[4 + sizeof(reply)];
    len = (uint32_t)strlen(reply);
    memcpy(wbuf, &len, 4);
    memcpy(&wbuf[4], reply, len);
    return write_all(connfd, wbuf, 4 + len);
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

    /* Source: man socket.7, man setsockopt.2
     * SOL_SOCKET + SO_REUSEADDR    specifies the reuse address options to be set
     *
     * &val + sizeof(val)           sets the value of the option
     *
     * setsockopt()                 set options on sockets
     */
    int val = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;       // use IPv4 internet protocol
    addr.sin_port = ntohs(1234);     // use port 1234
    addr.sin_addr.s_addr = ntohl(0); // use wildcard ip 0.0.0.0

    /* Source: man bind.2
     * bind()   binds the file descriptor with a socket address and return the result
     *          (0 for success, otherwise, fail)
     */
    if (bind(fd, (const struct sockaddr*)&addr, sizeof(addr)) != 0) { 
        die("bind()"); 
    }

    /* Source: man listen, man listen.2
     * SOMAXCONN    defines the maximum pending connection requests to a socket
     *              (default limit is set to 4096).
     *
     * listen()     listtens for any connection requests sent to the bound socket
     */
    if (listen(fd, SOMAXCONN) != 0) {
        die("listen()");
    }

    while (true) {
        struct sockaddr_in client_addr = {};
        socklen_t addrlen = sizeof(client_addr);

        /* Source: man accept.2
         * accept() the first pending connection in the socket queue and returns a
         *          file descriptor containing the address and port of both the 
         *          server and the client
         */
        int connfd = accept(fd, (struct sockaddr*)&client_addr, &addrlen);
        if (connfd < 0) {
            continue;
        }

        while (true) {
            int32_t err = one_request(connfd);
            if (err) {
                break;
            }
        }

        /* Source: man close.2
         * close() closes a file descriptor
         */
        close(connfd);
    }

    return 0;
}
