#include <cstddef>
#include <assert.h>
#include <unistd.h>

#include "shared/io.h"

int32_t read_full(int fd, char* buf, size_t n) {
    while (n > 0) {
        /* Source: man read.2
         * read()   reads a specified number of bytes from a file descriptor into a 
         *          buffer
         */
        ssize_t rv = read(fd, buf, n);
        if (rv <= 0) {
            return -1;
        }
        assert((size_t)rv <= n);
        n = n - (size_t)rv;
        buf = buf + rv;
    }
    return 0;
}

int32_t write_all(int fd, const char* buf, size_t n) {
    while (n > 0) {
        /* Source: man read.2
         * write()   writes a specified number of bytes from a buffer into a file 
         *           descriptor
         */
        ssize_t rv = write(fd, buf, n);
        if (rv <= 0) {
            return -1;
        }
        assert((size_t)rv <= n);
        n = n - (size_t)rv;
        buf = buf + rv;
    }
    return 0;
}

void fd_set_nb(int fd) {
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);
}
