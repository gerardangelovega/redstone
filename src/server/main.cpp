#include <cstddef>
#include <cstdint>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/poll.h>
#include <unistd.h>
#include <vector>

#include "server/data.h"
#include "server/dlist.h"
#include "server/hashtable.h"
#include "server/time.h"
#include "server/zset.h"
#include "shared/io.h"
#include "shared/error.h"
#include "server/conn.h"

// static int32_t one_request(int connfd) {
//     char rbuf[4 + K_MAX_MSG];
//     errno = 0;
//     int32_t err = read_full(connfd, rbuf, 4);
//     if (err) {
//         msg(errno == 0 ? "EOF" : "read() error");
//         return err;
//     }
//     uint32_t len = 0;
//     memcpy(&len, rbuf, 4);
//     if (len > K_MAX_MSG) {
//         msg("too long");
//         return -1;
//     }
//     err = read_full(connfd, &rbuf[4], len);
//     if (err) {
//         msg("read() error");
//         return err;
//     }
//
//     printf("client says: %.*s\n", len, &rbuf[4]);
//     const char reply[] = "world";
//     char wbuf[4 + sizeof(reply)];
//     len = (uint32_t)strlen(reply);
//     memcpy(wbuf, &len, 4);
//     memcpy(&wbuf[4], reply, len);
//     return write_all(connfd, wbuf, 4 + len);
// }

int main () {
    dlist_init(&g_data.idle_list);
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

    fd_set_nb(fd); // set socket fd to non-blocking

    /* Source: man listen, man listen.2
     * SOMAXCONN    defines the maximum pending connection requests to a socket
     *              (default limit is set to 4096).
     *
     * listen()     listtens for any connection requests sent to the bound socket
     */
    if (listen(fd, SOMAXCONN) != 0) {
        die("listen()");
    }

    // std::vector<Conn *> fd2conn;
    std::vector<struct pollfd> poll_args;

    while (true) {
        poll_args.clear();

        struct pollfd pfd = {fd, POLLIN, 0};
        poll_args.push_back(pfd);

        for (Conn* conn : g_data.fd2conn) {
            if (!conn) {
                continue;
            }

            /* Source: man poll.2
             * POLLERR  flag to poll the OS for any errors that occurred
             *          with the associated file descriptor
             *
             * POLLIN   flag to poll the OS whether or not there are bytes in the
             *          the buffer to read
             *
             * POLLOUT  flag to poll the OS whether or not there is enough space in
             *          the buffer without blocking
             */
            struct pollfd pfd = {conn->fd, POLLERR, 0};
            if (conn->want_read) {
                pfd.events = pfd.events | POLLIN;
            }
            if (conn->want_write) {
                pfd.events = pfd.events | POLLOUT;
            }
            poll_args.push_back(pfd);
        }

        int32_t timeout_ms = next_timer_ms();
        /* Source: man poll.2
         * poll()   polls multiple file descriptors for events they want to monitor
         *          (e.g. error, ready to read, ready to write, & etc.)
         */
        int rv = poll(poll_args.data(), (nfds_t)poll_args.size(), timeout_ms);

        /* Source: errno.h
         * EINTR    an error number returned by a syscall when it is interrupted
         */
        if (rv == 0 && errno == EINTR) {
            continue; // retry polling by performing another iteration 
        }
        if (rv < 0) {
            die("poll()");
        }

        if (poll_args[0].revents) {
            handle_accept(fd);
        }

        for (size_t i = 1; i < poll_args.size(); ++i) {
            uint32_t ready = poll_args[i].revents;
            if (ready == 0) {
                continue;
            }
            Conn* conn = g_data.fd2conn[poll_args[i].fd];

            conn->last_active_ms = get_monotonic_ms();
            dlist_detach(&conn->idle_node);
            dlist_insert_before(&g_data.idle_list, &conn->idle_node);

            if (ready & POLLIN) {
                handle_read(conn);
            }
            if (ready & POLLOUT) {
                handle_write(conn);
            }
            if ((ready & POLLERR) || conn->want_close) {
                conn_destroy(conn);
            }
        }

        process_timers();
    }

    // while (true) {
    //     struct sockaddr_in client_addr = {};
    //     socklen_t addrlen = sizeof(client_addr);
    //
    //     /* Source: man accept.2
    //      * accept() the first pending connection in the socket queue and returns a
    //      *          file descriptor containing the address and port of both the 
    //      *          server and the client
    //      */
    //     int connfd = accept(fd, (struct sockaddr*)&client_addr, &addrlen);
    //     if (connfd < 0) {
    //         continue;
    //     }
    //
    //     while (true) {
    //         int32_t err = one_request(connfd);
    //         if (err) {
    //             break;
    //         }
    //     }
    //
    //     /* Source: man close.2
    //      * close() closes a file descriptor
    //      */
    //     close(connfd);
    // }

    return 0;
}
