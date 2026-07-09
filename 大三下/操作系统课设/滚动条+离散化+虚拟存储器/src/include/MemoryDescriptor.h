#ifndef MEMORY_DESCRIPTOR_H
#define MEMORY_DESCRIPTOR_H

#include "PageTable.h"
#include "VMArea.h"

class MemoryDescriptor
{
public:
	static const unsigned int USER_SPACE_SIZE           = 0x800000;
	static const unsigned int USER_SPACE_PAGE_TABLE_CNT = 0x2;
	static const unsigned long USER_SPACE_START_ADDRESS = 0x0;

public:
	MemoryDescriptor();
	~MemoryDescriptor();

public:
	void Initialize();
	void Release();

	void MapTextEntrys(unsigned long textStartAddress, unsigned long textSize, unsigned long textPageIdxInPhyMemory);
	void MapDataEntrys(unsigned long dataStartAddress, unsigned long dataSize, unsigned long dataPageIdxInPhyMemory);
	void MapStackEntrys(unsigned long stackSize, unsigned long stackPageIdxInPhyMemory);

	void MapToPageTable();
	void DisplayPageTable();

	bool EstablishUserPageTable(unsigned long textVirtualAddress, unsigned long textSize,
	                             unsigned long dataVirtualAddress, unsigned long dataSize,
	                             unsigned long stackSize, Inode* pExeInode);
	void ClearUserPageTable();
	PageTable* GetUserPageTableArray();
	unsigned long GetTextStartAddress();
	unsigned long GetTextSize();
	unsigned long GetDataStartAddress();
	unsigned long GetDataSize();
	unsigned long GetStackSize();

	/* vm_area: 遍历链表查找 cr2 所属区域 */
	VMArea* FindVMArea(unsigned long vaddr);
	void    AddVMArea(unsigned long start, unsigned long end, VMAType type,
	                   unsigned long foff, Inode* inode);
	void    RemoveAllVMAreas();

private:
	unsigned int MapEntry(unsigned long virtualAddress, unsigned int size,
	                      unsigned long phyPageIdx, bool isReadWrite);

public:
	PageTable*    m_UserPageTableArray;
	unsigned long m_TextStartAddress;
	unsigned long m_TextSize;
	unsigned long m_DataStartAddress;
	unsigned long m_DataSize;
	unsigned long m_StackSize;

	VMArea*       m_VMList;

private:
	VMArea        m_VMAreas[8];
	int           m_VMCount;
};

#endif
