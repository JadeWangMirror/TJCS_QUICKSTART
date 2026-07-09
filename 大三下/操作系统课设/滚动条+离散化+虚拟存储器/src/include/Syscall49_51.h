#ifndef SYSCALL_49_51_H
#define SYSCALL_49_51_H

#include <sys/types.h>

#define get_ppid() \
	(int)({ \
		int __res; \
		__asm__ __volatile__ ( \
			"int $0x80" \
			: "=a" (__res) \
			: "0" (49) \
		); \
		__res; \
	})

#define get_pids() \
	(int)({ \
		int __res; \
		__asm__ __volatile__ ( \
			"int $0x80" \
			: "=a" (__res) \
			: "0" (50) \
		); \
		__res; \
	})

#define get_proc(text_addr, data_addr, text_size, data_size, stack_size) \
	(int)({ \
		int __res; \
		__asm__ __volatile__ ( \
			"int $0x80" \
			: "=a" (__res) \
			: "0" (51), "b" (text_addr), "c" (data_addr), \
			  "d" (text_size), "S" (data_size), "D" (stack_size) \
		); \
		__res; \
	})

#endif
