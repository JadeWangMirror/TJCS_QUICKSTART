#include "HashTable.h"
#include "Utility.h"

HashTable::HashTable()
    : m_PoolIdx(0)
{
    for (unsigned int i = 0; i < HASH_SIZE; i++)
        m_Buckets[i] = NULL;
    for (unsigned int i = 0; i < HASH_SIZE * 2; i++)
    {
        m_EntryPool[i].h_inode    = NULL;
        m_EntryPool[i].h_filePage = 0;
        m_EntryPool[i].h_frame    = 0;
        m_EntryPool[i].h_refCount = 0;
        m_EntryPool[i].h_next     = NULL;
    }
}

HashTable::~HashTable()
{
}

HashEntry* HashTable::Lookup(Inode* inode, unsigned int filePage)
{
    unsigned int bucket = Utility::Hash((unsigned long)inode, filePage) % HASH_SIZE;
    HashEntry* entry = m_Buckets[bucket];

    while (entry != NULL)
    {
        if (entry->h_inode == inode && entry->h_filePage == filePage)
            return entry;
        entry = entry->h_next;
    }
    return NULL;
}

HashEntry* HashTable::Insert(Inode* inode, unsigned int filePage, unsigned int frame)
{
    if (m_PoolIdx >= HASH_SIZE * 2)
        return NULL;  /* 哈希表满 */

    unsigned int bucket = Utility::Hash((unsigned long)inode, filePage) % HASH_SIZE;

    HashEntry* entry = &m_EntryPool[m_PoolIdx++];
    entry->h_inode    = inode;
    entry->h_filePage = filePage;
    entry->h_frame    = frame;
    entry->h_refCount = 1;
    entry->h_next     = m_Buckets[bucket];
    m_Buckets[bucket] = entry;

    return entry;
}

unsigned int HashTable::Release(Inode* inode, unsigned int filePage)
{
    unsigned int bucket = Utility::Hash((unsigned long)inode, filePage) % HASH_SIZE;
    HashEntry** pp = &m_Buckets[bucket];

    while (*pp != NULL)
    {
        HashEntry* entry = *pp;
        if (entry->h_inode == inode && entry->h_filePage == filePage)
        {
            if (--entry->h_refCount == 0)
            {
                unsigned int frame = entry->h_frame;
                *pp = entry->h_next;       /* 从链表删除 */
                entry->h_inode = NULL;      /* 标记为可用 */
                return frame;               /* 调用者负责释放物理帧 */
            }
            return 0;
        }
        pp = &entry->h_next;
    }
    return 0;
}

void HashTable::Remove(Inode* inode, unsigned int filePage)
{
    unsigned int bucket = Utility::Hash((unsigned long)inode, filePage) % HASH_SIZE;
    HashEntry** pp = &m_Buckets[bucket];

    while (*pp != NULL)
    {
        HashEntry* entry = *pp;
        if (entry->h_inode == inode && entry->h_filePage == filePage)
        {
            *pp = entry->h_next;
            entry->h_inode = NULL;
            return;
        }
        pp = &entry->h_next;
    }
}

void HashTable::AddRef(Inode* inode, unsigned int filePage)
{
    HashEntry* entry = Lookup(inode, filePage);
    if (entry != NULL)
        entry->h_refCount++;
}
