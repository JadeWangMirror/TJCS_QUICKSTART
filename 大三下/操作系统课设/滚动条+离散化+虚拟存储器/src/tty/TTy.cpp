#include "TTy.h"
#include "Assembly.h"
#include "Kernel.h"
#include "CRT.h"
#include "Video.h"

/*==============================class TTy_Queue===============================*/
TTy_Queue::TTy_Queue()
{
	this->m_Head = 0;
	this->m_Tail = 0;
}

TTy_Queue::~TTy_Queue()
{
	//nothing to do here
}

char TTy_Queue::GetChar()
{
	char ch = TTy::GET_ERROR;
	{
		if ( this->m_Head == this->m_Tail )
		{
			//Buffer Empty
			return ch;
		}
	}

	ch = this->m_CharBuf[m_Tail];
	this->m_Tail = ( this->m_Tail + 1 ) % TTY_BUF_SIZE;

	return ch;
}

void TTy_Queue::PutChar(char ch)
{
	this->m_CharBuf[m_Head] = ch;
	this->m_Head = ( this->m_Head + 1 ) % TTY_BUF_SIZE;
}

int TTy_Queue::CharNum()
{
	/* ��Head < Tailʱʹ��%���������⣡������'&'���㡣
	 *  Ʃ���±�Head = 5��Tail = 10�� (5 - 10) %  TTY_BUF_SIZE ��
	 *  �ᱻ����0xFFFF FFFB  ( =4294967291) ȥģ����TTY_BUF_SIZE������ʹ��ˡ�
	 */
	// unsigned int ans = this->m_Head - this->m_Tail;
	// ans = ans % TTY_BUF_SIZE;
	// return ans;
	
	int ans = (this->m_Head - this->m_Tail) & (TTy_Queue::TTY_BUF_SIZE - 1);
	return ans;
}

char* TTy_Queue::CurrentChar()
{
	/* ������һ����Ҫȡ���ַ��ĵ�ַ */
	return &this->m_CharBuf[m_Tail];
}

/*==============================class TTy===============================*/
/* ����̨����ʵ���Ķ��� */
TTy g_TTy;

TTy::TTy()
{

}

TTy::~TTy()
{

}

/*
 * �ӱ�׼�������ȡ�ַ������û���
 * ֱ������Ϊ�գ�������Ӧ�ó���֮���裨u.u_IOParam.m_Count Ϊ  0��
 * ��䣬�����п�����˯����һ���� ��Ϊ��׼�������Ϊ�գ���ԭʼ���������û�ж����
 * ���û�û������س��������ܶ�ԭʼ�����е��������ݽ����޸ģ�
 * */
void TTy::TTRead()
{
	/* �豸û�п�ʼ���������� */
	if ( (this->t_state & TTy::CARR_ON) == 0 )
	{
		return;
	}

	if ( this->t_canq.CharNum() || this->Canon() )
	{
		while ( this->t_canq.CharNum() && (this->PassC(this->t_canq.GetChar()) >= 0) );
	}
}

/*
 * һ��һ���ֽڵؽ��û����еȴ�����������ͱ�׼������С�
 * ��������������������ˢ�����Դ档 ������̻��������ˢ�¡�
 * ����CRT::m_BeginChar����ָ����������д����һ���ַ��ĵ�Ԫ��BackSpace�����Բ�����ָ��֮ǰ���κ��ַ���
 */
void TTy::TTWrite()
{
	/* 
	 * ��Ϊ���ڵ�����豸���ڴ棬����Ӧ�ٶ��൱�죬����
	 * ����Ҫ�ڽ������Ժ����жϣ������Ĵ��۷ǳ������
	 * ԭ��unix v6����Щ��ͬ����������������ַ��Ĺ����й�
	 * �ж�����ֹ�û����뵫���ܱ�����ɾ����bug,����Ϊ����
	 * ���ܻᵼ��ʱ���ж���Ӧ���ӳ٣��������������أ���
	 * ��û����������
	 */
	char ch;
	
	 /* �豸û�п�ʼ���������� */
	if ( (this->t_state & TTy::CARR_ON) == 0 )
	{
		return;
	}

	while ( (ch = CPass()) > 0 )
	{
		/*��������г����涨�ַ�������Ҫ�Ͽ���ʾ */
		if ( this->t_outq.CharNum() > TTy::TTHIWAT)
		{
			this->TTStart();
			// CRT::m_BeginChar = this->t_outq.CurrentChar();
		}
		this->TTyOutput(ch);
	}
	this->TTStart();
	// CRT::m_BeginChar = this->t_outq.CurrentChar();
	/* ����BeginCharΪ�˷�ֹ����ɾ����ӡ���ַ���������Ҫ�����ʾ���棬�������ǰ���������
	 * ���ַ��ڱ�ɾ��ʱ�����ܱ�ɾ����������ʵ�����Ѿ���ɾ���ˡ�
	 */
}

/* ���жϴ���������á�����ch��ɨ����ת���ɵ�ASCII�롣
 * ���ܣ���ch����ԭʼ������У���������л��� ���ͱ�׼������У�֮������TTStart���Դ棩
 * �����дֲڵĵط���this->t_rawq.PutChar(ch) ֮ǰû���ж�ԭʼ���������û��������ɵĽ����ԭʼ������ԭ������
 * ���ַ���ɾ����
 * ԭʼ���������ֻ��˵��һ�����⣺û�н����ڵȴ��������롣
 * ���� �Ľ�ϵͳ��TTyInput���������жϣ�û�н���˯�ߵȴ����������ʱ�򣬲�Ҫ��ch����ԭʼ���С�
 * */
void TTy::TTyInput(char ch)
{
//	if ( (ch &= 0xFF) == '\r' && (this->t_flags & TTy::CRMOD) )
//	{
//		ch = '\n';
//	}

	/* �����Сд�ն� */
//	if ( (this->t_flags & TTy::LCASE) && ch >= 'A' && ch <= 'Z' )
//	{
//		ch += 'a' - 'A';
//	}

	/* ���ع�����ݼ� */
	if (ch == 0x05) // Ctrl+E: CRT Scroll Up
	{
		CRT::ScrollUp();
		return;
	}
	if (ch == 0x04) // Ctrl+D: CRT Scroll Down
	{
		int maxViewRow = (int)CRT::m_WriteRow - (int)CRT::ROWS + 1;
		if (maxViewRow < 0) maxViewRow = 0;
		if (CRT::m_ViewStartRow < maxViewRow) { CRT::ScrollDown(); return; }
	}
	if (ch == 0x12) // Ctrl+R: Diagnose Scroll Up
	{
		Diagnose::ScrollUp();
		return;
	}
	if (ch == 0x06) // Ctrl+F: Diagnose Scroll Down
	{
		Diagnose::ScrollDown();
		return;
	}

	/* 将字符放入原始字符队列 */
	this->t_rawq.PutChar(ch);

	if ( ch == '\n' || ch == TTy::CEOT || ch == 0x13 || ch == 0x17 || ch == 0x09 || ch == 0x08 || ch == 0x7F )
	{
		Kernel::Instance().GetProcessManager().WakeUpAll((unsigned long)&this->t_rawq);
		this->t_rawq.PutChar(0x7);
		this->t_delct++;
	}

	if ( this->t_flags & TTy::ECHO )
	{
		/* 控制字符不回显，由 shell 自行处理显示 */
		if ( ch != 0x13 && ch != 0x17 && ch != 0x09 && ch != TTy::CEOT && ch != 0x08 && ch != 0x7F )
		{
			this->TTyOutput(ch);
			this->TTStart();
		}
	}
}

void TTy::TTyOutput(char ch)
{
	/* ��������ַ�Ϊ�ļ��������������ն˹�����ԭʼ��ʽ�£��򷵻� */
	 /*if ( (ch &= 0xFF) == TTy::CEOT && (this->t_flags & TTy::RAW) == 0 )
	{
		return;
	}

	if ( '\n' == ch && (this->t_flags & TTy::CRMOD) )
	{
		this->TTyOutput('\r');
	} */

	/* ���ַ���������ַ���������� */
	if (ch)
	{
		this->t_outq.PutChar(ch);
	}
}

void TTy::TTStart()
{
	CRT::CRTStart(this);
}

void TTy::FlushTTy()
{
	while ( this->t_canq.GetChar() >= 0 );
	while ( this->t_outq.GetChar() >= 0 );
	Kernel::Instance().GetProcessManager().WakeUpAll((unsigned long)&this->t_canq);
	Kernel::Instance().GetProcessManager().WakeUpAll((unsigned long)&this->t_outq);
	
	X86Assembly::CLI();
	while ( this->t_rawq.GetChar() >= 0 );
	this->t_delct = 0;
	X86Assembly::STI();
}

int TTy::Canon()
{
     char* pChar;
     char ch;
     User& u = Kernel::Instance().GetUser();

     X86Assembly::CLI();
     while ( this->t_delct == 0 )   // ԭʼ�����޻س�����û�п����͸�Ӧ�ó�������ݣ�˯�ߵȴ��û�����س���
     {
         if ( (this->t_state & TTy::CARR_ON) == 0 )
        	 return 0;   // �豸û�򿪣�����
         u.u_procp->Sleep((unsigned long)&this->t_rawq, ProcessManager::TTIPRI);
     }
    X86Assembly::STI();

    // ����ԭʼ�����е��ַ�������canon����
    pChar = &Canonb[0];

    while ( (ch = this->t_rawq.GetChar()) >= 0 )    // ��ԭʼ����ȡһ���ַ�������Canonb���С�
    {
        if ( 0x7 == ch )		/* �Ƕ����*/
        {
        	this->t_delct--;     //  ԭʼ��������--
        	break;
        }

       if ( ch == this->t_erase )     	/* backspace: 透传给 shell 自行处理 */
       {
           *pChar++ = ch;
           continue;
       }

       if ( ch == TTy::CEOT )	/* CEOT == 0x4������ ctrl + d�� */
    	   continue;       		/* ���ļ���������û������������ */

       *pChar++ = ch;       		/* ����ͨ�ַ�������Canonb���� */

       if ( pChar >= Canonb + TTy::CANBSIZ )
    	   break;    			/* Canonb���������ء�����ʣ���ַ����´�Canon����ִ��ʱ��ȡ */
    }

    char* pEnd = pChar;
    pChar = &Canonb[0];

    while ( pChar < pEnd )
        this->t_canq.PutChar(*pChar++);   /* ��Cannonb�����д��������ַ��ͱ�׼���� */

    return 1;
}

int TTy::PassC(char ch)
{
	User& u = Kernel::Instance().GetUser();

	/* ���ַ������û�Ŀ���� */
	if ( u.u_IOParam.m_Count > 0 )
	{
		*(u.u_IOParam.m_Base++) = ch;
		//u.u_IOParam.m_Offset++;
		u.u_IOParam.m_Count--;
		return 0;
	}
	return -1;
}

char TTy::CPass()
{
	char ch;
	User& u = Kernel::Instance().GetUser();

	ch = *(u.u_IOParam.m_Base++);
	if ( u.u_IOParam.m_Count > 0 )
	{
		u.u_IOParam.m_Count--;
		//u.u_IOParam.m_Offset++;
		return ch;
	}
	else
	{
		return -1;
	}
}



