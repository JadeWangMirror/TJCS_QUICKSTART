/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE Connection Matrix Master Select                   ////
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

`include "wb_conmax_defines.v"   // 包含WISHBONE Conmax宏定义文件

module wb_conmax_msel(           // 模块：WISHBONE连接矩阵主设备选择器
		clk_i, rst_i,        // 时钟、复位
		conf, req, sel, next // 配置、请求、选择输出、下一目标
	);

////////////////////////////////////////////////////////////////////
//
// Module Parameters
//
// 模块参数

parameter	[1:0]	pri_sel = 2'd0;  // 优先级选择模式：0=简单轮询，1=2级优先级，2=4级优先级

////////////////////////////////////////////////////////////////////
//
// Module IOs
//
// 模块IO

input		clk_i, rst_i;   // 时钟和复位输入
input	[15:0]	conf;           // 16位配置输入，每主设备2位优先级配置
input	[7:0]	req;            // 8位请求输入，每位对应一个主设备
output	[2:0]	sel;            // 3位主设备选择输出，编码被选中的主设备编号
input		next;           // 下一目标信号

////////////////////////////////////////////////////////////////////
//
// Local Wires
//
// 本地线网

wire	[1:0]	pri0, pri1, pri2, pri3;  // 主设备0~3的2位优先级值
wire	[1:0]	pri4, pri5, pri6, pri7;  // 主设备4~7的2位优先级值
wire	[1:0]	pri_out_d;               // 优先级编码器组合逻辑输出
reg	[1:0]	pri_out;                  // 优先级编码器寄存器输出

wire	[7:0]	req_p0, req_p1, req_p2, req_p3;  // 4个优先级级别的请求向量
wire	[2:0]	gnt_p0, gnt_p1, gnt_p2, gnt_p3;  // 4个优先级级别的授权输出

reg	[2:0]	sel1, sel2;   // 中间选择结果寄存器
wire	[2:0]	sel;          // 最终选择输出线网

////////////////////////////////////////////////////////////////////
//
// Priority Select logic
//
// 优先级选择逻辑：根据pri_sel模式从配置字中提取各主设备的优先级

// 主设备0优先级：位0为pri_sel!=0时取自conf[0]，位1为pri_sel==2时取自conf[1]
assign pri0[0] = (pri_sel == 2'd0) ? 1'b0 : conf[0];
assign pri0[1] = (pri_sel == 2'd2) ? conf[1] : 1'b0;

// 主设备1优先级：位0为pri_sel!=0时取自conf[2]，位1为pri_sel==2时取自conf[3]
assign pri1[0] = (pri_sel == 2'd0) ? 1'b0 : conf[2];
assign pri1[1] = (pri_sel == 2'd2) ? conf[3] : 1'b0;

// 主设备2优先级
assign pri2[0] = (pri_sel == 2'd0) ? 1'b0 : conf[4];
assign pri2[1] = (pri_sel == 2'd2) ? conf[5] : 1'b0;

// 主设备3优先级
assign pri3[0] = (pri_sel == 2'd0) ? 1'b0 : conf[6];
assign pri3[1] = (pri_sel == 2'd2) ? conf[7] : 1'b0;

// 主设备4优先级
assign pri4[0] = (pri_sel == 2'd0) ? 1'b0 : conf[8];
assign pri4[1] = (pri_sel == 2'd2) ? conf[9] : 1'b0;

// 主设备5优先级
assign pri5[0] = (pri_sel == 2'd0) ? 1'b0 : conf[10];
assign pri5[1] = (pri_sel == 2'd2) ? conf[11] : 1'b0;

// 主设备6优先级
assign pri6[0] = (pri_sel == 2'd0) ? 1'b0 : conf[12];
assign pri6[1] = (pri_sel == 2'd2) ? conf[13] : 1'b0;

// 主设备7优先级
assign pri7[0] = (pri_sel == 2'd0) ? 1'b0 : conf[14];
assign pri7[1] = (pri_sel == 2'd2) ? conf[15] : 1'b0;

// Priority Encoder
// 实例化优先级编码器，提取当前最高优先级请求的优先级编号
wb_conmax_pri_enc #(pri_sel) pri_enc(
	.valid(		req		),
	.pri0(		pri0		),
	.pri1(		pri1		),
	.pri2(		pri2		),
	.pri3(		pri3		),
	.pri4(		pri4		),
	.pri5(		pri5		),
	.pri6(		pri6		),
	.pri7(		pri7		),
	.pri_out(	pri_out_d	)
	);

// 优先级输出寄存器：上升沿采样
always @(posedge clk_i)
	if(rst_i)	pri_out <= #1 2'h0;     // 复位时清零
	else
	if(next)	pri_out <= #1 pri_out_d; // next有效时更新为编码器输出

////////////////////////////////////////////////////////////////////
//
// Arbiters
//
// 4个仲裁器实例：将请求按优先级分组，每组内使用轮询仲裁

// 优先级0组请求：仅包含优先级为0的主设备请求
assign req_p0[0] = req[0] & (pri0 == 2'd0);
assign req_p0[1] = req[1] & (pri1 == 2'd0);
assign req_p0[2] = req[2] & (pri2 == 2'd0);
assign req_p0[3] = req[3] & (pri3 == 2'd0);
assign req_p0[4] = req[4] & (pri4 == 2'd0);
assign req_p0[5] = req[5] & (pri5 == 2'd0);
assign req_p0[6] = req[6] & (pri6 == 2'd0);
assign req_p0[7] = req[7] & (pri7 == 2'd0);

// 优先级1组请求
assign req_p1[0] = req[0] & (pri0 == 2'd1);
assign req_p1[1] = req[1] & (pri1 == 2'd1);
assign req_p1[2] = req[2] & (pri2 == 2'd1);
assign req_p1[3] = req[3] & (pri3 == 2'd1);
assign req_p1[4] = req[4] & (pri4 == 2'd1);
assign req_p1[5] = req[5] & (pri5 == 2'd1);
assign req_p1[6] = req[6] & (pri6 == 2'd1);
assign req_p1[7] = req[7] & (pri7 == 2'd1);

// 优先级2组请求
assign req_p2[0] = req[0] & (pri0 == 2'd2);
assign req_p2[1] = req[1] & (pri1 == 2'd2);
assign req_p2[2] = req[2] & (pri2 == 2'd2);
assign req_p2[3] = req[3] & (pri3 == 2'd2);
assign req_p2[4] = req[4] & (pri4 == 2'd2);
assign req_p2[5] = req[5] & (pri5 == 2'd2);
assign req_p2[6] = req[6] & (pri6 == 2'd2);
assign req_p2[7] = req[7] & (pri7 == 2'd2);

// 优先级3组请求
assign req_p3[0] = req[0] & (pri0 == 2'd3);
assign req_p3[1] = req[1] & (pri1 == 2'd3);
assign req_p3[2] = req[2] & (pri2 == 2'd3);
assign req_p3[3] = req[3] & (pri3 == 2'd3);
assign req_p3[4] = req[4] & (pri4 == 2'd3);
assign req_p3[5] = req[5] & (pri5 == 2'd3);
assign req_p3[6] = req[6] & (pri6 == 2'd3);
assign req_p3[7] = req[7] & (pri7 == 2'd3);

// 实例化4个轮询仲裁器，每个负责一个优先级组
wb_conmax_arb arb0(
	.clk(		clk_i		),
	.rst(		rst_i		),
	.req(		req_p0		),
	.gnt(		gnt_p0		),
	.next(		1'b0		)    // 仲裁器内部不使用next
	);

wb_conmax_arb arb1(
	.clk(		clk_i		),
	.rst(		rst_i		),
	.req(		req_p1		),
	.gnt(		gnt_p1		),
	.next(		1'b0		)
	);

wb_conmax_arb arb2(
	.clk(		clk_i		),
	.rst(		rst_i		),
	.req(		req_p2		),
	.gnt(		gnt_p2		),
	.next(		1'b0		)
	);

wb_conmax_arb arb3(
	.clk(		clk_i		),
	.rst(		rst_i		),
	.req(		req_p3		),
	.gnt(		gnt_p3		),
	.next(		1'b0		)
	);

////////////////////////////////////////////////////////////////////
//
// Final Master Select
//
// 最终主设备选择：根据优先级编码器输出选择对应优先级组的仲裁结果

// 2级优先级模式：pri_out[0]=1时选优先级1组，否则选优先级0组
always @(pri_out or gnt_p0 or gnt_p1)
	if(pri_out[0])	sel1 = gnt_p1;
	else		sel1 = gnt_p0;

// 4级优先级模式：根据pri_out选择对应优先级组的授权结果
always @(pri_out or gnt_p0 or gnt_p1 or gnt_p2 or gnt_p3)
	case(pri_out)
	   2'd0: sel2 = gnt_p0;
	   2'd1: sel2 = gnt_p1;
	   2'd2: sel2 = gnt_p2;
	   2'd3: sel2 = gnt_p3;
	endcase

// 根据pri_sel模式选择最终输出：0=直接轮询，1=2级优先级，2=4级优先级
assign sel = (pri_sel==2'd0) ? gnt_p0 : ( (pri_sel==2'd1) ? sel1 : sel2 );

endmodule  // 模块定义结束
