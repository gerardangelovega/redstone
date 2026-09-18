#pragma once

#include <cstddef>
#include <cstdint>

struct AVLNode {
    AVLNode* parent = NULL;
    AVLNode* left   = NULL;
    AVLNode* right  = NULL;

    uint32_t height = 0;
    uint32_t cnt = 0;
};

AVLNode* rot_left(AVLNode* node);
AVLNode* rot_right(AVLNode* node);

void     avl_init(AVLNode* node);
uint32_t avl_height(AVLNode* node);
uint32_t avl_cnt(AVLNode* node);
void     avl_update(AVLNode* node);
uint8_t  avl_get_height_diff(AVLNode* node);
AVLNode* avl_get_parent(AVLNode* node);
AVLNode* avl_fix_left(AVLNode* node);
AVLNode* avl_fix_right(AVLNode* node);
AVLNode* avl_fix(AVLNode* node);
AVLNode* avl_del_easy(AVLNode* node);
AVLNode* avl_del(AVLNode* node);
