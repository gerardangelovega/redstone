#pragma once

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdlib>

struct HNode {
    HNode*   next  = NULL;
    uint64_t hcode = 0;
};

struct HTable {
    HNode** table = NULL;
    size_t  mask  = 0;      // used for bitwise modulo
    size_t  size  = 0;      // used to track number of entries
};
void    h_init(HTable*   htable, size_t  n);
void    h_insert(HTable* htable, HNode*  node);
HNode** h_lookup(HTable* htable, HNode*  key, bool (*eq)(HNode*, HNode*));
HNode*  h_detach(HTable* htable, HNode** from);

constexpr size_t K_MAX_LOAD_FACTOR = 8;
constexpr size_t K_REHASHING_WORK = 128;

struct HMap {
    HTable newer;
    HTable older;
    size_t migrate_pos = 0;
};
HNode* hm_lookup(HMap* hmap, HNode* key, bool (*eq)(HNode*, HNode*));
void   hm_insert(HMap* hmap, HNode* node);
HNode* hm_delete(HMap* hmap, HNode* key, bool (*eq)(HNode*, HNode*));
void   hm_trigger_rehashing(HMap* hmap);
void   hm_help_rehashing(HMap* hmap);
