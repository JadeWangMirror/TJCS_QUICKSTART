//////////////////////////////////////////////////////////////////////
// Module:  regfile
// File:    regfile.v
// Description: 通用寄存器文件 — 共 32 个 32 位寄存器
//             支持双端口异步读、单端口同步写
//             寄存器 0 ($zero) 硬连线为 0，不可写入
//             写操作发生在时钟上升沿，具备内部前推 (bypass)
//               — 若读地址与写地址相同且写使能，读数据直通写数据
//////////////////////////////////////////////////////////////////////

`include "defines.v"             // 引入宏定义：RegBus(数据宽度)、RegAddrBus(地址宽度)、RegNum(寄存器数量)等

module regfile(

	// --- 时钟与复位 ---
	input	wire										clk,      // 时钟信号，上升沿触发写操作
	input wire										rst,      // 复位信号，高电平有效(RstEnable=1'b1)

	// --- 写端口 ---
	input wire										we,       // 写使能，WriteEnable(1'b1)时允许写入
	input wire[`RegAddrBus]				waddr,    // 写地址，指定要写入的目标寄存器编号
	input wire[`RegBus]						wdata,    // 写数据，要写入寄存器的32位数据

	// --- 读端口1 ---
	input wire										re1,      // 读使能1，ReadEnable(1'b1)时允许读出
	input wire[`RegAddrBus]			  raddr1,   // 读地址1，指定要读出的寄存器编号
	output reg[`RegBus]           rdata1,   // 读数据1，组合逻辑输出(无时钟延迟)

	// --- 读端口2 ---
	input wire										re2,      // 读使能2，ReadEnable(1'b1)时允许读出
	input wire[`RegAddrBus]			  raddr2,   // 读地址2，指定要读出的寄存器编号
	output reg[`RegBus]           rdata2    // 读数据2，组合逻辑输出(无时钟延迟)

);

	// 寄存器堆：32个32位通用寄存器 (regs[0] ~ regs[31])
	// 由宏 RegNum(32) 和 RegBus(31:0) 决定位宽与数量
	reg[`RegBus]  regs[0:`RegNum-1];

	// ============================================================
	// 写操作：时钟上升沿触发，同步写入
	//   条件：复位无效(rst==RstDisable) 且 写使能有效(we==WriteEnable)
	//         且写地址不为0(waddr!=0)
	//   寄存器0($zero)硬连线为0，不可写入 — 这是MIPS/RISC-V的惯例
	// ============================================================
	always @ (posedge clk) begin
		if (rst == `RstDisable) begin                     // 复位无效时才能写入
			if((we == `WriteEnable) && (waddr != `RegNumLog2'h0)) begin  // 写使能且非0号寄存器
				regs[waddr] <= wdata;                       // 将写数据写入目标寄存器
			end
		end
	end
	
	// ============================================================
	// 读端口1：组合逻辑读取(always @(*))
	//   优先级顺序：
	//   1) 复位(rst==RstEnable)          → 输出全0
	//   2) 读地址为0(raddr1==0)          → 输出全0 ($zero恒为0)
	//   3) 内部前推/旁路(bypass)：
	//      当读地址与当前写地址相同(raddr1==waddr)且写使能有效
	//      且读使能有效时 → 直接将写数据wdata送到读端口
	//      这实现了同周期"写后读"无需阻塞流水线
	//   4) 正常读(re1==ReadEnable)       → 从寄存器堆regs[raddr1]读出
	//   5) 读使能无效                     → 输出全0
	// ============================================================
	always @ (*) begin
		if(rst == `RstEnable) begin                       // 复位：输出清零
			  rdata1 <= `ZeroWord;
	  end else if(raddr1 == `RegNumLog2'h0) begin         // 读$zero寄存器：恒为0
	  		rdata1 <= `ZeroWord;
	  end else if((raddr1 == waddr) && (we == `WriteEnable)   // ★ 内部前推(bypass)：
	  	            && (re1 == `ReadEnable)) begin             //    同地址读写时，读数据直通写数据
	  	  rdata1 <= wdata;                                     //    避免RAW(写后读)数据冒险
	  end else if(re1 == `ReadEnable) begin                // 正常读：从寄存器堆读出
	      rdata1 <= regs[raddr1];
	  end else begin                                       // 读使能无效：输出0
	      rdata1 <= `ZeroWord;
	  end
	end

	// ============================================================
	// 读端口2：组合逻辑读取(always @(*))
	//   与读端口1完全对称，具有相同的前推(bypass)逻辑
	//   优先级顺序：
	//   1) 复位(rst==RstEnable)          → 输出全0
	//   2) 读地址为0(raddr2==0)          → 输出全0 ($zero恒为0)
	//   3) 内部前推/旁路(bypass)：
	//      当读地址与当前写地址相同(raddr2==waddr)且写使能有效
	//      且读使能有效时 → 直接将写数据wdata送到读端口
	//   4) 正常读(re2==ReadEnable)       → 从寄存器堆regs[raddr2]读出
	//   5) 读使能无效                     → 输出全0
	// ============================================================
	always @ (*) begin
		if(rst == `RstEnable) begin                       // 复位：输出清零
			  rdata2 <= `ZeroWord;
	  end else if(raddr2 == `RegNumLog2'h0) begin         // 读$zero寄存器：恒为0
	  		rdata2 <= `ZeroWord;
	  end else if((raddr2 == waddr) && (we == `WriteEnable)   // ★ 内部前推(bypass)：
	  	            && (re2 == `ReadEnable)) begin             //    同地址读写时，读数据直通写数据
	  	  rdata2 <= wdata;                                     //    避免RAW(写后读)数据冒险
	  end else if(re2 == `ReadEnable) begin                // 正常读：从寄存器堆读出
	      rdata2 <= regs[raddr2];
	  end else begin                                       // 读使能无效：输出0
	      rdata2 <= `ZeroWord;
	  end
	end

endmodule