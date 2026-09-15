#include <cstddef>
#include <cstdlib>

#include "server/hashtable.h"
#include "server/data.h"

void h_init(HTable* htable, size_t n) {
    // Assert that the capacity of the hash table is at least one and that the initial
    // capacity is a power of 2.
    // Ex. n = 4, n - 1 = 3, 4 = 0b100, 3 - 0b011, 0b100 & 0b011 = 0b000
    assert(n > 0 && ((n - 1) & n) == 0);

    htable->table = (HNode**)calloc(n, sizeof(HNode*));
    htable->mask  = n - 1;
    htable->size  = 0;
}

void h_insert(HTable* htable, HNode* node) {
    size_t pos = node->hcode & htable->mask;
    HNode* next = htable->table[pos];
    node->next = next;
    htable->table[pos] = node;
    htable->size++;
}

HNode** h_lookup(HTable* htable, HNode* key, bool (*eq)(HNode*, HNode*)) {
    if (!htable->table) {
        return NULL;
    }
    size_t pos = key->hcode & htable->mask; // get position by bitmasking
    HNode** from = &htable->table[pos]; // get the htable slot instead of the pointer

    // 1. traverse through the linked list until we hit a null
    // 2. (curr = *from) is so that curr gets updated everytime we perform a comparison
    // 3. eq() is a pointer to a function that can perform node comparisons
    for (HNode* cur; (cur = *from) != NULL; from = &cur->next) {
        if (cur->hcode == key->hcode && eq(cur, key)) {
            return from;
        }
    }
    return NULL;
}
// 13: 1,2,3,4 (look for 3)
// *13
// 1
// *2
// 2
// *3
// 3
// ret *3 (pointer to node* 3)

HNode* h_detach(HTable* htable, HNode** from) {
    HNode* node = *from;
    *from = node->next;
    htable->size--;
    return node;
}

bool h_foreach(HTable* htable, bool (*f)(HNode*, void*), void* arg) {
    for (size_t i = 0; htable->mask != 0 && i <= htable->mask; ++i) {
        for (HNode* node = htable->table[i]; node != NULL; node = node->next) {
            if (!f(node, arg)) {
                return false;
            }
        }
    }
    return true;
}

HNode* hm_lookup(HMap* hmap, HNode* key, bool (*eq)(HNode*, HNode*)) {
    hm_help_rehashing(hmap);
    // from is the 'next' field of the target node's parent
    // we first check if it exists in the new hashtable
    HNode** from = h_lookup(&hmap->newer, key, eq);
    // if not in the new hashtable, we check in the old
    if (!from) {
        from = h_lookup(&hmap->older, key, eq);
    }
    // if from is not null, we dereference from to get the target node
    // (we are effectively accessing the target node through its parents 'next' field)
    // otherwise, we return NULL
    return from ? *from : NULL;
}

void hm_insert(HMap* hmap, HNode* node) {
    if (!hmap->newer.table) {
        h_init(&hmap->newer, 4);
    }
    h_insert(&hmap->newer, node);
    if (!hmap->older.table) {
        size_t threshold = (hmap->newer.mask + 1) * K_MAX_LOAD_FACTOR;
        if (hmap->newer.size >= threshold) {
            hm_trigger_rehashing(hmap);
        }
    }
    hm_help_rehashing(hmap);
}

HNode* hm_delete(HMap* hmap, HNode* key, bool (*eq)(HNode*, HNode*)) {
    hm_help_rehashing(hmap);
    if (HNode** from = h_lookup(&hmap->newer, key, eq)) {
        return h_detach(&hmap->newer, from);
    }
    if (HNode** from = h_lookup(&hmap->older, key, eq)) {
        return h_detach(&hmap->older, from);
    }
    return NULL;
}

void hm_trigger_rehashing(HMap* hmap) {
    // copy the new table to the old table
    hmap->older = hmap->newer;
    // we modify the new table to have double the space and zero it out
    h_init(&hmap->newer, (hmap->newer.mask + 1) * 2);
    // we set the migration position to 0
    hmap->migrate_pos = 0;
}

void hm_help_rehashing(HMap* hmap) {
    size_t nwork = 0;
    while (nwork < K_REHASHING_WORK && hmap->older.size > 0) {
        HNode** from = &hmap->older.table[hmap->migrate_pos];
        if (!*from) {
            hmap->migrate_pos++;
            continue;
        }
        h_insert(&hmap->newer, h_detach(&hmap->older, from));
        nwork++;
    }
    if (hmap->older.size == 0 && hmap->older.table) {
        free(hmap->older.table);
        hmap->older = HTable{};
    }
}

size_t hm_size(HMap* hmap) {
    return hmap->older.size + hmap->newer.size;
}

void hm_foreach(HMap* hmap, bool (*f)(HNode*, void*), void* arg) {
    h_foreach(&hmap->newer, f, arg) && h_foreach(&hmap->older, f, arg);
}
