#include <cstdint>
#include <cstdio>
#include <ctime>

#include "server/time.h"
#include "server/common.h"
#include "server/conn.h"
#include "server/data.h"
#include "server/dlist.h"

uint64_t get_monotonic_ms() {
    struct timespec tv = {0, 0};
    clock_gettime(CLOCK_MONOTONIC, &tv);
    return uint64_t(tv.tv_sec) * 1000 + tv.tv_nsec / 1000 / 100;
}

int32_t next_timer_ms() {
    if (dlist_empty(&g_data.idle_list)) {
        return -1;
    }
    uint64_t now_ms = get_monotonic_ms();
    Conn* conn = container_of(g_data.idle_list.next, Conn, idle_node);
    uint64_t next_ms = conn->last_active_ms + K_IDLE_TIMEOUT_MS;
    if (next_ms <= now_ms) {
        return 0;
    }
    return (int32_t)(next_ms - now_ms);
}

void process_timers() {
    uint64_t now_ms = get_monotonic_ms();
    while (!dlist_empty(&g_data.idle_list)) {
        Conn* conn = container_of(g_data.idle_list.next, Conn, idle_node);
        uint64_t next_ms = conn->last_active_ms + K_IDLE_TIMEOUT_MS;
        if (next_ms >= now_ms) {
            break;
        }
        fprintf(stderr, "removing idle connection: %d\n", conn->fd);
        conn_destroy(conn);
    }
}
