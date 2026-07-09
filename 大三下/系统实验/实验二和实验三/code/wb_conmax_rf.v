//////////////////////////////////////////////////////////////////////
// File:    wb_conmax_rf.v
// Description: Wishbone ConMax 寄存器文件 — 存储主设备到从设备的路由信息
//             功能: 为每个主设备存储其目标从设备编号和地址信息
//             基于 OpenCores wb_conmax 项目
//////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE Connection Matrix Register File                   ////
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

`include "wb_conmax_defines.v"	// 包含共享宏定义文件（如地址宽度、数据宽度等参数）

// ============================================================================
// 模块名称: wb_conmax_rf（WISHBONE连接矩阵寄存器文件）
// 功能描述: 该模块实现了WISHBONE总线互连矩阵中的寄存器文件，
//          用于存储16个从设备（slave）的16位配置字。
//          模块对外呈现两组WISHBONE接口:
//            - Internal Wishbone (i_wb_*): 面向主设备（master）的内部总线接口
//            - External Wishbone (e_wb_*): 面向从设备的对外总线接口
//          当主设备访问本寄存器文件地址空间（rf_addr）时，访问在内部处理，
//          不传递到外部总线；其他地址则直通（bypass）到外部接口。
// ============================================================================
module wb_conmax_rf(
		clk_i, rst_i,	// 时钟和复位信号

		// Internal Wishbone Interface — 面向主设备的内部总线接口
		i_wb_data_i, i_wb_data_o, i_wb_addr_i, i_wb_sel_i, i_wb_we_i, i_wb_cyc_i,
		i_wb_stb_i, i_wb_ack_o, i_wb_err_o, i_wb_rty_o,

		// External Wishbone Interface — 面向从设备的对外总线接口（直通/旁路）
		e_wb_data_i, e_wb_data_o, e_wb_addr_o, e_wb_sel_o, e_wb_we_o, e_wb_cyc_o,
		e_wb_stb_o, e_wb_ack_i, e_wb_err_i, e_wb_rty_i,

		// Configuration Registers — 16个16位配置寄存器输出，对应16个从设备
		conf0, conf1, conf2, conf3, conf4, conf5, conf6, conf7,
		conf8, conf9, conf10, conf11, conf12, conf13, conf14, conf15

		);

////////////////////////////////////////////////////////////////////
//
// Module Parameters — 模块参数定义
//

parameter	[3:0]	rf_addr	= 4'hf;	// 寄存器文件基地址（addr[31:28]），默认0xF，即地址空间0xFxxx_xxxx
parameter		dw	= 32;		// Data bus Width — 数据总线位宽，默认32位
parameter		aw	= 32;		// Address bus Width — 地址总线位宽，默认32位
parameter		sw	= dw / 8;	// Number of Select Lines — 字节选择线数量，dw/8（32位时为4）

////////////////////////////////////////////////////////////////////
//
// Module IOs — 模块输入输出端口定义
//

input		clk_i, rst_i;	// 系统时钟和异步复位（高有效）

// Internal Wishbone Interface — 内部WISHBONE接口（连接主设备/仲裁器侧）
input	[dw-1:0]	i_wb_data_i;	// 内部写数据输入（主设备写入的数据）
output	[dw-1:0]	i_wb_data_o;	// 内部读数据输出（返回给主设备的数据）
input	[aw-1:0]	i_wb_addr_i;	// 内部地址输入（主设备发出的访问地址）
input	[sw-1:0]	i_wb_sel_i;	// 内部字节选择信号（标识哪些字节有效）
input			i_wb_we_i;	// 内部写使能（1=写操作，0=读操作）
input			i_wb_cyc_i;	// 内部周期信号（表示一次总线周期的开始到结束）
input			i_wb_stb_i;	// 内部选通信号（表示当前传输有效）
output			i_wb_ack_o;	// 内部应答输出（表示传输完成，返回给主设备）
output			i_wb_err_o;	// 内部错误输出（表示传输异常）
output			i_wb_rty_o;	// 内部重试输出（表示从设备忙，需要重试）

// External Wishbone Interface — 外部WISHBONE接口（连接从设备侧，直通/旁路模式）
input	[dw-1:0]	e_wb_data_i;	// 外部读数据输入（从设备返回的数据）
output	[dw-1:0]	e_wb_data_o;	// 外部写数据输出（传递给从设备的数据）
output	[aw-1:0]	e_wb_addr_o;	// 外部地址输出（传递给从设备的地址）
output	[sw-1:0]	e_wb_sel_o;	// 外部字节选择输出（传递给从设备）
output			e_wb_we_o;	// 外部写使能输出（传递给从设备）
output			e_wb_cyc_o;	// 外部周期信号输出（传递给从设备；访问寄存器文件时为0）
output			e_wb_stb_o;	// 外部选通信号输出（传递给从设备）
input			e_wb_ack_i;	// 外部应答输入（从设备返回的应答）
input			e_wb_err_i;	// 外部错误输入（从设备返回的错误）
input			e_wb_rty_i;	// 外部重试输入（从设备返回的重试）

// Configuration Registers — 16个配置寄存器输出（每个16位，对应一个从设备的路由信息）
output	[15:0]		conf0;	// 从设备0的配置寄存器
output	[15:0]		conf1;	// 从设备1的配置寄存器
output	[15:0]		conf2;	// 从设备2的配置寄存器
output	[15:0]		conf3;	// 从设备3的配置寄存器
output	[15:0]		conf4;	// 从设备4的配置寄存器
output	[15:0]		conf5;	// 从设备5的配置寄存器
output	[15:0]		conf6;	// 从设备6的配置寄存器
output	[15:0]		conf7;	// 从设备7的配置寄存器
output	[15:0]		conf8;	// 从设备8的配置寄存器
output	[15:0]		conf9;	// 从设备9的配置寄存器
output	[15:0]		conf10;	// 从设备10的配置寄存器
output	[15:0]		conf11;	// 从设备11的配置寄存器
output	[15:0]		conf12;	// 从设备12的配置寄存器
output	[15:0]		conf13;	// 从设备13的配置寄存器
output	[15:0]		conf14;	// 从设备14的配置寄存器
output	[15:0]		conf15;	// 从设备15的配置寄存器

////////////////////////////////////////////////////////////////////
//
// Local Wires — 本地信号声明
//

// 配置寄存器：16个16位寄存器，存储每个从设备的路由配置信息
// 每个寄存器在复位时清零，只有在rf_we有效且地址匹配时才写入新值
reg	[15:0]	conf0, conf1, conf2, conf3, conf4, conf5;
reg	[15:0]	conf6, conf7, conf8, conf9, conf10, conf11;
reg	[15:0]	conf12, conf13, conf14, conf15;

// Synopsys综合指导：要求综合工具将conf寄存器推断为多bit寄存器（避免分解为单个触发器）
//synopsys infer_multibit "conf0"
//synopsys infer_multibit "conf1"
//synopsys infer_multibit "conf2"
//synopsys infer_multibit "conf3"
//synopsys infer_multibit "conf4"
//synopsys infer_multibit "conf5"
//synopsys infer_multibit "conf6"
//synopsys infer_multibit "conf7"
//synopsys infer_multibit "conf8"
//synopsys infer_multibit "conf9"
//synopsys infer_multibit "conf10"
//synopsys infer_multibit "conf11"
//synopsys infer_multibit "conf12"
//synopsys infer_multibit "conf13"
//synopsys infer_multibit "conf14"
//synopsys infer_multibit "conf15"

wire		rf_sel;		// 寄存器文件选择信号：当WISHBONE访问地址的高4位匹配rf_addr时为1
reg	[15:0]	rf_dout;	// 寄存器文件读数据输出：被选中的配置寄存器的16位值
reg		rf_ack;		// 寄存器文件应答：内部访问完成时的应答信号（单周期脉冲）
reg		rf_we;		// 寄存器文件写使能：自清零的写脉冲（rf_sel & wb_we_i & !rf_we）

////////////////////////////////////////////////////////////////////
//
// Register File Select Logic — 寄存器文件地址选择逻辑
//
// rf_sel有效条件（三个信号同时为高）:
//   1. i_wb_cyc_i: WISHBONE总线周期正在进行
//   2. i_wb_stb_i: 当前传输有效（选通）
//   3. i_wb_addr_i[aw-5:aw-8] == rf_addr: 地址高4位（bit[31:28]）与寄存器文件基地址匹配
//      即主设备正在访问地址空间 0xFnxx_xxxx（n = rf_addr，默认0xF）
// 当rf_sel=1时：访问在内部处理（读/写配置寄存器），不传递到外部从设备总线
// 当rf_sel=0时：访问直通到外部WISHBONE接口（旁路模式）
assign rf_sel = i_wb_cyc_i & i_wb_stb_i & (i_wb_addr_i[aw-5:aw-8] == rf_addr);

////////////////////////////////////////////////////////////////////
//
// Register File Logic — 寄存器文件核心逻辑（写使能生成、应答生成、写操作、读操作）
//

// ===================================================================
// rf_we: 寄存器文件写使能脉冲生成（自清零，单周期写选通）
// 逻辑: rf_we = rf_sel & i_wb_we_i & !rf_we
//   - 当rf_sel有效、写操作(i_wb_we_i=1)且rf_we当前为0时，下一个时钟沿rf_we变为1
//   - 一旦rf_we变为1，!rf_we=0，下一个时钟沿rf_we自动回0
//   - 因此rf_we仅在写操作的首个周期产生一个单周期脉冲
//   - 这种自清零设计保证了每个写事务只写入一次配置寄存器
// ===================================================================
always @(posedge clk_i)
	rf_we <= #1 rf_sel & i_wb_we_i & !rf_we;

// ===================================================================
// rf_ack: 寄存器文件应答信号生成（自清零，单周期应答脉冲）
// 逻辑: rf_ack = rf_sel & !rf_ack
//   - 当rf_sel有效且rf_ack当前为0时，应答在下一拍变为1
//   - 一旦rf_ack=1，!rf_ack=0，下一拍自动清零
//   - 读操作：在rf_sel有效的第一个周期即产生应答（rf_dout同时被锁存）
//   - 写操作：写使能和应答同时产生单周期脉冲
// ===================================================================
always @(posedge clk_i)
	rf_ack <= #1 rf_sel & !rf_ack;

// ===================================================================
// 配置寄存器写逻辑（conf0 ~ conf15）
// 每个conf寄存器:
//   - 复位时清零（16'h0）
//   - 在rf_we有效（写脉冲）且子地址 addr[5:2] 匹配时写入 i_wb_data_i[15:0]
//   - 子地址 addr[5:2] 选择16个配置寄存器中的哪一个（0~15）
//   - 每个寄存器宽度16位，总共构成256位的寄存器阵列
//   - 这些寄存器存储的路由信息被上层模块（wb_conmax_top）用于选择主设备到从设备的连接
// ===================================================================

// Writre Logic — 配置寄存器写入逻辑
// conf0: 子地址 = 4'd0，存储从设备0的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf0 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd0) )		conf0 <= #1 i_wb_data_i[15:0];

// conf1: 子地址 = 4'd1，存储从设备1的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf1 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd1) )		conf1 <= #1 i_wb_data_i[15:0];

// conf2: 子地址 = 4'd2，存储从设备2的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf2 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd2) )		conf2 <= #1 i_wb_data_i[15:0];

// conf3: 子地址 = 4'd3，存储从设备3的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf3 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd3) )		conf3 <= #1 i_wb_data_i[15:0];

// conf4: 子地址 = 4'd4，存储从设备4的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf4 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd4) )		conf4 <= #1 i_wb_data_i[15:0];

// conf5: 子地址 = 4'd5，存储从设备5的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf5 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd5) )		conf5 <= #1 i_wb_data_i[15:0];

// conf6: 子地址 = 4'd6，存储从设备6的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf6 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd6) )		conf6 <= #1 i_wb_data_i[15:0];

// conf7: 子地址 = 4'd7，存储从设备7的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf7 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd7) )		conf7 <= #1 i_wb_data_i[15:0];

// conf8: 子地址 = 4'd8，存储从设备8的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf8 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd8) )		conf8 <= #1 i_wb_data_i[15:0];

// conf9: 子地址 = 4'd9，存储从设备9的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf9 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd9) )		conf9 <= #1 i_wb_data_i[15:0];

// conf10: 子地址 = 4'd10，存储从设备10的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf10 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd10) )	conf10 <= #1 i_wb_data_i[15:0];

// conf11: 子地址 = 4'd11，存储从设备11的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf11 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd11) )	conf11 <= #1 i_wb_data_i[15:0];

// conf12: 子地址 = 4'd12，存储从设备12的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf12 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd12) )	conf12 <= #1 i_wb_data_i[15:0];

// conf13: 子地址 = 4'd13，存储从设备13的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf13 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd13) )	conf13 <= #1 i_wb_data_i[15:0];

// conf14: 子地址 = 4'd14，存储从设备14的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf14 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd14) )	conf14 <= #1 i_wb_data_i[15:0];

// conf15: 子地址 = 4'd15，存储从设备15的路由配置
always @(posedge clk_i or posedge rst_i)
	if(rst_i)					conf15 <= #1 16'h0;
	else
	if(rf_we & (i_wb_addr_i[5:2] == 4'd15) )	conf15 <= #1 i_wb_data_i[15:0];

// ===================================================================
// Read Logic — 配置寄存器读取逻辑（带寄存器的多路选择器）
//   - 当rf_sel无效时：rf_dout输出0（不在寄存器文件地址空间）
//   - 当rf_sel有效时：根据地址位addr[5:2]（子地址）选择16个配置寄存器之一
//   - 输出为寄存器输出（posedge clk_i），读数据在下一拍可用
//   - addr[5:2]用作case选择：4'd0选择conf0，4'd1选择conf1，...，4'd15选择conf15
// ===================================================================
always @(posedge clk_i)
	if(!rf_sel)	rf_dout <= #1 16'h0;	// 不在寄存器文件地址范围，输出0
	else
	case(i_wb_addr_i[5:2])			// 根据子地址addr[5:2]多路选择
	   4'd0:	rf_dout <= #1 conf0;	// 子地址0 -> 读conf0
	   4'd1:	rf_dout <= #1 conf1;	// 子地址1 -> 读conf1
	   4'd2:	rf_dout <= #1 conf2;	// 子地址2 -> 读conf2
	   4'd3:	rf_dout <= #1 conf3;	// 子地址3 -> 读conf3
	   4'd4:	rf_dout <= #1 conf4;	// 子地址4 -> 读conf4
	   4'd5:	rf_dout <= #1 conf5;	// 子地址5 -> 读conf5
	   4'd6:	rf_dout <= #1 conf6;	// 子地址6 -> 读conf6
	   4'd7:	rf_dout <= #1 conf7;	// 子地址7 -> 读conf7
	   4'd8:	rf_dout <= #1 conf8;	// 子地址8 -> 读conf8
	   4'd9:	rf_dout <= #1 conf9;	// 子地址9 -> 读conf9
	   4'd10:	rf_dout <= #1 conf10;	// 子地址10 -> 读conf10
	   4'd11:	rf_dout <= #1 conf11;	// 子地址11 -> 读conf11
	   4'd12:	rf_dout <= #1 conf12;	// 子地址12 -> 读conf12
	   4'd13:	rf_dout <= #1 conf13;	// 子地址13 -> 读conf13
	   4'd14:	rf_dout <= #1 conf14;	// 子地址14 -> 读conf14
	   4'd15:	rf_dout <= #1 conf15;	// 子地址15 -> 读conf15
	endcase

////////////////////////////////////////////////////////////////////
//
// Register File By-Pass Logic — 寄存器文件旁路/直通逻辑
//
// 该模块的核心设计思想:
//   当主设备访问寄存器文件地址空间（rf_sel=1）时，访问在本模块内部处理，
//   不传递到外部WISHBONE总线（e_wb_*）；读数据、应答等由内部寄存器文件逻辑提供。
//   当访问其他地址空间（rf_sel=0）时，信号直接旁路到外部接口（直通模式），
//   此时本模块是透明的——主设备直接与外部从设备通信。
//

// ---------- 外部接口输出：地址、字节选择、写数据始终直通 ----------
// 无论rf_sel是否有效，地址、字节选择和写数据都直接传递到外部从设备
assign e_wb_addr_o = i_wb_addr_i;	// 地址直通：外部从设备看到与主设备相同的地址
assign e_wb_sel_o  = i_wb_sel_i;	// 字节选择直通
assign e_wb_data_o = i_wb_data_i;	// 写数据直通：主设备写入的数据直接送到外部从设备

// ---------- 外部周期信号：仅在非寄存器文件访问时才有效 ----------
// 关键: 当访问寄存器文件(rf_sel=1)时，e_wb_cyc_o=0，外部从设备不会启动总线周期
//       这防止了外部从设备对寄存器文件访问的响应，避免总线冲突
assign e_wb_cyc_o  = rf_sel ? 1'b0 : i_wb_cyc_i;	// rf_sel时cyc=0（阻断外部周期），否则直通
assign e_wb_stb_o  = i_wb_stb_i;	// 选通信号直通（即使cyc=0，stb也会直通——但这不影响，因为cyc=0时从设备不应响应）
assign e_wb_we_o   = i_wb_we_i;	// 写使能直通

// ---------- 内部接口输出：根据rf_sel选择数据源 ----------
// 当rf_sel=1（访问寄存器文件）:
//   - data_o: 来自内部rf_dout（寄存器读数据），高位补零扩展到32位
//   - ack_o:  来自内部rf_ack（寄存器文件应答脉冲）
//   - err_o:  固定为0（寄存器文件访问不会产生错误）
//   - rty_o:  固定为0（寄存器文件访问不需要重试）
//
// 当rf_sel=0（访问外部从设备）:
//   - data_o: 来自外部从设备的数据 e_wb_data_i（旁路直通）
//   - ack_o:  来自外部从设备的应答 e_wb_ack_i
//   - err_o:  来自外部从设备的错误 e_wb_err_i
//   - rty_o:  来自外部从设备的重试 e_wb_rty_i
assign i_wb_data_o = rf_sel ? { {aw-16{1'b0}}, rf_dout} : e_wb_data_i;	// 寄存器文件读取时：16位数据高位补零扩展为32位
assign i_wb_ack_o  = rf_sel ? rf_ack  : e_wb_ack_i;	// 内部访问用rf_ack，外部访问用e_wb_ack_i
assign i_wb_err_o  = rf_sel ? 1'b0    : e_wb_err_i;	// 寄存器文件访问不会出错，err固定为0
assign i_wb_rty_o  = rf_sel ? 1'b0    : e_wb_rty_i;	// 寄存器文件访问不需重试，rty固定为0

endmodule
