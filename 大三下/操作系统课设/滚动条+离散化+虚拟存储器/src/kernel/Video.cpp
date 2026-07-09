#include "Video.h"

unsigned short* Diagnose::m_VideoMemory = (unsigned short *)(0xB8000 + 0xC0000000);
unsigned int Diagnose::m_Row = 10;
unsigned int Diagnose::m_Column = 0;
unsigned int Diagnose::ROWS = 10;
bool Diagnose::trace_on = true;

char Diagnose::m_Buffer[Diagnose::BUFFER_ROWS][Diagnose::COLUMNS];
unsigned int Diagnose::m_WriteRow = 0;
int Diagnose::m_ViewStartRow = 0;

Diagnose::Diagnose() {}
Diagnose::~Diagnose() {}

void Diagnose::TraceOn() { Diagnose::trace_on = 1; }
void Diagnose::TraceOff() { Diagnose::trace_on = 0; }

void Diagnose::Write(const char* fmt, ...)
{
	if (false == Diagnose::trace_on) return;
	unsigned int *va_arg = (unsigned int *)&fmt + 1;
	const char *ch = fmt;
	while (1)
	{
		while (*ch != '%' && *ch != '\n')
		{
			if (*ch == '\0') return;
			if (*ch == '\n') break;
			WriteChar(*ch++);
		}
		ch++;
		if (*ch == 'd' || *ch == 'x')
		{
			int value = (int)(*va_arg);
			va_arg++;
			if (*ch == 'x') Write("0x");
			PrintInt(value, *ch == 'd' ? 10 : 16);
			ch++;
		}
		else if (*ch == 's')
		{
			ch++;
			char *str = (char *)(*va_arg);
			va_arg++;
			while (char tmp = *str++) WriteChar(tmp);
		}
		else
		{
			Diagnose::NextLine();
		}
	}
}

void Diagnose::PrintInt(unsigned int value, int base)
{
	static char Digits[] = "0123456789ABCDEF";
	int i;
	if ((i = value / base) != 0) PrintInt(i, base);
	WriteChar(Digits[value % base]);
}

void Diagnose::NextLine()
{
	m_Column = 0;
	m_WriteRow++;
	if (m_WriteRow >= BUFFER_ROWS)
	{
		for (int i = 0; i < BUFFER_ROWS - 1; i++)
			for (int j = 0; j < COLUMNS; j++)
				m_Buffer[i][j] = m_Buffer[i+1][j];
		for (int j = 0; j < COLUMNS; j++) m_Buffer[BUFFER_ROWS-1][j] = ' ';
		m_WriteRow = BUFFER_ROWS - 1;
	}
	if (m_ViewStartRow < (int)m_WriteRow - (int)ROWS + 1)
		m_ViewStartRow = m_WriteRow - ROWS + 1;
	if (m_ViewStartRow < 0) m_ViewStartRow = 0;
	Refresh();
}

void Diagnose::WriteChar(const char ch)
{
	m_Buffer[m_WriteRow][m_Column] = ch;
	if (m_WriteRow >= (unsigned int)m_ViewStartRow && m_WriteRow < (unsigned int)m_ViewStartRow + ROWS)
	{
		unsigned int screenRow = m_WriteRow - m_ViewStartRow + (SCREEN_ROWS - ROWS);
		Diagnose::m_VideoMemory[screenRow * COLUMNS + Diagnose::m_Column] = (unsigned char)ch | Diagnose::COLOR;
	}
	Diagnose::m_Column++;
	if (Diagnose::m_Column >= Diagnose::COLUMNS) NextLine();
}

void Diagnose::ClearScreen()
{
	for (unsigned int i = 0; i < BUFFER_ROWS; i++)
		for (unsigned int j = 0; j < COLUMNS; j++)
			m_Buffer[i][j] = ' ';
	m_WriteRow = 0;
	m_ViewStartRow = 0;
	m_Column = 0;
	Refresh();
}

void Diagnose::ScrollUp()
{
	if (m_ViewStartRow > 0) { m_ViewStartRow--; Refresh(); }
}

void Diagnose::ScrollDown()
{
	int maxViewRow = (int)m_WriteRow - (int)ROWS + 1;
	if (maxViewRow < 0) maxViewRow = 0;
	if (m_ViewStartRow < maxViewRow) { m_ViewStartRow++; Refresh(); }
}

void Diagnose::Refresh()
{
	for (unsigned int i = 0; i < ROWS; i++)
	{
		unsigned int bufRow = m_ViewStartRow + i;
		unsigned int screenRow = i + (SCREEN_ROWS - ROWS);
		for (unsigned int j = 0; j < COLUMNS; j++)
		{
			char ch = ' ';
			if (bufRow < BUFFER_ROWS) ch = m_Buffer[bufRow][j];
			m_VideoMemory[screenRow * COLUMNS + j] = (unsigned char)ch | Diagnose::COLOR;
		}
	}
}
