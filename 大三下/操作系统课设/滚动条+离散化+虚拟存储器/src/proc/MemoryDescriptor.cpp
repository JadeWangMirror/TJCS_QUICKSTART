#include "MemoryDescriptor.h"
#include "Kernel.h"
#include "PageManager.h"
#include "Machine.h"
#include "PageDirectory.h"
#include "Video.h"

MemoryDescriptor::MemoryDescriptor()
	: m_UserPageTableArray(NULL),
	  m_TextStartAddress(0), m_TextSize(0),
	  m_DataStartAddress(0), m_DataSize(0),
	  m_StackSize(0),
	  m_VMList(NULL), m_VMCount(0)
{
}

MemoryDescriptor::~MemoryDescriptor()
{
}

void MemoryDescriptor::Initialize()
{
	KernelPageManager& kernelPageManager = Kernel::Instance().GetKernelPageManager();
	this->m_UserPageTableArray = (PageTable*)(kernelPageManager.AllocMemory(
		sizeof(PageTable) * USER_SPACE_PAGE_TABLE_CNT) + Machine::KERNEL_SPACE_START_ADDRESS);

	this->m_VMList = NULL;
	this->m_VMCount = 0;
}

void MemoryDescriptor::Release()
{
	KernelPageManager& kernelPageManager = Kernel::Instance().GetKernelPageManager();
	if ( this->m_UserPageTableArray )
	{
		kernelPageManager.FreeMemory(sizeof(PageTable) * USER_SPACE_PAGE_TABLE_CNT,
			(unsigned long)this->m_UserPageTableArray - Machine::KERNEL_SPACE_START_ADDRESS);
		this->m_UserPageTableArray = NULL;
	}
}

/* ---------- vm_area management ---------- */

VMArea* MemoryDescriptor::FindVMArea(unsigned long vaddr)
{
	VMArea* vma = this->m_VMList;
	while (vma != NULL)
	{
		if (vaddr >= vma->vm_start && vaddr < vma->vm_end)
			return vma;
		vma = vma->vm_next;
	}
	return NULL;
}

void MemoryDescriptor::AddVMArea(unsigned long start, unsigned long end, VMAType type,
                                  unsigned long foff, Inode* inode)
{
	if (this->m_VMCount >= 8)
		return;

	VMArea* vma = &this->m_VMAreas[this->m_VMCount++];
	vma->vm_start = start;
	vma->vm_end   = end;
	vma->vm_type  = type;
	vma->vm_foff  = foff;
	vma->vm_inode = inode;
	vma->vm_next  = this->m_VMList;
	this->m_VMList = vma;
}

void MemoryDescriptor::RemoveAllVMAreas()
{
	this->m_VMList  = NULL;
	this->m_VMCount = 0;
}

/* ---------- MapEntry ---------- */

unsigned int MemoryDescriptor::MapEntry(unsigned long virtualAddress, unsigned int size,
                                        unsigned long phyPageIdx, bool isReadWrite)
{
	unsigned long address  = virtualAddress - USER_SPACE_START_ADDRESS;
	unsigned long startIdx = address >> 12;
	unsigned long cnt      = (size + (PageManager::PAGE_SIZE - 1)) / PageManager::PAGE_SIZE;

	PageTableEntry* entrys = (PageTableEntry*)this->m_UserPageTableArray;
	for (unsigned int i = startIdx; i < startIdx + cnt; i++, phyPageIdx++)
	{
		entrys[i].m_Present        = 0x1;
		entrys[i].m_ReadWriter      = isReadWrite;
		entrys[i].m_PageBaseAddress = phyPageIdx;
	}
	return phyPageIdx;
}

void MemoryDescriptor::MapTextEntrys(unsigned long textStartAddress,
                                      unsigned long textSize, unsigned long textPageIdx)
{
	this->MapEntry(textStartAddress, textSize, textPageIdx, false);
}

void MemoryDescriptor::MapDataEntrys(unsigned long dataStartAddress,
                                      unsigned long dataSize, unsigned long dataPageIdx)
{
	this->MapEntry(dataStartAddress, dataSize, dataPageIdx, true);
}

void MemoryDescriptor::MapStackEntrys(unsigned long stackSize, unsigned long stackPageIdx)
{
	unsigned long stackStartAddress =
		(USER_SPACE_START_ADDRESS + USER_SPACE_SIZE - stackSize) & 0xFFFFF000;
	this->MapEntry(stackStartAddress, stackSize, stackPageIdx, true);
}

PageTable* MemoryDescriptor::GetUserPageTableArray() { return this->m_UserPageTableArray; }
unsigned long MemoryDescriptor::GetTextStartAddress() { return this->m_TextStartAddress; }
unsigned long MemoryDescriptor::GetTextSize()         { return this->m_TextSize; }
unsigned long MemoryDescriptor::GetDataStartAddress() { return this->m_DataStartAddress; }
unsigned long MemoryDescriptor::GetDataSize()         { return this->m_DataSize; }
unsigned long MemoryDescriptor::GetStackSize()        { return this->m_StackSize; }

/* ---------- EstablishUserPageTable ---------- */

bool MemoryDescriptor::EstablishUserPageTable(
	unsigned long textVirtualAddress, unsigned long textSize,
	unsigned long dataVirtualAddress, unsigned long dataSize,
	unsigned long stackSize, Inode* pExeInode)
{
	User& u = Kernel::Instance().GetUser();

	if (textSize + dataSize + stackSize + PageManager::PAGE_SIZE >
	    USER_SPACE_SIZE - textVirtualAddress)
	{
		u.u_error = User::ENOMEM;
		return false;
	}

	this->ClearUserPageTable();
	this->RemoveAllVMAreas();

	/* 设置 VMA 区域 */
	if (textSize > 0)
	{
		unsigned long textEnd = (textVirtualAddress + textSize + PageManager::PAGE_SIZE - 1)
		                        & ~(PageManager::PAGE_SIZE - 1);
		this->AddVMArea(textVirtualAddress, textEnd, VMA_TEXT, 0, pExeInode);
	}
	if (dataSize > 0)
	{
		unsigned long dataEnd = (dataVirtualAddress + dataSize + PageManager::PAGE_SIZE - 1)
		                        & ~(PageManager::PAGE_SIZE - 1);
		this->AddVMArea(dataVirtualAddress, dataEnd, VMA_DATA, 0, NULL);
	}
	if (stackSize > 0)
	{
		unsigned long stackStart =
			(USER_SPACE_START_ADDRESS + USER_SPACE_SIZE - stackSize) & 0xFFFFF000;
		this->AddVMArea(stackStart, USER_SPACE_START_ADDRESS + USER_SPACE_SIZE,
		                VMA_STACK, 0, NULL);
	}

	/*
	 * 文本段：先立即映射（Relocate 需要从内核态写文本页），
	 * Exec() 末尾会将其切为惰性按需调页。
	 */
	if (textSize > 0)
	{
		unsigned int textFrame = (u.u_procp->p_textp != NULL)
			? (u.u_procp->p_textp->x_caddr >> 12) : 0;
		this->MapEntry(textVirtualAddress, textSize, textFrame, false);
	}

	/* 数据段：立即映射 */
	if (dataSize > 0)
	{
		unsigned int dataFrame = (u.u_procp->p_addr >> 12) + 1;
		this->MapEntry(dataVirtualAddress, dataSize, dataFrame, true);
	}

	/* 栈：立即映射 */
	if (stackSize > 0)
	{
		unsigned long stackStartAddress =
			(USER_SPACE_START_ADDRESS + USER_SPACE_SIZE - stackSize) & 0xFFFFF000;
		unsigned int stackFrame = (u.u_procp->p_addr >> 12) + 1
			+ ((dataSize + PageManager::PAGE_SIZE - 1) >> 12);
		this->MapEntry(stackStartAddress, stackSize, stackFrame, true);
	}

	this->MapToPageTable();
	return true;
}

void MemoryDescriptor::ClearUserPageTable()
{
	PageTable* pUserPageTable = this->m_UserPageTableArray;
	if (pUserPageTable == NULL)
		return;

	unsigned int* p = (unsigned int*)pUserPageTable;
	unsigned int total = Machine::USER_PAGE_TABLE_CNT * PageTable::ENTRY_CNT_PER_PAGETABLE;
	for (unsigned int k = 0; k < total; k++)
		p[k] = 0;

	for (unsigned int i = 0; i < Machine::USER_PAGE_TABLE_CNT; i++)
		for (unsigned int j = 0; j < PageTable::ENTRY_CNT_PER_PAGETABLE; j++)
			pUserPageTable[i].m_Entrys[j].m_UserSupervisor = 1;
}

void MemoryDescriptor::DisplayPageTable()
{
	unsigned int i, j;

	Diagnose::Write("Process PT:");
	for (i = 0; i < Machine::USER_PAGE_TABLE_CNT; i++)
		for (j = 0; j < PageTable::ENTRY_CNT_PER_PAGETABLE; j++)
			if (1 == this->m_UserPageTableArray[i].m_Entrys[j].m_Present)
				Diagnose::Write("<%d,%x>  ", i*1024+j,
					this->m_UserPageTableArray[i].m_Entrys[j].m_PageBaseAddress);
	Diagnose::Write("\n");

	Diagnose::Write("<PPDA,%x>  ",
		Machine::Instance().GetKernelPageTable().m_Entrys[1023].m_PageBaseAddress);

	PageTable* pUserPageTable = Machine::Instance().GetUserPageTableArray();
	Diagnose::Write("System PT:");
	for (i = 0; i < Machine::USER_PAGE_TABLE_CNT; i++)
		for (j = 0; j < PageTable::ENTRY_CNT_PER_PAGETABLE; j++)
			if (1 == pUserPageTable[i].m_Entrys[j].m_Present)
				Diagnose::Write("<%d,%x>  ", i*1024+j,
					pUserPageTable[i].m_Entrys[j].m_PageBaseAddress);
	Diagnose::Write("\n");
}

void MemoryDescriptor::MapToPageTable()
{
	User& u = Kernel::Instance().GetUser();

	if (u.u_MemoryDescriptor.m_UserPageTableArray == NULL)
		return;

	PageTable* pUserPageTable = Machine::Instance().GetUserPageTableArray();

	for (unsigned int i = 0; i < Machine::USER_PAGE_TABLE_CNT; i++)
		for (unsigned int j = 0; j < PageTable::ENTRY_CNT_PER_PAGETABLE; j++)
		{
			pUserPageTable[i].m_Entrys[j] = this->m_UserPageTableArray[i].m_Entrys[j];
			pUserPageTable[i].m_Entrys[j].m_UserSupervisor = 1;
		}

	pUserPageTable[0].m_Entrys[0].m_Present        = 1;
	pUserPageTable[0].m_Entrys[0].m_ReadWriter      = 1;
	pUserPageTable[0].m_Entrys[0].m_PageBaseAddress = 0;

	FlushPageDirectory();
}
