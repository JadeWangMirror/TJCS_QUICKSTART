#include "CRT.h"
#include "IOPort.h"

unsigned short* CRT::m_VideoMemory = (unsigned short *)(0xB8000 + 0xC0000000);
unsigned int CRT::m_CursorX = 0;
unsigned int CRT::m_CursorY = 0;
char* CRT::m_Position = 0;
char* CRT::m_BeginChar = 0;
unsigned int CRT::ROWS = 15;

char CRT::m_Buffer[CRT::BUFFER_ROWS][CRT::COLUMNS];
unsigned int CRT::m_WriteRow = 0;
int CRT::m_ViewStartRow = 0;

void CRT::CRTStart(TTy* pTTy)
{
	char ch;
	if (0 == CRT::m_BeginChar) m_BeginChar = pTTy->t_outq.CurrentChar();
	if (0 == m_Position) m_Position = m_BeginChar;

	while ((ch = pTTy->t_outq.GetChar()) != TTy::GET_ERROR)
	{
		switch (ch)
		{
		case '\n':
			NextLine();
			CRT::m_BeginChar = pTTy->t_outq.CurrentChar();
			m_Position = CRT::m_BeginChar;
			break;
		case 0x15:
			break;
		case '\b':
			if (m_Position != CRT::m_BeginChar) { BackSpace(); m_Position--; }
			break;
		case '\t':
			Tab(); m_Position++;
			break;
		default:
			WriteChar(ch); m_Position++;
			break;
		}
	}
}

void CRT::MoveCursor(unsigned int col, unsigned int row)
{
	if ((col < 0 || col >= CRT::COLUMNS) || (row < 0 || row >= CRT::ROWS)) return;
	unsigned short cursorPosition = row * CRT::COLUMNS + col;
	IOPort::OutByte(CRT::VIDEO_ADDR_PORT, 14);
	IOPort::OutByte(CRT::VIDEO_DATA_PORT, cursorPosition >> 8);
	IOPort::OutByte(CRT::VIDEO_ADDR_PORT, 15);
	IOPort::OutByte(CRT::VIDEO_DATA_PORT, cursorPosition & 0xFF);
}

void CRT::NextLine()
{
	m_CursorX = 0;
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
	m_CursorY = m_WriteRow - m_ViewStartRow;
	if (m_CursorY >= ROWS) m_CursorY = ROWS - 1;
	Refresh();
	MoveCursor(m_CursorX, m_CursorY);
}

void CRT::BackSpace()
{
	m_CursorX--;
	if (m_CursorX < 0)
	{
		m_CursorX = CRT::COLUMNS - 1;
		if (m_WriteRow > 0)
		{
			m_WriteRow--;
			if (m_ViewStartRow > (int)m_WriteRow - (int)ROWS + 1)
			{
				m_ViewStartRow = m_WriteRow - ROWS + 1;
				if (m_ViewStartRow < 0) m_ViewStartRow = 0;
			}
		}
	}
	m_CursorY = m_WriteRow - m_ViewStartRow;
	if (m_CursorY >= ROWS) m_CursorY = ROWS - 1;
	MoveCursor(m_CursorX, m_CursorY);
	m_Buffer[m_WriteRow][m_CursorX] = ' ';
	Refresh();
}

void CRT::Tab()
{
	m_CursorX &= 0xFFFFFFF8;
	m_CursorX += 8;
	if (m_CursorX >= CRT::COLUMNS)
		NextLine();
	else
		MoveCursor(m_CursorX, m_CursorY);
}

void CRT::WriteChar(char ch)
{
	m_Buffer[m_WriteRow][m_CursorX] = ch;
	if (m_WriteRow >= (unsigned int)m_ViewStartRow && m_WriteRow < (unsigned int)m_ViewStartRow + ROWS)
	{
		unsigned int screenRow = m_WriteRow - m_ViewStartRow;
		m_VideoMemory[screenRow * CRT::COLUMNS + m_CursorX] = (unsigned char)ch | CRT::COLOR;
	}
	m_CursorX++;
	if (m_CursorX >= CRT::COLUMNS)
		NextLine();
	else
		MoveCursor(m_CursorX, m_CursorY);
}

void CRT::ClearScreen()
{
	for (unsigned int i = 0; i < BUFFER_ROWS; i++)
		for (unsigned int j = 0; j < COLUMNS; j++)
			m_Buffer[i][j] = ' ';
	m_WriteRow = 0;
	m_ViewStartRow = 0;
	m_CursorX = 0;
	m_CursorY = 0;
	Refresh();
	MoveCursor(0, 0);
}

void CRT::ScrollUp()
{
	if (m_ViewStartRow > 0)
	{
		m_ViewStartRow--;
		Refresh();
		int screenY = (int)m_WriteRow - m_ViewStartRow;
		if (screenY >= 0 && screenY < (int)ROWS)
			MoveCursor(m_CursorX, screenY);
		else
			MoveCursor(0, ROWS);
	}
}

void CRT::ScrollDown()
{
	int maxViewRow = (int)m_WriteRow - (int)ROWS + 1;
	if (maxViewRow < 0) maxViewRow = 0;
	if (m_ViewStartRow < maxViewRow)
	{
		m_ViewStartRow++;
		Refresh();
		int screenY = (int)m_WriteRow - m_ViewStartRow;
		if (screenY >= 0 && screenY < (int)ROWS)
			MoveCursor(m_CursorX, screenY);
		else
			MoveCursor(0, ROWS);
	}
}

void CRT::Refresh()
{
	for (unsigned int i = 0; i < ROWS; i++)
	{
		unsigned int bufRow = m_ViewStartRow + i;
		for (unsigned int j = 0; j < COLUMNS; j++)
		{
			char ch = ' ';
			if (bufRow < BUFFER_ROWS) ch = m_Buffer[bufRow][j];
			m_VideoMemory[i * COLUMNS + j] = (unsigned char)ch | CRT::COLOR;
		}
	}
}
