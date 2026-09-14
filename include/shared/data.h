#pragma once

#include "shared/conn.h"
#include "shared/hashtable.h"
#include <string>
#include <vector>

#define container_of(ptr, T, member) \
    ((T*)((char*)ptr - offsetof(T, member)))

struct Data {
    HMap db;
};

extern struct Data g_data;

struct Entry {
    struct HNode node;
    std::string key;
    std::string val;
};

bool entry_eq(HNode* lhs, HNode* rhs);

uint64_t str_hash(const uint8_t *data, size_t len);

void do_get(std::vector<std::string>& cmd, Response& out);

void do_set(std::vector<std::string>& cmd, Response& out);

void do_del(std::vector<std::string>& cmd, Response& out);
