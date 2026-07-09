/////////////////////////////////////////////////////////////////////
////                                                             ////
////  General Round Robin Arbiter                                ////
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
//
//

`include "wb_conmax_defines.v"   // 包含WISHBONE Conmax宏定义文件

module wb_conmax_arb(clk, rst, req, gnt, next);  // 模块：通用轮询仲裁器

input		clk;     // 时钟输入
input		rst;     // 复位输入，高有效
input	[7:0]	req;     // 请求输入，8位对应8个主设备		// Req input
output	[2:0]	gnt;     // 授权输出，3位编码当前授权的主设备编号 		// Grant output
input		next;    // 下一目标信号，用于触发仲裁切换		// Next Target

///////////////////////////////////////////////////////////////////////
//
// Parameters
//
// 参数定义：8个授权状态的编码值

parameter	[2:0]
                grant0 = 3'h0,   // 授权主设备0
                grant1 = 3'h1,   // 授权主设备1
                grant2 = 3'h2,   // 授权主设备2
                grant3 = 3'h3,   // 授权主设备3
                grant4 = 3'h4,   // 授权主设备4
                grant5 = 3'h5,   // 授权主设备5
                grant6 = 3'h6,   // 授权主设备6
                grant7 = 3'h7;   // 授权主设备7

///////////////////////////////////////////////////////////////////////
//
// Local Registers and Wires
//
// 本地寄存器和线网

reg [2:0]	state, next_state;  // 当前状态寄存器和下一状态组合逻辑

///////////////////////////////////////////////////////////////////////
//
//  Misc Logic
//
// 杂项逻辑

assign	gnt = state;  // 授权输出等于当前状态

// 状态寄存器：时钟上升沿或复位上升沿触发
always@(posedge clk or posedge rst)
	if(rst)		state <= #1 grant0;   // 复位时回到授权主设备0
	else		state <= #1 next_state; // 否则更新为下一状态

///////////////////////////////////////////////////////////////////////
//
// Next State Logic
//   - implements round robin arbitration algorithm
//   - switches grant if current req is dropped or next is asserted
//   - parks at last grant
//
// 下一状态组合逻辑
//   - 实现轮询仲裁算法
//   - 若当前请求被撤销或next信号有效，则切换授权
//   - 无请求时停留在上一个授权状态

always@(state or req or next)
   begin
	next_state = state;	// 默认保持当前状态	// Default Keep State
	case(state)		// 根据当前状态选择分支	// synopsys parallel_case full_case
 	   grant0:      // 当前授权主设备0
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[0] | next)
		   begin
			if(req[1])	next_state = grant1;  // 若主设备1有请求，授权给它
			else
			if(req[2])	next_state = grant2;  // 否则若主设备2有请求
			else
			if(req[3])	next_state = grant3;  // 否则若主设备3有请求
			else
			if(req[4])	next_state = grant4;  // 否则若主设备4有请求
			else
			if(req[5])	next_state = grant5;  // 否则若主设备5有请求
			else
			if(req[6])	next_state = grant6;  // 否则若主设备6有请求
			else
			if(req[7])	next_state = grant7;  // 否则若主设备7有请求
		   end
 	   grant1:      // 当前授权主设备1
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[1] | next)
		   begin
			if(req[2])	next_state = grant2;  // 按轮询顺序从下一个开始检查
			else
			if(req[3])	next_state = grant3;
			else
			if(req[4])	next_state = grant4;
			else
			if(req[5])	next_state = grant5;
			else
			if(req[6])	next_state = grant6;
			else
			if(req[7])	next_state = grant7;
			else
			if(req[0])	next_state = grant0;  // 轮询绕回主设备0
		   end
 	   grant2:      // 当前授权主设备2
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[2] | next)
		   begin
			if(req[3])	next_state = grant3;
			else
			if(req[4])	next_state = grant4;
			else
			if(req[5])	next_state = grant5;
			else
			if(req[6])	next_state = grant6;
			else
			if(req[7])	next_state = grant7;
			else
			if(req[0])	next_state = grant0;
			else
			if(req[1])	next_state = grant1;
		   end
 	   grant3:      // 当前授权主设备3
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[3] | next)
		   begin
			if(req[4])	next_state = grant4;
			else
			if(req[5])	next_state = grant5;
			else
			if(req[6])	next_state = grant6;
			else
			if(req[7])	next_state = grant7;
			else
			if(req[0])	next_state = grant0;
			else
			if(req[1])	next_state = grant1;
			else
			if(req[2])	next_state = grant2;
		   end
 	   grant4:      // 当前授权主设备4
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[4] | next)
		   begin
			if(req[5])	next_state = grant5;
			else
			if(req[6])	next_state = grant6;
			else
			if(req[7])	next_state = grant7;
			else
			if(req[0])	next_state = grant0;
			else
			if(req[1])	next_state = grant1;
			else
			if(req[2])	next_state = grant2;
			else
			if(req[3])	next_state = grant3;
		   end
 	   grant5:      // 当前授权主设备5
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[5] | next)
		   begin
			if(req[6])	next_state = grant6;
			else
			if(req[7])	next_state = grant7;
			else
			if(req[0])	next_state = grant0;
			else
			if(req[1])	next_state = grant1;
			else
			if(req[2])	next_state = grant2;
			else
			if(req[3])	next_state = grant3;
			else
			if(req[4])	next_state = grant4;
		   end
 	   grant6:      // 当前授权主设备6
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[6] | next)
		   begin
			if(req[7])	next_state = grant7;
			else
			if(req[0])	next_state = grant0;
			else
			if(req[1])	next_state = grant1;
			else
			if(req[2])	next_state = grant2;
			else
			if(req[3])	next_state = grant3;
			else
			if(req[4])	next_state = grant4;
			else
			if(req[5])	next_state = grant5;
		   end
 	   grant7:      // 当前授权主设备7
		// 若该请求被撤销或next信号有效，检查其他请求 // if this req is dropped or next is asserted, check for other req's
		if(!req[7] | next)
		   begin
			if(req[0])	next_state = grant0;
			else
			if(req[1])	next_state = grant1;
			else
			if(req[2])	next_state = grant2;
			else
			if(req[3])	next_state = grant3;
			else
			if(req[4])	next_state = grant4;
			else
			if(req[5])	next_state = grant5;
			else
			if(req[6])	next_state = grant6;
		   end
	endcase
   end

endmodule  // 模块定义结束
