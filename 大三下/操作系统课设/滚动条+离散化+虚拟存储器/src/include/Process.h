#ifndef PROCESS_H
#define PROCESS_H

#include "Text.h"
#include "TTy.h"
#include "Regs.h"
#include "PageDirectory.h"

class Process
{
public:
	enum ProcessState
	{
		SNULL = 0, SSLEEP = 1, SWAIT = 2, SRUN = 3,
		SIDL = 4, SZOMB = 5, SSTOP = 6
	};
	enum ProcessFlag
	{
		SLOAD = 0x1, SSYS = 0x2, SLOCK = 0x4,
		SSWAP = 0x8, STRC = 0x10, STWED = 0x20
	};

public:
	Process();
	~Process();
	void SetRun();
	void SetPri();
	bool IsSleepOn(unsigned long chan);
	void Sleep(unsigned long chan, int pri);
	void Expand(unsigned int newSize);
	void Exit();
	void Clone(Process& proc);
	void SStack();
	void SBreak();
	void PSignal(int signal);
	void PSig(struct pt_context* pContext);
	void Nice();
	void Ssig();
	int IsSig();

	// NOTE 3: 获取页目录物理地址
	unsigned long GetPageDirectoryPhyAddr();

	// 系统调用 49/50/51
	void Getppid();
	void Getpids();
	void Getproc();

public:
	short p_uid;
	int p_pid;
	int p_ppid;

	unsigned long p_addr;
	unsigned int p_size;
	Text* p_textp;

	ProcessState p_stat;
	int p_flag;
	int p_pri;
	int p_cpu;
	int p_nice;
	int p_time;
	unsigned long p_wchan;

	int p_sig;
	TTy* p_ttyp;
	unsigned long p_sigmap;

	// NOTE 3: 每个进程存储页目录首地址
	PageDirectory *pPageDirectory;
};

#endif
