#include "Kernel.h"
#include "Machine.h"
#include "New.h"
#include "Video.h"

Kernel Kernel::instance;

/* 
 * �ڴ������ص�ȫ��manager
 */
UserPageManager g_UserPageManager(&(BitMapAllocator::GetInstance()));
KernelPageManager g_KernelPageManager(&(BitMapAllocator::GetInstance()));
KernelAllocator g_KernelAllocator(&(Allocator::GetInstance()));

/*
 * ���������ȫ��manager
 */
SwapperManager g_SwapperManager(&(Allocator::GetInstance()));

/* 
 * �������ȫ��manager
 */
ProcessManager g_ProcessManager;

/*
 * �豸���������ٻ������ȫ��manager
 */
BufferManager g_BufferManager;
DeviceManager g_DeviceManager;

/*
 * �ļ�ϵͳ���ȫ��manager
 */
FileSystem g_FileSystem;
FileManager g_FileManager;

/*
 * 共享页哈希表
 */
HashTable g_HashTable;

Kernel::Kernel()
{
}

Kernel::~Kernel()
{
}

Kernel& Kernel::Instance()
{
	return Kernel::instance;
}

void Kernel::InitMemory()
{
	this->m_KernelPageManager = &g_KernelPageManager;
	this->m_UserPageManager = &g_UserPageManager;
	
	Diagnose::Write("Initilize Memory...");
	this->GetKernelPageManager().Initialize();
	this->GetUserPageManager().Initialize();
	Diagnose::Write("Ok.\n");

	this->m_KernelAllocator = &g_KernelAllocator;

	Diagnose::Write("Initilize KernelAllocator...");
	this->GetKernelAllocator().Initialize();
	Diagnose::Write("Ok.\n");

	/* ����new/delete operator��Ҫʹ�õ�Allocator */
	set_kernel_allocator(this->m_KernelAllocator);

	this->m_SwapperManager = &g_SwapperManager;
	Diagnose::Write("Initialize Swapper...");
	this->GetSwapperManager().Initialize();
	Diagnose::Write("Ok.\n");

	this->m_HashTable = &g_HashTable;
	Diagnose::Write("Initialize HashTable...Ok.\n");
}

void Kernel::InitProcess()
{
	this->m_ProcessManager = &g_ProcessManager;

	Diagnose::Write("Initilize Process...");
	this->GetProcessManager().Initialize();
	Diagnose::Write("Ok.\n");
}

void Kernel::InitBuffer()
{
	this->m_BufferManager = &g_BufferManager;
	this->m_DeviceManager = &g_DeviceManager;

	Diagnose::Write("Initialize Buffer...");
	this->GetBufferManager().Initialize();
	Diagnose::Write("OK.\n");

	Diagnose::Write("Initialize Device Manager...");
	this->GetDeviceManager().Initialize();
	Diagnose::Write("OK.\n");
}

void Kernel::InitFileSystem()
{
	this->m_FileSystem = &g_FileSystem;
	this->m_FileManager = &g_FileManager;

	Diagnose::Write("Initialize File System...");
	this->GetFileSystem().Initialize();
	Diagnose::Write("OK.\n");

	Diagnose::Write("Initialize File Manager...");
	this->GetFileManager().Initialize();
	Diagnose::Write("OK.\n");
}

void Kernel::Initialize()
{
	InitMemory();
	InitProcess();
	InitBuffer();
	InitFileSystem();
}

KernelPageManager& Kernel::GetKernelPageManager()
{
	return *(this->m_KernelPageManager);
}

UserPageManager& Kernel::GetUserPageManager()
{
	return *(this->m_UserPageManager);
}

ProcessManager& Kernel::GetProcessManager()
{
	return *(this->m_ProcessManager);
}

KernelAllocator& Kernel::GetKernelAllocator()
{
	return *(this->m_KernelAllocator);
}

SwapperManager& Kernel::GetSwapperManager()
{
	return *(this->m_SwapperManager);
}

BufferManager& Kernel::GetBufferManager()
{
	return *(this->m_BufferManager);
}

DeviceManager& Kernel::GetDeviceManager()
{
	return *(this->m_DeviceManager);
}

FileSystem& Kernel::GetFileSystem()
{
	return *(this->m_FileSystem);
}

FileManager& Kernel::GetFileManager()
{
	return *(this->m_FileManager);
}

HashTable& Kernel::GetHashTable()
{
	return *(this->m_HashTable);
}

User& Kernel::GetUser()
{
	return *(User*)USER_ADDRESS;
}
