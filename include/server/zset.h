#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

#include "server/avl.h"
#include "server/hashtable.h"

struct ZNode {
    AVLNode tree; // 32 bytes
    HNode   hmap; // 16 bytes

    double score = 0; // 8 bytes
    size_t len   = 0; // 8 bytes (linux)
    char   name[0];   // variable bytes
};

ZNode* znode_new(const char* name, size_t len, double score);
void   znode_del(ZNode* node);
ZNode* znode_offset(ZNode* node, int64_t offset);

struct HKey {
    HNode node;
    const char* name = NULL;
    size_t len = 0;
};
bool hcmp(HNode* node, HNode* key);

struct ZSet {
    AVLNode* root = NULL;
    HMap     hmap;
};
ZNode* zset_lookup(ZSet* zset, const char* name, size_t len);
bool   zset_insert(ZSet* zset, const char* name, size_t len, double score);
void   zset_update(ZSet* zset, ZNode* node, double score);
void   zset_delete(ZSet* zset, ZNode* node);
void   zset_clear(ZSet* zset);
ZNode* zset_seekge(ZSet* zset, double score, const char* name, size_t len);
bool   zless(AVLNode* lhs, double score, const char* name, size_t len);
bool   zless(AVLNode* lhs, AVLNode* rhs);
void   tree_insert(ZSet* zset, ZNode* node);
void   tree_dispose(AVLNode* node);

inline const ZSet k_empty_zset{};
