#include "PageManager.h"
#include "Allocator.h"
#include "Video.h"
#include "Kernel.h"
#include "Machine.h"
#include "Buf.h"

unsigned int PageManager::PHY_MEM_SIZE;
unsigned int UserPageManager::USER_PAGE_POOL_SIZE;

PageManager::PageManager(BitMapAllocator *allocator)
{
	this->m_pAllocator = allocator;
}

int PageManager::Initialize()
{
	for (unsigned int i = 0; i < MEMORY_MAP_ARRAY_SIZE; i++)
	{
		this->map[i].m_AddressIdx = 0;
		this->map[i].m_Size = 0;
	}
	// NOTE:COW
	for (int i = 0; i < MemoryDescriptor::USER_SPACE_SIZE / PAGE_SIZE; ++i)
		Page[i] = 0;
	return 0;
}

unsigned long PageManager::AllocMemory(unsigned long size)
{
	unsigned long newaddr = this->m_pAllocator->Alloc(this->bitmap, size);
	Diagnose::Write("[BitMap] Alloc addr=0x%x\n", newaddr);
	Page[newaddr >> 12] = 1;
	return newaddr;
}

unsigned long PageManager::FreeMemory(unsigned long size, unsigned long startAddress)
{
	Page[startAddress >> 12]--;
	if (Page[startAddress >> 12] == 0)
		this->m_pAllocator->Free(this->bitmap, size, startAddress);
	return 1;
}

PageManager::~PageManager()
{
}

KernelPageManager::KernelPageManager(BitMapAllocator *allocator)
	: PageManager(allocator)
{
}

int KernelPageManager::Initialize()
{
	PageManager::Initialize();
	this->map[0].m_AddressIdx = KERNEL_PAGE_POOL_START_ADDR / PageManager::PAGE_SIZE;
	this->map[0].m_Size = KERNEL_PAGE_POOL_SIZE / PageManager::PAGE_SIZE;
	this->bitmap.set(KERNEL_PAGE_POOL_START_ADDR, KERNEL_PAGE_POOL_SIZE / PageManager::PAGE_SIZE);
	return 0;
}

UserPageManager::UserPageManager(BitMapAllocator *allocator)
	: PageManager(allocator)
{
}

int UserPageManager::Initialize()
{
	PageManager::Initialize();
	this->map[0].m_AddressIdx = USER_PAGE_POOL_START_ADDR / PageManager::PAGE_SIZE;
	this->map[0].m_Size = USER_PAGE_POOL_SIZE / PageManager::PAGE_SIZE;
	this->bitmap.set(USER_PAGE_POOL_START_ADDR, USER_PAGE_POOL_SIZE / PageManager::PAGE_SIZE);
	return 0;
}

void UserPageManager::EvictOnePage()
{
	User& u = Kernel::Instance().GetUser();
	MemoryDescriptor& md = u.u_MemoryDescriptor;
	SwapperManager& swapMgr = Kernel::Instance().GetSwapperManager();
	BufferManager& bufMgr = Kernel::Instance().GetBufferManager();

	PageTable* hwPT = Machine::Instance().GetUserPageTableArray();
	PageTableEntry* hwEntrys = (PageTableEntry*)hwPT;
	PageTableEntry* softEntrys = (PageTableEntry*)md.m_UserPageTableArray;

	static unsigned int hand = 0;

	/* 第一轮：清除所有可写页的 Accessed 位 */
	for ( unsigned int i = 1; i < MemoryDescriptor::USER_SPACE_SIZE / PageManager::PAGE_SIZE; i++ )
		if ( hwEntrys[i].m_Present && hwEntrys[i].m_ReadWriter )
			hwEntrys[i].m_Accessed = 0;

	/* 第二轮：找到一个 Accessed==0 的受害者 */
	for ( unsigned int n = 0; n < MemoryDescriptor::USER_SPACE_SIZE / PageManager::PAGE_SIZE; n++ )
	{
		unsigned int i = (hand + n) % (MemoryDescriptor::USER_SPACE_SIZE / PageManager::PAGE_SIZE);
		if ( i == 0 ) continue;  /* 跳过 runtime 入口页 */
		if ( !hwEntrys[i].m_Present || !hwEntrys[i].m_ReadWriter ) continue;
		if ( hwEntrys[i].m_Accessed ) continue;

		unsigned int physFrame = hwEntrys[i].m_PageBaseAddress;

		if ( hwEntrys[i].m_Dirty )
		{
			int swapBlock = swapMgr.AllocSwap(PageManager::PAGE_SIZE);
			if ( swapBlock == 0 ) continue;  /* 交换区满，跳过此页 */
			bufMgr.Swap(swapBlock, (unsigned long)physFrame << 12, PageManager::PAGE_SIZE, Buf::B_WRITE);
			softEntrys[i].m_PageBaseAddress = swapBlock;
			softEntrys[i].m_ForSystemUser   = 1;
			Diagnose::Write("[VM] Evict dirty va=0x%x sw=%d\n", i << 12, swapBlock);
		}
		else
		{
			softEntrys[i].m_ForSystemUser = 0;
			Diagnose::Write("[VM] Evict clean va=0x%x\n", i << 12);
		}

		softEntrys[i].m_Present = 0;
		hwEntrys[i].m_Present   = 0;
		__asm__ __volatile__("invlpg (%0)" :: "r"(i << 12) : "memory");
		FreeMemory(PageManager::PAGE_SIZE, (unsigned long)physFrame << 12);
		hand = (i + 1) % (MemoryDescriptor::USER_SPACE_SIZE / PageManager::PAGE_SIZE);
		return;
	}
}
