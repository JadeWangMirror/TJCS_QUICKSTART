//////////////////////////////////////////////////////////////////////
////                                                              ////
////  uart_top.v                                                  ////
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
////  UART core top level.                                        ////
////                                                              ////
////  Known problems (limits):                                    ////
////  Note that transmitter and receiver instances are inside     ////
////  the uart_regs.v file.                                       ////
////                                                              ////
////  To Do:                                                      ////
////  Nothing so far.                                             ////
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
// Warnings fixed (unused signals removed).
//
// Bug in LSR[0] is fixed.
// All WISHBONE signals are now sampled, so another wait-state is introduced on all transfers.
//
// Updated specification documentation.
// Added full 32-bit data bus interface, now as default.
// Address is 5-bit wide in 32-bit data bus mode.
// Added wb_sel_i input to the core. It's used in the 32-bit mode.
// Added debug interface with two 32-bit read-only registers in 32-bit mode.
// Bits 5 and 6 of LSR are now only cleared on TX FIFO write.
// My small test bench is modified to work with 32-bit mode.
//
// Heavily rewritten interrupt and LSR subsystems.
// Many bugs hopefully squashed.
//
// Small synopsis fixes
//
// Modified port names again
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

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

`include "uart_defines.v"

module uart_top	(                         // [顶层模块] UART 16550核顶层, 集成WISHBONE接口子模块和寄存器子模块
	wb_clk_i,                              // [时钟] WISHBONE总线时钟

	// Wishbone signals                      // WISHBONE总线信号
	wb_rst_i, wb_adr_i, wb_dat_i, wb_dat_o, wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_sel_i,  // [WISHBONE] 复位/地址/数据输入/数据输出/写使能/选通/周期/应答/字节选择
	int_o, // interrupt request            // [中断] 中断请求输出

	// UART	signals                          // UART串行接口信号
	// serial input/output                   // 串行输入/输出
	stx_pad_o, srx_pad_i,                   // [串口] 串行发送输出 / 串行接收输入

	// modem signals                         // 调制解调器信号
	rts_pad_o, cts_pad_i, dtr_pad_o, dsr_pad_i, ri_pad_i, dcd_pad_i  // [MODEM] RTS/CTS/DTR/DSR/RI/DCD
`ifdef UART_HAS_BAUDRATE_OUTPUT             // 如果定义了波特率输出
	, baud_o                                 // [波特率输出] 可选的波特率时钟输出
`endif
	);

parameter 							 uart_data_width = `UART_DATA_WIDTH;    // [参数] UART数据总线宽度
parameter 							 uart_addr_width = `UART_ADDR_WIDTH;    // [参数] UART地址总线宽度

input 								 wb_clk_i;                           // [时钟] WISHBONE总线时钟输入

// WISHBONE interface                         // WISHBONE总线接口信号
input 								 wb_rst_i;                           // [复位] WISHBONE总线复位, 高有效
input [uart_addr_width-1:0] 	 wb_adr_i;                           // [地址] WISHBONE地址总线输入
input [uart_data_width-1:0] 	 wb_dat_i;                           // [数据输入] WISHBONE数据总线输入
output [uart_data_width-1:0] 	 wb_dat_o;                           // [数据输出] WISHBONE数据总线输出
input 								 wb_we_i;                            // [写使能] WISHBONE写使能 (高: 写, 低: 读)
input 								 wb_stb_i;                           // [选通] WISHBONE选通信号
input 								 wb_cyc_i;                           // [周期] WISHBONE总线周期信号
input [3:0]							 wb_sel_i;                           // [字节选择] WISHBONE字节选择 (32位模式)
output 								 wb_ack_o;                           // [应答] WISHBONE应答信号输出
output 								 int_o;                              // [中断] 中断请求输出

// UART	signals                               // UART串行接口信号
input 								 srx_pad_i;                          // [串行输入] 串行接收引脚输入
output 								 stx_pad_o;                          // [串行输出] 串行发送引脚输出
output 								 rts_pad_o;                          // [RTS] 请求发送输出
input 								 cts_pad_i;                          // [CTS] 允许发送输入
output 								 dtr_pad_o;                          // [DTR] 数据终端就绪输出
input 								 dsr_pad_i;                          // [DSR] 数据设备就绪输入
input 								 ri_pad_i;                           // [RI] 振铃指示输入
input 								 dcd_pad_i;                          // [DCD] 数据载波检测输入

// optional baudrate output                    // 可选波特率输出
`ifdef UART_HAS_BAUDRATE_OUTPUT             // 如果定义了波特率输出功能
output	baud_o;                              // [波特率输出] 波特率时钟输出
`endif


wire 									 stx_pad_o;                          // [线网] 串行发送输出线网
wire 									 rts_pad_o;                          // [线网] RTS输出线网
wire 									 dtr_pad_o;                          // [线网] DTR输出线网

wire [uart_addr_width-1:0] 	 wb_adr_i;                           // [线网] WISHBONE地址线网
wire [uart_data_width-1:0] 	 wb_dat_i;                           // [线网] WISHBONE数据输入线网
wire [uart_data_width-1:0] 	 wb_dat_o;                           // [线网] WISHBONE数据输出线网

wire [7:0] 							 wb_dat8_i; // 8-bit internal data input   // [内部数据输入] 8位内部数据总线输入
wire [7:0] 							 wb_dat8_o; // 8-bit internal data output  // [内部数据输出] 8位内部数据总线输出
wire [31:0] 						 wb_dat32_o; // debug interface 32-bit output  // [调试输出] 调试接口32位数据输出
wire [3:0] 							 wb_sel_i;  // WISHBONE select signal           // [线网] WISHBONE字节选择线网
wire [uart_addr_width-1:0] 	 wb_adr_int;                         // [内部地址] 内部地址总线
wire 									 we_o;	// Write enable for registers     // [写使能] 寄存器写使能
wire		          	     re_o;	// Read enable for registers      // [读使能] 寄存器读使能
//
// MODULE INSTANCES                           // 子模块实例化
//

`ifdef DATA_BUS_WIDTH_8                      // 如果使用8位数据总线
`else                                        // 否则使用32位数据总线 (含调试接口)
// debug interface wires                     // 调试接口线网声明
wire	[3:0] ier;                             // [调试] 中断使能寄存器 (IER)
wire	[3:0] iir;                             // [调试] 中断识别寄存器 (IIR)
wire	[1:0] fcr;                             // [调试] FIFO控制寄存器 (FCR)
wire	[4:0] mcr;                             // [调试] 调制解调器控制寄存器 (MCR)
wire	[7:0] lcr;                             // [调试] 线路控制寄存器 (LCR)
wire	[7:0] msr;                             // [调试] 调制解调器状态寄存器 (MSR)
wire	[7:0] lsr;                             // [调试] 线路状态寄存器 (LSR)
wire	[`UART_FIFO_COUNTER_W-1:0] rf_count;  // [调试] 接收FIFO计数
wire	[`UART_FIFO_COUNTER_W-1:0] tf_count;  // [调试] 发送FIFO计数
wire	[2:0] tstate;                          // [调试] 发送器状态
wire	[3:0] rstate;                          // [调试] 接收器状态
`endif

`ifdef DATA_BUS_WIDTH_8                      // 8位数据总线模式: WISHBONE接口
////  WISHBONE interface module               // WISHBONE总线接口模块实例化
uart_wb		wb_interface(                    // [WISHBONE接口] 实例名: wb_interface
		.clk(		wb_clk_i		),               // 时钟连接
		.wb_rst_i(	wb_rst_i	),                // 复位连接
	.wb_dat_i(wb_dat_i),                       // 数据输入连接
	.wb_dat_o(wb_dat_o),                       // 数据输出连接
	.wb_dat8_i(wb_dat8_i),                     // 8位内部数据输入
	.wb_dat8_o(wb_dat8_o),                     // 8位内部数据输出
	 .wb_dat32_o(32'b0),                       // 32位数据输出 (8位模式置0)
	 .wb_sel_i(4'b0),                          // 字节选择 (8位模式置0)
		.wb_we_i(	wb_we_i		),               // 写使能连接
		.wb_stb_i(	wb_stb_i	),                // 选通信号连接
		.wb_cyc_i(	wb_cyc_i	),                // 周期信号连接
		.wb_ack_o(	wb_ack_o	),               // 应答信号连接
	.wb_adr_i(wb_adr_i),                       // 地址输入连接
	.wb_adr_int(wb_adr_int),                   // 内部地址输出连接
		.we_o(		we_o		),               // 写使能输出连接
		.re_o(re_o)                            // 读使能输出连接
		);
`else                                        // 32位数据总线模式: WISHBONE接口
uart_wb		wb_interface(                    // [WISHBONE接口] 实例名: wb_interface (32位模式)
		.clk(		wb_clk_i		),               // 时钟连接
		.wb_rst_i(	wb_rst_i	),                // 复位连接
	.wb_dat_i(wb_dat_i),                       // 数据输入连接
	.wb_dat_o(wb_dat_o),                       // 数据输出连接
	.wb_dat8_i(wb_dat8_i),                     // 8位内部数据输入
	.wb_dat8_o(wb_dat8_o),                     // 8位内部数据输出
	 .wb_sel_i(wb_sel_i),                      // 字节选择连接
	 .wb_dat32_o(wb_dat32_o),                  // 32位调试数据输出
		.wb_we_i(	wb_we_i		),               // 写使能连接
		.wb_stb_i(	wb_stb_i	),                // 选通信号连接
		.wb_cyc_i(	wb_cyc_i	),                // 周期信号连接
		.wb_ack_o(	wb_ack_o	),               // 应答信号连接
	.wb_adr_i(wb_adr_i),                       // 地址输入连接
	.wb_adr_int(wb_adr_int),                   // 内部地址输出连接
		.we_o(		we_o		),               // 写使能输出连接
		.re_o(re_o)                            // 读使能输出连接
		);
`endif

// Registers                                  // UART寄存器模块实例化
uart_regs	regs(                            // [寄存器模块] 实例名: regs
	.clk(		wb_clk_i		),                 // 时钟连接
	.wb_rst_i(	wb_rst_i	),                  // 复位连接
	.wb_addr_i(	wb_adr_int	),                // 地址连接 (内部地址)
	.wb_dat_i(	wb_dat8_i	),                 // 数据输入 (8位内部数据)
	.wb_dat_o(	wb_dat8_o	),                 // 数据输出 (8位内部数据)
	.wb_we_i(	we_o		),                 // 写使能连接
   .wb_re_i(re_o),                            // 读使能连接
	.modem_inputs(	{cts_pad_i, dsr_pad_i,     // MODEM输入: {CTS, DSR, RI, DCD}
	ri_pad_i,  dcd_pad_i}	),
	.stx_pad_o(		stx_pad_o		),           // 串行发送输出连接
	.srx_pad_i(		srx_pad_i		),           // 串行接收输入连接
`ifdef DATA_BUS_WIDTH_8                      // 8位模式: 无调试接口
`else                                        // 32位模式: 调试接口信号连接
// debug interface signals	enabled            // 调试接口信号使能
.ier(ier),                                   // IER连接
.iir(iir),                                   // IIR连接
.fcr(fcr),                                   // FCR连接
.mcr(mcr),                                   // MCR连接
.lcr(lcr),                                   // LCR连接
.msr(msr),                                   // MSR连接
.lsr(lsr),                                   // LSR连接
.rf_count(rf_count),                         // 接收FIFO计数连接
.tf_count(tf_count),                         // 发送FIFO计数连接
.tstate(tstate),                             // 发送器状态连接
.rstate(rstate),                             // 接收器状态连接
`endif
	.rts_pad_o(		rts_pad_o		),           // RTS输出连接
	.dtr_pad_o(		dtr_pad_o		),           // DTR输出连接
	.int_o(		int_o		)                  // 中断输出连接
`ifdef UART_HAS_BAUDRATE_OUTPUT             // 如果定义了波特率输出
	, .baud_o(baud_o)                          // 波特率输出连接
`endif

);

`ifdef DATA_BUS_WIDTH_8                      // 8位模式: 无调试接口模块
`else                                        // 32位模式: 调试接口模块实例化
uart_debug_if dbg(/*AUTOINST*/              // [调试接口] 实例名: dbg
						// Outputs
						.wb_dat32_o				 (wb_dat32_o[31:0]),    // 32位调试数据输出
						// Inputs
						.wb_adr_i				 (wb_adr_int[`UART_ADDR_WIDTH-1:0]),  // 地址输入
						.ier						 (ier[3:0]),            // IER连接
						.iir						 (iir[3:0]),            // IIR连接
						.fcr						 (fcr[1:0]),            // FCR连接
						.mcr						 (mcr[4:0]),            // MCR连接
						.lcr						 (lcr[7:0]),            // LCR连接
						.msr						 (msr[7:0]),            // MSR连接
						.lsr						 (lsr[7:0]),            // LSR连接
						.rf_count				 (rf_count[`UART_FIFO_COUNTER_W-1:0]),  // 接收FIFO计数连接
						.tf_count				 (tf_count[`UART_FIFO_COUNTER_W-1:0]),  // 发送FIFO计数连接
						.tstate					 (tstate[2:0]),         // 发送状态连接
						.rstate					 (rstate[3:0]));        // 接收状态连接
`endif

initial                                    // [仿真初始化] 显示UART配置信息
begin
	`ifdef DATA_BUS_WIDTH_8                 // 如果使用8位数据总线
		$display("(%m) UART INFO: Data bus width is 8. No Debug interface.\n");  // 打印: 8位总线, 无调试接口
	`else                                   // 否则使用32位数据总线
		$display("(%m) UART INFO: Data bus width is 32. Debug Interface present.\n");  // 打印: 32位总线, 有调试接口
	`endif
	`ifdef UART_HAS_BAUDRATE_OUTPUT        // 如果定义了波特率输出
		$display("(%m) UART INFO: Has baudrate output\n");  // 打印: 有波特率输出
	`else                                   // 否则无波特率输出
		$display("(%m) UART INFO: Doesn't have baudrate output\n");  // 打印: 无波特率输出
	`endif
end

endmodule                                  // 模块结束
