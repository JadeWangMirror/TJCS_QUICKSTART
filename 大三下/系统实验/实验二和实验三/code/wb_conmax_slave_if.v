/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE Connection Matrix Slave Interface                 ////
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

module wb_conmax_slave_if(       // 模块：WISHBONE连接矩阵从设备接口

	clk_i, rst_i, conf,      // 时钟、复位、配置

	// 从设备接口（连接WISHBONE总线从设备） // Slave interface
	wb_data_i, wb_data_o, wb_addr_o, wb_sel_o, wb_we_o, wb_cyc_o,
	wb_stb_o, wb_ack_i, wb_err_i, wb_rty_i,

	// 主设备0接口 // Master 0 Interface
	m0_data_i, m0_data_o, m0_addr_i, m0_sel_i, m0_we_i, m0_cyc_i,
	m0_stb_i, m0_ack_o, m0_err_o, m0_rty_o,

	// 主设备1接口 // Master 1 Interface
	m1_data_i, m1_data_o, m1_addr_i, m1_sel_i, m1_we_i, m1_cyc_i,
	m1_stb_i, m1_ack_o, m1_err_o, m1_rty_o,

	// 主设备2接口 // Master 2 Interface
	m2_data_i, m2_data_o, m2_addr_i, m2_sel_i, m2_we_i, m2_cyc_i,
	m2_stb_i, m2_ack_o, m2_err_o, m2_rty_o,

	// 主设备3接口 // Master 3 Interface
	m3_data_i, m3_data_o, m3_addr_i, m3_sel_i, m3_we_i, m3_cyc_i,
	m3_stb_i, m3_ack_o, m3_err_o, m3_rty_o,

	// 主设备4接口 // Master 4 Interface
	m4_data_i, m4_data_o, m4_addr_i, m4_sel_i, m4_we_i, m4_cyc_i,
	m4_stb_i, m4_ack_o, m4_err_o, m4_rty_o,

	// 主设备5接口 // Master 5 Interface
	m5_data_i, m5_data_o, m5_addr_i, m5_sel_i, m5_we_i, m5_cyc_i,
	m5_stb_i, m5_ack_o, m5_err_o, m5_rty_o,

	// 主设备6接口 // Master 6 Interface
	m6_data_i, m6_data_o, m6_addr_i, m6_sel_i, m6_we_i, m6_cyc_i,
	m6_stb_i, m6_ack_o, m6_err_o, m6_rty_o,

	// 主设备7接口 // Master 7 Interface
	m7_data_i, m7_data_o, m7_addr_i, m7_sel_i, m7_we_i, m7_cyc_i,
	m7_stb_i, m7_ack_o, m7_err_o, m7_rty_o
	);

////////////////////////////////////////////////////////////////////
//
// Module Parameters
//
// 模块参数

parameter [1:0]		pri_sel = 2'd2;  // 优先级选择模式，默认4级优先级
parameter		aw	= 32;         // 地址总线宽度（Address bus Width）
parameter		dw	= 32;         // 数据总线宽度（Data bus Width）
parameter		sw	= dw / 8;     // 字节选择线数量（Number of Select Lines）

////////////////////////////////////////////////////////////////////
//
// Module IOs
//
// 模块IO声明

input			clk_i, rst_i;   // 时钟和复位
input	[15:0]		conf;           // 16位配置输入

// Slave Interface
// 从设备接口信号
input	[dw-1:0]	wb_data_i;      // 从设备读数据输入
output	[dw-1:0]	wb_data_o;      // 从设备写数据输出
output	[aw-1:0]	wb_addr_o;      // 从设备地址输出
output	[sw-1:0]	wb_sel_o;       // 从设备字节选择输出
output			wb_we_o;        // 从设备写使能输出
output			wb_cyc_o;       // 从设备周期信号输出
output			wb_stb_o;       // 从设备选通信号输出
input			wb_ack_i;       // 从设备应答输入
input			wb_err_i;       // 从设备错误输入
input			wb_rty_i;       // 从设备重试输入

// Master 0 Interface
// 主设备0接口信号
input	[dw-1:0]	m0_data_i;      // 主设备0写数据输入
output	[dw-1:0]	m0_data_o;      // 主设备0读数据输出
input	[aw-1:0]	m0_addr_i;      // 主设备0地址输入
input	[sw-1:0]	m0_sel_i;       // 主设备0字节选择输入
input			m0_we_i;        // 主设备0写使能输入
input			m0_cyc_i;       // 主设备0周期信号输入
input			m0_stb_i;       // 主设备0选通信号输入
output			m0_ack_o;       // 主设备0应答输出
output			m0_err_o;       // 主设备0错误输出
output			m0_rty_o;       // 主设备0重试输出

// Master 1 Interface
// 主设备1接口信号
input	[dw-1:0]	m1_data_i;
output	[dw-1:0]	m1_data_o;
input	[aw-1:0]	m1_addr_i;
input	[sw-1:0]	m1_sel_i;
input			m1_we_i;
input			m1_cyc_i;
input			m1_stb_i;
output			m1_ack_o;
output			m1_err_o;
output			m1_rty_o;

// Master 2 Interface
// 主设备2接口信号
input	[dw-1:0]	m2_data_i;
output	[dw-1:0]	m2_data_o;
input	[aw-1:0]	m2_addr_i;
input	[sw-1:0]	m2_sel_i;
input			m2_we_i;
input			m2_cyc_i;
input			m2_stb_i;
output			m2_ack_o;
output			m2_err_o;
output			m2_rty_o;

// Master 3 Interface
// 主设备3接口信号
input	[dw-1:0]	m3_data_i;
output	[dw-1:0]	m3_data_o;
input	[aw-1:0]	m3_addr_i;
input	[sw-1:0]	m3_sel_i;
input			m3_we_i;
input			m3_cyc_i;
input			m3_stb_i;
output			m3_ack_o;
output			m3_err_o;
output			m3_rty_o;

// Master 4 Interface
// 主设备4接口信号
input	[dw-1:0]	m4_data_i;
output	[dw-1:0]	m4_data_o;
input	[aw-1:0]	m4_addr_i;
input	[sw-1:0]	m4_sel_i;
input			m4_we_i;
input			m4_cyc_i;
input			m4_stb_i;
output			m4_ack_o;
output			m4_err_o;
output			m4_rty_o;

// Master 5 Interface
// 主设备5接口信号
input	[dw-1:0]	m5_data_i;
output	[dw-1:0]	m5_data_o;
input	[aw-1:0]	m5_addr_i;
input	[sw-1:0]	m5_sel_i;
input			m5_we_i;
input			m5_cyc_i;
input			m5_stb_i;
output			m5_ack_o;
output			m5_err_o;
output			m5_rty_o;

// Master 6 Interface
// 主设备6接口信号
input	[dw-1:0]	m6_data_i;
output	[dw-1:0]	m6_data_o;
input	[aw-1:0]	m6_addr_i;
input	[sw-1:0]	m6_sel_i;
input			m6_we_i;
input			m6_cyc_i;
input			m6_stb_i;
output			m6_ack_o;
output			m6_err_o;
output			m6_rty_o;

// Master 7 Interface
// 主设备7接口信号
input	[dw-1:0]	m7_data_i;
output	[dw-1:0]	m7_data_o;
input	[aw-1:0]	m7_addr_i;
input	[sw-1:0]	m7_sel_i;
input			m7_we_i;
input			m7_cyc_i;
input			m7_stb_i;
output			m7_ack_o;
output			m7_err_o;
output			m7_rty_o;

////////////////////////////////////////////////////////////////////
//
// Local Wires
//
// 本地线网和寄存器

reg	[aw-1:0]	wb_addr_o;      // 从设备地址输出寄存器
reg	[dw-1:0]	wb_data_o;      // 从设备数据输出寄存器
reg	[sw-1:0]	wb_sel_o;       // 从设备字节选择输出寄存器
reg			wb_we_o;        // 从设备写使能输出寄存器
reg			wb_cyc_o;       // 从设备周期信号输出寄存器
reg			wb_stb_o;       // 从设备选通信号输出寄存器
wire	[2:0]		mast_sel_simple;  // 简单轮询模式的主设备选择
wire	[2:0]		mast_sel_pe;      // 优先级编码模式的主设备选择
wire	[2:0]		mast_sel;         // 最终主设备选择结果

reg			next;           // 下一目标信号寄存器
reg			m0_cyc_r, m1_cyc_r, m2_cyc_r, m3_cyc_r;  // 主设备0~3周期信号延迟
reg			m4_cyc_r, m5_cyc_r, m6_cyc_r, m7_cyc_r;  // 主设备4~7周期信号延迟

////////////////////////////////////////////////////////////////////
//
// Select logic
//
// 主设备选择逻辑

// 产生next信号：当前总线周期结束时（wb_cyc_o下降沿）触发
always @(posedge clk_i)
	next <= #1 ~wb_cyc_o;

// 简单轮询仲裁器：始终使用轮询方式
wb_conmax_arb arb(
	.clk(		clk_i		),
	.rst(		rst_i		),
	.req(	{	m7_cyc_i,   // 位7：主设备7请求
			m6_cyc_i,   // 位6
			m5_cyc_i,   // 位5
			m4_cyc_i,   // 位4
			m3_cyc_i,   // 位3
			m2_cyc_i,   // 位2
			m1_cyc_i,   // 位1
			m0_cyc_i }	),  // 位0：主设备0请求
	.gnt(		mast_sel_simple	),  // 简单轮询授权输出
	.next(		1'b0		)
	);

// 优先级主设备选择器：支持优先级配置
wb_conmax_msel #(pri_sel) msel(
	.clk_i(		clk_i		),
	.rst_i(		rst_i		),
	.conf(		conf		),
	.req(	{	m7_cyc_i,
			m6_cyc_i,
			m5_cyc_i,
			m4_cyc_i,
			m3_cyc_i,
			m2_cyc_i,
			m1_cyc_i,
			m0_cyc_i}	),
	.sel(		mast_sel_pe	),  // 优先级选择输出
	.next(		next		)
	);

// 根据pri_sel选择最终主设备选择来源：0=简单轮询，非0=优先级模式
assign mast_sel = (pri_sel == 2'd0) ? mast_sel_simple : mast_sel_pe;

////////////////////////////////////////////////////////////////////
//
// Address & Data Pass
//
// 地址和数据通路：根据mast_sel将选中主设备的信号路由到从设备接口

// 地址多路选择：将选中主设备的地址输出到从设备
always @(mast_sel or m0_addr_i or m1_addr_i or m2_addr_i or m3_addr_i
	or m4_addr_i or m5_addr_i or m6_addr_i or m7_addr_i)
	case(mast_sel)	// synopsys parallel_case
	   3'd0: wb_addr_o = m0_addr_i;  // 主设备0选中
	   3'd1: wb_addr_o = m1_addr_i;  // 主设备1选中
	   3'd2: wb_addr_o = m2_addr_i;  // 主设备2选中
	   3'd3: wb_addr_o = m3_addr_i;  // 主设备3选中
	   3'd4: wb_addr_o = m4_addr_i;  // 主设备4选中
	   3'd5: wb_addr_o = m5_addr_i;  // 主设备5选中
	   3'd6: wb_addr_o = m6_addr_i;  // 主设备6选中
	   3'd7: wb_addr_o = m7_addr_i;  // 主设备7选中
	   default: wb_addr_o = {aw{1'bx}};  // 默认值（不定态）
	endcase

// 字节选择多路选择
always @(mast_sel or m0_sel_i or m1_sel_i or m2_sel_i or m3_sel_i
	or m4_sel_i or m5_sel_i or m6_sel_i or m7_sel_i)
	case(mast_sel)	// synopsys parallel_case
	   3'd0: wb_sel_o = m0_sel_i;
	   3'd1: wb_sel_o = m1_sel_i;
	   3'd2: wb_sel_o = m2_sel_i;
	   3'd3: wb_sel_o = m3_sel_i;
	   3'd4: wb_sel_o = m4_sel_i;
	   3'd5: wb_sel_o = m5_sel_i;
	   3'd6: wb_sel_o = m6_sel_i;
	   3'd7: wb_sel_o = m7_sel_i;
	   default: wb_sel_o = {sw{1'bx}};  // 默认值（不定态）
	endcase

// 写数据多路选择
always @(mast_sel or m0_data_i or m1_data_i or m2_data_i or m3_data_i
	or m4_data_i or m5_data_i or m6_data_i or m7_data_i)
	case(mast_sel)	// synopsys parallel_case
	   3'd0: wb_data_o = m0_data_i;
	   3'd1: wb_data_o = m1_data_i;
	   3'd2: wb_data_o = m2_data_i;
	   3'd3: wb_data_o = m3_data_i;
	   3'd4: wb_data_o = m4_data_i;
	   3'd5: wb_data_o = m5_data_i;
	   3'd6: wb_data_o = m6_data_i;
	   3'd7: wb_data_o = m7_data_i;
	   default: wb_data_o = {dw{1'bx}};  // 默认值（不定态）
	endcase

// 读数据广播：从设备读数据同时广播给所有主设备
assign m0_data_o = wb_data_i;
assign m1_data_o = wb_data_i;
assign m2_data_o = wb_data_i;
assign m3_data_o = wb_data_i;
assign m4_data_o = wb_data_i;
assign m5_data_o = wb_data_i;
assign m6_data_o = wb_data_i;
assign m7_data_o = wb_data_i;

////////////////////////////////////////////////////////////////////
//
// Control Signal Pass
//
// 控制信号通路

// 写使能多路选择
always @(mast_sel or m0_we_i or m1_we_i or m2_we_i or m3_we_i
	or m4_we_i or m5_we_i or m6_we_i or m7_we_i)
	case(mast_sel)	// synopsys parallel_case
	   3'd0: wb_we_o = m0_we_i;
	   3'd1: wb_we_o = m1_we_i;
	   3'd2: wb_we_o = m2_we_i;
	   3'd3: wb_we_o = m3_we_i;
	   3'd4: wb_we_o = m4_we_i;
	   3'd5: wb_we_o = m5_we_i;
	   3'd6: wb_we_o = m6_we_i;
	   3'd7: wb_we_o = m7_we_i;
	   default: wb_we_o = 1'bx;  // 默认值（不定态）
	endcase

// 各主设备周期信号延迟一拍（用于消抖/同步）
always @(posedge clk_i)
	m0_cyc_r <= #1 m0_cyc_i;

always @(posedge clk_i)
	m1_cyc_r <= #1 m1_cyc_i;

always @(posedge clk_i)
	m2_cyc_r <= #1 m2_cyc_i;

always @(posedge clk_i)
	m3_cyc_r <= #1 m3_cyc_i;

always @(posedge clk_i)
	m4_cyc_r <= #1 m4_cyc_i;

always @(posedge clk_i)
	m5_cyc_r <= #1 m5_cyc_i;

always @(posedge clk_i)
	m6_cyc_r <= #1 m6_cyc_i;

always @(posedge clk_i)
	m7_cyc_r <= #1 m7_cyc_i;

// 周期信号多路选择（使用延迟后的信号进行门控，防止毛刺）
always @(mast_sel or m0_cyc_i or m1_cyc_i or m2_cyc_i or m3_cyc_i
	or m4_cyc_i or m5_cyc_i or m6_cyc_i or m7_cyc_i
	or m0_cyc_r or m1_cyc_r or m2_cyc_r or m3_cyc_r
	or m4_cyc_r or m5_cyc_r or m6_cyc_r or m7_cyc_r)
	case(mast_sel)	// synopsys parallel_case
	   3'd0: wb_cyc_o = m0_cyc_i & m0_cyc_r;  // 当前值与延迟值相与，过滤毛刺
	   3'd1: wb_cyc_o = m1_cyc_i & m1_cyc_r;
	   3'd2: wb_cyc_o = m2_cyc_i & m2_cyc_r;
	   3'd3: wb_cyc_o = m3_cyc_i & m3_cyc_r;
	   3'd4: wb_cyc_o = m4_cyc_i & m4_cyc_r;
	   3'd5: wb_cyc_o = m5_cyc_i & m5_cyc_r;
	   3'd6: wb_cyc_o = m6_cyc_i & m6_cyc_r;
	   3'd7: wb_cyc_o = m7_cyc_i & m7_cyc_r;
	   default: wb_cyc_o = 1'b0;
	endcase

// 选通信号多路选择
always @(mast_sel or m0_stb_i or m1_stb_i or m2_stb_i or m3_stb_i
	or m4_stb_i or m5_stb_i or m6_stb_i or m7_stb_i)
	case(mast_sel)	// synopsys parallel_case
	   3'd0: wb_stb_o = m0_stb_i;
	   3'd1: wb_stb_o = m1_stb_i;
	   3'd2: wb_stb_o = m2_stb_i;
	   3'd3: wb_stb_o = m3_stb_i;
	   3'd4: wb_stb_o = m4_stb_i;
	   3'd5: wb_stb_o = m5_stb_i;
	   3'd6: wb_stb_o = m6_stb_i;
	   3'd7: wb_stb_o = m7_stb_i;
	   default: wb_stb_o = 1'b0;
	endcase

// 应答信号路由：仅当主设备被选中且从设备应答时才向该主设备发出应答
assign m0_ack_o = (mast_sel==3'd0) & wb_ack_i;
assign m1_ack_o = (mast_sel==3'd1) & wb_ack_i;
assign m2_ack_o = (mast_sel==3'd2) & wb_ack_i;
assign m3_ack_o = (mast_sel==3'd3) & wb_ack_i;
assign m4_ack_o = (mast_sel==3'd4) & wb_ack_i;
assign m5_ack_o = (mast_sel==3'd5) & wb_ack_i;
assign m6_ack_o = (mast_sel==3'd6) & wb_ack_i;
assign m7_ack_o = (mast_sel==3'd7) & wb_ack_i;

// 错误信号路由：仅当主设备被选中且从设备报错时才向该主设备发出错误
assign m0_err_o = (mast_sel==3'd0) & wb_err_i;
assign m1_err_o = (mast_sel==3'd1) & wb_err_i;
assign m2_err_o = (mast_sel==3'd2) & wb_err_i;
assign m3_err_o = (mast_sel==3'd3) & wb_err_i;
assign m4_err_o = (mast_sel==3'd4) & wb_err_i;
assign m5_err_o = (mast_sel==3'd5) & wb_err_i;
assign m6_err_o = (mast_sel==3'd6) & wb_err_i;
assign m7_err_o = (mast_sel==3'd7) & wb_err_i;

// 重试信号路由：仅当主设备被选中且从设备请求重试时才向该主设备发出重试
assign m0_rty_o = (mast_sel==3'd0) & wb_rty_i;
assign m1_rty_o = (mast_sel==3'd1) & wb_rty_i;
assign m2_rty_o = (mast_sel==3'd2) & wb_rty_i;
assign m3_rty_o = (mast_sel==3'd3) & wb_rty_i;
assign m4_rty_o = (mast_sel==3'd4) & wb_rty_i;
assign m5_rty_o = (mast_sel==3'd5) & wb_rty_i;
assign m6_rty_o = (mast_sel==3'd6) & wb_rty_i;
assign m7_rty_o = (mast_sel==3'd7) & wb_rty_i;

endmodule  // 模块定义结束
