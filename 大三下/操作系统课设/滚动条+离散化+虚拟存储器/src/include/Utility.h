#ifndef UITILITY_H
#define UITILITY_H

/*
 *@comment ����һЩ���߳���
 * ����ʹ���˱���ѡ��-fno-builtin��
 * ���������ṩ��Щ�����Ķ��塣
 */
#define NULL	0

/* ����ϵͳʱ����Ϣ�Ľṹ�� */
struct SystemTime
{
	int Second;		/* Seconds: 0 ~ 59 */
	int Minute;		/* Minutes: 0 ~ 59 */
	int Hour;		/* Hours of Day: 0 ~ 23 */
	int DayOfMonth;	/* Day of Month: 1 ~ 31 */
	int Month;		/* Months since January: 1 ~ 12 */
	int Year;		/* Years since 1900 */
	int DayOfWeek;	/* Days since Sunday: 1 ~ 7 */
};

/* ��¼����ʹ�õ��ں�̬���û�̬��CPUʱ��Ľṹ�� */
struct tms
{
	int utime;		/* �����û�̬CPUʱ�� */
	int stime;		/* ���̺���̬CPUʱ�� */
	int cutime;		/* �ӽ����û�̬ʱ���ܺ� */
	int cstime;		/* �ӽ��̺���̬ʱ���ܺ� */
};

/*
 *@comment һЩ������ʹ�õ��Ĺ��ߺ���
 *
 *
 */
class Utility
{
public:
	static void MemCopy(unsigned long src, unsigned long des, unsigned int count);
	
	static int CaluPageNeed(unsigned int memoryneed, unsigned int pagesize);

	static void StringCopy(char* src, char* dst);

	static int StringLength(char* pString);
	
	/* @comment
	 * ���ڴ�������ַsrc copy ��������ַdes 1��byte
	 */
	static void CopySeg(unsigned long src, unsigned long des);
	static void CopySeg2(unsigned long src, unsigned long des);
	/* ��ȡ����dev�е����豸��major����8���� */
	static short GetMajor(const short dev);
	/* ��ȡ����dev�еĴ��豸��minor����8���� */
	static short GetMinor(const short dev);
	/* ���ò���dev�е����豸�Ų��֣���8���� */
	static short SetMajor(short dev, const short value);
	/* ���ò���dev�еĴ��豸�Ų��֣���8���� */
	static short SetMinor(short dev, const short vlaue);
	/* ���������Ϣ��Ȼ����ѭ�� */
	static void Panic(char* str);

	/* ��srcΪԴ��ַ��dstΪĿ�ĵ�ַ������count��˫�� */
	static void DWordCopy(int* src, int* dst, int count);

	/* DJB2 变体哈希函数，用于共享页哈希表 */
	static unsigned long Hash(unsigned long a, unsigned long b);

	static int Min(int a, int b);

	static int Max(int a, int b);

	/* Convert BCD to Binary */
	static int BCDToBinary(int value);

	/* �����ڶ���д�ļ�ʱ�����ٻ������û�ָ��Ŀ���ڴ�����֮�����ݴ��� */
	static void IOMove(unsigned char* from, unsigned char* to, int count);

	/* ����SystemTime�ṹ���е�ֵ������ں˸�ʽ��ʱ��ֵ����1970��1��1��0ʱ����ǰ������ */
	static unsigned int MakeKernelTime(struct SystemTime* pTime);

	static bool IsLeapYear(int year);

	static unsigned int DaysInYear(int year);

	static const unsigned int borrowedPTE = 256;
	static const unsigned int SECONDS_IN_MINUTE = 60;	/* һ����60�� */
	static const unsigned int SECONDS_IN_HOUR = 3600;	/* һСʱ3600�� */
	static const unsigned int SECONDS_IN_DAY = 86400;	/* һ��86400�� */

	/* ĳ���·�ǰ���������� */
	static const unsigned int DaysBeforeMonth[13];
};

#endif
