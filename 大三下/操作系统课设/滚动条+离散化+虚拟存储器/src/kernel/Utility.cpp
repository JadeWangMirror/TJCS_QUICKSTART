#include "Utility.h"
#include "Kernel.h"
#include "User.h"
#include "PageManager.h"
#include "Machine.h"
#include "MemoryDescriptor.h"
#include "Video.h"
#include "Assembly.h"

void Utility::MemCopy(unsigned long src, unsigned long des, unsigned int count)
{
	unsigned char* psrc = (unsigned char*)src;
	unsigned char* pdes = (unsigned char*)des;
	
	for ( unsigned int i = 0; i < count; i++ ) 
		pdes[i] = psrc[i];
}

int Utility::CaluPageNeed(unsigned int memoryneed, unsigned int pagesize)
{
	int pageRequired = memoryneed / pagesize;
	pageRequired += memoryneed % pagesize ? 1 : 0;

	return pageRequired;
}

void Utility::StringCopy(char* src, char* dst)
{
	while ( (*dst++ = *src++) != 0 ) ;
}

int Utility::StringLength(char* pString)
{
	int length = 0;
	char* pChar = pString;

	while( *pChar++ )
	{
		length++;
	}

	/* �����ַ������� */
	return length;
}

void Utility::CopySeg2(unsigned long src, unsigned long des)
{
	PageTableEntry* userPageTable = (PageTableEntry*)Machine::Instance().GetUserPageTableArray();
	

	/*
	 * �ȱ���ԭ�û�̬��һҳ��ڶ�ҳPageTableEntry����Ϊ����Ĳ���
	 * ���Ὣsrc����ҳӳ�䵽0#Ŀ¼���desӳ�䵽1#���������copy
	 */
	unsigned long oriEntry1 = userPageTable[0].m_PageBaseAddress;
	unsigned long oriEntry2 = userPageTable[1].m_PageBaseAddress;	

	userPageTable[0].m_PageBaseAddress = src / PageManager::PAGE_SIZE;
	userPageTable[1].m_PageBaseAddress = des / PageManager::PAGE_SIZE;

	unsigned char* addressSrc = (unsigned char*)(src % PageManager::PAGE_SIZE);	
	//�ڶ�ҳvirtual addess��4096��ʼ
	unsigned char* addressDes = (unsigned char*)(PageManager::PAGE_SIZE + des % PageManager::PAGE_SIZE);	
	//��Ҫˢ��ҳ������
	FlushPageDirectory();

	*addressDes = *addressSrc;
	
	//�ָ�ԭҳ��ӳ��
	userPageTable[0].m_PageBaseAddress = oriEntry1;
	userPageTable[1].m_PageBaseAddress = oriEntry2;
	FlushPageDirectory();
}

void Utility::CopySeg(unsigned long src, unsigned long des)
{
	PageTableEntry* PageTable = Machine::Instance().GetKernelPageTable().m_Entrys;

	/*
	 * �ȱ���ԭ�û�̬��һҳ��ڶ�ҳPageTableEntry����Ϊ����Ĳ���
	 * ���Ὣsrc����ҳӳ�䵽0#Ŀ¼���desӳ�䵽1#���������copy
	 */
	unsigned long oriEntry1 = PageTable[borrowedPTE].m_PageBaseAddress;
	unsigned long oriEntry2 = PageTable[borrowedPTE + 1].m_PageBaseAddress;

	PageTable[256].m_PageBaseAddress = src / PageManager::PAGE_SIZE;
	PageTable[257].m_PageBaseAddress = des / PageManager::PAGE_SIZE;

	unsigned char* addressSrc = (unsigned char*)(0xC0000000 + borrowedPTE*PageManager::PAGE_SIZE + src % PageManager::PAGE_SIZE);

	unsigned char* addressDes = (unsigned char*)(0xC0000000 + (borrowedPTE + 1)*PageManager::PAGE_SIZE + des % PageManager::PAGE_SIZE);
	//��Ҫˢ��ҳ������
	FlushPageDirectory();

	*addressDes = *addressSrc;

	//�ָ�ԭҳ��ӳ��
	PageTable[borrowedPTE].m_PageBaseAddress = oriEntry1;
	PageTable[(borrowedPTE + 1)].m_PageBaseAddress = oriEntry2;
	FlushPageDirectory();
}

short Utility::GetMajor(const short dev)
{
	short major;
	major = dev >> 8;
	return major;
}

short Utility::GetMinor(const short dev)
{
	short minor;
	minor = dev & 0x00FF;
	return minor;
}

short Utility::SetMajor(short dev, const short value)
{
	dev &= 0x00FF;	/*  ���dev��ԭ�ȸ�8���� */
	dev |= (value << 8);
	return dev;
}

short Utility::SetMinor(short dev, const short value)
{
	dev &= 0xFF00;	/*  ���dev��ԭ�ȵ�8���� */
	dev |= (value & 0x00FF);	/* ������value�еĵ�8λ */
	return dev;
}

void Utility::Panic(char* str)
{
	Diagnose::TraceOn();
	Diagnose::Write("%s\n", str);
	X86Assembly::CLI();
	for(;;);
}

void Utility::DWordCopy(int *src, int *dst, int count)
{
	while(count--)
	{
		*dst++ = *src++;
	}
	return;
}

int Utility::Min(int a, int b)
{
	if(a < b)
		return a;
	return b;
}

int Utility::Max(int a, int b)
{
	if(a > b)
		return a;
	return b;
}

int Utility::BCDToBinary( int value )
{
	return ( (value >> 4) * 10 + (value & 0xF) );
}

void Utility::IOMove(unsigned char* from, unsigned char* to, int count)
{
	while(count--)
	{
		*to++ = *from++;
	}
	return;
}

unsigned int Utility::MakeKernelTime( struct SystemTime* pTime )
{
	unsigned int timeInSeconds = 0;
	unsigned int days;
	int currentYear = 2000 + pTime->Year;	/* Year��ֻ����ݺ�2λ */

	/* compute hours, minutes, seconds */
	timeInSeconds += pTime->Second;
	timeInSeconds += pTime->Minute * Utility::SECONDS_IN_MINUTE;
	timeInSeconds += pTime->Hour * Utility::SECONDS_IN_HOUR;

	/* compute days in current year */
	days = pTime->DayOfMonth - 1;
	days += Utility::DaysBeforeMonth[pTime->Month];
	if (Utility::IsLeapYear(currentYear) && pTime->Month >= 3 /* After February */)
		days++;

	/* compute days in previous years */
	for (int year = 1970; year < currentYear; year++)
	{
		days += Utility::DaysInYear(year);
	}
	timeInSeconds += days * Utility::SECONDS_IN_DAY;
	
	return timeInSeconds;
}

/* ĳ���·�ǰ��������������0�ʹ�ã�δ�����������2�·�29�� */
const unsigned int Utility::DaysBeforeMonth[13] = {0xFFFFFFFF/* Unused */, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};

bool Utility::IsLeapYear( int year )
{
	return (year % 4) == 0 && ( (year % 100) != 0 || (year % 400) == 0 );
}

unsigned int Utility::DaysInYear( int year )
{
	return IsLeapYear(year) ? 366 : 365;
}

/*
 * DJB2 变体哈希：合并两个 unsigned long 为桶索引。
 * 用于共享页哈希表，键为 (inode 地址, 文件页号)。
 */
unsigned long Utility::Hash(unsigned long a, unsigned long b)
{
	unsigned long hash = 5381;

	hash = ((hash << 5) + hash) + (a & 0xFF);
	hash = ((hash << 5) + hash) + ((a >> 8) & 0xFF);
	hash = ((hash << 5) + hash) + ((a >> 16) & 0xFF);
	hash = ((hash << 5) + hash) + ((a >> 24) & 0xFF);

	hash = ((hash << 5) + hash) + (b & 0xFF);
	hash = ((hash << 5) + hash) + ((b >> 8) & 0xFF);
	hash = ((hash << 5) + hash) + ((b >> 16) & 0xFF);
	hash = ((hash << 5) + hash) + ((b >> 24) & 0xFF);

	return hash;
}
