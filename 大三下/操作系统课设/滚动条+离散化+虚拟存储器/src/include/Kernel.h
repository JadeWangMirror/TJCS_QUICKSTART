#ifndef KERNEL_H
#define KERNEL_H

#include "PageManager.h"
#include "ProcessManager.h"
#include "KernelAllocator.h"
#include "User.h"
#include "BufferManager.h"
#include "DeviceManager.h"
#include "FileManager.h"
#include "FileSystem.h"
#include "SwapperManager.h"
#include "HashTable.h"

class Kernel
{
public:
	static const unsigned long USER_ADDRESS  = 0x400000 - 0x1000 + 0xc0000000;
	static const unsigned long USER_PAGE_INDEX = 1023;

public:
	Kernel();
	~Kernel();
	static Kernel& Instance();
	void Initialize();

	KernelPageManager& GetKernelPageManager();
	UserPageManager& GetUserPageManager();
	ProcessManager& GetProcessManager();
	KernelAllocator& GetKernelAllocator();
	SwapperManager& GetSwapperManager();
	BufferManager& GetBufferManager();
	DeviceManager& GetDeviceManager();
	FileSystem& GetFileSystem();
	FileManager& GetFileManager();
	HashTable& GetHashTable();
	User& GetUser();

private:
	void InitMemory();
	void InitProcess();
	void InitBuffer();
	void InitFileSystem();

private:
	static Kernel instance;

	KernelPageManager*  m_KernelPageManager;
	UserPageManager*    m_UserPageManager;
	ProcessManager*     m_ProcessManager;
	KernelAllocator*    m_KernelAllocator;
	SwapperManager*     m_SwapperManager;
	BufferManager*      m_BufferManager;
	DeviceManager*      m_DeviceManager;
	FileSystem*         m_FileSystem;
	FileManager*        m_FileManager;
	HashTable*          m_HashTable;
};

#endif
