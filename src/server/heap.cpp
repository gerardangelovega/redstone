#include <cstddef>
#include <cstdio>
#include <vector>

#include "server/heap.h"

static size_t heap_parent(size_t i) {
    return (i + 1) / 2 - 1;
}

static size_t heap_left(size_t i) {
    return i * 2 + 1;
}

static size_t heap_right(size_t i) {
    return i * 2 + 2;
}

// a is an array of HeapItems
static void heap_up(HeapItem* a, size_t pos) {
    HeapItem t = a[pos];
    while (pos > 0 && t.val < a[heap_parent(pos)].val) {
        a[pos] = a[heap_parent(pos)];
        *a[pos].ref = pos;
        pos = heap_parent(pos);
    }
    a[pos] = t;
    *a[pos].ref = pos;
}

static void heap_down(HeapItem* a, size_t pos, size_t len) {
    HeapItem t = a[pos];
    while (true) {
        size_t left = heap_left(pos);
        size_t right = heap_right(pos);
        size_t min_pos = pos;
        uint64_t min_val = t.val;

        if (left < len && a[left].val < min_val) {
            min_pos = left;
            min_val = a[left].val;
        }
        if (right < len && a[right].val < min_val) {
            min_pos = right;
        }
        if (min_pos == pos) {
            break;
        }
        a[pos] = a[min_pos];
        *a[pos].ref = pos;
        pos = min_pos;
    }
    a[pos] = t;
    *a[pos].ref = pos;
}

void heap_update(HeapItem* a, size_t pos, size_t len) {
    if (pos > 0 && a[pos].val < a[heap_parent(pos)].val) {
        heap_up(a, pos);
    } else {
        heap_down(a, pos, len);
    }
}

void heap_delete(std::vector<HeapItem> &a, size_t pos) {
    a[pos] = a.back();
    a.pop_back();
    if (pos < a.size()) {
        heap_update(a.data(), pos, a.size());
    }
}

void heap_upsert(std::vector<HeapItem>& a, size_t pos, HeapItem t) {
    // printf("updating/inserting expiration timer\n");
    if (pos < a.size()) {
        a[pos] = t;
    } else {
        pos = a.size();
        a.push_back(t);
    }
    heap_update(a.data(), pos, a.size());
}
