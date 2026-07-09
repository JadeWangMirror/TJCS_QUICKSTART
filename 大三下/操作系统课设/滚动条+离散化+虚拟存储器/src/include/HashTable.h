#ifndef HASH_TABLE_H
#define HASH_TABLE_H

#include "INode.h"

/*
 * 共享页哈希表：以 (inode, filePage) 为键管理进程间共享的物理页框。
 * 主要用于文本段按需调页 — 多个进程执行同一可执行文件时共享代码页。
 */

struct HashEntry
{
    Inode*       h_inode;     /* 可执行文件 inode */
    unsigned int h_filePage;  /* 文件内页号 (offset >> 12) */
    unsigned int h_frame;     /* 物理帧号 */
    unsigned int h_refCount;  /* 共享此帧的进程数 */
    HashEntry*   h_next;      /* 链表下一项（冲突链） */
};

class HashTable
{
public:
    static const unsigned int HASH_SIZE = 256;

public:
    HashTable();
    ~HashTable();

    /* 查找已有共享页，未找到返回 NULL */
    HashEntry* Lookup(Inode* inode, unsigned int filePage);

    /* 插入新的共享页映射，失败返回 NULL */
    HashEntry* Insert(Inode* inode, unsigned int filePage, unsigned int frame);

    /* 递减引用计数；归零时删除条目并返回 frame（调用者负责释放），否则返回 0 */
    unsigned int Release(Inode* inode, unsigned int filePage);

    /* 纯释放：仅删除条目，不返回 frame */
    void Remove(Inode* inode, unsigned int filePage);

    /* 递增引用计数 */
    void AddRef(Inode* inode, unsigned int filePage);

private:
    HashEntry  m_EntryPool[HASH_SIZE * 2];  /* 条目池 */
    HashEntry* m_Buckets[HASH_SIZE];        /* 桶头指针 */
    int        m_PoolIdx;                   /* 下一个可用池条目 */
};

#endif
