#ifndef PAGE_MANAGER_H
#define PAGE_MANAGER_H

#include "MapNode.h"
#include "Allocator.h"
#include "MemoryDescriptor.h"

class PageManager
{
public:
	static unsigned int PHY_MEM_SIZE;

	static const unsigned int PAGE_SIZE = 0x1000;
	static const unsigned int MEMORY_MAP_ARRAY_SIZE = 0x200;
	static const unsigned int KERNEL_MEM_START_ADDR = 0x100000;
	static const unsigned int KERNEL_SIZE = 0x80000;

public:
	PageManager(BitMapAllocator *allocator);
	virtual ~PageManager();

	int Initialize();
	unsigned long AllocMemory(unsigned long size);
	unsigned long FreeMemory(unsigned long size, unsigned long memoryStartAddress);

private:
	PageManager();

public:
	MapNode map[PageManager::MEMORY_MAP_ARRAY_SIZE];
	// NOTE:1
	BitMap bitmap;
	// NOTE:3 COW reference counting
	int Page[MemoryDescriptor::USER_SPACE_SIZE / PAGE_SIZE];

private:
	BitMapAllocator *m_pAllocator;
};


class KernelPageManager : public PageManager
{
public:
	static const unsigned int KERNEL_PAGE_POOL_START_ADDR = 0x200000 + 0x2000 + 0x2000;
	static const unsigned int KERNEL_PAGE_POOL_SIZE = 0x200000 - 0x4000;

public:
	KernelPageManager(BitMapAllocator *allocator);
	int Initialize();
};


class UserPageManager : public PageManager
{
public:
	static const unsigned int USER_PAGE_POOL_START_ADDR = 0x400000;
	static unsigned int USER_PAGE_POOL_SIZE;

public:
	UserPageManager(BitMapAllocator *allocator);
	int Initialize();
	void EvictOnePage();
};

#endif
