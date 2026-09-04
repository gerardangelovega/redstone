#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "shared/error.h"

// prints a message to stderr
void msg(const char* msg) {
    fprintf(stderr, "%s\n", msg);
}

// prints the error number and message and then aborts the program
void die(const char* msg) {
    int err = errno;
    fprintf(stderr, "[%d] %s\n", err, msg);
    abort();
}
