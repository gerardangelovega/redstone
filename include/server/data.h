#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "server/buffer.h"
#include "server/conn.h"
#include "server/dlist.h"
#include "server/hashtable.h"
#include "server/heap.h"
#include "server/zset.h"

struct Data {
    HMap db;
    std::vector<Conn*> fd2conn;
    DList idle_list;
    std::vector<HeapItem> heap;
};

extern struct Data g_data;

enum {
    T_INIT = 0,
    T_STR  = 1,
    T_ZSET = 2,
};

struct Entry {
    struct HNode node;
    std::string key;

    size_t heap_idx = -1;

    uint32_t type = 0;

    std::string str;
    ZSet zset;
};

Entry* entry_new(uint32_t type);
bool entry_eq(HNode* lhs, HNode* rhs);
void entry_del(Entry* ent);
void entry_set_ttl(Entry* ent, int64_t ttl_ms);
bool cb_keys(HNode* node, void* arg);

uint64_t str_hash(const uint8_t *data, size_t len);

void do_get(std::vector<std::string>& cmd, Buffer& out);
void do_set(std::vector<std::string>& cmd, Buffer& out);
void do_del(std::vector<std::string>& cmd, Buffer& out);
void do_keys(std::vector<std::string>& cmd, Buffer& out);
void do_zadd(std::vector<std::string>& cmd, Buffer& out);
void do_zrem(std::vector<std::string>& cmd, Buffer& out);
void do_zscore(std::vector<std::string>& cmd, Buffer& out);
void do_zquery(std::vector<std::string>& cmd, Buffer& out);
void do_expire(std::vector<std::string>& cmd, Buffer& out);
void do_ttl(std::vector<std::string>& cmd, Buffer& out);
