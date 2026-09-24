#include <cassert>
#include <cstddef>
#include <cstdint>
#include <regex>

#include "server/avl.h"

static uint32_t max(uint32_t lhs, uint32_t rhs) {
    return lhs > rhs ? lhs : rhs;
}

// sets the height of a node to 1 + the tallest subtree of the node
void avl_update(AVLNode* node) {
    node->height = 1 + max(avl_height(node->left), avl_height(node->right));
    node->cnt = 1 + avl_cnt(node->left) + avl_cnt(node->right);
}

// extracts the last 2 bits of the parent node pointer to get the 
// bits representing the node's balance factor
uint8_t avl_get_height_diff(AVLNode* node) {
    uintptr_t p = (uintptr_t)node->parent;
    return p & 0b11;
}

// returns the parent by stripping the last 2 bits and casting into a node
// pointer
AVLNode* avl_get_parent(AVLNode* node) {
    uintptr_t p = (uintptr_t)node->parent;
    return (AVLNode*)(p & (~0b11));
}

AVLNode* rot_left(AVLNode* node) {
    // get the parent of the node
    AVLNode* parent = node->parent;
    // get the right child of the node
    AVLNode* new_node = node->right;
    // get the left child of the right child of the node
    AVLNode* inner = new_node->left;
    // TREE VISUALIZATION
    //     A
    //    / \
    //   B  C
    //     / \
    //    D  E

    // set the right child of the node to the left child of the right child of the node
    node->right = inner;
    // if left child of the right child of the node is not null, then we its parent
    // to the node
    if (inner) {
        inner->parent = node;
    }
    // TREE VISUALIZATION
    //      A          A   C
    //     / \        / \   \
    //    B  C  -->  B  D    E
    //      / \
    //     D  E 
    //  A.right = D or A.right = A.right.left

    // set the parent of the right child of the node to the parent of the node
    new_node->parent = parent;
    // set the left child if the right child of the node to the node
    new_node->left = node;
    // set the parent of the node to the right child of the node
    node->parent = new_node;
    // TREE VISUALIZATION
    //    A   C           C
    //   / \   \         / \
    //  B  D    E  -->  A   E
    //                 / \
    //                B  D
    //  C.left = A

    avl_update(node);
    avl_update(new_node);
    return new_node;
}

AVLNode* rot_right(AVLNode* node) {
    AVLNode* parent = node->parent;
    AVLNode* new_node = node->left;
    AVLNode* inner = new_node->right;

    node->left = inner;
    if (inner) {
        inner->parent = node;
    }

    new_node->parent = parent;
    new_node->right = node;
    node->parent = new_node;

    avl_update(node);
    avl_update(new_node);
    return new_node;
}

AVLNode* avl_fix_left(AVLNode* node) {
    if (avl_height(node->left->left) < avl_height(node->left->right)) {
        node->left = rot_left(node->left);
    }
    return rot_right(node);
}

AVLNode* avl_fix_right(AVLNode* node) {
    if (avl_height(node->right->right) < avl_height(node->right->left)) {
        node->right = rot_right(node->right);
    }
    return rot_left(node);
}

AVLNode* avl_fix(AVLNode* node) {
    while (true) {
        AVLNode** from = &node;
        AVLNode* parent = node->parent;
        if (parent) {
            from = parent->left == node ? &parent->left : &parent->right;
        }
        avl_update(node);
        uint32_t l = avl_height(node->left);
        uint32_t r = avl_height(node->right);
        if (l == r + 2) {
            *from = avl_fix_left(node);
        } else if (r == l + 2) {
            *from = avl_fix_right(node);
        }

        if (!parent) {
            return *from;
        }

        node = parent;
    }
}

AVLNode* avl_del_easy(AVLNode* node) {
    // asserts that there is at least one child
    assert(!node->left || !node->right);

    // get the only child of the node
    AVLNode* child = node->left ? node->left : node->right;

    // get the parent of the node
    AVLNode* parent = node->parent;

    // if child is not null, set its parent to its grandparent
    if (child) {
        child->parent = parent;
    }

    // if parent is null, then child is the root node and therefore, 
    // return the child node
    if (!parent) {
        return child;
    }

    // get a pointer to the pointer in the parent node pointing to the current node 
    // (i.i pointer to Parent.left or Parent.right so we can modify which node it is
    // pointing to)
    AVLNode** from = parent->left == node ? &parent->left : &parent->right;
    // set the parent's child to child
    *from = child;

    // fix any imbalance starting from the parent node to the root node
    return avl_fix(parent);
}

AVLNode* avl_del(AVLNode* node) {
    // if the node only has one child, then we do the easy delete algorithm
    if (!node->left || !node->right) {
        return avl_del_easy(node);
    }

    // get the right child of the node
    AVLNode* victim = node->right;
    // get the left most descenant of the right child of the node
    while (victim->left) {
        victim = victim->left;
    }

    // delete the left most descendant of the right child of the node and get the
    // root of the tree
    AVLNode* root = avl_del_easy(victim);
    // set the data of the victim node to the data of the node
    // we are effectively stealing the family of node and transplanting them into 
    // victim
    *victim = *node;
    // set the parent of the children of node to victim
    if (victim->left) {
        victim->left->parent = victim;
    }
    if (victim->right) {
        victim->right->parent = victim;
    }
    // make a pointer that points to the root pointer
    AVLNode** from = &root;
    // get the parent of the node
    AVLNode* parent = node->parent;
    // if the node has a parent, make a pointer that points the the parents left or right pointer
    if (parent) {
        from = parent->left == node ? &parent->left : &parent->right;
    }
    // make the victim either the root of the tree or the child of the node's parent
    *from = victim;
    return root;
}

static AVLNode* successor(AVLNode* node) {
    // If the node has a right subtree, then we can find the right subtree's leftmost
    // node to find its succssor by property of a BST
    if (node->right) {
        for (node = node->right; node->left; node = node->left) {}
        return node;
    }
    // If the node has no right subtree, then we can find the closest ancestor in 
    // which the node is a member of it's left subtree and return the closest ancestor
    // as its successor by property of a BST
    while (AVLNode* parent = node->parent) {
        if (node == parent->left) {
            return parent;
        }
        node = parent;
    }
    // If the node has no right subtree and is not a member of some ancestor's left
    // subtree, then the node has no successors by property of a BST
    return NULL;
}

static AVLNode* predecessor(AVLNode* node) {
    // If the node has a left subtree, then we can find the left subtree's rightmost
    // node to find its predecessor by property of a BST
    if (node->left) {
        for (node = node->left; node->right; node = node->right) {}
        return node;
    }
    // If the node has no left subtree, then we can find the closest ancestor in 
    // which the node is a member of it's right subtree and return the closest 
    // ancestor as its successor by property of a BST
    while (AVLNode* parent = node->parent) {
        if (node == parent->right) {
            return parent;
        }
        node = parent;
    }
    // If the node has neither a left subtree nor belongs to the rightmost subtree of
    // some ancestor, then the node has no predecessor by property of a BST
    return NULL;
}

AVLNode* avl_offset_reg(AVLNode* node, int64_t offset) {
    for (; offset > 0 && node; offset--) {
        node = successor(node);
    }
    for (; offset < 0 && node; offset++) {
        node = predecessor(node);
    }
    return node;
}

AVLNode* avl_offset(AVLNode* node, int64_t offset) {
    int64_t pos = 0;
    while (offset != pos) {
        if (pos < offset && pos + avl_cnt(node->right) >= offset) {
            node = node->right;
            pos += avl_cnt(node->left) + 1;
        } else if (pos > offset && pos - avl_cnt(node->left) <= offset) {
            node = node->left;
            pos -= avl_cnt(node->right) + 1;
        } else {
            AVLNode* parent = node->parent;
            if (!parent) {
                return NULL;
            }
            if (parent->right == node) {
                pos -= avl_cnt(node->left) + 1;
            } else {
                pos += avl_cnt(node->right) + 1;
            }
            node = parent;
        }
    }
    return node;
}
