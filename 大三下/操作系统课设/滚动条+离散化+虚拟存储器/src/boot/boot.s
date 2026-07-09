org 0x7c00

;section .code16
[BITS 16]
start:
		lgdt [gdtr]
		
		cli

		;��a20 ��ַ��
		in al,92h
		or al,00000010b
		out 92h, al

;		start to load sector 1 to memory 
		
		mov eax, cr0;
		or eax, 1;
		mov cr0, eax
				
		jmp dword 0x8:_startup ;

	
;section .code32
[BITS 32]
_startup:

		mov ax, 0x10
		mov ds, ax
		mov es, ax
		mov ss, ax

		mov	ecx, KERNEL_SIZE 	;cx = ������KERNEL_SIZE����Ϊloop�Ĵ���
		mov eax, 1				;LBAѰַģʽ��sector��Ŵ�0��ʼ��  #0������������#1������ʼ����kernel��������
		mov ebx, 0x100000		;Ŀ���ŵ�ַ��1M����ʼ��ÿ��loop����512 bytes
_load_kernel:
		push eax
		inc eax
		
		push ebx
		add	ebx, 512
		call _load_sector
		loop _load_kernel		
		
		;�޸����мĴ�������λ��ַ
		mov ax, 0x20
		mov ds, ax
		mov es, ax
		mov ss, ax
		or esp, 0xc0000000
		jmp 0x18:0xc0100000
		
_load_sector:
	push ebp
	mov ebp,esp
	
	push edx
	push ecx
	push edi
	push eax		
	
	mov al,1		;��1������
	mov dx,1f2h		;�������Ĵ��� 0x1f2
	out dx,al
	
	mov eax,[ebp+12] ;[ebp+12]��Ӧ����mov eax, 1   push eaxָ����ջ��ֵ��eaxΪҪ�����������
					;LBA28(Linear Block Addressing)ģʽ���������ŵ�Bits 7~0�� ��28 Bits������
	inc dx			;�����żĴ��� 0x1f3
	out dx,al
	
	shr eax,8		;LBA28(Linear Block Addressing)ģʽ���������ŵ�Bits 15~8 ����AL�У� ��28 Bits������
	inc dx			;Port��DX = 0x1f3+1 = 0x1f4  
	out dx,al
	
	shr eax,8		;LBA28(Linear Block Addressing)ģʽ���������ŵ�Bits 23~16����AL�У� ��28 Bits������
	inc dx			;Port��DX = 0x1f4+1 = 0x1f5 
	out dx,al
	
	shr eax,8
	and al,0x0f
	or al,11100000b ;Bit(7��5)Ϊ1��ʾ��IDE�ӿڣ�Bit(6)Ϊ1��ʾ����LBA28ģʽ��Bit(4)Ϊ1��ʾ���̡�
					;Bit(3~0)ΪLBA28�е�Bit27~24λ
	inc dx			;Port��DX = 0x1f5+1 = 0x1f6 
	out dx,al
	
	mov al,0x20		;0x20��ʾ��1��sector��0x30��ʾд1��sector
	inc dx			;Port��DX = 0x1f6+1 = 0x1f7 
	out dx,al
	
.test:
	in al,dx
	test al,10000000b
	jnz .test
	
	test al,00001000b
	jz .load_error
	
	
	mov ecx,512/4
	mov dx,0x1f0
	mov edi,[ebp+8]	;ȡ��callǰ��ջ����[ebp+8] = 0x100000  = 1MB
	rep insd
	xor ax,ax
	jmp .load_exit
	
.load_error:
	mov dx,0x1f1
	in al,dx
	xor ah,ah
			
.load_exit:
	
	pop eax		
	pop edi
	pop ecx
	pop edx
	leave		;Destory stack frame
	retn 8		
		
;section .data
KERNEL_SIZE		equ		200	    

gdt:		
		dw	0x0000
		dw	0x0000
		dw	0x0000
		dw	0x0000
		
		dw	0xFFFF		
		dw	0x0000		
		dw	0x9A00		
		dw	0x00CF		
		
		dw	0xFFFF		
		dw	0x0000		
		dw	0x9200		
		dw	0x00CF		
		
		dw	0xFFFF		
		dw	0x0000		
		dw	0x9A00		
		dw	0x40CF		
		
		dw	0xFFFF		
		dw	0x0000		
		dw	0x9200		
		dw	0x40CF		
		
gdtr:
		dw $-gdt		;limit
		dd gdt			;offset

		times 510 - ($ - $$) db 0
		dw 0xAA55
