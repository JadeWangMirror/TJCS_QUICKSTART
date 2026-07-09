//////////////////////////////////////////////////////////////////////
// File:    wb_conmax_master_if.v
// Description: Wishbone ConMax 主设备接口 — 连接主设备到互联矩阵
//             功能:
//               - 将主设备的 Wishbone 信号接入互联矩阵
//               - 管理主设备到目标从设备的路由
//               - 产生 ack/err/rty 响应给主设备
//             基于 OpenCores wb_conmax 项目
//////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE Connection Matrix Master Interface                ////
////                                                             ////
////                                                             ////
////                                                             ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/cores/wb_conmax/ ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
////                         www.asics.ws                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
// 以上为 OpenCores wb_conmax 项目的原始英文版权声明，保留不变
// 以下为 Wishbone ConMax 主设备接口模块的详细中文注释版本

//
//
//  $Date: 2002-10-03 05:40:07 $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               WISHBONE CONMAX IP Core
//
//
//
//
//

`include "wb_conmax_defines.v"	// 包含 Wishbone ConMax 公共宏定义（如数据宽度、地址宽度参数等）

// Wishbone ConMax 主设备接口模块：负责将单个主设备的 Wishbone 总线信号连接到最多 16 个从设备
// 核心功能：根据地址高位 [31:28] 选择目标从设备，广播地址/数据/字节使能，仅向选中从设备发送 cyc/stb
module wb_conmax_master_if(

	clk_i, rst_i,

	// Master interface
	wb_data_i, wb_data_o, wb_addr_i, wb_sel_i, wb_we_i, wb_cyc_i,
	wb_stb_i, wb_ack_o, wb_err_o, wb_rty_o,

	// Slave 0 Interface
	s0_data_i, s0_data_o, s0_addr_o, s0_sel_o, s0_we_o, s0_cyc_o,
	s0_stb_o, s0_ack_i, s0_err_i, s0_rty_i,

	// Slave 1 Interface
	s1_data_i, s1_data_o, s1_addr_o, s1_sel_o, s1_we_o, s1_cyc_o,
	s1_stb_o, s1_ack_i, s1_err_i, s1_rty_i,

	// Slave 2 Interface
	s2_data_i, s2_data_o, s2_addr_o, s2_sel_o, s2_we_o, s2_cyc_o,
	s2_stb_o, s2_ack_i, s2_err_i, s2_rty_i,

	// Slave 3 Interface
	s3_data_i, s3_data_o, s3_addr_o, s3_sel_o, s3_we_o, s3_cyc_o,
	s3_stb_o, s3_ack_i, s3_err_i, s3_rty_i,

	// Slave 4 Interface
	s4_data_i, s4_data_o, s4_addr_o, s4_sel_o, s4_we_o, s4_cyc_o,
	s4_stb_o, s4_ack_i, s4_err_i, s4_rty_i,

	// Slave 5 Interface
	s5_data_i, s5_data_o, s5_addr_o, s5_sel_o, s5_we_o, s5_cyc_o,
	s5_stb_o, s5_ack_i, s5_err_i, s5_rty_i,

	// Slave 6 Interface
	s6_data_i, s6_data_o, s6_addr_o, s6_sel_o, s6_we_o, s6_cyc_o,
	s6_stb_o, s6_ack_i, s6_err_i, s6_rty_i,

	// Slave 7 Interface
	s7_data_i, s7_data_o, s7_addr_o, s7_sel_o, s7_we_o, s7_cyc_o,
	s7_stb_o, s7_ack_i, s7_err_i, s7_rty_i,

	// Slave 8 Interface
	s8_data_i, s8_data_o, s8_addr_o, s8_sel_o, s8_we_o, s8_cyc_o,
	s8_stb_o, s8_ack_i, s8_err_i, s8_rty_i,

	// Slave 9 Interface
	s9_data_i, s9_data_o, s9_addr_o, s9_sel_o, s9_we_o, s9_cyc_o,
	s9_stb_o, s9_ack_i, s9_err_i, s9_rty_i,

	// Slave 10 Interface
	s10_data_i, s10_data_o, s10_addr_o, s10_sel_o, s10_we_o, s10_cyc_o,
	s10_stb_o, s10_ack_i, s10_err_i, s10_rty_i,

	// Slave 11 Interface
	s11_data_i, s11_data_o, s11_addr_o, s11_sel_o, s11_we_o, s11_cyc_o,
	s11_stb_o, s11_ack_i, s11_err_i, s11_rty_i,

	// Slave 12 Interface
	s12_data_i, s12_data_o, s12_addr_o, s12_sel_o, s12_we_o, s12_cyc_o,
	s12_stb_o, s12_ack_i, s12_err_i, s12_rty_i,

	// Slave 13 Interface
	s13_data_i, s13_data_o, s13_addr_o, s13_sel_o, s13_we_o, s13_cyc_o,
	s13_stb_o, s13_ack_i, s13_err_i, s13_rty_i,

	// Slave 14 Interface
	s14_data_i, s14_data_o, s14_addr_o, s14_sel_o, s14_we_o, s14_cyc_o,
	s14_stb_o, s14_ack_i, s14_err_i, s14_rty_i,

	// Slave 15 Interface
	s15_data_i, s15_data_o, s15_addr_o, s15_sel_o, s15_we_o, s15_cyc_o,
	s15_stb_o, s15_ack_i, s15_err_i, s15_rty_i
	);

////////////////////////////////////////////////////////////////////
//
// Module Parameters
//  模块参数定义：数据总线宽度 dw=32、地址总线宽度 aw=32、字节选择线数量 sw=dw/8=4
//

parameter		dw	= 32;		// Data bus Width（数据总线宽度，默认 32 位）
parameter		aw	= 32;		// Address bus Width（地址总线宽度，默认 32 位）
parameter		sw	= dw / 8;	// Number of Select Lines（字节选择线数 = dw/8，用于字节粒度的写使能）

////////////////////////////////////////////////////////////////////
//
// Module IOs
//  模块 I/O 端口声明：分为主设备侧接口和 16 个从设备侧接口（s0 ~ s15）
//

input			clk_i, rst_i;	// 系统时钟和同步复位（高电平有效）

// =========================================================================
// Master Interface（主设备侧 Wishbone 接口）
//   所有信号直接连接到上游主设备，这是整个 master_if 的"北向"接口
// =========================================================================
input	[dw-1:0]	wb_data_i;	// 主设备写数据输入（主设备 -> 从设备方向）
output	[dw-1:0]	wb_data_o;	// 主设备读数据输出（从设备 -> 主设备方向）
input	[aw-1:0]	wb_addr_i;	// 地址总线输入：高 4 位 [31:28] 用于选择从设备 (slv_sel)
input	[sw-1:0]	wb_sel_i;	// 字节选择信号：指示哪些字节通道有效（写时用于字节掩码）
input			wb_we_i;	// 读写控制：1 = 写周期，0 = 读周期
input			wb_cyc_i;	// 总线周期信号：整个总线事务期间保持高电平
input			wb_stb_i;	// 选通信号：指示当前数据阶段有效，与 cyc_i 配合使用
output			wb_ack_o;	// 应答信号：从设备正常完成数据传输
output			wb_err_o;	// 错误信号：从设备报告总线错误
output			wb_rty_o;	// 重试信号：从设备要求主设备重试本次传输

// =========================================================================
// Slave 0 ~ Slave 15 Interface（从设备侧 Wishbone 接口，共 16 个）
//   每个从设备接口结构完全相同，均为"南向"连接到对应的从设备
//   方向说明（以 master_if 为参考点）：
//     _i 后缀：从设备到 master_if 的输入信号（如响应 ack/err/rty，读数据 data_i）
//     _o 后缀：master_if 到从设备的输出信号（如地址 addr，写数据 data_o，控制 cyc/stb/we）
//   注意：sX_data_o 是 master_if 发往从设备的写数据（从主设备的 wb_data_i 直通而来）
//         sX_data_i 是从设备返回的读数据（MUX 选通后送给主设备的 wb_data_o）
// =========================================================================

// Slave 0 Interface（从设备 0，对应地址空间 0x0xxxxxxx）
input	[dw-1:0]	s0_data_i;	// 从设备 0 读数据输入（s0 -> master_if）
output	[dw-1:0]	s0_data_o;	// 从设备 0 写数据输出（master_if -> s0）
output	[aw-1:0]	s0_addr_o;	// 从设备 0 地址输出（广播自主设备地址 wb_addr_i）
output	[sw-1:0]	s0_sel_o;	// 从设备 0 字节选择输出（广播自主设备 wb_sel_i）
output			s0_we_o;	// 从设备 0 读写控制输出（广播自主设备 wb_we_i）
output			s0_cyc_o;	// 从设备 0 周期信号输出（仅 slv_sel==0 且 wb_cyc_i 有效时置位，带寄存）
output			s0_stb_o;	// 从设备 0 选通信号输出（仅 slv_sel==0 时选通 wb_stb_i）
input			s0_ack_i;	// 从设备 0 应答输入（MUX 送回主设备）
input			s0_err_i;	// 从设备 0 错误输入（MUX 送回主设备）
input			s0_rty_i;	// 从设备 0 重试输入（MUX 送回主设备）

// Slave 1 Interface（从设备 1，对应地址空间 0x1xxxxxxx）
input	[dw-1:0]	s1_data_i;	// s1 -> master_if 读数据
output	[dw-1:0]	s1_data_o;	// master_if -> s1 写数据（广播自 wb_data_i）
output	[aw-1:0]	s1_addr_o;	// master_if -> s1 地址（广播自 wb_addr_i）
output	[sw-1:0]	s1_sel_o;	// master_if -> s1 字节选择（广播自 wb_sel_i）
output			s1_we_o;	// master_if -> s1 读写控制（广播自 wb_we_i）
output			s1_cyc_o;	// master_if -> s1 周期信号（仅 slv_sel==1 时有效，带寄存）
output			s1_stb_o;	// master_if -> s1 选通信号（仅 slv_sel==1 时有效）
input			s1_ack_i;	// s1 -> master_if 应答（MUX 送回主设备）
input			s1_err_i;	// s1 -> master_if 错误（MUX 送回主设备）
input			s1_rty_i;	// s1 -> master_if 重试（MUX 送回主设备）

// Slave 2 Interface（从设备 2，对应地址空间 0x2xxxxxxx）
input	[dw-1:0]	s2_data_i;	// s2 -> master_if 读数据
output	[dw-1:0]	s2_data_o;	// master_if -> s2 写数据（广播自 wb_data_i）
output	[aw-1:0]	s2_addr_o;	// master_if -> s2 地址（广播自 wb_addr_i）
output	[sw-1:0]	s2_sel_o;	// master_if -> s2 字节选择（广播自 wb_sel_i）
output			s2_we_o;	// master_if -> s2 读写控制（广播自 wb_we_i）
output			s2_cyc_o;	// master_if -> s2 周期信号（仅 slv_sel==2 时有效，带寄存）
output			s2_stb_o;	// master_if -> s2 选通信号（仅 slv_sel==2 时有效）
input			s2_ack_i;	// s2 -> master_if 应答（MUX 送回主设备）
input			s2_err_i;	// s2 -> master_if 错误（MUX 送回主设备）
input			s2_rty_i;	// s2 -> master_if 重试（MUX 送回主设备）

// Slave 3 Interface（从设备 3，对应地址空间 0x3xxxxxxx）
input	[dw-1:0]	s3_data_i;	// s3 -> master_if 读数据
output	[dw-1:0]	s3_data_o;	// master_if -> s3 写数据（广播自 wb_data_i）
output	[aw-1:0]	s3_addr_o;	// master_if -> s3 地址（广播自 wb_addr_i）
output	[sw-1:0]	s3_sel_o;	// master_if -> s3 字节选择（广播自 wb_sel_i）
output			s3_we_o;	// master_if -> s3 读写控制（广播自 wb_we_i）
output			s3_cyc_o;	// master_if -> s3 周期信号（仅 slv_sel==3 时有效，带寄存）
output			s3_stb_o;	// master_if -> s3 选通信号（仅 slv_sel==3 时有效）
input			s3_ack_i;	// s3 -> master_if 应答（MUX 送回主设备）
input			s3_err_i;	// s3 -> master_if 错误（MUX 送回主设备）
input			s3_rty_i;	// s3 -> master_if 重试（MUX 送回主设备）

// Slave 4 Interface（从设备 4，对应地址空间 0x4xxxxxxx）
input	[dw-1:0]	s4_data_i;	// s4 -> master_if 读数据
output	[dw-1:0]	s4_data_o;	// master_if -> s4 写数据（广播自 wb_data_i）
output	[aw-1:0]	s4_addr_o;	// master_if -> s4 地址（广播自 wb_addr_i）
output	[sw-1:0]	s4_sel_o;	// master_if -> s4 字节选择（广播自 wb_sel_i）
output			s4_we_o;	// master_if -> s4 读写控制（广播自 wb_we_i）
output			s4_cyc_o;	// master_if -> s4 周期信号（仅 slv_sel==4 时有效，带寄存）
output			s4_stb_o;	// master_if -> s4 选通信号（仅 slv_sel==4 时有效）
input			s4_ack_i;	// s4 -> master_if 应答（MUX 送回主设备）
input			s4_err_i;	// s4 -> master_if 错误（MUX 送回主设备）
input			s4_rty_i;	// s4 -> master_if 重试（MUX 送回主设备）

// Slave 5 Interface（从设备 5，对应地址空间 0x5xxxxxxx）
input	[dw-1:0]	s5_data_i;	// s5 -> master_if 读数据
output	[dw-1:0]	s5_data_o;	// master_if -> s5 写数据（广播自 wb_data_i）
output	[aw-1:0]	s5_addr_o;	// master_if -> s5 地址（广播自 wb_addr_i）
output	[sw-1:0]	s5_sel_o;	// master_if -> s5 字节选择（广播自 wb_sel_i）
output			s5_we_o;	// master_if -> s5 读写控制（广播自 wb_we_i）
output			s5_cyc_o;	// master_if -> s5 周期信号（仅 slv_sel==5 时有效，带寄存）
output			s5_stb_o;	// master_if -> s5 选通信号（仅 slv_sel==5 时有效）
input			s5_ack_i;	// s5 -> master_if 应答（MUX 送回主设备）
input			s5_err_i;	// s5 -> master_if 错误（MUX 送回主设备）
input			s5_rty_i;	// s5 -> master_if 重试（MUX 送回主设备）

// Slave 6 Interface（从设备 6，对应地址空间 0x6xxxxxxx）
input	[dw-1:0]	s6_data_i;	// s6 -> master_if 读数据
output	[dw-1:0]	s6_data_o;	// master_if -> s6 写数据（广播自 wb_data_i）
output	[aw-1:0]	s6_addr_o;	// master_if -> s6 地址（广播自 wb_addr_i）
output	[sw-1:0]	s6_sel_o;	// master_if -> s6 字节选择（广播自 wb_sel_i）
output			s6_we_o;	// master_if -> s6 读写控制（广播自 wb_we_i）
output			s6_cyc_o;	// master_if -> s6 周期信号（仅 slv_sel==6 时有效，带寄存）
output			s6_stb_o;	// master_if -> s6 选通信号（仅 slv_sel==6 时有效）
input			s6_ack_i;	// s6 -> master_if 应答（MUX 送回主设备）
input			s6_err_i;	// s6 -> master_if 错误（MUX 送回主设备）
input			s6_rty_i;	// s6 -> master_if 重试（MUX 送回主设备）

// Slave 7 Interface（从设备 7，对应地址空间 0x7xxxxxxx）
input	[dw-1:0]	s7_data_i;	// s7 -> master_if 读数据
output	[dw-1:0]	s7_data_o;	// master_if -> s7 写数据（广播自 wb_data_i）
output	[aw-1:0]	s7_addr_o;	// master_if -> s7 地址（广播自 wb_addr_i）
output	[sw-1:0]	s7_sel_o;	// master_if -> s7 字节选择（广播自 wb_sel_i）
output			s7_we_o;	// master_if -> s7 读写控制（广播自 wb_we_i）
output			s7_cyc_o;	// master_if -> s7 周期信号（仅 slv_sel==7 时有效，带寄存）
output			s7_stb_o;	// master_if -> s7 选通信号（仅 slv_sel==7 时有效）
input			s7_ack_i;	// s7 -> master_if 应答（MUX 送回主设备）
input			s7_err_i;	// s7 -> master_if 错误（MUX 送回主设备）
input			s7_rty_i;	// s7 -> master_if 重试（MUX 送回主设备）

// Slave 8 Interface（从设备 8，对应地址空间 0x8xxxxxxx）
input	[dw-1:0]	s8_data_i;	// s8 -> master_if 读数据
output	[dw-1:0]	s8_data_o;	// master_if -> s8 写数据（广播自 wb_data_i）
output	[aw-1:0]	s8_addr_o;	// master_if -> s8 地址（广播自 wb_addr_i）
output	[sw-1:0]	s8_sel_o;	// master_if -> s8 字节选择（广播自 wb_sel_i）
output			s8_we_o;	// master_if -> s8 读写控制（广播自 wb_we_i）
output			s8_cyc_o;	// master_if -> s8 周期信号（仅 slv_sel==8 时有效，带寄存）
output			s8_stb_o;	// master_if -> s8 选通信号（仅 slv_sel==8 时有效）
input			s8_ack_i;	// s8 -> master_if 应答（MUX 送回主设备）
input			s8_err_i;	// s8 -> master_if 错误（MUX 送回主设备）
input			s8_rty_i;	// s8 -> master_if 重试（MUX 送回主设备）

// Slave 9 Interface（从设备 9，对应地址空间 0x9xxxxxxx）
input	[dw-1:0]	s9_data_i;	// s9 -> master_if 读数据
output	[dw-1:0]	s9_data_o;	// master_if -> s9 写数据（广播自 wb_data_i）
output	[aw-1:0]	s9_addr_o;	// master_if -> s9 地址（广播自 wb_addr_i）
output	[sw-1:0]	s9_sel_o;	// master_if -> s9 字节选择（广播自 wb_sel_i）
output			s9_we_o;	// master_if -> s9 读写控制（广播自 wb_we_i）
output			s9_cyc_o;	// master_if -> s9 周期信号（仅 slv_sel==9 时有效，带寄存）
output			s9_stb_o;	// master_if -> s9 选通信号（仅 slv_sel==9 时有效）
input			s9_ack_i;	// s9 -> master_if 应答（MUX 送回主设备）
input			s9_err_i;	// s9 -> master_if 错误（MUX 送回主设备）
input			s9_rty_i;	// s9 -> master_if 重试（MUX 送回主设备）

// Slave 10 Interface（从设备 10，对应地址空间 0xAxxxxxxx）
input	[dw-1:0]	s10_data_i;	// s10 -> master_if 读数据
output	[dw-1:0]	s10_data_o;	// master_if -> s10 写数据（广播自 wb_data_i）
output	[aw-1:0]	s10_addr_o;	// master_if -> s10 地址（广播自 wb_addr_i）
output	[sw-1:0]	s10_sel_o;	// master_if -> s10 字节选择（广播自 wb_sel_i）
output			s10_we_o;	// master_if -> s10 读写控制（广播自 wb_we_i）
output			s10_cyc_o;	// master_if -> s10 周期信号（仅 slv_sel==10 时有效，带寄存）
output			s10_stb_o;	// master_if -> s10 选通信号（仅 slv_sel==10 时有效）
input			s10_ack_i;	// s10 -> master_if 应答（MUX 送回主设备）
input			s10_err_i;	// s10 -> master_if 错误（MUX 送回主设备）
input			s10_rty_i;	// s10 -> master_if 重试（MUX 送回主设备）

// Slave 11 Interface（从设备 11，对应地址空间 0xBxxxxxxx）
input	[dw-1:0]	s11_data_i;	// s11 -> master_if 读数据
output	[dw-1:0]	s11_data_o;	// master_if -> s11 写数据（广播自 wb_data_i）
output	[aw-1:0]	s11_addr_o;	// master_if -> s11 地址（广播自 wb_addr_i）
output	[sw-1:0]	s11_sel_o;	// master_if -> s11 字节选择（广播自 wb_sel_i）
output			s11_we_o;	// master_if -> s11 读写控制（广播自 wb_we_i）
output			s11_cyc_o;	// master_if -> s11 周期信号（仅 slv_sel==11 时有效，带寄存）
output			s11_stb_o;	// master_if -> s11 选通信号（仅 slv_sel==11 时有效）
input			s11_ack_i;	// s11 -> master_if 应答（MUX 送回主设备）
input			s11_err_i;	// s11 -> master_if 错误（MUX 送回主设备）
input			s11_rty_i;	// s11 -> master_if 重试（MUX 送回主设备）

// Slave 12 Interface（从设备 12，对应地址空间 0xCxxxxxxx）
input	[dw-1:0]	s12_data_i;	// s12 -> master_if 读数据
output	[dw-1:0]	s12_data_o;	// master_if -> s12 写数据（广播自 wb_data_i）
output	[aw-1:0]	s12_addr_o;	// master_if -> s12 地址（广播自 wb_addr_i）
output	[sw-1:0]	s12_sel_o;	// master_if -> s12 字节选择（广播自 wb_sel_i）
output			s12_we_o;	// master_if -> s12 读写控制（广播自 wb_we_i）
output			s12_cyc_o;	// master_if -> s12 周期信号（仅 slv_sel==12 时有效，带寄存）
output			s12_stb_o;	// master_if -> s12 选通信号（仅 slv_sel==12 时有效）
input			s12_ack_i;	// s12 -> master_if 应答（MUX 送回主设备）
input			s12_err_i;	// s12 -> master_if 错误（MUX 送回主设备）
input			s12_rty_i;	// s12 -> master_if 重试（MUX 送回主设备）

// Slave 13 Interface（从设备 13，对应地址空间 0xDxxxxxxx）
input	[dw-1:0]	s13_data_i;	// s13 -> master_if 读数据
output	[dw-1:0]	s13_data_o;	// master_if -> s13 写数据（广播自 wb_data_i）
output	[aw-1:0]	s13_addr_o;	// master_if -> s13 地址（广播自 wb_addr_i）
output	[sw-1:0]	s13_sel_o;	// master_if -> s13 字节选择（广播自 wb_sel_i）
output			s13_we_o;	// master_if -> s13 读写控制（广播自 wb_we_i）
output			s13_cyc_o;	// master_if -> s13 周期信号（仅 slv_sel==13 时有效，带寄存）
output			s13_stb_o;	// master_if -> s13 选通信号（仅 slv_sel==13 时有效）
input			s13_ack_i;	// s13 -> master_if 应答（MUX 送回主设备）
input			s13_err_i;	// s13 -> master_if 错误（MUX 送回主设备）
input			s13_rty_i;	// s13 -> master_if 重试（MUX 送回主设备）

// Slave 14 Interface（从设备 14，对应地址空间 0xExxxxxxx）
input	[dw-1:0]	s14_data_i;	// s14 -> master_if 读数据
output	[dw-1:0]	s14_data_o;	// master_if -> s14 写数据（广播自 wb_data_i）
output	[aw-1:0]	s14_addr_o;	// master_if -> s14 地址（广播自 wb_addr_i）
output	[sw-1:0]	s14_sel_o;	// master_if -> s14 字节选择（广播自 wb_sel_i）
output			s14_we_o;	// master_if -> s14 读写控制（广播自 wb_we_i）
output			s14_cyc_o;	// master_if -> s14 周期信号（仅 slv_sel==14 时有效，带寄存）
output			s14_stb_o;	// master_if -> s14 选通信号（仅 slv_sel==14 时有效）
input			s14_ack_i;	// s14 -> master_if 应答（MUX 送回主设备）
input			s14_err_i;	// s14 -> master_if 错误（MUX 送回主设备）
input			s14_rty_i;	// s14 -> master_if 重试（MUX 送回主设备）

// Slave 15 Interface（从设备 15，对应地址空间 0xFxxxxxxx）
input	[dw-1:0]	s15_data_i;	// s15 -> master_if 读数据
output	[dw-1:0]	s15_data_o;	// master_if -> s15 写数据（广播自 wb_data_i）
output	[aw-1:0]	s15_addr_o;	// master_if -> s15 地址（广播自 wb_addr_i）
output	[sw-1:0]	s15_sel_o;	// master_if -> s15 字节选择（广播自 wb_sel_i）
output			s15_we_o;	// master_if -> s15 读写控制（广播自 wb_we_i）
output			s15_cyc_o;	// master_if -> s15 周期信号（仅 slv_sel==15 时有效，带寄存）
output			s15_stb_o;	// master_if -> s15 选通信号（仅 slv_sel==15 时有效）
input			s15_ack_i;	// s15 -> master_if 应答（MUX 送回主设备）
input			s15_err_i;	// s15 -> master_if 错误（MUX 送回主设备）
input			s15_rty_i;	// s15 -> master_if 重试（MUX 送回主设备）

////////////////////////////////////////////////////////////////////
//
// Local Wires
//  内部局部信号定义
//

reg	[dw-1:0]	wb_data_o;	// 读数据返回寄存器（组合逻辑驱动，由 MUX 选择选中的从设备读数据）
reg			wb_ack_o;	// 应答信号寄存器（组合逻辑驱动，由 MUX 选择选中的从设备应答）
reg			wb_err_o;	// 错误信号寄存器（组合逻辑驱动，由 MUX 选择选中的从设备错误）
reg			wb_rty_o;	// 重试信号寄存器（组合逻辑驱动，由 MUX 选择选中的从设备重试）
wire	[3:0]		slv_sel;	// 从设备选择信号 = 主设备地址高 4 位 [31:28]，4位可表示 0~15 共 16 个从设备

// 各从设备 cyc_o 的下一状态（组合逻辑），经过寄存器一拍后输出到从设备
wire		s0_cyc_o_next, s1_cyc_o_next, s2_cyc_o_next, s3_cyc_o_next;
wire		s4_cyc_o_next, s5_cyc_o_next, s6_cyc_o_next, s7_cyc_o_next;
wire		s8_cyc_o_next, s9_cyc_o_next, s10_cyc_o_next, s11_cyc_o_next;
wire		s12_cyc_o_next, s13_cyc_o_next, s14_cyc_o_next, s15_cyc_o_next;

// 各从设备 cyc_o 的寄存器输出（时序逻辑，在时钟上升沿更新）
// 使用寄存器是为了在背靠背（back-to-back）跨从设备传输时保持上一个从设备的 cyc_o 状态
reg		s0_cyc_o, s1_cyc_o, s2_cyc_o, s3_cyc_o;
reg		s4_cyc_o, s5_cyc_o, s6_cyc_o, s7_cyc_o;
reg		s8_cyc_o, s9_cyc_o, s10_cyc_o, s11_cyc_o;
reg		s12_cyc_o, s13_cyc_o, s14_cyc_o, s15_cyc_o;

////////////////////////////////////////////////////////////////////
//
// Select logic
//  从设备选择逻辑：取主设备地址的高 4 位 [31:28] 作为从设备编号
//  例如：wb_addr_i = 0x2XXX_XXXX 时，slv_sel = 4'd2，选中从设备 2
//

assign slv_sel = wb_addr_i[aw-1:aw-4];	// slv_sel = wb_addr_i[31:28]，4位对应16个从设备

////////////////////////////////////////////////////////////////////
//
// Address & Data Pass
//  地址、字节选择、写数据 — 广播直通模式
//  策略：这些信号 (addr, sel, data_o) 不经过选择，直接同时发送给所有 16 个从设备
//  原因：只有被选中的从设备才会收到有效的 cyc/stb 信号，未选中的从设备不会响应
//        因此广播不会造成功能错误，反而简化了路由逻辑
//
//  sX_addr_o = wb_addr_i   — 所有从设备收到相同的地址
//  sX_sel_o  = wb_sel_i    — 所有从设备收到相同的字节选择
//  sX_data_o = wb_data_i   — 所有从设备收到相同的写数据
//
//  注意：sX_data_o 是 master_if 发往从设备的写数据（主设备写操作时使用）
//        sX_data_i 是从设备返回的读数据（下面的 MUX 会从中选出一个送给主设备）
// =========================================================================
//

// -------------------- 地址广播：sX_addr_o = wb_addr_i --------------------
assign s0_addr_o = wb_addr_i;	// 从设备0地址 = 主设备地址（广播，所有从设备相同）
assign s1_addr_o = wb_addr_i;	// 从设备1地址 = 主设备地址（广播，所有从设备相同）
assign s2_addr_o = wb_addr_i;	// 从设备2地址 = 主设备地址（广播，所有从设备相同）
assign s3_addr_o = wb_addr_i;	// 从设备3地址 = 主设备地址（广播，所有从设备相同）
assign s4_addr_o = wb_addr_i;	// 从设备4地址 = 主设备地址（广播，所有从设备相同）
assign s5_addr_o = wb_addr_i;	// 从设备5地址 = 主设备地址（广播，所有从设备相同）
assign s6_addr_o = wb_addr_i;	// 从设备6地址 = 主设备地址（广播，所有从设备相同）
assign s7_addr_o = wb_addr_i;	// 从设备7地址 = 主设备地址（广播，所有从设备相同）
assign s8_addr_o = wb_addr_i;	// 从设备8地址 = 主设备地址（广播，所有从设备相同）
assign s9_addr_o = wb_addr_i;	// 从设备9地址 = 主设备地址（广播，所有从设备相同）
assign s10_addr_o = wb_addr_i;	// 从设备10地址 = 主设备地址（广播，所有从设备相同）
assign s11_addr_o = wb_addr_i;	// 从设备11地址 = 主设备地址（广播，所有从设备相同）
assign s12_addr_o = wb_addr_i;	// 从设备12地址 = 主设备地址（广播，所有从设备相同）
assign s13_addr_o = wb_addr_i;	// 从设备13地址 = 主设备地址（广播，所有从设备相同）
assign s14_addr_o = wb_addr_i;	// 从设备14地址 = 主设备地址（广播，所有从设备相同）
assign s15_addr_o = wb_addr_i;	// 从设备15地址 = 主设备地址（广播，所有从设备相同）

// -------------------- 字节选择广播：sX_sel_o = wb_sel_i --------------------
assign s0_sel_o = wb_sel_i;	// 从设备0字节选择 = 主设备字节选择（广播）
assign s1_sel_o = wb_sel_i;	// 从设备1字节选择 = 主设备字节选择（广播）
assign s2_sel_o = wb_sel_i;	// 从设备2字节选择 = 主设备字节选择（广播）
assign s3_sel_o = wb_sel_i;	// 从设备3字节选择 = 主设备字节选择（广播）
assign s4_sel_o = wb_sel_i;	// 从设备4字节选择 = 主设备字节选择（广播）
assign s5_sel_o = wb_sel_i;	// 从设备5字节选择 = 主设备字节选择（广播）
assign s6_sel_o = wb_sel_i;	// 从设备6字节选择 = 主设备字节选择（广播）
assign s7_sel_o = wb_sel_i;	// 从设备7字节选择 = 主设备字节选择（广播）
assign s8_sel_o = wb_sel_i;	// 从设备8字节选择 = 主设备字节选择（广播）
assign s9_sel_o = wb_sel_i;	// 从设备9字节选择 = 主设备字节选择（广播）
assign s10_sel_o = wb_sel_i;	// 从设备10字节选择 = 主设备字节选择（广播）
assign s11_sel_o = wb_sel_i;	// 从设备11字节选择 = 主设备字节选择（广播）
assign s12_sel_o = wb_sel_i;	// 从设备12字节选择 = 主设备字节选择（广播）
assign s13_sel_o = wb_sel_i;	// 从设备13字节选择 = 主设备字节选择（广播）
assign s14_sel_o = wb_sel_i;	// 从设备14字节选择 = 主设备字节选择（广播）
assign s15_sel_o = wb_sel_i;	// 从设备15字节选择 = 主设备字节选择（广播）

// -------------------- 写数据广播：sX_data_o = wb_data_i --------------------
// sX_data_o 是 master_if 输出给从设备的写数据通路（主设备写操作时数据流向：master -> slave）
assign s0_data_o = wb_data_i;	// 从设备0写数据 = 主设备写数据输入（广播）
assign s1_data_o = wb_data_i;	// 从设备1写数据 = 主设备写数据输入（广播）
assign s2_data_o = wb_data_i;	// 从设备2写数据 = 主设备写数据输入（广播）
assign s3_data_o = wb_data_i;	// 从设备3写数据 = 主设备写数据输入（广播）
assign s4_data_o = wb_data_i;	// 从设备4写数据 = 主设备写数据输入（广播）
assign s5_data_o = wb_data_i;	// 从设备5写数据 = 主设备写数据输入（广播）
assign s6_data_o = wb_data_i;	// 从设备6写数据 = 主设备写数据输入（广播）
assign s7_data_o = wb_data_i;	// 从设备7写数据 = 主设备写数据输入（广播）
assign s8_data_o = wb_data_i;	// 从设备8写数据 = 主设备写数据输入（广播）
assign s9_data_o = wb_data_i;	// 从设备9写数据 = 主设备写数据输入（广播）
assign s10_data_o = wb_data_i;	// 从设备10写数据 = 主设备写数据输入（广播）
assign s11_data_o = wb_data_i;	// 从设备11写数据 = 主设备写数据输入（广播）
assign s12_data_o = wb_data_i;	// 从设备12写数据 = 主设备写数据输入（广播）
assign s13_data_o = wb_data_i;	// 从设备13写数据 = 主设备写数据输入（广播）
assign s14_data_o = wb_data_i;	// 从设备14写数据 = 主设备写数据输入（广播）
assign s15_data_o = wb_data_i;	// 从设备15写数据 = 主设备写数据输入（广播）

// =========================================================================
// 读数据 MUX：从被选中的从设备读回数据
//   根据 slv_sel 选择对应的 sX_data_i 送给主设备的 wb_data_o
//   这是一个纯组合逻辑的 16 选 1 多路选择器
//   写操作时该值无意义（此时 wb_we_i=1，主设备不应读取 wb_data_o）
// =========================================================================
always @(slv_sel or s0_data_i or s1_data_i or s2_data_i or s3_data_i or
	s4_data_i or s5_data_i or s6_data_i or s7_data_i or s8_data_i or
	s9_data_i or s10_data_i or s11_data_i or s12_data_i or
	s13_data_i or s14_data_i or s15_data_i)
	case(slv_sel)	// synopsys parallel_case（综合指令：case 分支互斥，生成并行MUX）
	   4'd0:	wb_data_o = s0_data_i;	// slv_sel=0: 选择从设备0的读数据
	   4'd1:	wb_data_o = s1_data_i;	// slv_sel=1: 选择从设备1的读数据
	   4'd2:	wb_data_o = s2_data_i;	// slv_sel=2: 选择从设备2的读数据
	   4'd3:	wb_data_o = s3_data_i;	// slv_sel=3: 选择从设备3的读数据
	   4'd4:	wb_data_o = s4_data_i;	// slv_sel=4: 选择从设备4的读数据
	   4'd5:	wb_data_o = s5_data_i;	// slv_sel=5: 选择从设备5的读数据
	   4'd6:	wb_data_o = s6_data_i;	// slv_sel=6: 选择从设备6的读数据
	   4'd7:	wb_data_o = s7_data_i;	// slv_sel=7: 选择从设备7的读数据
	   4'd8:	wb_data_o = s8_data_i;	// slv_sel=8: 选择从设备8的读数据
	   4'd9:	wb_data_o = s9_data_i;	// slv_sel=9: 选择从设备9的读数据
	   4'd10:	wb_data_o = s10_data_i;	// slv_sel=10: 选择从设备10的读数据
	   4'd11:	wb_data_o = s11_data_i;	// slv_sel=11: 选择从设备11的读数据
	   4'd12:	wb_data_o = s12_data_i;	// slv_sel=12: 选择从设备12的读数据
	   4'd13:	wb_data_o = s13_data_i;	// slv_sel=13: 选择从设备13的读数据
	   4'd14:	wb_data_o = s14_data_i;	// slv_sel=14: 选择从设备14的读数据
	   4'd15:	wb_data_o = s15_data_i;	// slv_sel=15: 选择从设备15的读数据
	   default:	wb_data_o = {dw{1'bx}};	// 不应该到达：非法slv_sel时输出全X
	endcase

////////////////////////////////////////////////////////////////////
//
// Control Signal Pass
//  控制信号直通与选通
//
//  sX_we_o = wb_we_i — 读写控制信号广播到所有从设备（与地址/数据一样，不被选中的从设备忽略）
//  sX_cyc_o — 周期信号仅发往被选中的从设备（带寄存器，支持跨从设备背靠背传输）
//  sX_stb_o — 选通信号仅发往被选中的从设备（组合逻辑，由 slv_sel 即时选择）
// =========================================================================
//

// -------------------- 读写控制广播：sX_we_o = wb_we_i --------------------
assign s0_we_o = wb_we_i;	// 从设备0读写控制 = 主设备读写控制（广播，1=写，0=读）
assign s1_we_o = wb_we_i;	// 从设备1读写控制 = 主设备读写控制（广播）
assign s2_we_o = wb_we_i;	// 从设备2读写控制 = 主设备读写控制（广播）
assign s3_we_o = wb_we_i;	// 从设备3读写控制 = 主设备读写控制（广播）
assign s4_we_o = wb_we_i;	// 从设备4读写控制 = 主设备读写控制（广播）
assign s5_we_o = wb_we_i;	// 从设备5读写控制 = 主设备读写控制（广播）
assign s6_we_o = wb_we_i;	// 从设备6读写控制 = 主设备读写控制（广播）
assign s7_we_o = wb_we_i;	// 从设备7读写控制 = 主设备读写控制（广播）
assign s8_we_o = wb_we_i;	// 从设备8读写控制 = 主设备读写控制（广播）
assign s9_we_o = wb_we_i;	// 从设备9读写控制 = 主设备读写控制（广播）
assign s10_we_o = wb_we_i;	// 从设备10读写控制 = 主设备读写控制（广播）
assign s11_we_o = wb_we_i;	// 从设备11读写控制 = 主设备读写控制（广播）
assign s12_we_o = wb_we_i;	// 从设备12读写控制 = 主设备读写控制（广播）
assign s13_we_o = wb_we_i;	// 从设备13读写控制 = 主设备读写控制（广播）
assign s14_we_o = wb_we_i;	// 从设备14读写控制 = 主设备读写控制（广播）
assign s15_we_o = wb_we_i;	// 从设备15读写控制 = 主设备读写控制（广播）

// =========================================================================
// cyc_o_next 组合逻辑：决定每个从设备下一个周期的 cyc_o 值
//
// 逻辑拆解（以 s0 为例）：
//   assign s0_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s0_cyc_o
//                         : ((slv_sel==4'd0) ? wb_cyc_i : 1'b0);
//
//   情况1：wb_cyc_i=1 且 wb_stb_i=0（背靠背跨从设备传输的间隙）
//         -> 保持当前 sX_cyc_o 不变（旧从设备仍需维持 cyc 来完成事务）
//         此时主设备可能正在切换地址（slv_sel 已改变但 stb 尚未拉高），
//         需要保持前一个从设备的 cyc_o 高电平，以维持 Wishbone 协议连续性
//
//   情况2：其他情况（正常传输中）
//         如果 slv_sel==X -> sX_cyc_o_next = wb_cyc_i（将主设备周期信号传递给选中从设备）
//         如果 slv_sel!=X -> sX_cyc_o_next = 1'b0（未选中从设备 cyc 为低）
//
//   总结：cyc_o 仅在 slv_sel 匹配时传递给对应从设备；
//         背靠背切换时保留旧从设备的 cyc_o 高电平
// =========================================================================

assign s0_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s0_cyc_o : ((slv_sel==4'd0) ? wb_cyc_i : 1'b0); // s0: 背靠背保活 或 选中时传cyc
assign s1_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s1_cyc_o : ((slv_sel==4'd1) ? wb_cyc_i : 1'b0); // s1: 背靠背保活 或 选中时传cyc
assign s2_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s2_cyc_o : ((slv_sel==4'd2) ? wb_cyc_i : 1'b0); // s2: 背靠背保活 或 选中时传cyc
assign s3_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s3_cyc_o : ((slv_sel==4'd3) ? wb_cyc_i : 1'b0); // s3: 背靠背保活 或 选中时传cyc
assign s4_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s4_cyc_o : ((slv_sel==4'd4) ? wb_cyc_i : 1'b0); // s4: 背靠背保活 或 选中时传cyc
assign s5_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s5_cyc_o : ((slv_sel==4'd5) ? wb_cyc_i : 1'b0); // s5: 背靠背保活 或 选中时传cyc
assign s6_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s6_cyc_o : ((slv_sel==4'd6) ? wb_cyc_i : 1'b0); // s6: 背靠背保活 或 选中时传cyc
assign s7_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s7_cyc_o : ((slv_sel==4'd7) ? wb_cyc_i : 1'b0); // s7: 背靠背保活 或 选中时传cyc
assign s8_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s8_cyc_o : ((slv_sel==4'd8) ? wb_cyc_i : 1'b0); // s8: 背靠背保活 或 选中时传cyc
assign s9_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s9_cyc_o : ((slv_sel==4'd9) ? wb_cyc_i : 1'b0); // s9: 背靠背保活 或 选中时传cyc
assign s10_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s10_cyc_o : ((slv_sel==4'd10) ? wb_cyc_i : 1'b0); // s10: 背靠背保活 或 选中时传cyc
assign s11_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s11_cyc_o : ((slv_sel==4'd11) ? wb_cyc_i : 1'b0); // s11: 背靠背保活 或 选中时传cyc
assign s12_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s12_cyc_o : ((slv_sel==4'd12) ? wb_cyc_i : 1'b0); // s12: 背靠背保活 或 选中时传cyc
assign s13_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s13_cyc_o : ((slv_sel==4'd13) ? wb_cyc_i : 1'b0); // s13: 背靠背保活 或 选中时传cyc
assign s14_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s14_cyc_o : ((slv_sel==4'd14) ? wb_cyc_i : 1'b0); // s14: 背靠背保活 或 选中时传cyc
assign s15_cyc_o_next = (wb_cyc_i & !wb_stb_i) ? s15_cyc_o : ((slv_sel==4'd15) ? wb_cyc_i : 1'b0); // s15: 背靠背保活 或 选中时传cyc

// =========================================================================
// 各从设备 cyc_o 寄存器：时序逻辑，带同步复位
//   将 cyc_o_next（组合逻辑）打一拍输出，保证时序收敛
//   复位时所有从设备 cyc_o 清零
//   使用 #1 延迟是为了仿真中避免零延迟竞争（综合时被忽略）
// =========================================================================

always @(posedge clk_i or posedge rst_i) 	// s0 cyc_o 寄存器
	if(rst_i)	s0_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s0_cyc_o <= #1 s0_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s1 cyc_o 寄存器
	if(rst_i)	s1_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s1_cyc_o <= #1 s1_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s2 cyc_o 寄存器
	if(rst_i)	s2_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s2_cyc_o <= #1 s2_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s3 cyc_o 寄存器
	if(rst_i)	s3_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s3_cyc_o <= #1 s3_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s4 cyc_o 寄存器
	if(rst_i)	s4_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s4_cyc_o <= #1 s4_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s5 cyc_o 寄存器
	if(rst_i)	s5_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s5_cyc_o <= #1 s5_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s6 cyc_o 寄存器
	if(rst_i)	s6_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s6_cyc_o <= #1 s6_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s7 cyc_o 寄存器
	if(rst_i)	s7_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s7_cyc_o <= #1 s7_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s8 cyc_o 寄存器
	if(rst_i)	s8_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s8_cyc_o <= #1 s8_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s9 cyc_o 寄存器
	if(rst_i)	s9_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s9_cyc_o <= #1 s9_cyc_o_next; 	// 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s10 cyc_o 寄存器
	if(rst_i)	s10_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s10_cyc_o <= #1 s10_cyc_o_next; // 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s11 cyc_o 寄存器
	if(rst_i)	s11_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s11_cyc_o <= #1 s11_cyc_o_next; // 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s12 cyc_o 寄存器
	if(rst_i)	s12_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s12_cyc_o <= #1 s12_cyc_o_next; // 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s13 cyc_o 寄存器
	if(rst_i)	s13_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s13_cyc_o <= #1 s13_cyc_o_next; // 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s14 cyc_o 寄存器
	if(rst_i)	s14_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s14_cyc_o <= #1 s14_cyc_o_next; // 非复位：更新为下一状态值

always @(posedge clk_i or posedge rst_i) 	// s15 cyc_o 寄存器
	if(rst_i)	s15_cyc_o <= #1 1'b0; 		// 复位：cyc_o 清零
	else		s15_cyc_o <= #1 s15_cyc_o_next; // 非复位：更新为下一状态值

// =========================================================================
// stb_o 组合逻辑选通：仅被选中的从设备收到 wb_stb_i
//   sX_stb_o = (slv_sel==X) ? wb_stb_i : 1'b0
//   未被选中的从设备 stb_o 始终为低（故不会响应传输）
//   这是纯组合逻辑，与 cyc_o（带寄存器）不同——stb 不需要背靠背保活
// =========================================================================

assign s0_stb_o = (slv_sel==4'd0) ? wb_stb_i : 1'b0;	// slv_sel=0 时选通，否则为0
assign s1_stb_o = (slv_sel==4'd1) ? wb_stb_i : 1'b0;	// slv_sel=1 时选通，否则为0
assign s2_stb_o = (slv_sel==4'd2) ? wb_stb_i : 1'b0;	// slv_sel=2 时选通，否则为0
assign s3_stb_o = (slv_sel==4'd3) ? wb_stb_i : 1'b0;	// slv_sel=3 时选通，否则为0
assign s4_stb_o = (slv_sel==4'd4) ? wb_stb_i : 1'b0;	// slv_sel=4 时选通，否则为0
assign s5_stb_o = (slv_sel==4'd5) ? wb_stb_i : 1'b0;	// slv_sel=5 时选通，否则为0
assign s6_stb_o = (slv_sel==4'd6) ? wb_stb_i : 1'b0;	// slv_sel=6 时选通，否则为0
assign s7_stb_o = (slv_sel==4'd7) ? wb_stb_i : 1'b0;	// slv_sel=7 时选通，否则为0
assign s8_stb_o = (slv_sel==4'd8) ? wb_stb_i : 1'b0;	// slv_sel=8 时选通，否则为0
assign s9_stb_o = (slv_sel==4'd9) ? wb_stb_i : 1'b0;	// slv_sel=9 时选通，否则为0
assign s10_stb_o = (slv_sel==4'd10) ? wb_stb_i : 1'b0;	// slv_sel=10 时选通，否则为0
assign s11_stb_o = (slv_sel==4'd11) ? wb_stb_i : 1'b0;	// slv_sel=11 时选通，否则为0
assign s12_stb_o = (slv_sel==4'd12) ? wb_stb_i : 1'b0;	// slv_sel=12 时选通，否则为0
assign s13_stb_o = (slv_sel==4'd13) ? wb_stb_i : 1'b0;	// slv_sel=13 时选通，否则为0
assign s14_stb_o = (slv_sel==4'd14) ? wb_stb_i : 1'b0;	// slv_sel=14 时选通，否则为0
assign s15_stb_o = (slv_sel==4'd15) ? wb_stb_i : 1'b0;	// slv_sel=15 时选通，否则为0

// =========================================================================
// 应答信号 (ack) MUX：从被选中的从设备到主设备
//   根据 slv_sel 选择对应从设备的 ack 信号路由回主设备
//   这是一个 16 选 1 组合逻辑 MUX
//   Wishbone 协议：ack 表示从设备正常完成了一次数据传输
// =========================================================================
always @(slv_sel or s0_ack_i or s1_ack_i or s2_ack_i or s3_ack_i or
	s4_ack_i or s5_ack_i or s6_ack_i or s7_ack_i or s8_ack_i or
	s9_ack_i or s10_ack_i or s11_ack_i or s12_ack_i or
	s13_ack_i or s14_ack_i or s15_ack_i)
	case(slv_sel)	// synopsys parallel_case
	   4'd0:	wb_ack_o = s0_ack_i;	// slv_sel=0: 选通从设备0的应答
	   4'd1:	wb_ack_o = s1_ack_i;	// slv_sel=1: 选通从设备1的应答
	   4'd2:	wb_ack_o = s2_ack_i;	// slv_sel=2: 选通从设备2的应答
	   4'd3:	wb_ack_o = s3_ack_i;	// slv_sel=3: 选通从设备3的应答
	   4'd4:	wb_ack_o = s4_ack_i;	// slv_sel=4: 选通从设备4的应答
	   4'd5:	wb_ack_o = s5_ack_i;	// slv_sel=5: 选通从设备5的应答
	   4'd6:	wb_ack_o = s6_ack_i;	// slv_sel=6: 选通从设备6的应答
	   4'd7:	wb_ack_o = s7_ack_i;	// slv_sel=7: 选通从设备7的应答
	   4'd8:	wb_ack_o = s8_ack_i;	// slv_sel=8: 选通从设备8的应答
	   4'd9:	wb_ack_o = s9_ack_i;	// slv_sel=9: 选通从设备9的应答
	   4'd10:	wb_ack_o = s10_ack_i;	// slv_sel=10: 选通从设备10的应答
	   4'd11:	wb_ack_o = s11_ack_i;	// slv_sel=11: 选通从设备11的应答
	   4'd12:	wb_ack_o = s12_ack_i;	// slv_sel=12: 选通从设备12的应答
	   4'd13:	wb_ack_o = s13_ack_i;	// slv_sel=13: 选通从设备13的应答
	   4'd14:	wb_ack_o = s14_ack_i;	// slv_sel=14: 选通从设备14的应答
	   4'd15:	wb_ack_o = s15_ack_i;	// slv_sel=15: 选通从设备15的应答
	   default:	wb_ack_o = 1'b0;	// 不应该到达：默认输出低电平（无应答）
	endcase

// =========================================================================
// 错误信号 (err) MUX：从被选中的从设备到主设备
//   与 ack MUX 结构完全相同：根据 slv_sel 选通对应从设备的 err 信号
//   Wishbone 协议：err 表示从设备检测到总线错误（如访问非法地址）
// =========================================================================
always @(slv_sel or s0_err_i or s1_err_i or s2_err_i or s3_err_i or
	s4_err_i or s5_err_i or s6_err_i or s7_err_i or s8_err_i or
	s9_err_i or s10_err_i or s11_err_i or s12_err_i or
	s13_err_i or s14_err_i or s15_err_i)
	case(slv_sel)	// synopsys parallel_case
	   4'd0:	wb_err_o = s0_err_i;	// slv_sel=0: 选通从设备0的错误
	   4'd1:	wb_err_o = s1_err_i;	// slv_sel=1: 选通从设备1的错误
	   4'd2:	wb_err_o = s2_err_i;	// slv_sel=2: 选通从设备2的错误
	   4'd3:	wb_err_o = s3_err_i;	// slv_sel=3: 选通从设备3的错误
	   4'd4:	wb_err_o = s4_err_i;	// slv_sel=4: 选通从设备4的错误
	   4'd5:	wb_err_o = s5_err_i;	// slv_sel=5: 选通从设备5的错误
	   4'd6:	wb_err_o = s6_err_i;	// slv_sel=6: 选通从设备6的错误
	   4'd7:	wb_err_o = s7_err_i;	// slv_sel=7: 选通从设备7的错误
	   4'd8:	wb_err_o = s8_err_i;	// slv_sel=8: 选通从设备8的错误
	   4'd9:	wb_err_o = s9_err_i;	// slv_sel=9: 选通从设备9的错误
	   4'd10:	wb_err_o = s10_err_i;	// slv_sel=10: 选通从设备10的错误
	   4'd11:	wb_err_o = s11_err_i;	// slv_sel=11: 选通从设备11的错误
	   4'd12:	wb_err_o = s12_err_i;	// slv_sel=12: 选通从设备12的错误
	   4'd13:	wb_err_o = s13_err_i;	// slv_sel=13: 选通从设备13的错误
	   4'd14:	wb_err_o = s14_err_i;	// slv_sel=14: 选通从设备14的错误
	   4'd15:	wb_err_o = s15_err_i;	// slv_sel=15: 选通从设备15的错误
	   default:	wb_err_o = 1'b0;	// 不应该到达：默认无错误
	endcase

// =========================================================================
// 重试信号 (rty) MUX：从被选中的从设备到主设备
//   与 ack/err MUX 结构相同：根据 slv_sel 选通对应从设备的 rty 信号
//   Wishbone 协议：rty 表示从设备暂时忙，要求主设备稍后重试本次传输
// =========================================================================
always @(slv_sel or s0_rty_i or s1_rty_i or s2_rty_i or s3_rty_i or
	s4_rty_i or s5_rty_i or s6_rty_i or s7_rty_i or s8_rty_i or
	s9_rty_i or s10_rty_i or s11_rty_i or s12_rty_i or
	s13_rty_i or s14_rty_i or s15_rty_i)
	case(slv_sel)	// synopsys parallel_case
	   4'd0:	wb_rty_o = s0_rty_i;	// slv_sel=0: 选通从设备0的重试请求
	   4'd1:	wb_rty_o = s1_rty_i;	// slv_sel=1: 选通从设备1的重试请求
	   4'd2:	wb_rty_o = s2_rty_i;	// slv_sel=2: 选通从设备2的重试请求
	   4'd3:	wb_rty_o = s3_rty_i;	// slv_sel=3: 选通从设备3的重试请求
	   4'd4:	wb_rty_o = s4_rty_i;	// slv_sel=4: 选通从设备4的重试请求
	   4'd5:	wb_rty_o = s5_rty_i;	// slv_sel=5: 选通从设备5的重试请求
	   4'd6:	wb_rty_o = s6_rty_i;	// slv_sel=6: 选通从设备6的重试请求
	   4'd7:	wb_rty_o = s7_rty_i;	// slv_sel=7: 选通从设备7的重试请求
	   4'd8:	wb_rty_o = s8_rty_i;	// slv_sel=8: 选通从设备8的重试请求
	   4'd9:	wb_rty_o = s9_rty_i;	// slv_sel=9: 选通从设备9的重试请求
	   4'd10:	wb_rty_o = s10_rty_i;	// slv_sel=10: 选通从设备10的重试请求
	   4'd11:	wb_rty_o = s11_rty_i;	// slv_sel=11: 选通从设备11的重试请求
	   4'd12:	wb_rty_o = s12_rty_i;	// slv_sel=12: 选通从设备12的重试请求
	   4'd13:	wb_rty_o = s13_rty_i;	// slv_sel=13: 选通从设备13的重试请求
	   4'd14:	wb_rty_o = s14_rty_i;	// slv_sel=14: 选通从设备14的重试请求
	   4'd15:	wb_rty_o = s15_rty_i;	// slv_sel=15: 选通从设备15的重试请求
	   default:	wb_rty_o = 1'b0;	// 不应该到达：默认无重试请求
	endcase

// wb_conmax_master_if 模块结束
// 总结：该模块实现了 Wishbone 总线 1 主对 16 从的交叉互联
//       地址/数据/读写控制采用广播方式（所有从设备均收到）
//       周期/选通信号仅发给被选中的从设备（由 addr[31:28] 选择）
//       应答/错误/重试信号通过 MUX 从选中从设备路由回主设备
endmodule


