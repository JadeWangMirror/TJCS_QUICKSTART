#include "Process.h"
#include "ProcessManager.h"
#include "Kernel.h"
#include "Utility.h"
#include "Machine.h"
#include "Video.h"


Process::Process()
{
	/* ��ʶ����p_statΪSNULL����ʶ�ý��������ʹ�� */
	this->p_stat = SNULL;
	/* ����0#������Wait()ʱ���������process����0#����Ϊ������ */
	this->p_ppid = -1;
}

Process::~Process()
{
}


void Process::SetRun()
{
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();

	/* ���˯��ԭ��תΪ����״̬ */
	this->p_wchan = 0;
	this->p_stat = Process::SRUN;
	if ( this->p_pri < procMgr.CurPri )
	{
		procMgr.RunRun++;
	}
	if ( 0 != procMgr.RunOut && (this->p_flag & Process::SLOAD) == 0 )
	{
		procMgr.RunOut = 0;
		procMgr.WakeUpAll((unsigned long)&procMgr.RunOut);
	}
}

void Process::SetPri()
{
	int priority;
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();

	priority = this->p_cpu / 16;
	priority += ProcessManager::PUSER + this->p_nice;

	if ( priority > 255 )
	{
		priority = 255;
	}
	if ( priority > procMgr.CurPri )
	{
		procMgr.RunRun++;
	}
	this->p_pri = priority;
}

bool Process::IsSleepOn(unsigned long chan)
{
	/* ��鵱ǰ����˯��ԭ���Ƿ�Ϊchan */
	if( this->p_wchan == chan 
		&& (this->p_stat == Process::SWAIT || this->p_stat == Process::SSLEEP) )
	{
		return true;
	}
	return false;
}

void Process::Sleep(unsigned long chan, int pri)
{
	User& u = Kernel::Instance().GetUser();
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();

	if ( pri > 0 )
	{
		/* 
		 * �����ڽ��������Ȩ˯��֮ǰ���Լ�������֮��������յ����ɺ���
		 * ���źţ���ִֹͣ��Sleep()��ͨ��aRetU()ֱ����ת��Trap1()����
		 */
		if ( this->IsSig() )
		{
			/* returnȷ��aRetU()���ص�SystemCall::Trap1()֮������ִ��ret����ָ�� */
			aRetU(u.u_qsav);
			return;
		}
		/* 
		* �˴����жϽ����ٽ�������֤����������˯��ԭ��chan��
		* �Ľ���״̬ΪSSLEEP֮�䲻�ᷢ���л���
		*/
		X86Assembly::CLI();
		this->p_wchan = chan;
		/* ����˯�����ȼ�priȷ�����̽���ߡ�������Ȩ˯�� */
		this->p_stat = Process::SWAIT;
		this->p_pri = pri;
		X86Assembly::STI();

		if ( procMgr.RunIn != 0 )
		{
			procMgr.RunIn = 0;
			procMgr.WakeUpAll((unsigned long)&procMgr.RunIn);
		}
		/* ��ǰ���̷���CPU���л�����������̨ */
		//Diagnose::Write("Process %d Start Sleep!\n", this->p_pid);
		Kernel::Instance().GetProcessManager().Swtch();
		//Diagnose::Write("Process %d End Sleep!\n", this->p_pid);
		/* ������֮���ٴμ���ź� */
		if ( this->IsSig() )
		{
			/* returnȷ��aRetU()���ص�SystemCall::Trap1()֮������ִ��ret����ָ�� */
			aRetU(u.u_qsav);
			return;
		}
	}
	else
	{
		X86Assembly::CLI();
		this->p_wchan = chan;
		/* ����˯�����ȼ�priȷ�����̽���ߡ�������Ȩ˯�� */
		this->p_stat = Process::SSLEEP;
		this->p_pri = pri;
		X86Assembly::STI();

		/* ��ǰ���̷���CPU���л�����������̨ */
		//Diagnose::Write("Process %d Start Sleep!\n", this->p_pid);
		Kernel::Instance().GetProcessManager().Swtch();
		//Diagnose::Write("Process %d End Sleep!\n", this->p_pid);
	}
}

void Process::Expand(unsigned int newSize)
{
	UserPageManager& userPgMgr = Kernel::Instance().GetUserPageManager();
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	User& u = Kernel::Instance().GetUser();
	Process* pProcess = u.u_procp;

	unsigned int oldSize = pProcess->p_size;
	p_size = newSize;
	unsigned long oldAddress = pProcess->p_addr;
	unsigned long newAddress;

	/* �������ͼ����С�����ͷŶ�����ڴ� */
	if ( oldSize >= newSize )
	{
		if(oldSize > newSize)
			userPgMgr.FreeMemory(oldSize - newSize, oldAddress + newSize);
		return;
	}

	/* ����ͼ��������ҪѰ��һ���СnewSize�������ڴ��� */
	SaveU(u.u_rsav);
	newAddress = userPgMgr.AllocMemory(newSize);
	/* �����ڴ�ʧ�ܣ���������ʱ�������������� */
	if ( NULL == newAddress )
	{
		SaveU(u.u_ssav);
		procMgr.XSwap(pProcess, true, oldSize);
		pProcess->p_flag |= Process::SSWAP;
		procMgr.Swtch();
		/* no return */
	}
	/* �����ڴ�ɹ���������ͼ�񿽱������ڴ�����Ȼ����ת�����ڴ����������� */
	pProcess->p_addr = newAddress;
	for ( unsigned int i = 0; i < oldSize; i++ )
	{
		Utility::CopySeg(oldAddress + i, newAddress + i);
	}

	/* �ͷ�ԭ��ռ�õ��ڴ��� */
	userPgMgr.FreeMemory(oldSize, oldAddress);
	
	X86Assembly::CLI();
	SwtchUStruct(pProcess);
	RetU();
	X86Assembly::STI();

	u.u_MemoryDescriptor.MapToPageTable();
}

void Process::Exit()
{
	int i;
	User& u = Kernel::Instance().GetUser();
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	OpenFileTable& fileTable = *Kernel::Instance().GetFileManager().m_OpenFileTable;
	InodeTable& inodeTable = *Kernel::Instance().GetFileManager().m_InodeTable;

	Diagnose::Write("Process %d is exiting\n",u.u_procp->p_pid);
	/* Reset Tracing flag */
	u.u_procp->p_flag &= (~Process::STRC);

	/* ������̵��źŴ�������������Ϊ1��ʾ���Ը��ź����κδ��� */
	for ( i = 0; i < User::NSIG; i++ )
	{
		u.u_signal[i] = 1;
	}

	/* �رս��̴��ļ� */
	for ( i = 0; i < OpenFiles::NOFILES; i++ )
	{
		File* pFile = NULL;
		if ( (pFile = u.u_ofiles.GetF(i)) != NULL )
		{
			fileTable.CloseF(pFile);
			u.u_ofiles.SetF(i, NULL);
		}
	}
	/*  ���ʲ����ڵ�fd�����error code�����u.u_error����Ӱ���������ִ������ */
	u.u_error = User::NOERROR;

	/* �ݼ���ǰĿ¼�����ü��� */
	inodeTable.IPut(u.u_cdir);

	/* �ͷŸý��̶Թ������Ķε����� */
	if ( u.u_procp->p_textp != NULL )
	{
		u.u_procp->p_textp->XFree();
		u.u_procp->p_textp = NULL;
	}

	/* ��u��д�뽻�������ȴ����������ƺ��� */
	SwapperManager& swapperMgr = Kernel::Instance().GetSwapperManager();
	BufferManager& bufMgr = Kernel::Instance().GetBufferManager();
	/* u���Ĵ�С���ᳬ��512�ֽڣ�����ֻд��ppda����ǰ512�ֽڣ�������u�ṹ��ȫ����Ϣ */
	int blkno = swapperMgr.AllocSwap(BufferManager::BUFFER_SIZE);
	if ( NULL == blkno )
	{
		Utility::Panic("Out of Swapper Space");
	}
	Buf* pBuf = bufMgr.GetBlk(DeviceManager::ROOTDEV, blkno);
	Utility::DWordCopy((int *)&u, (int *)pBuf->b_addr, BufferManager::BUFFER_SIZE / sizeof(int));
	bufMgr.Bwrite(pBuf);

	/* 逐页释放数据段和栈区的物理帧 */
	{
		MemoryDescriptor& md2 = u.u_MemoryDescriptor;
		UserPageManager& userPageMgr2 = Kernel::Instance().GetUserPageManager();
		SwapperManager& swapMgr2 = Kernel::Instance().GetSwapperManager();
		PageTableEntry* entrys = (PageTableEntry*)md2.m_UserPageTableArray;

		unsigned int dataStart = md2.m_DataStartAddress >> 12;
		unsigned int dataEnd   = (md2.m_DataStartAddress + md2.m_DataSize) >> 12;
		for ( unsigned int i = dataStart; i < dataEnd; i++ )
		{
			if ( entrys[i].m_Present )
				userPageMgr2.FreeMemory(PageManager::PAGE_SIZE, (unsigned long)entrys[i].m_PageBaseAddress << 12);
			else if ( entrys[i].m_ForSystemUser & 1 )
				swapMgr2.FreeSwap(PageManager::PAGE_SIZE, entrys[i].m_PageBaseAddress);
		}

		unsigned int stkStart = (MemoryDescriptor::USER_SPACE_SIZE - md2.m_StackSize) >> 12;
		unsigned int stkEnd   = MemoryDescriptor::USER_SPACE_SIZE >> 12;
		for ( unsigned int i = stkStart; i < stkEnd; i++ )
		{
			if ( entrys[i].m_Present )
				userPageMgr2.FreeMemory(PageManager::PAGE_SIZE, (unsigned long)entrys[i].m_PageBaseAddress << 12);
			else if ( entrys[i].m_ForSystemUser & 1 )
				swapMgr2.FreeSwap(PageManager::PAGE_SIZE, entrys[i].m_PageBaseAddress);
		}
	}

	/* 清理文本段哈希表引用 */
	{
		VMArea* vma = u.u_MemoryDescriptor.m_VMList;
		HashTable& ht = Kernel::Instance().GetHashTable();
		while (vma != NULL)
		{
			if (vma->vm_type == VMA_TEXT && vma->vm_inode != NULL)
			{
				unsigned int textPages = ((vma->vm_end - vma->vm_start) + PageManager::PAGE_SIZE - 1) >> 12;
				for (unsigned int tp = 0; tp < textPages; tp++)
					ht.Release(vma->vm_inode, tp);
			}
			vma = vma->vm_next;
		}
	}

	/* 释放内存描述符（软件页表）和 PPDA 物理帧 */
	u.u_MemoryDescriptor.Release();
	Process* current = u.u_procp;
	UserPageManager& userPageMgr = Kernel::Instance().GetUserPageManager();
	userPageMgr.FreeMemory(PageManager::PAGE_SIZE, current->p_addr);  /* 仅释放 PPDA */
	current->p_addr = blkno;
	current->p_stat = Process::SZOMB;

	/* ���Ѹ����̽����ƺ��� */
	for ( i = 0; i < ProcessManager::NPROC; i++ )
	{
		if ( procMgr.process[i].p_pid == current->p_ppid )
		{
			procMgr.WakeUpAll((unsigned long)&procMgr.process[i]);
			break;
		}
	}
	/* û�ҵ������� */
	if ( ProcessManager::NPROC == i )
	{
		current->p_ppid = 1;
		procMgr.WakeUpAll((unsigned long)&procMgr.process[1]);
	}

	/* ���Լ����ӽ��̴����Լ��ĸ����� */
	for ( i = 0; i < ProcessManager::NPROC; i++ )
	{
		if ( current->p_pid == procMgr.process[i].p_ppid )
		{
			Diagnose::Write("My:%d 's child %d passed to 1#process",current->p_pid,procMgr.process[i].p_pid);
			procMgr.process[i].p_ppid = 1;
			if ( procMgr.process[i].p_stat == Process::SSTOP )
			{
				procMgr.process[i].SetRun();
			}
		}
	}

	procMgr.Swtch();
}

void Process::Clone(Process& proc)
{
	User& u = Kernel::Instance().GetUser();

	/* ����������Process�ṹ�еĴ󲿷����� */
	proc.p_size = this->p_size;
	proc.p_stat = Process::SRUN;
	proc.p_flag = Process::SLOAD;
	proc.p_uid = this->p_uid;
	proc.p_ttyp = this->p_ttyp;
	proc.p_nice = this->p_nice;
	proc.p_textp = this->p_textp;
	
	/* �������ӹ�ϵ */
	proc.p_pid = ProcessManager::NextUniquePid();
	proc.p_ppid = this->p_pid;
	
	/* ��ʼ�����̵�����س�Ա */
	proc.p_pri = 0;		/* ȷ��child����������С��������������ȸ��л���ռ��CPU */
	proc.p_time = 0;
	

	/* ���ļ����ƿ�File�ṹ���ü���+1 */
	for ( int i = 0; i < OpenFiles::NOFILES; i++ )
	{
		File* pFile;
		if ( (pFile = u.u_ofiles.GetF(i)) != NULL )
		{
			pFile->f_count++;
		}
	}
	/* 
	 * GetF()����u.u_ofiles�еĿ��������������룬
	 * �粻��������½��̴���(fork)ϵͳ����ʧ�ܡ�
	 */
	u.u_error = User::NOERROR;

	/* ���ӶԹ������Ķε����ü��� */
	if ( proc.p_textp != 0 )
	{
		proc.p_textp->x_count++;
		proc.p_textp->x_ccount++;
	}

	/* ���ӶԵ�ǰ����Ŀ¼�����ü��� */
	u.u_cdir->i_count++;
}

void Process::SStack()
{
	User& u = Kernel::Instance().GetUser();
	MemoryDescriptor& md = u.u_MemoryDescriptor;
	UserPageManager& userPageMgr = Kernel::Instance().GetUserPageManager();

	md.m_StackSize += PageManager::PAGE_SIZE;

	if ( md.m_DataSize + md.m_StackSize + PageManager::PAGE_SIZE >
		 MemoryDescriptor::USER_SPACE_SIZE - md.m_DataStartAddress )
	{
		md.m_StackSize -= PageManager::PAGE_SIZE;
		u.u_error = User::ENOMEM;
		return;
	}

	unsigned long frame = userPageMgr.AllocMemory(PageManager::PAGE_SIZE);
	if ( frame == 0 )
	{
		md.m_StackSize -= PageManager::PAGE_SIZE;
		u.u_error = User::ENOMEM;
		return;
	}

	/* 先写软件 PTE，然后 MapToPageTable 建立硬件映射 */
	unsigned int vPageIdx = (MemoryDescriptor::USER_SPACE_SIZE - md.m_StackSize) >> 12;
	PageTableEntry* entrys = (PageTableEntry*)md.m_UserPageTableArray;
	entrys[vPageIdx].m_Present       = 1;
	entrys[vPageIdx].m_ReadWriter     = 1;
	entrys[vPageIdx].m_UserSupervisor = 1;
	entrys[vPageIdx].m_PageBaseAddress = frame >> 12;

	this->p_size += PageManager::PAGE_SIZE;

	/* 扩展栈 VMArea */
	unsigned long newStackStart = MemoryDescriptor::USER_SPACE_SIZE - md.m_StackSize;
	VMArea* svma = md.FindVMArea(newStackStart + PageManager::PAGE_SIZE);
	if (svma != NULL && svma->vm_type == VMA_STACK)
		svma->vm_start = newStackStart;

	u.u_MemoryDescriptor.MapToPageTable();

	/* 页表已建立，通过用户虚拟地址零填充 */
	unsigned int* ptr = (unsigned int*)(newStackStart);
	for ( unsigned int k = 0; k < PageManager::PAGE_SIZE / 4; k++ ) ptr[k] = 0;
}


void Process::SBreak()
{
	User& u = Kernel::Instance().GetUser();
	unsigned int newEnd = u.u_arg[0];
	MemoryDescriptor& md = u.u_MemoryDescriptor;
	UserPageManager& userPageMgr = Kernel::Instance().GetUserPageManager();

	if (newEnd == 0)
	{
		u.u_ar0[User::EAX] = md.m_DataStartAddress + md.m_DataSize;
		return;
	}

	unsigned int newSize = newEnd - md.m_DataStartAddress;
	int change = (int)newSize - (int)md.m_DataSize;

	if ( newSize + md.m_StackSize + PageManager::PAGE_SIZE >
		 MemoryDescriptor::USER_SPACE_SIZE - md.m_DataStartAddress )
	{
		u.u_error = User::ENOMEM;
		return;
	}

	PageTableEntry* entrys = (PageTableEntry*)md.m_UserPageTableArray;

	if ( change < 0 )
	{
		/* 收缩：逐页释放物理帧并清零 PTE */
		unsigned int freeStart = (md.m_DataStartAddress + newSize) >> 12;
		unsigned int freeEnd   = (md.m_DataStartAddress + md.m_DataSize) >> 12;
		for ( unsigned int i = freeStart; i < freeEnd; i++ )
		{
			if ( entrys[i].m_Present )
			{
				userPageMgr.FreeMemory(PageManager::PAGE_SIZE, (unsigned long)entrys[i].m_PageBaseAddress << 12);
				entrys[i].m_Present = 0;
				entrys[i].m_PageBaseAddress = 0;
			}
		}
		/* 收缩或移除堆 VMArea */
		{
			unsigned long oldHeapStart = md.m_DataStartAddress + newSize; /* 新堆起点 */
			VMArea* hvma = md.FindVMArea(oldHeapStart);
			if (hvma != NULL && hvma->vm_type == VMA_HEAP)
			{
				if (newSize <= (unsigned int)(hvma->vm_start - md.m_DataStartAddress))
					hvma->vm_start = 0; /* 标记无效 */
				else
					hvma->vm_start = md.m_DataStartAddress + newSize;
			}
		}
		md.m_DataSize = newSize;
		u.u_MemoryDescriptor.MapToPageTable();
	}
	else if ( change > 0 )
	{
		/* 扩展：惰性，仅更新元数据，物理页在缺页时按需分配 */
		unsigned long oldEnd = md.m_DataStartAddress + md.m_DataSize;
		md.m_DataSize = newSize;
		unsigned long newEnd = md.m_DataStartAddress + newSize;
		/* 扩展堆 VMArea */
		VMArea* hvma = md.FindVMArea(oldEnd > 0 ? oldEnd - 1 : oldEnd);
		if (hvma != NULL && hvma->vm_type == VMA_HEAP)
			hvma->vm_end = (newEnd + PageManager::PAGE_SIZE - 1) & ~(PageManager::PAGE_SIZE - 1);
		else
			md.AddVMArea(oldEnd, (newEnd + PageManager::PAGE_SIZE - 1) & ~(PageManager::PAGE_SIZE - 1),
			             VMA_HEAP, 0, NULL);
	}

	u.u_ar0[User::EAX] = md.m_DataStartAddress + md.m_DataSize;
}

void Process::PSignal( int signal )
{
	if ( signal >= User::NSIG )
	{
		return;
	}

	/* ����Ѿ����յ�SIGKILL�źţ�����Ժ����ź� */
	if ( this->p_sig != User::SIGKILL )
	{
		this->p_sig = signal;
	}
	/* �����̵�����������PUSER(100)����������ΪPUSER */
	if ( this->p_pri > ProcessManager::PUSER )
	{
		this->p_pri	= ProcessManager::PUSER;
	}
	/* �����̵Ĵ��ڵ�����Ȩ˯�ߣ����份�� */
	if ( this->p_stat == Process::SWAIT )
	{
		this->SetRun();
	}
}

int Process::IsSig()
{
	User& u = Kernel::Instance().GetUser();

	/* δ���ܵ��ź� */
	if ( this->p_sig == 0 )
	{
		return 0;
	}
	/* u.u_signal[n]Ϊż���ű�ʾ���źŽ��̴��� */
	else if ( (u.u_signal[this->p_sig] & 1) == 0 )
	{
		return this->p_sig;
	}
	return 0;
}

/*
extern "C" void runtime();
extern "C" void SignalHandler();
*/

void Process::PSig(struct pt_context* pContext)
{
	User& u = Kernel::Instance().GetUser();
	int signal = this->p_sig;
	/* ����ѽ��봦�����̵��ź� */
	this->p_sig = 0;

	if ( u.u_signal[signal] != 0 )
	{
		/* ����������յ��ź�֮ǰִ��ϵͳ�����ڼ���ܲ�����ErrCode */
		u.u_error = User::NOERROR;

		unsigned int old_eip = pContext->eip;

		/* ����̬����ֵΪԤ�����û�����SignalHandler()���׵�ַ */
		/*pContext->eip = ((unsigned long)SignalHandler - (unsigned long)runtime);
		pContext->esp -= 8;
		int* pInt = (int *)pContext->esp;
		*pInt = u.u_signal[signal];
		*(pInt + 1) = old_eip;*/
		pContext->eip = u.u_signal[signal];
		pContext->esp -= 4;
		int* pInt = (int *)pContext->esp;
		*pInt = old_eip;

		/* 
		 * ��ǰ�źŴ�����������Ӧ�걾���ź�֮����Ҫ����ΪĬ��
		 * ���źŴ�����������Ϊ0��ʾ���źŵĴ�����ʽΪ��ֹ�����̡�
		 */
		u.u_signal[signal] = 0;
		return;
	}

	/* u.u_signal[n]Ϊ0������źŵĴ�����ʽ����ֹ������ */
	u.u_procp->Exit();
}

void Process::Nice()
{
	User& u = Kernel::Instance().GetUser();
	int niceValue = u.u_arg[0];

	if (niceValue > 20)
	{
		niceValue = 20;
	}
	if (niceValue < 0 && !u.SUser())
	{
		/* ��ϵͳ�����û�����Ϊ��������С��0�Ľ�������������ƫ��ֵ */
		niceValue = 0;
	}
	this->p_nice = niceValue;
}

void Process::Ssig()
{
	User& u = Kernel::Instance().GetUser();

	int signalIndex = u.u_arg[0];
	unsigned long func = u.u_arg[1];

	/* �⼸���źŲ������� */
	if ( signalIndex <= 0 || signalIndex >= User::NSIG || signalIndex == User::SIGKILL )
	{
		u.u_error = User::EINVAL;
		return;
	}
	/* ���ú�����ַ���źŴ����������� */
	u.u_ar0[User::EAX] = u.u_signal[signalIndex];
	u.u_signal[signalIndex] = func;
	/* �嵱ǰ�ź� */
	if ( u.u_procp->p_sig == signalIndex )
	{
		u.u_procp->p_sig = 0;
	}
}

// NOTE 3: 获取页目录物理地址
unsigned long Process::GetPageDirectoryPhyAddr()
{
	return (unsigned long)(this->pPageDirectory) - Machine::KERNEL_SPACE_START_ADDRESS;
}

// 系统调用 49: 获取父进程 PID
void Process::Getppid()
{
	User& u = Kernel::Instance().GetUser();
	int *ptr_ppid = (int *)u.u_arg[0];
	if (ptr_ppid == NULL) { u.u_error = User::EFAULT; u.u_ar0[User::EAX] = -1; return; }
	*ptr_ppid = this->p_ppid;
	u.u_ar0[User::EAX] = 0;
}

// 系统调用 50: 获取当前进程和父进程 PID
void Process::Getpids()
{
	User& u = Kernel::Instance().GetUser();
	unsigned long pppid_ptr = (unsigned long)u.u_arg[0];
	unsigned long ppid_ptr = (unsigned long)u.u_arg[1];
	if (pppid_ptr == 0 || ppid_ptr == 0) { u.u_error = User::EFAULT; u.u_ar0[User::EAX] = -1; return; }
	int ppid_val = this->p_ppid;
	Utility::MemCopy((unsigned long)&ppid_val, pppid_ptr, sizeof(int));
	int pid_val = this->p_pid;
	Utility::MemCopy((unsigned long)&pid_val, ppid_ptr, sizeof(int));
	u.u_ar0[User::EAX] = 0;
}

// 系统调用 51: 获取进程内存信息
void Process::Getproc()
{
	User& u = Kernel::Instance().GetUser();
	unsigned long *ptext_vaddr = (unsigned long *)u.u_arg[0];
	unsigned long *ptext_size  = (unsigned long *)u.u_arg[1];
	unsigned long *pdata_vaddr = (unsigned long *)u.u_arg[2];
	unsigned long *pdata_size  = (unsigned long *)u.u_arg[3];
	if (!ptext_vaddr || !ptext_size || !pdata_vaddr || !pdata_size)
	{ u.u_error = User::EFAULT; u.u_ar0[User::EAX] = -1; return; }
	*ptext_vaddr = u.u_MemoryDescriptor.GetTextStartAddress();
	*ptext_size  = u.u_MemoryDescriptor.GetTextSize();
	*pdata_vaddr = u.u_MemoryDescriptor.GetDataStartAddress();
	*pdata_size  = u.u_MemoryDescriptor.GetDataSize();
	u.u_ar0[User::EAX] = (int)u.u_MemoryDescriptor.GetStackSize();
}

