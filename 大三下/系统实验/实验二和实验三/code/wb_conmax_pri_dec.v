//////////////////////////////////////////////////////////////////////
// File:    wb_conmax_pri_dec.v
// Description: Wishbone ConMax 优先级解码器
//             功能: 将二进制编码的优先级值解码为独热码 (one-hot)
//             基于 OpenCores wb_conmax 项目
//////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE Connection Matrix Priority Decoder                ////
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

`include "wb_conmax_defines.v"			// 包含 Wishbone ConMax 宏定义文件（定义参数、地址映射等）

// 模块名: wb_conmax_pri_dec —— Wishbone ConMax 优先级解码器
// 功能: 将主设备(master)的 2-bit 二进制优先级值(pri_in)解码为 4-bit 独热码(one-hot)输出(pri_out)
// 独热码输出随后送入 pri_enc（优先级编码器）进行 OR 归约 + 前导1检测，实现多主设备的优先级仲裁
module wb_conmax_pri_dec(valid, pri_in, pri_out);

////////////////////////////////////////////////////////////////////
//
// Module Parameters
//

parameter [1:0]	pri_sel = 2'd0;		// pri_sel: 优先级级数选择参数
						//   pri_sel >= 2: 4级优先级模式（pri_in: 0/1/2/3 → 0001/0010/0100/1000）
						//   pri_sel == 1: 2级优先级模式（pri_in: 0 → 0001, 非0 → 0010）
						//   pri_sel == 0: 输出全0，表示优先级功能禁用

////////////////////////////////////////////////////////////////////
//
// Module IOs
//

input		valid;			// valid: 主设备请求有效信号，高有效
					//   valid=0 时表示该主设备未发起总线请求，默认分配最低优先级（pri_out = 4'b0001）
input	[1:0]	pri_in;			// pri_in:  2-bit 二进制编码的优先级输入值，来自主设备的优先级配置
output	[3:0]	pri_out;		// pri_out: 4-bit 独热码(one-hot)优先级输出，送往优先级编码器 pri_enc
					//   独热码中为1的位位置表示优先级等级，例如 4'b0100 表示优先级等级2

////////////////////////////////////////////////////////////////////
//
// Local Wires
//

wire	[3:0]	pri_out;		// pri_out: 最终输出线网，由 assign 连续赋值驱动
reg	[3:0]	pri_out_d0;		// pri_out_d0: 2级优先级模式下的解码结果寄存器
reg	[3:0]	pri_out_d1;		// pri_out_d1: 4级优先级模式下的解码结果寄存器

////////////////////////////////////////////////////////////////////
//
// Priority Decoder
//

// 4 Priority Levels —— 4级优先级解码逻辑
// 将 2-bit 的 pri_in 解码为 4-bit 独热码，实现四级优先级仲裁
// 独热码映射: pri_in=0 → 0001 (最低优先级), 1 → 0010, 2 → 0100, 3 → 1000 (最高优先级)
always @(valid or pri_in)		// 组合逻辑，valid 或 pri_in 任一变化即触发重新计算
	if(!valid)		pri_out_d1 = 4'b0001;	// 主设备未请求(valid=0): 默认赋予优先级0 (最低优先级，独热码 0001)
	else
	if(pri_in==2'h0)	pri_out_d1 = 4'b0001;	// pri_in=0: 优先级等级0（最低），独热码 bit[0]=1
	else
	if(pri_in==2'h1)	pri_out_d1 = 4'b0010;	// pri_in=1: 优先级等级1，独热码 bit[1]=1
	else
	if(pri_in==2'h2)	pri_out_d1 = 4'b0100;	// pri_in=2: 优先级等级2，独热码 bit[2]=1
	else			pri_out_d1 = 4'b1000;	// pri_in=3（或其他值）: 优先级等级3（最高），独热码 bit[3]=1

// 2 Priority Levels —— 2级优先级解码逻辑
// 仅区分"低优先级"(pri_in=0)和"高优先级"(pri_in!=0)两种情况
// 适用于只需简单两级仲裁的系统配置
always @(valid or pri_in)		// 组合逻辑，valid 或 pri_in 任一变化即触发重新计算
	if(!valid)		pri_out_d0 = 4'b0001;	// 主设备未请求(valid=0): 默认赋予优先级0（独热码 0001）
	else
	if(pri_in==2'h0)	pri_out_d0 = 4'b0001;	// pri_in=0: 低优先级，独热码 bit[0]=1
	else			pri_out_d0 = 4'b0010;	// pri_in!=0: 高优先级，独热码 bit[1]=1（所有非零值均视为同一高优先级）

// Select Configured Priority —— 根据参数 pri_sel 选择最终输出的优先级模式
// pri_sel==0: 优先级功能禁用，输出全0
// pri_sel==1: 选择2级优先级模式，输出 pri_out_d0
// pri_sel>=2: 选择4级优先级模式，输出 pri_out_d1（即 pri_sel!=0 且 pri_sel!=1 的所有情况）
assign pri_out = (pri_sel==2'd0) ? 4'h0 : ( (pri_sel==1'd1) ? pri_out_d0 : pri_out_d1 );
//                 └─ pri_sel=0 ─┘        └── pri_sel=1 ──┘      └─ pri_sel>=2 ─┘
//                 优先级禁用，输出0         2级优先级模式           4级优先级模式

endmodule

