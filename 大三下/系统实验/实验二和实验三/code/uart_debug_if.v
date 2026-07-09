//////////////////////////////////////////////////////////////////////
// File:    uart_debug_if.v
// Description: UART 调试接口 — 提供内部状态寄存器的只读访问
//             将 UART 内部状态映射到 Wishbone 地址空间:
//               - 地址 0x08: {msr, lcr, iir, ier, lsr}
//               - 地址 0x0c: {fcr, mcr, rf_count, rstate, tf_count, tstate}
//             用于开发和调试 UART 驱动
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  uart_debug_if.v                                             ////
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
////  UART core debug interface.                                  ////
////                                                              ////
////                                                              ////
////  Created:        2001/12/02                                  ////
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
// Warnings fixed (unused signals removed).
//
// some synthesis bugs fixed
//
// committed the debug interface file
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

`include "uart_defines.v"

module uart_debug_if (/*AUTOARG*/
// Outputs
wb_dat32_o, 
// Inputs
wb_adr_i, ier, iir, fcr, mcr, lcr, msr, 
lsr, rf_count, tf_count, tstate, rstate
) ;

input [`UART_ADDR_WIDTH-1:0] 		wb_adr_i;   // Wishbone总线地址输入 — 选择读取哪个调试寄存器 (0x08或0x0c)
output [31:0] 							wb_dat32_o; // 32位调试数据输出 — 组合逻辑直接驱动，零等待周期读取
input [3:0] 							ier;        // 中断使能寄存器 (Interrupt Enable Register, 地址0x01)
input [3:0] 							iir;        // 中断标识寄存器 (Interrupt Identification Register, 地址0x02, 只读)
input [1:0] 							fcr;        // FIFO控制寄存器 bits[7:6] (FIFO Control Register), 其余位在调试接口中忽略
input [4:0] 							mcr;        // 调制解调器控制寄存器 (Modem Control Register, 地址0x04)
input [7:0] 							lcr;        // 线路控制寄存器 (Line Control Register, 地址0x03)
input [7:0] 							msr;        // 调制解调器状态寄存器 (Modem Status Register, 地址0x06)
input [7:0] 							lsr;        // 线路状态寄存器 (Line Status Register, 地址0x05)
input [`UART_FIFO_COUNTER_W-1:0] rf_count;  // 接收FIFO当前数据计数 (Receive FIFO count)
input [`UART_FIFO_COUNTER_W-1:0] tf_count;  // 发送FIFO当前数据计数 (Transmit FIFO count)
input [2:0] 							tstate;     // 发送状态机当前状态 (Transmitter state machine)
input [3:0] 							rstate;     // 接收状态机当前状态 (Receiver state machine)


wire [`UART_ADDR_WIDTH-1:0] 		wb_adr_i;   // Wishbone地址总线内部连线（与输入端口同名，用于always块敏感列表）
reg [31:0] 								wb_dat32_o; // 调试数据输出寄存器 — 由组合逻辑always块驱动

// 组合逻辑: 根据Wishbone地址将UART内部状态拼接为32位调试数据输出
// 敏感信号列表 (由verilog-mode AUTOAS自动生成): wb_adr_i, ier, iir, fcr, mcr, lcr, msr, lsr, rf_count, rstate, tf_count, tstate
// 任一敏感信号发生变化，则重新计算所有case分支的输出值
			or rf_count or rstate or tf_count or tstate or wb_adr_i)
	case (wb_adr_i)
		                      // 地址0x08 — 位宽分解: msr(8) + lcr(8) + iir(4) + ier(4) + lsr(8) = 32位
		5'b01000: wb_dat32_o = {msr,lcr,iir,ier,lsr};
		               // 地址0x0c — 位宽分解: {8'b0(8)} + fcr(2) + mcr(5) + rf_count(5) + rstate(4) + tf_count(5) + tstate(3)
		5'b01100: wb_dat32_o = {8'b0, fcr,mcr, rf_count, rstate, tf_count, tstate};
		default: wb_dat32_o = 0;   // 无效地址: 输出0，避免综合产生锁存器(latch)
	endcase // case(wb_adr_i) — 结束地址译码，仅0x08和0x0c为有效调试地址

endmodule // uart_debug_if

