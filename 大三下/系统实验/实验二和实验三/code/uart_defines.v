//////////////////////////////////////////////////////////////////////
// File:    uart_defines.v
// Description: UART 16550 兼容 IP 核宏定义
//             包含: 寄存器地址、中断使能位、FIFO 控制、线路状态等定义
//             基于 OpenCores UART 16550 项目
//             配置: 32 位数据总线, 5 位地址宽度
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  uart_defines.v                                              ////
////                                                              ////
////                                                              ////
////  This file is part of the "UART 16550 compatible" project    ////
////  http://www.opencores.org/cores/uart16550/                   ////
////                                                              ////
////  Documentation related to this project:                      ////
////  - http://www.opencores.org/cores/uart16550/                 ////
////                                                              ////
////  Projects compatibility:                                     ////
////  - WISHBONE                                                  ////
////  RS232 Protocol                                              ////
////  16550D uart (mostly supported)                              ////
////                                                              ////
////  Overview (main Features):                                   ////
////  Defines of the Core                                         ////
////                                                              ////
////  Known problems (limits):                                    ////
////  None                                                        ////
////                                                              ////
////  To Do:                                                      ////
////  Nothing.                                                    ////
////                                                              ////
////                                                              ////
////  Created:        2001/05/12                                  ////
////  Last Updated:   2001/05/17                                  ////
////                                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
//
// $Log: not supported by cvs2svn $
// This fixes errors in some cases when data is being read and put to the FIFO at the same time. Patch is submitted by Scott Furman. Update is very recommended.
//
// Bug Fixes:
//  * Possible loss of sync and bad reception of stop bit on slow baud rates fixed.
//   Problem reported by Kenny.Tung.
//  * Bad (or lack of ) loopback handling fixed. Reported by Cherry Withers.
//
// Improvements:
//  * Made FIFO's as general inferrable memory where possible.
//  So on FPGA they should be inferred as RAM (Distributed RAM on Xilinx).
//  This saves about 1/3 of the Slice count and reduces P&R and synthesis times.
//
//  * Added optional baudrate output (baud_o).
//  This is identical to BAUDOUT* signal on 16550 chip.
//  It outputs 16xbit_clock_rate - the divided clock.
//  It's disabled by default. Define UART_HAS_BAUDRATE_OUTPUT to use.
//
// Scratch register define added.
//
// Updated specification documentation.
// Added full 32-bit data bus interface, now as default.
// Address is 5-bit wide in 32-bit data bus mode.
// Added wb_sel_i input to the core. It's used in the 32-bit mode.
// Added debug interface with two 32-bit read-only registers in 32-bit mode.
// Bits 5 and 6 of LSR are now only cleared on TX FIFO write.
// My small test bench is modified to work with 32-bit mode.
//
// Lots of fixes:
// Break condition wasn't handled correctly at all.
// LSR bits could lose their values.
// LSR value after reset was wrong.
// Timing of THRE interrupt signal corrected.
// LSR bit 0 timing corrected.
//
// Things connected to parity changed.
// Clock devider changed.
//
// Stop bit bug fixed.
// Parity bug fixed.
// WISHBONE read cycle bug fixed,
// OE indicator (Overrun Error) bug fixed.
// PE indicator (Parity Error) bug fixed.
// Register read bug fixed.
//
// FIFO changes and other corrections.
//
// Corrected some Linter messages.
//
// First 'stable' release. Should be sythesizable now. Also added new header.
//
//
//

// 数据总线宽度选择:
// 取消下面注释可切换至8位数据总线接口模式(与旧版OR1200不兼容)
// 在32位总线模式下，wb_sel_i信号用于将数据放入正确位置
// 8位版本不包含调试功能
// CAUTION: doesn't work with current version of OR1200
//`define DATA_BUS_WIDTH_8

// 8位/32位数据总线模式条件编译选择
`ifdef DATA_BUS_WIDTH_8
 `define UART_ADDR_WIDTH 3	// 8位模式: 地址宽度3位 (8个寄存器)
 `define UART_DATA_WIDTH 8	// 8位模式: 数据总线宽度8位
`else
 `define UART_ADDR_WIDTH 5	// 32位模式: 地址宽度5位 (32个寄存器)
 `define UART_DATA_WIDTH 32	// 32位模式: 数据总线宽度32位
`endif

// Uncomment this if you want your UART to have
// 16xBaudrate output port.
// If defined, the enable signal will be used to drive baudrate_o signal
// It's frequency is 16xbaudrate

// `define UART_HAS_BAUDRATE_OUTPUT

// 寄存器地址定义 (Register addresses)
// 基地址 + 偏移量, 与16550兼容
`define UART_REG_RB	`UART_ADDR_WIDTH'd0	// 接收缓冲寄存器 (Receiver Buffer, 只读)
`define UART_REG_TR  `UART_ADDR_WIDTH'd0	// 发送保持寄存器 (Transmitter Holding, 只写)
`define UART_REG_IE	`UART_ADDR_WIDTH'd1	// 中断使能寄存器 (Interrupt Enable)
`define UART_REG_II  `UART_ADDR_WIDTH'd2	// 中断标识寄存器 (Interrupt Identification, 只读)
`define UART_REG_FC  `UART_ADDR_WIDTH'd2	// FIFO控制寄存器 (FIFO Control, 只写)
`define UART_REG_LC	`UART_ADDR_WIDTH'd3	// 线路控制寄存器 (Line Control)
`define UART_REG_MC	`UART_ADDR_WIDTH'd4	// 调制解调器控制寄存器 (Modem Control)
`define UART_REG_LS  `UART_ADDR_WIDTH'd5	// 线路状态寄存器 (Line Status)
`define UART_REG_MS  `UART_ADDR_WIDTH'd6	// 调制解调器状态寄存器 (Modem Status)
`define UART_REG_SR  `UART_ADDR_WIDTH'd7	// 暂存寄存器 (Scratch Register)
`define UART_REG_DL1	`UART_ADDR_WIDTH'd0	// 除数锁存器低字节 (Divisor Latch LSB, 需DLAB=1)
`define UART_REG_DL2	`UART_ADDR_WIDTH'd1	// 除数锁存器高字节 (Divisor Latch MSB, 需DLAB=1)

// 中断使能寄存器(IER)位定义 (Interrupt Enable register bits)
// 写1使能对应中断, 写0禁止对应中断
`define UART_IE_RDA	0	// 接收数据可用中断使能 (Received Data Available)
`define UART_IE_THRE	1	// 发送保持寄存器空中断使能 (Transmitter Holding Register Empty)
`define UART_IE_RLS	2	// 接收线路状态中断使能 (Receiver Line Status)
`define UART_IE_MS	3	// 调制解调器状态中断使能 (Modem Status)

// 中断标识寄存器(IIR)位定义 (Interrupt Identification register bits)
`define UART_II_IP	0	// 中断挂起标志位 (Interrupt Pending): 0=有中断挂起, 1=无中断
`define UART_II_II	3:1	// 中断标识位[3:1] (Interrupt Identification): 编码指示当前最高优先级中断类型

// 中断标识码定义 (Interrupt identification values for bits 3:1)
// 优先级从高到低: RLS > RDA > TI > THRE > MS
`define UART_II_RLS	3'b011	// 接收线路状态中断 (Receiver Line Status) —— 优先级最高
`define UART_II_RDA	3'b010	// 接收数据可用中断 (Receiver Data Available)
`define UART_II_TI	3'b110	// 接收超时中断 (Timeout Indication) —— FIFO模式下有效
`define UART_II_THRE	3'b001	// 发送保持寄存器空中断 (Transmitter Holding Register Empty)
`define UART_II_MS	3'b000	// 调制解调器状态中断 (Modem Status) —— 优先级最低

// FIFO控制寄存器(FCR)位定义 (FIFO Control Register bits)
`define UART_FC_TL	1:0	// 接收FIFO触发等级位[1:0] (Trigger Level): 设置RX FIFO触发中断的阈值

// FIFO触发等级值定义 (FIFO trigger level values)
// 当接收FIFO中数据字节数达到该阈值时, 触发接收数据可用中断
`define UART_FC_1		2'b00	// 触发等级: 1字节
`define UART_FC_4		2'b01	// 触发等级: 4字节
`define UART_FC_8		2'b10	// 触发等级: 8字节
`define UART_FC_14	2'b11	// 触发等级: 14字节

// 线路控制寄存器(LCR)位定义 (Line Control register bits)
`define UART_LC_BITS	1:0	// 数据位长度[1:0] (Word Length): 00=5位, 01=6位, 10=7位, 11=8位
`define UART_LC_SB	2	// 停止位位数 (Stop Bits): 0=1个停止位, 1=1.5或2个停止位(取决于数据位长度)
`define UART_LC_PE	3	// 奇偶校验使能 (Parity Enable): 1=使能校验位生成与检测
`define UART_LC_EP	4	// 偶校验选择 (Even Parity): 0=奇校验, 1=偶校验 (仅在PE=1时有效)
`define UART_LC_SP	5	// 固定校验位 (Stick Parity): 与EP和PE配合, 强制校验位为固定值
`define UART_LC_BC	6	// 间断控制 (Break Control): 1=强制SOUT输出为逻辑0(发送间断信号)
`define UART_LC_DL	7	// 除数锁存访问位 (Divisor Latch Access Bit): 1=访问DL1/DL2, 0=访问RB/TR/IE

// 调制解调器控制寄存器(MCR)位定义 (Modem Control register bits)
`define UART_MC_DTR	0	// 数据终端就绪 (Data Terminal Ready): 1=使能DTR#输出(低有效)
`define UART_MC_RTS	1	// 请求发送 (Request To Send): 1=使能RTS#输出(低有效)
`define UART_MC_OUT1	2	// 辅助输出1 (Output1): 用户自定义输出, 环回模式下内部连接RI#
`define UART_MC_OUT2	3	// 辅助输出2 (Output2): 用户自定义输出, 环回模式下内部连接DCD#
`define UART_MC_LB	4	// 环回模式 (Loopback): 1=使能本地环回测试模式

// 线路状态寄存器(LSR)位定义 (Line Status Register bits)
`define UART_LS_DR	0	// 数据就绪 (Data Ready): 1=接收缓冲器中有数据, 读取RB后清零
`define UART_LS_OE	1	// 溢出错误 (Overrun Error): 接收缓冲器被覆盖, 读取LSR后清零
`define UART_LS_PE	2	// 奇偶校验错误 (Parity Error): 接收数据校验错误, 读取LSR后清零
`define UART_LS_FE	3	// 帧错误 (Framing Error): 未检测到有效停止位, 读取LSR后清零
`define UART_LS_BI	4	// 间断中断 (Break Interrupt): 检测到间断条件(连续0超过一个帧), 读取LSR后清零
`define UART_LS_TFE	5	// 发送FIFO空 (Transmit FIFO Empty): TX FIFO中无数据, 写入THR后清零
`define UART_LS_TE	6	// 发送器空 (Transmitter Empty): 发送FIFO和移位寄存器均为空
`define UART_LS_EI	7	// 错误指示 (Error in RX FIFO): RX FIFO中至少有一个错误(PE/FE/BI)

// 调制解调器状态寄存器(MSR)位定义 (Modem Status Register bits)
// 低4位(Delta位): 自上次读取MSR以来对应输入是否发生变化, 1=有变化
// 高4位(Complement位): 对应输入信号的当前反相状态
`define UART_MS_DCTS	0	// CTS变化标志 (Delta CTS): 自上次读取MSR后CTS#输入发生变化
`define UART_MS_DDSR	1	// DSR变化标志 (Delta DSR): 自上次读取MSR后DSR#输入发生变化
`define UART_MS_TERI	2	// RI下降沿标志 (Trailing Edge RI): 自上次读取MSR后RI#发生从低到高跳变
`define UART_MS_DDCD	3	// DCD变化标志 (Delta DCD): 自上次读取MSR后DCD#输入发生变化
`define UART_MS_CCTS	4	// CTS反相状态 (Complement of CTS): CTS#输入的当前反相值
`define UART_MS_CDSR	5	// DSR反相状态 (Complement of DSR): DSR#输入的当前反相值
`define UART_MS_CRI	6	// RI反相状态 (Complement of RI): RI#输入的当前反相值
`define UART_MS_CDCD	7	// DCD反相状态 (Complement of DCD): DCD#输入的当前反相值

// FIFO参数定义 (FIFO parameter defines)
// 发送FIFO参数
`define UART_FIFO_WIDTH	8	// FIFO数据宽度: 8位 (一个字节)
`define UART_FIFO_DEPTH	16	// FIFO深度: 16字节 (16550标准)
`define UART_FIFO_POINTER_W	4	// FIFO指针位宽: 4位 (可寻址16个位置, 2^4=16)
`define UART_FIFO_COUNTER_W	5	// FIFO计数器位宽: 5位 (可表示0~16共17种状态)
// 接收FIFO宽度为11位, 因为除了8位数据外还需存储break、parity和framing error标志位
`define UART_FIFO_REC_WIDTH  11	// 接收FIFO宽度: 11位 = 8bit数据 + 3bit错误标志


// 仿真调试与测试配置 (Simulation debug and test configuration)
`define VERBOSE_WB  0           // WISHBONE总线行为记录开关: 1=记录所有WISHBONE总线操作, 0=关闭
`define VERBOSE_LINE_STATUS 0   // 线路状态详细记录开关: 1=记录LSR(线路状态寄存器)的详细变化, 0=关闭
`define FAST_TEST   1           // 快速测试模式: 1=仅发送64/1024个数据包(加速仿真), 0=发送完整数量数据包







