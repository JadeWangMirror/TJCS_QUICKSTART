#ifndef CRT_H
#define CRT_H

#include "TTy.h"

class CRT
{
public:
	static const unsigned short VIDEO_ADDR_PORT = 0x3d4;
	static const unsigned short VIDEO_DATA_PORT = 0x3d5;

	static const unsigned int COLUMNS = 80;
	static unsigned int ROWS;
	static const unsigned short COLOR = 0x0F00;

public:
	static void CRTStart(TTy* pTTy);
	static void MoveCursor(unsigned int x, unsigned int y);
	static void NextLine();
	static void BackSpace();
	static void Tab();
	static void WriteChar(char ch);
	static void ClearScreen();

	static void ScrollUp();
	static void ScrollDown();
	static void Refresh();

public:
	static unsigned short* m_VideoMemory;
	static unsigned int m_CursorX;
	static unsigned int m_CursorY;

	static const unsigned int BUFFER_ROWS = 200;
	static char m_Buffer[BUFFER_ROWS][COLUMNS];
	static unsigned int m_WriteRow;
	static int m_ViewStartRow;

	static char* m_Position;
	static char* m_BeginChar;
};

#endif
