//////////////////////////////////////////////////////////////////////
////                                                              ////
////  uart_transmitter.v                                          ////
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
////  UART core transmitter logic                                 ////
////                                                              ////
////  Known problems (limits):                                    ////
////  None known                                                  ////
////                                                              ////
////  To Do:                                                      ////
////  Thourough testing.                                          ////
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
// tf_pop was too wide. Now it is only 1 clk cycle width.
//
// overrun signal was moved to separate block because many sequential lsr
// reads were preventing data from being written to rx fifo.
// underrun signal was not used and was removed from the project.
//
// Updated specification documentation.
// Added full 32-bit data bus interface, now as default.
// Address is 5-bit wide in 32-bit data bus mode.
// Added wb_sel_i input to the core. It's used in the 32-bit mode.
// Added debug interface with two 32-bit read-only registers in 32-bit mode.
// Bits 5 and 6 of LSR are now only cleared on TX FIFO write.
// My small test bench is modified to work with 32-bit mode.
//
// Comments in Slovene language deleted, few small fixes for better work of
// old tools. IRQs need to be fix.
//
// Heavily rewritten interrupt and LSR subsystems.
// Many bugs hopefully squashed.
//
// fixed parity sending and tx_fifo resets over- and underrun
//
// Small synopsis fixes
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
// DL made 16-bit long. Fixed transmission/reception bugs.
//
// Fixed receiver and transmitter. Major bug fixed.
//
// FIFO changes and other corrections.
//
// Fixed many bugs. Updated spec. Changed FIFO files structure. See CHANGES.txt file.
//
// Corrected some Linter messages.
//
// First 'stable' release. Should be sythesizable now. Also added new header.
//
//
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

`include "uart_defines.v"

module uart_transmitter (clk, wb_rst_i, lcr, tf_push, wb_dat_i, enable,	stx_pad_o, tstate, tf_count, tx_reset, lsr_mask);  // [发送器模块] UART发送器 — 含TX FIFO和发送状态机

input 										clk;                 // [时钟] 系统时钟输入
input 										wb_rst_i;            // [复位] Wishbone总线复位, 高有效
input [7:0] 								lcr;                 // [线路控制] 线路控制寄存器 (数据位/停止位/校验配置)
input 										tf_push;             // [FIFO写入] 发送FIFO写入选通, 高有效单周期脉冲
input [7:0] 								wb_dat_i;            // [数据输入] WISHBONE数据总线输入 (写入TX FIFO的数据)
input 										enable;              // [使能] 波特率使能信号 (16x时钟频率)
input 										tx_reset;            // [发送复位] 发送器软复位 (清空TX FIFO)
input 										lsr_mask; //reset of fifo  // [状态复位] LSR读操作触发, 清除TX FIFO overrun标志
output 										stx_pad_o;           // [串行输出] 串行发送数据输出引脚
output [2:0] 								tstate;              // [状态输出] 发送状态机当前状态
output [`UART_FIFO_COUNTER_W-1:0] 	tf_count;            // [FIFO计数] 发送FIFO当前有效条目数

reg [2:0] 									tstate;              // [状态寄存器] 发送状态机状态 (3位: s_idle/s_send_start/s_send_byte/s_send_parity/s_send_stop/s_pop_byte)
reg [4:0] 									counter;             // [计数器] 波特率分频计数器 (5位, 0~15, 用于16x过采样)
reg [2:0] 									bit_counter;   // counts the bits to be sent  // [位计数器] 当前字还需发送的数据位数
reg [6:0] 									shift_out;	// output shift register  // [移位寄存器] 输出移位寄存器, 存放待发送的7位数据
reg 											stx_o_tmp;           // [输出暂存] 串行输出暂存器 (最终输出前不考虑break条件)
reg 											parity_xor;  // parity of the word  // [校验异或] 当前字的奇偶校验计算结果
reg 											tf_pop;              // [FIFO读出] 发送FIFO pop选通, 高有效单周期脉冲
reg 											bit_out;             // [位输出] 当前发送位的值 (0或1)

// TX FIFO instance                           // 发送FIFO实例
//
// Transmitter FIFO signals                   // 发送器FIFO信号
wire [`UART_FIFO_WIDTH-1:0] 			tf_data_in;        // [FIFO输入] 发送FIFO写入数据
wire [`UART_FIFO_WIDTH-1:0] 			tf_data_out;       // [FIFO输出] 发送FIFO读出数据
wire 											tf_push;             // [FIFO写入选通] 发送FIFO push信号 (来自外部)
wire 											tf_overrun;          // [FIFO溢出] 发送FIFO溢出标志
wire [`UART_FIFO_COUNTER_W-1:0] 		tf_count;            // [FIFO计数] 发送FIFO当前条目数

assign 										tf_data_in = wb_dat_i;  // [数据连接] 发送FIFO输入直接取自WISHBONE数据总线

uart_tfifo fifo_tx(	// error bit signal is not used in transmitter FIFO  // [TX FIFO实例] 发送FIFO (错误位信号在发送器中未使用)
	.clk(		clk		),                   // 时钟连接
	.wb_rst_i(	wb_rst_i	),                // 复位连接
	.data_in(	tf_data_in	),               // 数据输入连接
	.data_out(	tf_data_out	),              // 数据输出连接
	.push(		tf_push		),               // push选通连接
	.pop(		tf_pop		),                // pop选通连接
	.overrun(	tf_overrun	),              // 溢出标志连接
	.count(		tf_count	),               // 计数输出连接
	.fifo_reset(	tx_reset	),           // FIFO软复位连接
	.reset_status(lsr_mask)                  // 状态复位连接
);

// TRANSMITTER FINAL STATE MACHINE            // 发送器最终状态机

parameter s_idle        = 3'd0;              // [状态0] 空闲: 等待FIFO中有数据
parameter s_send_start  = 3'd1;              // [状态1] 发送起始位: 输出低电平1个位周期
parameter s_send_byte   = 3'd2;              // [状态2] 发送数据位: 逐位发送5~8位数据
parameter s_send_parity = 3'd3;              // [状态3] 发送校验位: 发送1位奇偶校验 (可选)
parameter s_send_stop   = 3'd4;              // [状态4] 发送停止位: 输出高电平1/1.5/2个位周期
parameter s_pop_byte    = 3'd5;              // [状态5] 弹出数据: 从TX FIFO读取下一个待发送字节

begin                                        // [时序逻辑] 发送状态机主逻辑 (always块省略敏感列表)
  if (wb_rst_i)                              // 总线复位条件: 最高优先级
  begin
	tstate       <= #1 s_idle;                // 状态回到空闲
	stx_o_tmp       <= #1 1'b1;               // 串行输出复位为高 (空闲态 = 逻辑1)
	counter   <= #1 5'b0;                     // 波特率计数器清零
	shift_out   <= #1 7'b0;                   // 移位寄存器清零
	bit_out     <= #1 1'b0;                   // 发送位清零
	parity_xor  <= #1 1'b0;                   // 校验异或清零
	tf_pop      <= #1 1'b0;                   // FIFO pop清零
	bit_counter <= #1 3'b0;                   // 位计数器清零
  end
  else
  if (enable)                                // 使能有效: 波特率时钟周期到来
  begin
	case (tstate)                              // 状态机分支
	s_idle	 :	if (~|tf_count) // if tf_count==0  // [空闲状态] FIFO为空时停留在此状态
			begin
				tstate <= #1 s_idle;              // 保持在空闲状态
				stx_o_tmp <= #1 1'b1;             // 输出保持高电平 (线路空闲)
			end
			else                                 // FIFO非空: 有数据待发送
			begin
				tf_pop <= #1 1'b0;                // 先清零pop信号
				stx_o_tmp  <= #1 1'b1;            // 输出保持高电平
				tstate  <= #1 s_pop_byte;         // 跳转到弹出数据状态
			end
	s_pop_byte :	begin                      // [弹出数据状态] 从FIFO读取一个字节, 准备发送参数
				tf_pop <= #1 1'b1;                // 置位pop信号 (一个时钟周期后FIFO输出有效)
				case (lcr[/*`UART_LC_BITS*/1:0])  // number of bits in a word  根据LCR[1:0]设置字长
				2'b00 : begin                      // 5位数据字 (LCR[1:0]=00)
					bit_counter <= #1 3'b100;        // 位计数器 = 4 (还需发送4个数据位)
					parity_xor  <= #1 ^tf_data_out[4:0];  // 校验异或 = tf_data_out[4:0]的奇偶 (5位)
				     end
				2'b01 : begin                      // 6位数据字 (LCR[1:0]=01)
					bit_counter <= #1 3'b101;        // 位计数器 = 5 (还需发送5个数据位)
					parity_xor  <= #1 ^tf_data_out[5:0];  // 校验异或 = tf_data_out[5:0]的奇偶 (6位)
				     end
				2'b10 : begin                      // 7位数据字 (LCR[1:0]=10)
					bit_counter <= #1 3'b110;        // 位计数器 = 6 (还需发送6个数据位)
					parity_xor  <= #1 ^tf_data_out[6:0];  // 校验异或 = tf_data_out[6:0]的奇偶 (7位)
				     end
				2'b11 : begin                      // 8位数据字 (LCR[1:0]=11)
					bit_counter <= #1 3'b111;        // 位计数器 = 7 (还需发送7个数据位)
					parity_xor  <= #1 ^tf_data_out[7:0];  // 校验异或 = tf_data_out[7:0]的奇偶 (8位)
				     end
				endcase
				{shift_out[6:0], bit_out} <= #1 tf_data_out;  // 将FIFO数据加载到移位寄存器和bit_out
				tstate <= #1 s_send_start;         // 跳转到发送起始位状态
			end
	s_send_start :	begin                      // [发送起始位状态] 输出1个位周期的低电平
				tf_pop <= #1 1'b0;                // 清零pop信号
				if (~|counter)                     // counter==0: 首次进入该状态, 加载计数器
					counter <= #1 5'b01111;          // 加载15 (16个时钟周期 = 1个位时间)
				else
				if (counter == 5'b00001)            // counter==1: 起始位发送即将完成
				begin
					counter <= #1 0;                 // 计数器清零
					tstate <= #1 s_send_byte;        // 跳转到发送数据位状态
				end
				else
					counter <= #1 counter - 1'b1;    // 计数器递减
				stx_o_tmp <= #1 1'b0;              // 起始位: 输出低电平 (逻辑0)
			end
	s_send_byte :	begin                      // [发送数据位状态] 逐位发送5~8位数据
				if (~|counter)                     // counter==0: 重新加载计数器
					counter <= #1 5'b01111;          // 加载15
				else
				if (counter == 5'b00001)            // counter==1: 当前位发送即将完成
				begin
					if (bit_counter > 3'b0)          // 还有数据位要发送
					begin
						bit_counter <= #1 bit_counter - 1'b1;  // 位计数器减1
						{shift_out[5:0],bit_out  } <= #1 {shift_out[6:1], shift_out[0]};  // 右移1位: shift_out[0] → bit_out, shift_out[6:1] → shift_out[5:0]
						tstate <= #1 s_send_byte;     // 保持在发送数据位状态
					end
					else   // end of byte            // 所有数据位已发送完毕
					if (~lcr[`UART_LC_PE])            // 未使能校验 (LCR[PE]=0)
					begin
						tstate <= #1 s_send_stop;      // 跳转到发送停止位状态
					end
					else                             // 使能了校验 (LCR[PE]=1)
					begin
						case ({lcr[`UART_LC_EP],lcr[`UART_LC_SP]})  // 根据LCR[EP:SP]配置校验类型
						2'b00:	bit_out <= #1 ~parity_xor;  // 奇校验: 使总1个数为奇数
						2'b01:	bit_out <= #1 1'b1;          // 固定校验位=1 (stick parity)
						2'b10:	bit_out <= #1 parity_xor;    // 偶校验: 使总1个数为偶数
						2'b11:	bit_out <= #1 1'b0;          // 固定校验位=0 (stick parity)
						endcase
						tstate <= #1 s_send_parity;   // 跳转到发送校验位状态
					end
					counter <= #1 0;                 // 计数器清零
				end
				else
					counter <= #1 counter - 1'b1;    // 计数器递减
				stx_o_tmp <= #1 bit_out; // set output pin  // 输出当前位到串行引脚
			end
	s_send_parity :	begin                     // [发送校验位状态] 发送1位校验位
				if (~|counter)                     // counter==0: 重新加载计数器
					counter <= #1 5'b01111;          // 加载15
				else
				if (counter == 5'b00001)            // counter==1: 校验位发送即将完成
				begin
					counter <= #1 4'b0;              // 计数器清零
					tstate <= #1 s_send_stop;        // 跳转到发送停止位状态
				end
				else
					counter <= #1 counter - 1'b1;    // 计数器递减
				stx_o_tmp <= #1 bit_out;            // 输出校验位
			end
	s_send_stop :  begin                       // [发送停止位状态] 输出1/1.5/2个位周期的高电平
				if (~|counter)                     // counter==0: 加载停止位计数值
				  begin
						casex ({lcr[`UART_LC_SB],lcr[`UART_LC_BITS]})  // 根据LCR[SB:BITS]确定停止位长度
  						3'b0xx:	  counter <= #1 5'b01101;     // 1 stop bit    — 1个停止位 (13个时钟周期) ok igor
  						3'b100:	  counter <= #1 5'b10101;     // 1.5 stop bit  — 1.5个停止位 (21个时钟周期)
  						default:	  counter <= #1 5'b11101;     // 2 stop bits   — 2个停止位 (29个时钟周期)
						endcase
					end
				else
				if (counter == 5'b00001)            // counter==1: 停止位发送即将完成
				begin
					counter <= #1 0;                 // 计数器清零
					tstate <= #1 s_idle;             // 回到空闲状态 (一个字发送完毕)
				end
				else
					counter <= #1 counter - 1'b1;    // 计数器递减
				stx_o_tmp <= #1 1'b1;              // 停止位: 输出高电平 (逻辑1)
			end

		default : // should never get here       // 默认情况: 安全回到空闲 (理论上不应到达)
			tstate <= #1 s_idle;
	endcase
  end // end if enable
  else                                       // enable无效: 波特率时钟未到
    tf_pop <= #1 1'b0;  // tf_pop must be 1 cycle width  // 清零pop信号 (pop必须为单周期脉宽)
end // transmitter logic                      // 发送器状态机逻辑结束

assign stx_pad_o = lcr[`UART_LC_BC] ? 1'b0 : stx_o_tmp;    // Break condition  // [串行输出] 若LCR[BC]=1 (break条件)则强制输出0, 否则正常输出

endmodule                                    // 模块结束
