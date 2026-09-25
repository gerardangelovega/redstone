#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <string>

#include "server/common.h"
#include "server/serialize.h"
#include "server/zset.h"
#include "shared/io.h"
#include "shared/protocol.h"

#include "server/data.h"
#include "server/hashtable.h"

struct Data g_data;

struct LookupKey {
    struct HNode node;  // hashtable node
    std::string key;
};

Entry* entry_new(uint32_t type) {
    Entry* ent = new Entry();
    ent->type = type;
    return ent;
}

void entry_del(Entry* ent) {
    if (ent->type == T_ZSET) {
        zset_clear(&ent->zset);
    }
    delete ent;
}

bool entry_eq(HNode* lhs, HNode* rhs) {
    struct Entry* le = container_of(lhs, Entry, node);
    struct Entry* re = container_of(rhs, Entry, node);
    return le->key == re->key;
}

bool cb_keys(HNode* node, void* arg) {
    Buffer& out = *(Buffer*)arg;
    const std::string& key = container_of(node, Entry, node)->key;
    out_str(out, key.data(), key.size());
    return true;
};

void do_get(std::vector<std::string>& cmd, Buffer& out) {
    Entry key;
    key.key.swap(cmd[1]);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* node = hm_lookup(&g_data.db, &key.node, &entry_eq);
    if (!node) {
        return out_nil(out);
        // out.status = RES_NX;
        // return;
    }
    const std::string& val = container_of(node, Entry, node)->val;
    // assert(val.size() <= K_MAX_MSG);
    // out.data.assign(val.begin(), val.end());
    return out_str(out, val.data(), val.size());
}

void do_set(std::vector<std::string>& cmd, Buffer& out) {
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
    return out_nil(out);
}

void do_del(std::vector<std::string>& cmd, Buffer& out) {
    Entry key;
    key.key.swap(cmd[1]);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* node = hm_delete(&g_data.db, &key.node, &entry_eq);
    if (node) {
        // delete container_of(node, Entry, node);
        entry_del(container_of(node, Entry, node));
    }
    return out_int(out, node ? 1 : 0);
}

void do_keys(std::vector<std::string>&, Buffer& out) {
    out_arr(out, (uint32_t)hm_size(&g_data.db));
    hm_foreach(&g_data.db, &cb_keys, (void*)&out);
}

static ZSet* expect_zset(std::string& s) {
    LookupKey key;
    key.key.swap(s);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* hnode = hm_lookup(&g_data.db, &key.node, &entry_eq);
    if (!hnode) {
        return (ZSet*)&k_empty_zset;
    }
    Entry *ent = container_of(hnode, Entry, node);
    return ent->type == T_ZSET ? &ent->zset : NULL;
}

void do_zadd(std::vector<std::string>& cmd, Buffer& out) {
    double score = 0;
    if (!str_to_dbl(cmd[2], score)) {
        return out_err(out, ERR_BAD_ARG, "expect float");
    }

    LookupKey key;
    key.key.swap(cmd[1]);
    key.node.hcode = str_hash((uint8_t*)key.key.data(), key.key.size());
    HNode* hnode = hm_lookup(&g_data.db, &key.node, &entry_eq);

    Entry* ent = NULL;
    if (!hnode) {
        printf("ZSet not found, creating new ZSet\n");
        ent = entry_new(T_ZSET);
        ent->key.swap(key.key);
        ent->node.hcode = key.node.hcode;
        hm_insert(&g_data.db, &ent->node);
    } else {
        printf("ZSet found\n");
        ent = container_of(hnode, Entry, node);
        if (ent->type != T_ZSET) {
            return out_err(out, ERR_BAD_TYP, "expect zset");
        }
    }

    const std::string& name = cmd[3];
    bool added = zset_insert(&ent->zset, name.data(), name.size(), score);
    return out_int(out, (int64_t)added);

}

void do_zrem(std::vector<std::string>& cmd, Buffer& out) {
    ZSet* zset = expect_zset(cmd[1]);
    if (!zset) {
        return out_err(out, ERR_BAD_TYP, "expect zset");
    }

    const std::string& name = cmd[2];
    ZNode* znode = zset_lookup(zset, name.data(), name.size());
    if (znode) {
        zset_delete(zset, znode);
    }
    return out_int(out, znode ? 1 : 0);
}

void do_zscore(std::vector<std::string>& cmd, Buffer& out) {
    ZSet* zset = expect_zset(cmd[1]);
    if (!zset) {
        return out_err(out, ERR_BAD_TYP, "expect zset");
    }

    const std::string& name = cmd[2];
    ZNode* znode = zset_lookup(zset, name.data(), name.size());
    return znode ? out_dbl(out, znode->score) : out_nil(out);
}

void do_zquery(std::vector<std::string>& cmd, Buffer& out) {
    double score = 0;
    if (!str_to_dbl(cmd[2], score)) {
        return out_err(out, ERR_BAD_ARG, "expect fp number");
    }

    const std::string& name = cmd[3];

    int64_t offset, limit = 0;
    if (!str_to_int(cmd[4], offset)) {
        return out_err(out, ERR_BAD_ARG, "expect int");
    }
    if (!str_to_int(cmd[5], limit)) {
        return out_err(out, ERR_BAD_ARG, "expect int");
    }

    ZSet* zset = expect_zset(cmd[1]);
    if (!zset) {
        return out_err(out, ERR_BAD_TYP, "expect zset");
    }

    if (limit <= 0) {
        return out_arr(out, 0);
    }
    ZNode* znode = zset_seekge(zset, score, name.data(), name.size());
    znode = znode_offset(znode, offset);

    size_t ctx = out_begin_arr(out);
    int64_t n = 0;
    while (znode && n < limit) {
        out_str(out, znode->name, znode->len);
        out_dbl(out, znode->score);
        znode = znode_offset(znode, +1);
        n = n + 2;
    }
    out_end_arr(out, ctx, (uint32_t)n);
}
