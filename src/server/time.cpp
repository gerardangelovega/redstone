#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <vector>

#include "server/time.h"
#include "server/common.h"
#include "server/conn.h"
#include "server/data.h"
#include "server/dlist.h"
#include "server/hashtable.h"

uint64_t get_monotonic_ms() {
    struct timespec tv = {0, 0};
    clock_gettime(CLOCK_MONOTONIC, &tv);
    return uint64_t(tv.tv_sec) * 1000 + tv.tv_nsec / 1000 / 1000;
}

int32_t next_timer_ms() {
    uint64_t now_ms = get_monotonic_ms();
    uint64_t next_ms = (uint64_t)-1;
    if (!dlist_empty(&g_data.idle_list)) {
        Conn* conn = container_of(g_data.idle_list.next, Conn, idle_node);
        next_ms = conn->last_active_ms + K_IDLE_TIMEOUT_MS;
    }
    if (!g_data.heap.empty() && g_data.heap[0].val < next_ms) {
        next_ms = g_data.heap[0].val;
    }
    if (next_ms == (uint64_t)-1) {
        return -1;
    }
    if (next_ms <= now_ms) {
        return 0;
    }
    return (int32_t)(next_ms - now_ms);
}

static bool hnode_same(HNode* node, HNode* key) {
    return node == key;
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
    const std::vector<HeapItem>& heap = g_data.heap;
    size_t nworks = 0;
    while (!heap.empty() && heap[0].val < now_ms && nworks < K_TTL_MAX_WORKS) {
        // printf("expiring entry\n");
        Entry* ent = container_of(heap[0].ref, Entry, heap_idx);
        HNode* node = hm_delete(&g_data.db, &ent->node, &hnode_same);
        assert(node == &ent->node);
        entry_del(ent);
        nworks++;
    }
}
