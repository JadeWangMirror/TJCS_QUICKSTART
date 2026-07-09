#ifndef VMAREA_H
#define VMAREA_H

#include "INode.h"

/* 虚存区域类型 */
enum VMAType
{
    VMA_TEXT  = 0,  /* 代码段（只读，从文件调页） */
    VMA_DATA  = 1,  /* 数据段（读写，COW） */
    VMA_HEAP  = 2,  /* 堆（读写，向上增长） */
    VMA_STACK = 3   /* 栈（读写，向下增长） */
};

/* 虚存区域描述符 */
struct VMArea
{
    unsigned long vm_start;  /* 起始虚拟地址 */
    unsigned long vm_end;    /* 结束虚拟地址 (exclusive) */
    VMAType       vm_type;   /* 区域类型 */
    unsigned long vm_foff;   /* 文件内偏移（VMA_TEXT 用） */
    Inode*        vm_inode;  /* 可执行文件 inode（VMA_TEXT 用） */
    VMArea*       vm_next;   /* 链表指针 */
};

#endif
