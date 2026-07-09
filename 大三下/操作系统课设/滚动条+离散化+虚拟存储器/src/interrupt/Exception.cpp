#include "Exception.h"
#include "Kernel.h"
#include "Utility.h"
#include "Video.h"
#include "Machine.h"
#include "HashTable.h"
#include "VMArea.h"

#define IMPLEMENT_EXCEPTION_ENTRANCE(Exception_Entrance, Exception_Handler) \
void Exception::Exception_Entrance() \
{ \
	SaveContext();			\
\
	SwitchToKernel();		\
\
	CallHandler(Exception, Exception_Handler);	\
\
	RestoreContext();		\
\
	Leave();				\
\
	InterruptReturn();		\
}

#define IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(Exception_Entrance, Exception_Handler) \
void Exception::Exception_Entrance() \
{ \
	SaveContext();			\
\
	SwitchToKernel();		\
\
	CallHandler(Exception, Exception_Handler);	\
\
	RestoreContext();		\
\
	Leave();				\
\
	__asm__ __volatile__("addl $4, %%esp" ::);	\
\
	InterruptReturn();		\
}

#define IMPLEMENT_EXCEPTION_HANDLER(Exception_Handler, Error_Message, Signal_Value) \
void Exception::Exception_Handler(struct pt_regs* regs, struct pt_context* context) \
{	\
	User& u = Kernel::Instance().GetUser();			\
	Process* current = u.u_procp;					\
\
	if ( (context->xcs & USER_MODE) == USER_MODE )	\
	{												\
		current->PSignal(Signal_Value);				\
		if ( current->IsSig() )						\
			current->PSig(context);					\
	}												\
	else											\
	{												\
		Utility::Panic(Error_Message);				\
	}												\
}

#define IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(Exception_Handler, Error_Message, Signal_Value) \
void Exception::Exception_Handler(struct pt_regs* regs, struct pte_context* context) \
{	\
	User& u = Kernel::Instance().GetUser();			\
	Process* current = u.u_procp;					\
\
	if ( (context->xcs & USER_MODE) == USER_MODE )	\
	{												\
		current->PSignal(Signal_Value);				\
		if ( current->IsSig() )						\
			current->PSig( (pt_context *)&context->eip );		\
	}												\
	else											\
	{												\
		Utility::Panic(Error_Message);				\
	}												\
}


Exception::Exception()
{
}

Exception::~Exception()
{
}


IMPLEMENT_EXCEPTION_ENTRANCE(DivideErrorEntrance, DivideError)
IMPLEMENT_EXCEPTION_HANDLER(DivideError, "Divide Exception!", User::SIGFPE)

IMPLEMENT_EXCEPTION_ENTRANCE(DebugEntrance, Debug)
IMPLEMENT_EXCEPTION_HANDLER(Debug, "Debug Exception!", User::SIGTRAP)

IMPLEMENT_EXCEPTION_ENTRANCE(NMIEntrance, NMI)
IMPLEMENT_EXCEPTION_HANDLER(NMI, "Non-maskable Interrupt!", User::SIGNUL)

IMPLEMENT_EXCEPTION_ENTRANCE(BreakpointEntrance, Breakpoint)
IMPLEMENT_EXCEPTION_HANDLER(Breakpoint, "Breakpoint Exception!", User::SIGTRAP)

IMPLEMENT_EXCEPTION_ENTRANCE(OverflowEntrance, Overflow)
IMPLEMENT_EXCEPTION_HANDLER(Overflow, "Overflow Exception!", User::SIGSEGV)

IMPLEMENT_EXCEPTION_ENTRANCE(BoundEntrance, Bound)
IMPLEMENT_EXCEPTION_HANDLER(Bound, "Bound Range Exceeded!", User::SIGSEGV)

IMPLEMENT_EXCEPTION_ENTRANCE(InvalidOpcodeEntrance, InvalidOpcode)
IMPLEMENT_EXCEPTION_HANDLER(InvalidOpcode, "Invalid Opcode!", User::SIGILL)

IMPLEMENT_EXCEPTION_ENTRANCE(DeviceNotAvailableEntrance, DeviceNotAvailable)
IMPLEMENT_EXCEPTION_HANDLER(DeviceNotAvailable, "Device Not Available!", User::SIGSEGV)

IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(DoubleFaultEntrance, DoubleFault)
IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(DoubleFault, "Double Fault Exception!", User::SIGSEGV)

IMPLEMENT_EXCEPTION_ENTRANCE(CoprocessorSegmentOverrunEntrance, CoprocessorSegmentOverrun)
IMPLEMENT_EXCEPTION_HANDLER(CoprocessorSegmentOverrun, "Coprocessor Segment Overrun!", User::SIGFPE)

IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(InvalidTSSEntrance, InvalidTSS)
IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(InvalidTSS, "Invalid TSS!", User::SIGSEGV)

IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(SegmentNotPresentEntrance, SegmentNotPresent)
IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(SegmentNotPresent, "Segment Not Present!", User::SIGBUS)

IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(StackSegmentErrorEntrance, StackSegmentError)
IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(StackSegmentError, "Stack Segment Error!", User::SIGBUS)

IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(GeneralProtectionEntrance, GeneralProtection)
IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(GeneralProtection, "General Protection!", User::SIGSEGV)


// 缺页异常 (INT 14)  *有错误码*
IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(PageFaultEntrance, PageFault)

void Exception::PageFault(struct pt_regs* regs, struct pte_context* context)
{
	User& u = Kernel::Instance().GetUser();
	Process* current = u.u_procp;
	MemoryDescriptor& md = u.u_MemoryDescriptor;
	UserPageManager& userPageMgr = Kernel::Instance().GetUserPageManager();

	unsigned int cr2;
	__asm__ __volatile__(" mov %%cr2, %0":"=r"(cr2) );

	if ( (context->xcs & USER_MODE) != USER_MODE )
		Utility::Panic("Page Fault in Kernel Mode.");

	unsigned int vPageIdx = cr2 >> 12;
	PageTableEntry* entrys = (PageTableEntry*)md.m_UserPageTableArray;
	PageTableEntry* hwEntrys = (PageTableEntry*)Machine::Instance().GetUserPageTableArray();

	/* --- 0#: 遍历 vm_area 验证地址合法性 --- */
	VMArea* vma = md.FindVMArea(cr2);

	/* --- 分支 A: COW 写故障 --- */
	if ( (context->error_code & 0x2) &&
		 entrys[vPageIdx].m_Present && !entrys[vPageIdx].m_ReadWriter &&
		 ( (cr2 >= md.m_DataStartAddress && cr2 < md.m_DataStartAddress + md.m_DataSize) ||
		   (cr2 >= MemoryDescriptor::USER_SPACE_SIZE - md.m_StackSize) ) &&
		 userPageMgr.Page[entrys[vPageIdx].m_PageBaseAddress] >= 1 )
	{
		unsigned int oldFrame = entrys[vPageIdx].m_PageBaseAddress;
		if ( userPageMgr.Page[oldFrame] == 1 )
		{
			entrys[vPageIdx].m_ReadWriter = 1;
			hwEntrys[vPageIdx].m_ReadWriter = 1;
		}
		else
		{
			unsigned long newAddr = userPageMgr.AllocMemory(PageManager::PAGE_SIZE);
			if ( newAddr == 0 ) { userPageMgr.EvictOnePage(); newAddr = userPageMgr.AllocMemory(PageManager::PAGE_SIZE); }
			if ( newAddr == 0 ) goto sigsegv;

			KernelPageManager& kpm = Kernel::Instance().GetKernelPageManager();
			unsigned long tmpPage = kpm.AllocMemory(PageManager::PAGE_SIZE);
			if ( tmpPage == 0 ) { userPageMgr.FreeMemory(PageManager::PAGE_SIZE, newAddr); goto sigsegv; }

			unsigned long userVA = cr2 & 0xFFFFF000;
			Utility::DWordCopy((int*)userVA,
			                  (int*)(tmpPage | Machine::KERNEL_SPACE_START_ADDRESS),
			                  PageManager::PAGE_SIZE / sizeof(int));

			hwEntrys[vPageIdx].m_Present       = 1;
			hwEntrys[vPageIdx].m_ReadWriter     = 1;
			hwEntrys[vPageIdx].m_UserSupervisor = 1;
			hwEntrys[vPageIdx].m_PageBaseAddress = newAddr >> 12;
			__asm__ __volatile__("invlpg (%0)" :: "r"((void*)userVA) : "memory");

			Utility::DWordCopy((int*)(tmpPage | Machine::KERNEL_SPACE_START_ADDRESS),
			                  (int*)userVA,
			                  PageManager::PAGE_SIZE / sizeof(int));

			kpm.FreeMemory(PageManager::PAGE_SIZE, tmpPage);

			entrys[vPageIdx].m_PageBaseAddress  = newAddr >> 12;
			entrys[vPageIdx].m_ReadWriter        = 1;
			userPageMgr.Page[newAddr >> 12]      = 1;
			userPageMgr.Page[oldFrame]--;
		}
		__asm__ __volatile__("invlpg (%0)" :: "r"(cr2) : "memory");
		return;
	}

	/* --- 分支 B: 栈扩展 --- */
	if ( cr2 < MemoryDescriptor::USER_SPACE_SIZE - md.m_StackSize &&
		 cr2 >= context->esp - 8 &&
		 md.m_DataSize + md.m_StackSize + PageManager::PAGE_SIZE <
		     MemoryDescriptor::USER_SPACE_SIZE - md.m_DataStartAddress )
	{
		current->SStack();
		return;
	}

	/* --- 分支 C: 请求调页（数据/堆首次访问） --- */
	if ( !entrys[vPageIdx].m_Present &&
	     vma != NULL && (vma->vm_type == VMA_DATA || vma->vm_type == VMA_HEAP) )
	{
		unsigned long frame = userPageMgr.AllocMemory(PageManager::PAGE_SIZE);
		if ( frame == 0 ) { userPageMgr.EvictOnePage(); frame = userPageMgr.AllocMemory(PageManager::PAGE_SIZE); }
		if ( frame == 0 ) goto sigsegv;

		bool wasSwapped = (entrys[vPageIdx].m_ForSystemUser & 1) != 0;

		if ( wasSwapped )
		{
			unsigned int swapBlock = entrys[vPageIdx].m_PageBaseAddress;
			Kernel::Instance().GetBufferManager().Swap(swapBlock, frame, PageManager::PAGE_SIZE, Buf::B_READ);
			Kernel::Instance().GetSwapperManager().FreeSwap(PageManager::PAGE_SIZE, swapBlock);
			Diagnose::Write("[VM] SwapIn va=0x%x sw=%d\n", cr2, swapBlock);
		}

		entrys[vPageIdx].m_Present        = 1;
		entrys[vPageIdx].m_ReadWriter      = 1;
		entrys[vPageIdx].m_UserSupervisor  = 1;
		entrys[vPageIdx].m_PageBaseAddress = frame >> 12;
		entrys[vPageIdx].m_ForSystemUser   = 0;
		userPageMgr.Page[frame >> 12]      = 1;
		hwEntrys[vPageIdx] = entrys[vPageIdx];
		__asm__ __volatile__("invlpg (%0)" :: "r"(cr2) : "memory");

		if ( !wasSwapped )
		{
			/* 数据段/堆首次访问：零填充。堆段按设计可不清零，此处兼容处理 */
			unsigned int* ptr = (unsigned int*)(cr2 & 0xFFFFF000);
			for ( unsigned int k = 0; k < PageManager::PAGE_SIZE / 4; k++ ) ptr[k] = 0;
			Diagnose::Write("[VM] ZeroFill va=0x%x\n", cr2);
		}
		return;
	}

	/* --- 分支 D: 文本段按需调页（通过哈希表共享） --- */
	if ( !entrys[vPageIdx].m_Present && (entrys[vPageIdx].m_ForSystemUser & 2) &&
	     vma != NULL && vma->vm_type == VMA_TEXT && vma->vm_inode != NULL )
	{
		unsigned int filePage  = entrys[vPageIdx].m_PageBaseAddress; /* 文件内页号 */
		Inode*       inode     = vma->vm_inode;
		HashTable&   ht        = Kernel::Instance().GetHashTable();

		HashEntry* he = ht.Lookup(inode, filePage);
		if ( he != NULL )
		{
			/* 共享已有物理帧 */
			entrys[vPageIdx].m_Present        = 1;
			entrys[vPageIdx].m_ReadWriter      = 0;
			entrys[vPageIdx].m_UserSupervisor  = 1;
			entrys[vPageIdx].m_PageBaseAddress = he->h_frame;
			entrys[vPageIdx].m_ForSystemUser   = 0;
			hwEntrys[vPageIdx] = entrys[vPageIdx];
			ht.AddRef(inode, filePage);
			__asm__ __volatile__("invlpg (%0)" :: "r"(cr2) : "memory");
			Diagnose::Write("[VM] TextShare va=0x%x fp=%d frame=0x%x ref=%d\n",
			                cr2, filePage, he->h_frame, he->h_refCount);
			return;
		}
		else
		{
			/* Hash miss: text should have been inserted at Exec. */
			Diagnose::Write("[VM] TextMiss! inode=0x%x fp=%d\n",
			 (unsigned int)inode, filePage);
			goto sigsegv;
		}

	}

sigsegv:
	Diagnose::Write("Invalid MM access va=0x%x\n", cr2);
	current->PSignal(User::SIGSEGV);
	if ( current->IsSig() )
		current->PSig((pt_context *)&context->eip);
}


IMPLEMENT_EXCEPTION_ENTRANCE(CoprocessorErrorEntrance, CoprocessorError)
IMPLEMENT_EXCEPTION_HANDLER(CoprocessorError, "Coprocessor Error!", User::SIGFPE)

IMPLEMENT_EXCEPTION_ENTRANCE_ERRCODE(AlignmentCheckEntrance, AlignmentCheck)
IMPLEMENT_EXCEPTION_HANDLER_ERRCODE(AlignmentCheck, "Alignment Check!", User::SIGBUS)

IMPLEMENT_EXCEPTION_ENTRANCE(MachineCheckEntrance, MachineCheck)
IMPLEMENT_EXCEPTION_HANDLER(MachineCheck, "Machine Check!", User::SIGNUL)

IMPLEMENT_EXCEPTION_ENTRANCE(SIMDExceptionEntrance, SIMDException)
IMPLEMENT_EXCEPTION_HANDLER(SIMDException, "SIMD Float Point Exception!", User::SIGFPE)
