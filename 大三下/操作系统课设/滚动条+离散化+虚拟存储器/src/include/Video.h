//Video.h
#ifndef DIAGNOSE_H
#define DIAGNOSE_H

class Diagnose
{
public:
	static unsigned int ROWS;
	static const unsigned int COLUMNS = 80;
	static const unsigned short COLOR = 0x0B00;
	static const unsigned int SCREEN_ROWS = 25;

public:
	Diagnose();
	~Diagnose();

	static void TraceOn();
	static void TraceOff();

	static void Write(const char* fmt, ...);
	static void ClearScreen();

	static void ScrollUp();
	static void ScrollDown();
	static void Refresh();

private:
	static void PrintInt(unsigned int value, int base);
	static void NextLine();
	static void WriteChar(const char ch);

public:
	static unsigned int m_Row;
	static unsigned int m_Column;

	static const unsigned int BUFFER_ROWS = 200;
	static char m_Buffer[BUFFER_ROWS][COLUMNS];
	static unsigned int m_WriteRow;
	static int m_ViewStartRow;

private:
	static unsigned short* m_VideoMemory;
	static bool trace_on;
};

#endif
