#include "SystemCall.h"
#include "User.h"
#include "Kernel.h"
#include "Regs.h"
#include "TimeInterrupt.h"
#include "CRT.h"
#include "Video.h"
#include "Syscall49_51.h"

/* ϵͳ������ڱ��Ķ���
 * ����UNIX V6��sysent.c�ж�ϵͳ������ڱ�sysent�Ķ��� @line 2910 
 */
SystemCallTableEntry SystemCall::m_SystemEntranceTable[SYSTEM_CALL_NUM] = 
{
	{ 0, &Sys_NullSystemCall },		/* 0 = indir	*/
	{ 1, &Sys_Rexit },				/* 1 = rexit	*/
	{ 0, &Sys_Fork 	},				/* 2 = fork	*/
	{ 3, &Sys_Read 	},				/* 3 = read	*/
	{ 3, &Sys_Write	},				/* 4 = write	*/
	{ 2, &Sys_Open	},				/* 5 = open	*/
	{ 1, &Sys_Close	},				/* 6 = close	*/
	{ 1, &Sys_Wait	},				/* 7 = wait	*/
	{ 2, &Sys_Creat	},				/* 8 = creat	*/
	{ 2, &Sys_Link	},				/* 9 = link	*/
	{ 1, &Sys_UnLink},				/* 10 = unlink	*/
	{ 3, &Sys_Exec	},				/* 11 = Exec 	*/
	{ 1, &Sys_ChDir	},				/* 12 = chdir	*/
	{ 0, &Sys_GTime	},				/* 13 = time 	*/
	{ 3, &Sys_MkNod },				/* 14 = mknod	*/
	{ 2, &Sys_ChMod	},				/* 15 = chmod	*/
	{ 3, &Sys_ChOwn	},				/* 16 = chown	*/
	{ 1, &Sys_SBreak},				/* 17 = sbreak	*/
	{ 2, &Sys_Stat	},				/* 18 = stat 		*/
	{ 3, &Sys_Seek	},				/* 19 = seek	*/
	{ 0, &Sys_Getpid},				/* 20 = getpid	*/
	{ 3, &Sys_Smount	},			/* 21 = mount	*/
	{ 1, &Sys_Sumount	},			/* 22 = umount	*/
	{ 1, &Sys_Setuid	},			/* 23 = setuid	*/
	{ 0, &Sys_Getuid	},			/* 24 = getuid	*/
	{ 1, &Sys_Stime		},			/* 25 = stime	*/
	{ 3, &Sys_Ptrace	},			/* 26 = ptrace	*/
	{ 0, &Sys_Nosys	},				/* 27 = nosys	*/
	{ 2, &Sys_FStat	},				/* 28 = fstat	*/
	{ 1, &Sys_Trace	},				/* 29 = trace	*/
	{ 0, &Sys_NullSystemCall },		/* 30 = smdate; inoperative */
	{ 2, &Sys_Stty	},				/* 31 = stty	*/
	{ 2, &Sys_Gtty	},				/* 32 = gtty	*/
	{ 0, &Sys_Nosys	},				/* 33 = nosys	*/
	{ 1, &Sys_Nice	},				/* 34 = nice	*/
	{ 1, &Sys_Sslep	},				/* 35 = sleep	*/
	{ 0, &Sys_Sync	},				/* 36 = sync	*/
	{ 2, &Sys_Kill	},				/* 37 = kill		*/
	{ 0, &Sys_Getswit},				/* 38 = switch	*/
	{ 1, &Sys_Pwd	},				/* 39 = pwd	*/
	{ 0, &Sys_Nosys	},				/* 40 = nosys	*/
	{ 1, &Sys_Dup	},				/* 41 = dup		*/
	{ 1, &Sys_Pipe	},				/* 42 = pipe 	*/
	{ 1, &Sys_Times	},				/* 43 = times	*/
	{ 4, &Sys_Profil},				/* 44 = prof	*/
	{ 0, &Sys_Nosys	},				/* 45 = nosys	*/
	{ 1, &Sys_Setgid},				/* 46 = setgid	*/
	{ 0, &Sys_Getgid},				/* 47 = getgid	*/
	{ 2, &Sys_Ssig	},				/* 48 = sig	*/
	{ 1, &Sys_Getppid},				/* 49 = getppid	*/
	{ 2, &Sys_Getpids},				/* 50 = getpids	*/
	{ 4, &Sys_Getproc},				/* 51 = getproc	*/
	{ 0, &Sys_Nosys	},				/* 52 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 53 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 54 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 55 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 56 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 57= nosys	*/
	{ 0, &Sys_Nosys	},				/* 58 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 59 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 60 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 61 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 62 = nosys	*/
	{ 0, &Sys_Nosys	},				/* 63 = nosys	*/
};

SystemCall::SystemCall()
{
	//nothing to do here
}

SystemCall::~SystemCall()
{
	//nothing to do here
}

void SystemCall::SystemCallEntrance()
{
	SaveContext();

	SwitchToKernel();

	CallHandler(SystemCall, Trap);

	/* ��ȡ���ж���ָ��(��Ӳ��ʵʩ)ѹ�����ջ��pt_context��
	 * �����Ϳ��Է���context.xcs�е�OLD_CPL���ж���ǰ̬
	 * ���û�̬���Ǻ���̬��
	 */
	struct pt_context *context;
	__asm__ __volatile__ ("	movl %%ebp, %0; addl $0x4, %0 " : "+m" (context) );

	/* �ⲿ�ִ����ø߼�����ʵ�ָֻ��ֳ����жϷ��� @line 0785 */
	/* V6�б������߼��ǣ�
	 * if(�ж�ǰ==�û�̬) {
	 * 		ִ���豸(����)�����ӳ��� �ж�runrun�� swtch()�ȵȣ�	}
	 * else  {  //�ж�ǰ==����̬  
	 * 		����ǰ̬Ϊ�û�̬�� ִ���豸(����)�����ӳ��򣻻ָ��ֳ����˳���ǰһ���жϣ�}
	 * 
	 * ������ϵ�ṹ�Ĳ�ͬ(x86��PSW����¼��ǰ̬)��x86��ͨ���жϺ���ջCS��OLD_CPL == 0x3��
	 * �ж���ǰ���û�̬���ߺ���̬��
	 * 
	 * �����ж�ǰ==�û�̬or����̬����һ��ִ�д����ӳ�����ô�������ڵ���Trap֮ǰ�ж��ж�
	 * �ж��ж�ǰ���û�̬or����̬����Ϊ��������¶�Ҫִ��Trap()��
	 */
	if( context->xcs & USER_MODE ) /*��ǰΪ�û�̬*/
	{
		while(true)
		{
			X86Assembly::CLI();	/* ���������ȼ���Ϊ7�� */
			
			if(Kernel::Instance().GetProcessManager().RunRun > 0)
			{
				X86Assembly::STI();	/* ���������ȼ���Ϊ0�� */
				Kernel::Instance().GetProcessManager().Swtch();
			}
			else
			{
				break;	/* ���runrun == 0������ջ�ص��û�̬�����û������ִ�� */
			}
		}
	}
	RestoreContext();	//SysCallRestore();	/* �˺�EAX�д��ϵͳ���÷���ֵ����ֹһ�п��ܵ��޸� */
	
	Leave();				/* �ֹ�����ջ֡ */

	InterruptReturn();		/* �˳��ж� */
}

void SystemCall::Trap(struct pt_regs* regs, struct pt_context* context)
{	
	User& u = Kernel::Instance().GetUser();
	/* reference: u.u_ar0 = &r0 @line 2701 */

	/* �¼ӽ��Ĵ��롣�ж����޽��յ��źţ�����յ��ź��������Ӧ */
	if ( u.u_procp->IsSig() )
	{
		u.u_procp->PSig(context);
		u.u_error = User::EINTR;
		regs->eax = -u.u_error;
		return;
	}

	u.u_ar0 = &regs->eax;

	if(regs->eax == 20)
		regs->eax = 20;

	/* 
	 * ��տ�������ǰһ��ϵͳ����ʧ�ܶ����õĴ�����, u.u_error�������
	 * ������Ļ����������ĳ�����ȫ��ȷ���ں�Ҳ��������·�� **!!!!**
	 */
	u.u_error = User::NOERROR;

	SystemCallTableEntry *callp = &m_SystemEntranceTable[regs->eax];

	//Diagnose::Write("eax = %d, callp: count = %d, address = %x\n", regs->eax, callp->count, callp->call);

	/* ����callp->count��ϵͳ���õĴ�������ӼĴ�������u.u_arg[5] */
	unsigned int * syscall_arg = (unsigned int *)&regs->ebx;
	for( unsigned int i = 0; i < callp->count; i++ )
	{
		u.u_arg[i] = (int)(*syscall_arg++);
	}

	/* u.u_dirpһ������ָ��ϵͳ���õ�pathname���� */
	u.u_dirp = (char *)u.u_arg[0];

	/* 
	 * contextָ�����ջ��Ӳ�������ֳ����֣�������������ΪExec()ϵͳ����
	 * ��ҪFakeһ���˳�������ʹ֮�˳���ring3ʱ����ʼִ��user code��Ŀǰ����
	 * ϵͳ���ö��ǲ����õ�u.u_arg[4]�ġ�
	 */
	u.u_arg[4] = (int)context;
	
	Trap1(callp->call);		/* ϵͳ���ô����ӳ�����fork(), read()�ȵ� */

	/* 
	 * ���ϵͳ�����ڼ��ܵ��źŴ�ϣ���ô������ִ��Trap1()����
	 * ��u.u_intflg = 0����ֱ�ӷ�����Trap()������ǰλ��
	 */
	if ( u.u_intflg != 0 )
	{
		u.u_error = User::EINTR;
	}

	/* ע: Unix V6++��ϵͳ���ó���������ظ��û�����ķ�ʽ��V6(ͨ��PSW�е�EBIT)��������!
	 * ���ϵͳ�����ڼ��������u.u_error�����ã���ô��Ҫͨ��reg.eax����-u.u_error��
	 * �Ӷ��ͳɹ�ִ�е�ϵͳ���÷���>=0��ֵ���������̶�������ϵͳ����(������EAX�Ĵ���
	 * ����-u.u_error)�������������û�̬ȫ�ֱ���errno�У������û�����ͳͳ����-1��ʾ������
	 */

	if( User::NOERROR != u.u_error )
	{
		regs->eax = -u.u_error;
		Diagnose::Write("regs->eax = %d , u.u_error = %d\n",regs->eax,u.u_error);
	}

	/* �ж����޽��յ��źţ�����յ��ź��������Ӧ */
	if ( u.u_procp->IsSig() )
	{
		u.u_procp->PSig(context);
	}

	/* Trap()ĩβ���㵱ǰ���������� */
	u.u_procp->SetPri();
}

void SystemCall::Trap1(int (*func)())
{
	User& u = Kernel::Instance().GetUser();

	u.u_intflg = 1;
/*	int pid = u.u_procp->p_pid;
	int text = u.u_MemoryDescriptor.m_TextSize;
	int data =  u.u_MemoryDescriptor.m_DataSize;*/
	SaveU(u.u_qsav);
	func();
	u.u_intflg = 0;
}

/*	27, 49 - 63 = nosys		count = 0	*/
int SystemCall::Sys_Nosys()
{
	/* ��δ�����ϵͳ���ñ���ִ�д˿պ��� */
	User& u = Kernel::Instance().GetUser();
	u.u_error = User::ENOSYS;

	return 0;	/* GCC likes it ! */
}

/*	0 = indir	count = 0	*/
int SystemCall::Sys_NullSystemCall()
{
	/* This function should NEVER be called ! */

	return 0;	/* GCC likes it ! */
}

/*	1 = rexit	count = 0	*/
int SystemCall::Sys_Rexit()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->Exit();

	return 0;	/* GCC likes it ! */
}

/*	2 = fork	count = 0	*/
int SystemCall::Sys_Fork()
{
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	procMgr.Fork();

	return 0;	/* GCC likes it ! */
}

/*	3 = read	count = 2	*/
int SystemCall::Sys_Read()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Read();

	return 0;	/* GCC likes it ! */
}

/*	4 = write	count = 2	*/
int SystemCall::Sys_Write()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Write();

	return 0;	/* GCC likes it ! */
}

/*	5 = open	count = 2	*/
int SystemCall::Sys_Open()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Open();

	return 0;	/* GCC likes it ! */
}

/*	6 = close	count = 0	*/
int SystemCall::Sys_Close()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Close();

	return 0;	/* GCC likes it ! */
}

/*	7 = wait	count = 0	*/
int SystemCall::Sys_Wait()
{
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	procMgr.Wait();

	return 0;	/* GCC likes it ! */
}

/*	8 = creat	count = 2	*/
int SystemCall::Sys_Creat()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Creat();

	return 0;	/* GCC likes it ! */
}

/*	9 = link	count = 2	*/
int SystemCall::Sys_Link()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Link();

	return 0;	/* GCC likes it ! */
}

/*	10 = unlink	count = 1	*/
int SystemCall::Sys_UnLink()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.UnLink();

	return 0;	/* GCC likes it ! */
}

/*	11 = exec	count = 2	*/
int SystemCall::Sys_Exec()
{
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	procMgr.Exec();

	return 0;	/* GCC likes it ! */
}

/*	12 = chdir	count = 1	*/
int SystemCall::Sys_ChDir()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.ChDir();

	return 0;	/* GCC likes it ! */
}

/*	13 = gtime	count = 0	*/
int SystemCall::Sys_GTime()
{
	User& u = Kernel::Instance().GetUser();
	u.u_ar0[User::EAX] = Time::time;

	return 0;	/* GCC likes it ! */
}

/*	14 = mknod	count = 3	*/
int SystemCall::Sys_MkNod()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.MkNod();

	return 0;	/* GCC likes it ! */
}

/*	15 = chmod	count = 2	*/
int SystemCall::Sys_ChMod()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.ChMod();

	return 0;	/* GCC likes it ! */
}

/*	16 = chown	count = 2	*/
int SystemCall::Sys_ChOwn()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.ChOwn();

	return 0;	/* GCC likes it ! */
}

/*	17 = sbreak	count = 1	*/
int SystemCall::Sys_SBreak()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->SBreak();

	return 0;	/* GCC likes it ! */
}

/*	18 = stat	count = 2	*/
int SystemCall::Sys_Stat()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Stat();

	return 0;	/* GCC likes it ! */
}

/*	19 = seek	count = 2	*/
int SystemCall::Sys_Seek()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Seek();

	return 0;	/* GCC likes it ! */
}

/*	20 = getpid	count = 0	*/
int SystemCall::Sys_Getpid()
{
	User& u = Kernel::Instance().GetUser();
	u.u_ar0[User::EAX] = u.u_procp->p_pid;

	return 0;	/* GCC likes it ! */
}

/*	21 = mount	count = 3	*/
int SystemCall::Sys_Smount()
{
	return 0;	/* GCC likes it ! */
}

/*	22 = umount  count = 1	*/
int SystemCall::Sys_Sumount()
{
	return 0;	/* GCC likes it ! */
}

/*	23 = setuid	count = 0	*/
int SystemCall::Sys_Setuid()
{
	User& u = Kernel::Instance().GetUser();
	u.Setuid();

	return 0;	/* GCC likes it ! */
}

/*	24 = getuid	count = 0	*/
int SystemCall::Sys_Getuid()
{
	User& u = Kernel::Instance().GetUser();
	u.Getuid();

	return 0;	/* GCC likes it ! */
}

/*	25 = stime	count = 0	*/
int SystemCall::Sys_Stime()
{
	User& u = Kernel::Instance().GetUser();

	/* �������û��ž�������ϵͳʱ���Ȩ�� */
	if (u.SUser())
	{
		Time::time = u.u_ar0[User::EAX];
	}

	return 0;	/* GCC likes it ! */
}

/*	26 = ptrace	count = 3	*/
int SystemCall::Sys_Ptrace()
{
	return 0;	/* GCC likes it ! */
}

/*	28 = fstat	count = 1	*/
int SystemCall::Sys_FStat()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.FStat();

	return 0;	/* GCC likes it ! */
}

int SystemCall::Sys_Trace()
{
	User& u = Kernel::Instance().GetUser();

	if (Diagnose::ROWS == 0) /* if Diagnose not enabled */
	{
		Diagnose::ROWS = u.u_arg[0];	/* Diagnose���������������� */

		/* ��λ��ǰ������� */
		Diagnose::m_Row = Diagnose::SCREEN_ROWS - Diagnose::ROWS;
		Diagnose::m_Column = 0;

		CRT::ROWS = Diagnose::SCREEN_ROWS - Diagnose::ROWS;
	}
	else /* if enabled already */
	{
		Diagnose::ClearScreen();
		/* ֹͣDiagnose�������� */
		Diagnose::ROWS = 0;
		/* ��λ��ǰ������� */
		Diagnose::m_Row = Diagnose::SCREEN_ROWS - Diagnose::ROWS;
		Diagnose::m_Column = 0;

		/* �ַ��豸���ʹ��������Ļ������ */
		CRT::ROWS = Diagnose::SCREEN_ROWS;
	}
	u.u_ar0[User::EAX] = Diagnose::ROWS;

	return 0;	/* GCC likes it ! */
}

/*	31 = stty	count = 1	*/
int SystemCall::Sys_Stty()
{
	File* pFile;
	Inode* pInode;
	User& u = Kernel::Instance().GetUser();
	int fd = u.u_arg[0];
	TTy* pTTy = (TTy *)u.u_arg[1];

	if ( (pFile = u.u_ofiles.GetF(fd)) == NULL )
	{
		return 0;
	}
	pInode = pFile->f_inode;
	if ( (pInode->i_mode & Inode::IFMT) != Inode::IFCHR )
	{
		u.u_error = User::ENOTTY;
		return 0;
	}
	short dev = pInode->i_addr[0];
	Kernel::Instance().GetDeviceManager().GetCharDevice(dev).SgTTy(dev, pTTy);

	return 0;	/* GCC likes it ! */
}

/*	32 = gtty	count = 1	*/
int SystemCall::Sys_Gtty()
{
	File* pFile;
	Inode* pInode;
	User& u = Kernel::Instance().GetUser();
	int fd = u.u_arg[0];
	TTy* pTTy = (TTy *)u.u_arg[1];

	if ( (pFile = u.u_ofiles.GetF(fd)) == NULL )
	{
		return 0;
	}
	pInode = pFile->f_inode;
	if ( (pInode->i_mode & Inode::IFMT) != Inode::IFCHR )
	{
		u.u_error = User::ENOTTY;
		return 0;
	}
	short dev = pInode->i_addr[0];
	Kernel::Instance().GetDeviceManager().GetCharDevice(dev).SgTTy(dev, pTTy);

	return 0;	/* GCC likes it ! */
}

/*	34 = nice	count = 0	*/
int SystemCall::Sys_Nice()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->Nice();

	return 0;	/* GCC likes it ! */
}

/*	35 = sleep	count = 0	*/
int SystemCall::Sys_Sslep()
{
	User& u = Kernel::Instance().GetUser();

	X86Assembly::CLI();

	unsigned int wakeTime = Time::time + u.u_arg[0];	/* sleep(second) */

	/*
	 * ��   if ( Time::tout <= Time::time || Time::tout > wakeTime )  ���ж������Ľ��ͣ�
	 * 1��ϵͳ��ǰ���õ��������Ӿ��ѵ��ڡ�  ��󣬵�һ���������ӵĽ��̿����������� tout <= time���������Լ���waketimeд��tout������
	 * 2��ϵͳ�У���������δ���ڵĽ��̡�����н����������ӣ�������������tout > time�����̱ȶ�tout�������Լ���waketime����tout������ֵ�����н���waketime����Сֵ��
	 *
	 * ԭ�ȵ�ע�ͣ�
	 * �˴�������'wakeTime >= Time::time', ���򼫶������ǰһ��sleep(sec)�ս�����
	 * �����ŵڶ���sleep(0)����ʹwakeTime == Time::time == Time::tout��
	 * �������ʱ����ʱ���ж�ǡΪһ��ĩβ��Time::Clock()��Time::time++��
	 * �ᵼ��Time::tout��Time::timeС1����Զ�޷�����Time::time == Time::tout
	 * �Ļ�������������sleep(0)�Ľ�����Զ˯�ߡ�         The end.
	 *
	 * ԭ�ȵ�ע�Ͳ��ԡ����whileѭ�����ж�������'wakeTime >= Time::time'��ִ��sleep(0)�Ľ��̽���waketime��tout��Ϊ�ϸ������롣������ʱ���жϴ��������time++��֮��
	 * 1����������н������������ӣ�ϵͳ�����ӷ����̱���ˡ�������Ϊ�� time==tout��������Զ�޷����㣬ʱ���жϴ��������ٻỽ���κ������������Ӷ���˯�Ľ��̡�
	 * 2������н�������������newWaketime��ִ��sleep(0)�����Ľ����Լ�����waketime<=newWaketime�Ľ��̵Ļ���ʱ�̽��Ƴٵ�newWaketime��
	 *
	 * ���ڵ����ӷ�����ȷ��ִ��sleep(0)�Ľ��̲�����˯������ʹtoutֵ���ִ���
	 */
	while( wakeTime > Time::time )
	{
		if ( Time::tout <= Time::time || Time::tout > wakeTime )
		{
			Time::tout = wakeTime;
		}
		u.u_procp->Sleep((unsigned long)&Time::tout, ProcessManager::PSLEP);
	}

	X86Assembly::STI();

	return 0;	/* GCC likes it ! */
}

/*	36 = sync	count	= 0	*/
int SystemCall::Sys_Sync()
{
	Kernel::Instance().GetFileSystem().Update();

	return 0;	/* GCC likes it ! */
}

/*	37 = kill	count = 1	*/
int SystemCall::Sys_Kill()
{
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	procMgr.Kill();

	return 0;	/* GCC likes it ! */
}

/*	38 = switch	count = 0	*/
int SystemCall::Sys_Getswit()
{
	ProcessManager& procMgr = Kernel::Instance().GetProcessManager();
	User& u = Kernel::Instance().GetUser();

	u.u_ar0[User::EAX] = procMgr.SwtchNum;
	return 0;	/* GCC likes it ! */
}

/*	39 = pwd	count = 1	*/
int SystemCall::Sys_Pwd()
{
	User& u = Kernel::Instance().GetUser();
	u.Pwd();

	return 0;	/* GCC likes it ! */
}

/*	41 = dup	count = 0	*/
int SystemCall::Sys_Dup()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Dup();

	return 0;	/* GCC likes it ! */
}

/*	42 = pipe	count = 0	*/
int SystemCall::Sys_Pipe()
{
	FileManager& fileMgr = Kernel::Instance().GetFileManager();
	fileMgr.Pipe();

	return 0;	/* GCC likes it ! */
}

/*	43 = times	count = 1	*/
int SystemCall::Sys_Times()
{
	User& u = Kernel::Instance().GetUser();

	struct tms* ptms = (struct tms *)u.u_arg[0];
	
	ptms->utime = u.u_utime;
	ptms->stime = u.u_stime;
	ptms->cutime = u.u_cutime;
	ptms->cstime = u.u_cstime;

	return 0;	/* GCC likes it ! */
}

/*	44 = prof	count = 4	*/
int SystemCall::Sys_Profil()
{
	return 0;	/* GCC likes it ! */
}

/*	46 = setgid	count = 0	*/
int SystemCall::Sys_Setgid()
{
	User& u = Kernel::Instance().GetUser();
	u.Setgid();

	return 0;	/* GCC likes it ! */
}

/*	47 = getgid	count = 0	*/
int SystemCall::Sys_Getgid()
{
	User& u = Kernel::Instance().GetUser();
	u.Getgid();

	return 0;	/* GCC likes it ! */
}

/*	48 = ssig	count = 2	*/
int SystemCall::Sys_Ssig()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->Ssig();

	return 0;	/* GCC likes it ! */
}

/*	49 = getppid	*/
int SystemCall::Sys_Getppid()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->Getppid();
	return 0;
}

/*	50 = getpids	*/
int SystemCall::Sys_Getpids()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->Getpids();
	return 0;
}

/*	51 = getproc	*/
int SystemCall::Sys_Getproc()
{
	User& u = Kernel::Instance().GetUser();
	u.u_procp->Getproc();
	return 0;
}
