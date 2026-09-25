#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include "server/avl.h"
#include "server/common.h"
#include "server/data.h"
#include "server/hashtable.h"
#include "server/zset.h"

ZNode* znode_new(const char* name, size_t len, double score) {
    // Allocate enough memory to store a ZNode (64 bytes) and a string (N bytes)
    ZNode* node = (ZNode*)malloc(sizeof(ZNode) + len);
    avl_init(&node->tree);
    node->hmap.next = NULL;
    node->hmap.hcode = str_hash((uint8_t*)name, len);
    node->score = score;
    node->len = len;
    memcpy(&node->name, name, len);
    return node;
}

void znode_del(ZNode* node) {
    free(node);
}

ZNode* znode_offset(ZNode* node, int64_t offset) {
    AVLNode* tnode = node ? avl_offset(&node->tree, offset) : NULL;
    return tnode ? container_of(tnode, ZNode, tree) : NULL;
}

ZNode* zset_lookup(ZSet* zset, const char* name, size_t len) {
    if (!zset->root) {
        return NULL;
    }
    HKey key;
    key.node.hcode = str_hash((uint8_t*)name, len);
    key.name = name;
    key.len = len;
    HNode* found = hm_lookup(&zset->hmap, &key.node, &hcmp);
    return found ? container_of(found, ZNode, hmap) : NULL;
}

bool zset_insert(ZSet* zset, const char* name, size_t len, double score) {
    if (ZNode* node = zset_lookup(zset, name, len)) {
        zset_update(zset, node, score);
        return false;
    }
    ZNode* node = znode_new(name, len, score);
    hm_insert(&zset->hmap, &node->hmap);
    tree_insert(zset, node);
    return true;
}

void zset_update(ZSet* zset, ZNode* node, double score) {
    // detach node from tree
    zset->root = avl_del(&node->tree);
    // reset or re-init node
    avl_init(&node->tree);
    // set the score to the updated score
    node->score = score;
    // re-insert and re-fix the tree
    tree_insert(zset, node);
}

void zset_delete(ZSet* zset, ZNode* node) {
    // create a dummy key for lookup
    HKey key;
    key.node.hcode = node->hmap.hcode;
    key.name = node->name;
    key.len = node->len;
    // find and delete the hasmap node associated with the ZNode from the hashmap
    HNode* found = hm_delete(&zset->hmap, &key.node, &hcmp);
    assert(found);
    // find and delete the avl tree node associated with the ZNode from the AVL tree
    zset->root = avl_del(&node->tree);
    // delete the node from memory
    znode_del(node);
}

void zset_clear(ZSet* zset) {
    hm_clear(&zset->hmap);
    tree_dispose(zset->root);
    zset->root = NULL;
}

// Finds the first (score, name) tuple that is greater than or equal to the 
// (score, name) tuple specified in the parameters
ZNode* zset_seekge(ZSet* zset, double score, const char* name, size_t len) {
    AVLNode* found = NULL;
    for (AVLNode* node = zset->root; node; ) {
        if (zless(node, score, name, len)) {
            node = node->right;
        } else {
            found = node;
            node = node->left;
        }
    }
    return found ? container_of(found, ZNode, tree) : NULL;
}

bool zless(AVLNode* lhs, double score, const char* name, size_t len) {
    ZNode* zl = container_of(lhs, ZNode, tree);
    if (zl->score != score) {
        return zl->score < score;
    }
    int rv = memcmp(zl->name, name, std::min(zl->len, len));
    if (rv != 0) {
        return rv < 0;
    }
    return zl->len < len;
}

bool zless(AVLNode* lhs, AVLNode* rhs) {
    ZNode* zr = container_of(rhs, ZNode, tree);
    return zless(lhs, zr->score, zr->name, zr->len);
}

void tree_insert(ZSet* zset, ZNode* node) {
    AVLNode* parent = NULL;
    AVLNode** from = &zset->root;
    while (*from) {
        parent = *from;
        from = zless(&node->tree, parent) ? &parent->left : &parent->right;
    }
    *from = &node->tree;
    node->tree.parent = parent;
    zset->root = avl_fix(&node->tree);
}

void tree_dispose(AVLNode* node) {
    if (!node) {
        return;
    }
    tree_dispose(node->left);
    tree_dispose(node->right);
    znode_del(container_of(node, ZNode, tree));
}

bool hcmp(HNode* node, HNode* key) {
    ZNode* znode = container_of(node, ZNode, hmap);
    HKey* hkey = container_of(key, HKey, node);
    if (znode->len != hkey->len) {
        return false;
    }
    return 0 == memcmp(znode->name, hkey->name, znode->len);
}
