// UART core WISHBONE interface            // UART核的WISHBONE总线接口模块
//
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on
`include "uart_defines.v"

module uart_wb (clk, wb_rst_i,             // [时钟/复位] 系统时钟 / Wishbone总线复位
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_adr_i,  // [WISHBONE控制] 写使能 / 选通 / 周期 / 应答 / 地址
	wb_adr_int, wb_dat_i, wb_dat_o, wb_dat8_i, wb_dat8_o, wb_dat32_o, wb_sel_i,  // [数据] 内部地址 / 数据输入 / 数据输出 / 8位数据 / 32位数据 / 字节选择
	we_o, re_o // Write and read enable output for the core  // [内部使能] 寄存器写使能和读使能输出
);

input 		  clk;                           // [时钟] 系统时钟输入

// WISHBONE interface	                        // WISHBONE总线接口
input 		  wb_rst_i;                      // [复位] Wishbone总线复位, 高有效
input 		  wb_we_i;                       // [写使能] Wishbone写使能信号
input 		  wb_stb_i;                      // [选通] Wishbone选通信号
input 		  wb_cyc_i;                      // [周期] Wishbone总线周期信号
input [3:0]   wb_sel_i;                      // [字节选择] Wishbone字节选择信号 (32位模式用)
input [`UART_ADDR_WIDTH-1:0] 	wb_adr_i; // [地址] Wishbone地址线输入 (WISHBONE address line)

`ifdef DATA_BUS_WIDTH_8                      // 如果定义了8位数据总线宽度
input [7:0]  wb_dat_i; //input WISHBONE bus   // [数据输入] 8位WISHBONE数据总线输入
output [7:0] wb_dat_o;                       // [数据输出] 8位WISHBONE数据总线输出
reg [7:0] 	 wb_dat_o;                       // [寄存器] 8位输出数据寄存器
wire [7:0] 	 wb_dat_i;                       // [线网] 8位输入数据线网
reg [7:0] 	 wb_dat_is;                      // [寄存器] 8位输入数据采样寄存器
`else // for 32 data bus mode                // 否则使用32位数据总线模式
input [31:0]  wb_dat_i; //input WISHBONE bus  // [数据输入] 32位WISHBONE数据总线输入
output [31:0] wb_dat_o;                      // [数据输出] 32位WISHBONE数据总线输出
reg [31:0] 	  wb_dat_o;                      // [寄存器] 32位输出数据寄存器
wire [31:0]   wb_dat_i;                      // [线网] 32位输入数据线网
reg [31:0] 	  wb_dat_is;                     // [寄存器] 32位输入数据采样寄存器
`endif // !`ifdef DATA_BUS_WIDTH_8            // 数据总线宽度条件编译结束

output [`UART_ADDR_WIDTH-1:0]	wb_adr_int; // [内部地址] 内部使用的地址总线 (internal signal for address bus)
input [7:0]   wb_dat8_o;                     // [内部数据输出] 内部8位数据输出, 汇入wb_dat_o (internal 8 bit output to be put into wb_dat_o)
output [7:0]  wb_dat8_i;                     // [内部数据输入] 内部8位数据输入, 来自wb_dat_i
input [31:0]  wb_dat32_o; // 32 bit data output (for debug interface)  // [调试输出] 32位调试接口数据输出
output 		  wb_ack_o;                      // [应答] Wishbone应答信号输出
output 		  we_o;                          // [写使能输出] 内部寄存器写使能
output 		  re_o;                          // [读使能输出] 内部寄存器读使能

wire 			  we_o;                          // [线网] 写使能内部连线
reg 			  wb_ack_o;                       // [寄存器] 应答信号寄存器
reg [7:0] 	  wb_dat8_i;                     // [寄存器] 8位内部数据输入寄存器
wire [7:0] 	  wb_dat8_o;                     // [线网] 8位内部数据输出线网
wire [`UART_ADDR_WIDTH-1:0]	wb_adr_int; // [内部地址] 内部地址总线线网 (internal signal for address bus)
reg [`UART_ADDR_WIDTH-1:0]	wb_adr_is;  // [寄存器] 地址采样寄存器
reg 								wb_we_is;   // [寄存器] 写使能采样寄存器
reg 								wb_cyc_is;  // [寄存器] 周期采样寄存器
reg 								wb_stb_is;  // [寄存器] 选通采样寄存器
reg [3:0] 						wb_sel_is;  // [寄存器] 字节选择采样寄存器
wire [3:0]   wb_sel_i;                      // [线网] 字节选择输入线网
reg 			 wre ;// timing control signal for write or read enable  // [时序控制] 写/读使能时序控制信号

// wb_ack_o FSM                               // wb_ack_o应答信号有限状态机
reg [1:0] 	 wbstate;                        // [状态寄存器] WISHBONE状态机状态 (2位: 0/1/2/3)
always  @(posedge clk or posedge wb_rst_i)    // [时序逻辑] 时钟上升沿或复位上升沿触发
	if (wb_rst_i) begin                      // 总线复位: 清除所有状态
		wb_ack_o <= #1 1'b0;                   // 应答信号清零
		wbstate <= #1 0;                       // 状态机回到状态0 (空闲)
		wre <= #1 1'b1;                        // 写/读使能时序置1 (空闲态)
	end else
		case (wbstate)                         // 状态机主逻辑
			0: begin                           // 状态0 (空闲/等待): 等待总线周期开始
				if (wb_stb_is & wb_cyc_is) begin  // 选通和周期同时有效: 总线传输开始
					wre <= #1 0;                   // 写/读使能时序清零 (进入传输)
					wbstate <= #1 1;               // 跳转到状态1
					wb_ack_o <= #1 1;              // 应答信号置1 (第一拍应答)
				end else begin                   // 无有效总线周期
					wre <= #1 1;                   // 保持空闲时序
					wb_ack_o <= #1 0;              // 应答信号保持0
				end
			end
			1: begin                           // 状态1 (应答有效): 插入一个等待状态
			   wb_ack_o <= #1 0;                 // 应答信号清零 (第二拍无应答)
				wbstate <= #1 2;                  // 跳转到状态2
				wre <= #1 0;                      // 保持传输状态
			end
			2,3: begin                         // 状态2/3 (等待恢复): 等待总线周期结束
				wb_ack_o <= #1 0;                 // 应答信号保持0
				wbstate <= #1 0;                  // 回到状态0 (空闲)
				wre <= #1 0;                      // 保持传输状态
			end
		endcase

assign we_o =  wb_we_is & wb_stb_is & wb_cyc_is & wre ; // [写使能生成] WE = 写使能 & 选通 & 周期 & 时序控制 (WE for registers)
assign re_o = ~wb_we_is & wb_stb_is & wb_cyc_is & wre ; // [读使能生成] RE = ~写使能 & 选通 & 周期 & 时序控制 (RE for registers)

// Sample input signals                       // 输入信号采样 (同步化处理)
always  @(posedge clk or posedge wb_rst_i)    // [时序逻辑] 时钟上升沿或复位上升沿触发
	if (wb_rst_i) begin                      // 总线复位: 清除全部采样寄存器
		wb_adr_is <= #1 0;                     // 地址采样清零
		wb_we_is <= #1 0;                      // 写使能采样清零
		wb_cyc_is <= #1 0;                     // 周期采样清零
		wb_stb_is <= #1 0;                     // 选通采样清零
		wb_dat_is <= #1 0;                     // 数据采样清零
		wb_sel_is <= #1 0;                     // 字节选择采样清零
	end else begin                           // 正常工作: 对输入信号进行采样
		wb_adr_is <= #1 wb_adr_i;              // 采样WISHBONE地址
		wb_we_is <= #1 wb_we_i;                // 采样WISHBONE写使能
		wb_cyc_is <= #1 wb_cyc_i;              // 采样WISHBONE周期信号
		wb_stb_is <= #1 wb_stb_i;              // 采样WISHBONE选通信号
		wb_dat_is <= #1 wb_dat_i;              // 采样WISHBONE数据输入
		wb_sel_is <= #1 wb_sel_i;              // 采样WISHBONE字节选择
	end

`ifdef DATA_BUS_WIDTH_8 // 8-bit data bus     // 8位数据总线模式
always @(posedge clk or posedge wb_rst_i)     // [时序逻辑] 输出数据寄存器
	if (wb_rst_i)                            // 复位时数据输出清零
		wb_dat_o <= #1 0;
	else
		wb_dat_o <= #1 wb_dat8_o;             // 将内部8位数据直接输出

always @(wb_dat_is)                          // [组合逻辑] 将采样数据转发到内部8位数据总线
	wb_dat8_i = wb_dat_is;

assign wb_adr_int = wb_adr_is;               // 内部地址 = 采样后的地址

`else // 32-bit bus                           // 32位数据总线模式
// put output to the correct byte in 32 bits using select line  // 使用字节选择信号将输出放入32位总线的正确字节位置
always @(posedge clk or posedge wb_rst_i)     // [时序逻辑] 输出数据寄存器
	if (wb_rst_i)                            // 复位时输出清零
		wb_dat_o <= #1 0;
	else if (re_o)                           // 读使能有效时, 根据字节选择输出
		case (wb_sel_is)                       // 字节选择译码
			4'b0001: wb_dat_o <= #1 {24'b0, wb_dat8_o};     // 选通字节0: 数据放在最低8位
			4'b0010: wb_dat_o <= #1 {16'b0, wb_dat8_o, 8'b0};  // 选通字节1: 数据放在[15:8]
			4'b0100: wb_dat_o <= #1 {8'b0, wb_dat8_o, 16'b0};  // 选通字节2: 数据放在[23:16]
			4'b1000: wb_dat_o <= #1 {wb_dat8_o, 24'b0};        // 选通字节3: 数据放在[31:24]
			4'b1111: wb_dat_o <= #1 wb_dat32_o; // 全选通: 输出32位调试接口数据 (debug interface output)
 			default: wb_dat_o <= #1 0;           // 其他: 输出0
		endcase // case(wb_sel_i)

reg [1:0] wb_adr_int_lsb;                    // [寄存器] 内部地址低2位 (由字节选择信号决定)

always @(wb_sel_is or wb_dat_is)             // [组合逻辑] 根据字节选择提取8位数据, 并计算地址低2位
begin
	case (wb_sel_is)                          // 字节选择译码: 从32位总线的正确字节位置提取8位数据
		4'b0001 : wb_dat8_i = wb_dat_is[7:0];    // 选通字节0: 取[7:0]
		4'b0010 : wb_dat8_i = wb_dat_is[15:8];   // 选通字节1: 取[15:8]
		4'b0100 : wb_dat8_i = wb_dat_is[23:16];  // 选通字节2: 取[23:16]
		4'b1000 : wb_dat8_i = wb_dat_is[31:24];  // 选通字节3: 取[31:24]
		default : wb_dat8_i = wb_dat_is[7:0];    // 默认: 取[7:0]
	endcase // case(wb_sel_i)

  `ifdef LITLE_ENDIAN                         // 小端模式: 低地址对应低字节
	case (wb_sel_is)                           // 字节选择 → 地址低2位映射
		4'b0001 : wb_adr_int_lsb = 2'h0;         // 字节0 → 地址偏移0
		4'b0010 : wb_adr_int_lsb = 2'h1;         // 字节1 → 地址偏移1
		4'b0100 : wb_adr_int_lsb = 2'h2;         // 字节2 → 地址偏移2
		4'b1000 : wb_adr_int_lsb = 2'h3;         // 字节3 → 地址偏移3
		default : wb_adr_int_lsb = 2'h0;         // 默认: 地址偏移0
	endcase // case(wb_sel_i)
  `else                                       // 大端模式: 低地址对应高字节
	case (wb_sel_is)                           // 字节选择 → 地址低2位映射
		4'b0001 : wb_adr_int_lsb = 2'h3;         // 字节0 → 地址偏移3
		4'b0010 : wb_adr_int_lsb = 2'h2;         // 字节1 → 地址偏移2
		4'b0100 : wb_adr_int_lsb = 2'h1;         // 字节2 → 地址偏移1
		4'b1000 : wb_adr_int_lsb = 2'h0;         // 字节3 → 地址偏移0
		default : wb_adr_int_lsb = 2'h0;         // 默认: 地址偏移0
	endcase // case(wb_sel_i)
  `endif

end                                          // always块结束

assign wb_adr_int = {wb_adr_is[`UART_ADDR_WIDTH-1:2], wb_adr_int_lsb};  // [内部地址合成] 高地址位来自采样地址, 低2位来自字节选择译码

`endif // !`ifdef DATA_BUS_WIDTH_8            // 数据总线宽度条件编译结束

endmodule                                    // 模块结束
