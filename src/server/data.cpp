#include <cassert>
#include <cstdint>
#include <string>

#include "shared/io.h"
#include "shared/protocol.h"

#include "server/data.h"
#include "server/hashtable.h"

struct Data g_data;

bool entry_eq(HNode* lhs, HNode* rhs) {
    struct Entry* le = container_of(lhs, Entry, node);
    struct Entry* re = container_of(rhs, Entry, node);
    return le->key == re->key;
}

uint64_t str_hash(const uint8_t *data, size_t len) {
    uint32_t h = 0x811C9DC5;
    for (size_t i = 0; i < len; i++) {
        h = (h + data[i]) * 0x01000193;
    }
    return h;
}

void do_get(std::vector<std::string>& cmd, Response& out) {
    Entry key;
    key.key.swap(cmd[1]);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* node = hm_lookup(&g_data.db, &key.node, &entry_eq);
    if (!node) {
        out.status = RES_NX;
        return;
    }
    const std::string& val = container_of(node, Entry, node)->val;
    assert(val.size() <= K_MAX_MSG);
    out.data.assign(val.begin(), val.end());
}

void do_set(std::vector<std::string>& cmd, Response&) {
    Entry key;
    key.key.swap(cmd[1]);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* node = hm_lookup(&g_data.db, &key.node, &entry_eq);
    if (node) {
        container_of(node, Entry, node)->val.swap(cmd[2]);
    } else {
        Entry *ent = new Entry();
        ent->key.swap(key.key);
        ent->node.hcode = key.node.hcode;
        ent->val.swap(cmd[2]);
        hm_insert(&g_data.db, &ent->node);
    }
}

void do_del(std::vector<std::string>& cmd, Response&) {
    Entry key;
    key.key.swap(cmd[1]);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* node = hm_delete(&g_data.db, &key.node, &entry_eq);
    if (node) {
        delete container_of(node, Entry, node);
    }
}
