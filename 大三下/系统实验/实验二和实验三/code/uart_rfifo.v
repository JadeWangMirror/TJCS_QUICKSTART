//////////////////////////////////////////////////////////////////////
// File:    uart_rfifo.v
// Description: UART 接收 FIFO — 16 字节深度, 11 位宽度
//             数据格式: {break_error, frame_error, parity_error, data[7:0]}
//             支持: 可编程触发级别 (1/4/8/14 字节)
//             触发中断: 当 FIFO 中数据量达到触发级别时
//             内部使用 raminfr 分布式 RAM 实现
//
// === 模块架构说明 ===
// 本模块是UART 16550兼容核的接收(RX) FIFO, 核心功能:
//   1. 数据存储分两层:
//      a) 8位数据: 存入 raminfr 分布式RAM (16x8), 由写指针top寻址写入, 读指针bottom异步读出
//      b) 3位标志: 存入寄存器阵列 fifo[15:0][2:0], 存储 {break_error, frame_error, parity_error}
//   2. 指针管理: top(写指针) / bottom(读指针) 构成循环缓冲区 (circular buffer)
//      - push时将数据写入 top 位置, 然后 top++
//      - pop时从 bottom 位置读出, 然后 bottom++
//      - top和bottom均回绕 (0→1→...→15→0), 由位宽自然截断实现
//   3. 计数器: count 跟踪当前FIFO中有效条目数 (0为空, fifo_depth=16为满)
//   4. 溢出检测: overrun = 1 当FIFO已满(count==depth)且push有效但pop无效时
//   5. 错误汇总: error_bit = OR(所有16个fifo[i][2:0]中的任意位), 用于LSR[7]指示FIFO中有错误数据
//   6. 数据输出: data_out = {fifo[bottom][2:0], data8_out[7:0]}, 即将标志位与RAM数据拼接
//   7. 时序: data_out在pop信号后的下一个时钟周期才有效 (RAM读延迟1拍)
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  uart_rfifo.v (Modified from uart_fifo.v)                    ////
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
////  UART core receiver FIFO                                     ////
////                                                              ////
////  To Do:                                                      ////
////  Nothing.                                                    ////
////                                                              ////
////                                                              ////
////  Created:        2001/05/12                                  ////
////  Last Updated:   2002/07/22                                  ////
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
// The uart_defines.v file is included again in sources.
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
// rx push changed to be only one cycle wide.
//
// Bug that was entered in the last update fixed (rx state machine).
//
// overrun signal was moved to separate block because many sequential lsr
// reads were preventing data from being written to rx fifo.
// underrun signal was not used and was removed from the project.
//
// Lots of fixes:
// Break condition wasn't handled correctly at all.
// LSR bits could lose their values.
// LSR value after reset was wrong.
// Timing of THRE interrupt signal corrected.
// LSR bit 0 timing corrected.
//
// Comments in Slovene language deleted, few small fixes for better work of
// old tools. IRQs need to be fix.
//
// Heavily rewritten interrupt and LSR subsystems.
// Many bugs hopefully squashed.
//
// Small synopsis fixes
//
// Things connected to parity changed.
// Clock devider changed.
//
// FIFO was not cleared after the data was read bug fixed.
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
// Fixed many bugs. Updated spec. Changed FIFO files structure. See CHANGES.txt file.
//
// First 'stable' release. Should be sythesizable now. Also added new header.
//
//
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

`include "uart_defines.v"

module uart_rfifo (clk,            // [时钟] 系统时钟, 上升沿有效, 驱动所有寄存器
	wb_rst_i, data_in, data_out,   // [复位/数据] Wishbone总线复位 / 写入数据[10:0] / 读出数据[10:0]
// Control signals (控制信号)
	push, // [写入脉冲] push strobe, active high — 高有效单周期脉冲, 将data_in压入FIFO顶部
	pop,   // [读出脉冲] pop strobe, active high   — 高有效单周期脉冲, 从FIFO底部弹出一个数据
// status signals (状态信号)
	overrun,    // [溢出标志] FIFO满时仍push则置1, 由reset_status或fifo_reset清除
	count,      // [数据计数] 当前FIFO中有效条目数 [fifo_counter_w-1:0], 范围0~fifo_depth
	error_bit,  // [错误汇总] FIFO中任意条目的break/frame/parity错误位为1时输出1 (LSR[7])
	fifo_reset, // [FIFO复位] 软复位: 清除top/bottom/count及所有fifo标志寄存器
	reset_status // [状态复位] 仅清除overrun标志 (由LSR读操作触发, 不影响数据和指针)
	);


// FIFO parameters (宏定义来源: uart_defines.v)
// `UART_FIFO_WIDTH      = 11  — 数据宽度: 8位纯数据 + 3位错误/状态标志
// `UART_FIFO_DEPTH      = 16  — FIFO深度: 最多存储16个条目
// `UART_FIFO_POINTER_W   = 4   — 指针位宽: ceil(log2(16)) = 4位, 可寻址0~15
// `UART_FIFO_COUNTER_W   = 5   — 计数器位宽: 需表示0~16共17个值, 故需5位
parameter fifo_width = `UART_FIFO_WIDTH;           // FIFO数据位宽 = 11 (8bit data + 3bit flags)
parameter fifo_depth = `UART_FIFO_DEPTH;           // FIFO深度 = 16 条目
parameter fifo_pointer_w = `UART_FIFO_POINTER_W;   // 指针位宽 = 4 (寻址范围 0 ~ 15)
parameter fifo_counter_w = `UART_FIFO_COUNTER_W;   // 计数器位宽 = 5 (计数范围 0 ~ 16)

input				clk;            // 系统时钟: 上升沿触发所有寄存器操作
input				wb_rst_i;       // 同步复位: Wishbone总线复位信号, 高有效, 清除所有状态
input				push;           // 写入使能: 高有效单周期脉冲, 将data_in压入FIFO
input				pop;            // 读出使能: 高有效单周期脉冲, 从FIFO弹出一个数据
input	[fifo_width-1:0]	data_in;        // 写入数据: [10:0] = {break_err[10], frame_err[9], parity_err[8], data[7:0]}
input				fifo_reset;     // FIFO软复位: 清除指针/计数器/所有fifo标志寄存器 (不影响overrun)
input       reset_status;                   // 状态复位: 仅清除overrun标志 (由软件读LSR后触发)

output	[fifo_width-1:0]	data_out;       // 读出数据: [10:0] = {fifo[bottom][2:0]标志, data8_out[7:0]RAM数据}
output				overrun;        // 溢出标志: FIFO满时仍push导致数据丢失, 置1
output	[fifo_counter_w-1:0]	count;          // 有效数据计数: 当前FIFO中存储的条目数量 (0 ~ fifo_depth)
output				error_bit;      // 错误汇总: FIFO中任意条目的错误标志位为1时输出1, 驱动LSR[7]

wire	[fifo_width-1:0]	data_out;  // 数据输出总线: 由连续赋值 assign 驱动 = {fifo[bottom], data8_out}
wire [7:0] data8_out;                    // RAM读出数据: 8位纯数据字节 (不含3位错误标志), 来自raminfr的dpo端口

// === flags FIFO: 16条目 x 3位寄存器阵列 ===
// 每个条目 fifo[i] 存储3位: [2]=break_error(线路断开), [1]=frame_error(帧错误), [0]=parity_error(奇偶校验错误)
// 该寄存器阵列与raminfr中存储的8位数据在逻辑上属于同一个11位宽FIFO条目
// 写入: push时 data_in[2:0] → fifo[top] (标志位单独写入寄存器阵列)
// 读出: pop时 fifo[bottom] 被清零 (标志位清除)
reg	[2:0]	fifo[fifo_depth-1:0];

// === FIFO读写指针: 循环缓冲区寻址 ===
reg	[fifo_pointer_w-1:0]	top;    // top = 写指针: 指向下一次push操作写入的位置 (写入后top+1)
reg	[fifo_pointer_w-1:0]	bottom; // bottom = 读指针: 指向下一次pop操作读出的位置 (读出后bottom+1)
// 注: top和bottom均为4位, 当计数到15后自动回绕到0, 实现循环缓冲区 (circular buffer)

reg	[fifo_counter_w-1:0]	count;  // 有效数据计数器: 范围0~fifo_depth, 0=FIFO空, fifo_depth=16=FIFO满
reg				overrun;              // 溢出标志: FIFO满时仍push则置1, 由reset_status或fifo_reset清除

// top_plus_1: 预计算下一个写指针值 (组合逻辑)
// 用于push操作时更新top, 避免在每个case分支中重复计算
// 由于top是4位, +1后若top=15则自动回绕到0 (由位宽自然截断实现模16运算)
wire [fifo_pointer_w-1:0] top_plus_1 = top + 1'b1;

	// === raminfr: 分布式RAM实例 — 16x8位数据存储 (纯数据字节) ===
	// 参数 #(地址宽度, 数据宽度, 深度):
	//   地址宽度 = fifo_pointer_w(4) — 4位地址, 可寻址16个位置
	//   数据宽度 = 8 — 存储8位纯数据字节
	//   深度 = fifo_depth(16) — 16个存储位置
	// 端口说明:
	//   .clk(clk)    — 时钟输入, 上升沿同步写入
	//   .we(push)    — 写使能: push=1时, 在clk上升沿将di数据写入地址a
	//   .a(top)      — 写地址: 由写指针top驱动, 决定数据写入位置
	//   .dpra(bottom) — 读地址: 由读指针bottom驱动, 异步读出 (组合逻辑, 无时钟延迟)
	//   .di(...)      — 写入数据: data_in的低8位 data_in[7:0] (纯数据字节)
	//   .dpo(data8_out) — 读出数据: 从地址dpra异步读出的8位数据
	// 关键设计: 3位标志信息不存入RAM, 而是存入独立的寄存器阵列fifo[], 这样RAM只需8位宽
raminfr #(fifo_pointer_w,8,fifo_depth) rfifo  
        (.clk(clk), 
			.we(push), 
			.a(top), 
			.dpra(bottom), 
			.di(data_in[fifo_width-1:fifo_width-8]), 
			.dpo(data8_out)
		); 

	// ================================
	// === FIFO主状态机: Push/Pop 逻辑 ===
	// ================================
	// 本always块实现FIFO核心的循环缓冲区读写操作, 在clk上升沿触发:
	//   - 复位(wb_rst_i/fifo_reset): 清零top, bottom, count及所有fifo标志寄存器
	//   - push操作(2'b10): 将数据写入top位置, top+1, count+1
	//   - pop操作(2'b01): 清空bottom位置的标志位, bottom+1, count-1
	//   - 同时push/pop(2'b11): top和bottom均+1, count不变 (进出平衡)
	// 状态编码: {push, pop} 组成2位控制字
	//   2'b00 - 空闲: 无操作, 所有寄存器和指针保持不变
	//   2'b10 - push: 写入一个数据项 (条件: count < fifo_depth, FIFO未满)
	//   2'b01 - pop: 读出一个数据项 (条件: count > 0, FIFO非空)
	//   2'b11 - push+pop: 同时读写 (条件: 无限制, count不变)
	// 注意: #1 是仿真延迟, 综合工具会忽略
begin
	if (wb_rst_i)	// wb_rst_i总线复位: 清除所有状态
	begin
		top		<= #1 0;	// 写指针清零
		bottom		<= #1 1'b0;	// 读指针清零
		count		<= #1 0;	// 有效数据计数清零
		fifo[0] <= #1 0;	// 清除fifo[0]标志位
		fifo[1] <= #1 0;	// 清除fifo[1]标志位
		fifo[2] <= #1 0;	// 清除fifo[2]标志位
		fifo[3] <= #1 0;	// 清除fifo[3]标志位
		fifo[4] <= #1 0;	// 清除fifo[4]标志位
		fifo[5] <= #1 0;	// 清除fifo[5]标志位
		fifo[6] <= #1 0;	// 清除fifo[6]标志位
		fifo[7] <= #1 0;	// 清除fifo[7]标志位
		fifo[8] <= #1 0;	// 清除fifo[8]标志位
		fifo[9] <= #1 0;	// 清除fifo[9]标志位
		fifo[10] <= #1 0;	// 清除fifo[10]标志位
		fifo[11] <= #1 0;	// 清除fifo[11]标志位
		fifo[12] <= #1 0;	// 清除fifo[12]标志位
		fifo[13] <= #1 0;	// 清除fifo[13]标志位
		fifo[14] <= #1 0;	// 清除fifo[14]标志位
		fifo[15] <= #1 0;	// 清除fifo[15]标志位
	end
	else
	if (fifo_reset) begin	// fifo_reset软复位: 与总线复位相同, 清除所有状态
		top		<= #1 0;	// 写指针清零
		bottom		<= #1 1'b0;	// 读指针清零
		count		<= #1 0;	// 有效数据计数清零
		fifo[0] <= #1 0;	// 清除fifo[0]标志位
		fifo[1] <= #1 0;	// 清除fifo[1]标志位
		fifo[2] <= #1 0;	// 清除fifo[2]标志位
		fifo[3] <= #1 0;	// 清除fifo[3]标志位
		fifo[4] <= #1 0;	// 清除fifo[4]标志位
		fifo[5] <= #1 0;	// 清除fifo[5]标志位
		fifo[6] <= #1 0;	// 清除fifo[6]标志位
		fifo[7] <= #1 0;	// 清除fifo[7]标志位
		fifo[8] <= #1 0;	// 清除fifo[8]标志位
		fifo[9] <= #1 0;	// 清除fifo[9]标志位
		fifo[10] <= #1 0;	// 清除fifo[10]标志位
		fifo[11] <= #1 0;	// 清除fifo[11]标志位
		fifo[12] <= #1 0;	// 清除fifo[12]标志位
		fifo[13] <= #1 0;	// 清除fifo[13]标志位
		fifo[14] <= #1 0;	// 清除fifo[14]标志位
		fifo[15] <= #1 0;	// 清除fifo[15]标志位
	end
  else
	begin
		case ({push, pop})
		2'b10 : if (count<fifo_depth)  // 2'b10 = push only: 仅写入 (条件: count < fifo_depth, FIFO未满)
			begin
				top       <= #1 top_plus_1;	// 写指针递增: top = top + 1, 指向下一个空闲位置
				fifo[top] <= #1 data_in[2:0];	// 将3位错误标志 {break, frame, parity} 写入标志寄存器阵列
				count     <= #1 count + 1'b1;	// 有效数据计数+1
			end
		2'b01 : if(count>0)	// 2'b01 = pop only: 仅读出 (条件: count > 0, FIFO非空)
			begin
        fifo[bottom] <= #1 0;	// 清除刚读出条目的错误标志位 (标志位清零)
				bottom   <= #1 bottom + 1'b1;	// 读指针递增: bottom = bottom + 1, 指向下一个待读条目
				count	 <= #1 count - 1'b1;	// 有效数据计数-1
			end
		2'b11 : begin	// 2'b11 = push+pop 同时操作: 写入一个同时读出一个, count不变
				bottom   <= #1 bottom + 1'b1;	// 读指针递增 (pop侧), 为push腾出空间
				top       <= #1 top_plus_1;	// 写指针递增: top = top + 1, 指向下一个空闲位置
				fifo[top] <= #1 data_in[2:0];	// 将3位错误标志 {break, frame, parity} 写入标志寄存器阵列
		        end
    default: ;	// 2'b00 = 空闲: 无操作, 所有寄存器和指针保持不变
		endcase
	end
end   // always

	// ============================================
	// === Overrun (溢出) 检测/清除逻辑 ===
	// ============================================
	// 本always块独立管理overrun信号 (组合逻辑风格描述):
	//   置位条件: push & ~pop & count==fifo_depth
	//   即: push有效 且 pop无效 且 FIFO已满 -> 新数据无法存入, overrun=1 (数据丢失指示)
	//   清除条件 (优先级从高到低):
	//     1. wb_rst_i: 总线复位, 最高优先级
	//     2. fifo_reset | reset_status: FIFO软复位 或 LSR读操作触发的状态复位
	//   注意: overrun是粘性标志位, 置位后不会自动清零, 必须通过上述复位信号清除
	//   这符合16550标准: 软件读取LSR寄存器(reset_status)后overrun被清除
begin
  if (wb_rst_i)	// 最高优先级: Wishbone总线复位清除overrun
    overrun   <= #1 1'b0;	// 清除overrun标志
  else
  if(fifo_reset | reset_status) 	// FIFO软复位 或 LSR读操作: 清除overrun标志
    overrun   <= #1 1'b0;	// 清除overrun标志
  else
  if(push & ~pop & (count==fifo_depth))	// 溢出检测条件: push有效 且 pop无效 且 FIFO已满
    overrun   <= #1 1'b1;	// 置位overrun: 新数据写入时FIFO已满, 数据丢失
end   // always


// data_out: pop后下一时钟周期有效 (RAM异步读有1拍延迟)
assign data_out = {data8_out,fifo[bottom]};	// data_out[10:0] = {fifo[bottom][2:0]标志, data8_out[7:0]数据}

// === error_bit检测逻辑: 为LSR[7]提供FIFO错误汇总 ===
// 功能: 如果FIFO中任何条目的break/frame/parity错误位为1, 则error_bit=1

wire	[2:0]	word0 = fifo[0];	// 读出fifo[0]的3位标志[2:0]到组合逻辑线网word0
wire	[2:0]	word1 = fifo[1];	// 读出fifo[1]的3位标志[2:0]到组合逻辑线网word1
wire	[2:0]	word2 = fifo[2];	// 读出fifo[2]的3位标志[2:0]到组合逻辑线网word2
wire	[2:0]	word3 = fifo[3];	// 读出fifo[3]的3位标志[2:0]到组合逻辑线网word3
wire	[2:0]	word4 = fifo[4];	// 读出fifo[4]的3位标志[2:0]到组合逻辑线网word4
wire	[2:0]	word5 = fifo[5];	// 读出fifo[5]的3位标志[2:0]到组合逻辑线网word5
wire	[2:0]	word6 = fifo[6];	// 读出fifo[6]的3位标志[2:0]到组合逻辑线网word6
wire	[2:0]	word7 = fifo[7];	// 读出fifo[7]的3位标志[2:0]到组合逻辑线网word7

wire	[2:0]	word8 = fifo[8];	// 读出fifo[8]的3位标志[2:0]到组合逻辑线网word8
wire	[2:0]	word9 = fifo[9];	// 读出fifo[9]的3位标志[2:0]到组合逻辑线网word9
wire	[2:0]	word10 = fifo[10];	// 读出fifo[10]的3位标志[2:0]到组合逻辑线网word10
wire	[2:0]	word11 = fifo[11];	// 读出fifo[11]的3位标志[2:0]到组合逻辑线网word11
wire	[2:0]	word12 = fifo[12];	// 读出fifo[12]的3位标志[2:0]到组合逻辑线网word12
wire	[2:0]	word13 = fifo[13];	// 读出fifo[13]的3位标志[2:0]到组合逻辑线网word13
wire	[2:0]	word14 = fifo[14];	// 读出fifo[14]的3位标志[2:0]到组合逻辑线网word14
wire	[2:0]	word15 = fifo[15];	// 读出fifo[15]的3位标志[2:0]到组合逻辑线网word15

// 按位OR归约(|): 16个word中任意位为1则error_bit=1
assign	error_bit = |(word0[2:0]  | word1[2:0]  | word2[2:0]  | word3[2:0]  |	// 16路word按位或: word0 | word1 | ... | word15
            		      word4[2:0]  | word5[2:0]  | word6[2:0]  | word7[2:0]  |	// 继续: word4~word7
            		      word8[2:0]  | word9[2:0]  | word10[2:0] | word11[2:0] |	// 继续: word8~word11
            		      word12[2:0] | word13[2:0] | word14[2:0] | word15[2:0] );	// 完成: word12~word15, 输出error_bit

endmodule
