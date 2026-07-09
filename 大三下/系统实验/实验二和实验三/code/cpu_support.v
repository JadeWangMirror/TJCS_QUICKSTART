//////////////////////////////////////////////////////////////////////
// File:    cpu_support.v
// Description: OpenMIPS CPU 辅助模块集合 — 合并文件
//             包含: PC寄存器、HI/LO寄存器、LLbit寄存器、
//                   流水线控制器(ctrl)、除法器(div)
//
// 这些模块均为 CPU 核心的支撑逻辑:
//   - pc_reg    : 程序计数器，控制取指地址
//   - hilo_reg  : 乘除法结果寄存器 (HI/LO)
//   - LLbit_reg : Load-Linked 标志位 (用于 LL/SC 原子操作)
//   - ctrl      : 流水线控制单元，产生 stall/flush/new_pc 信号
//   - div       : 除法器，支持有符号/无符号除法，多周期执行
//////////////////////////////////////////////////////////////////////

`include "defines.v"

//==========================================================================
// 1. PC 寄存器 (Program Counter)
//    功能: 保存当前指令地址，控制取指流程
//    输入: stall/flush 控制信号, branch_flag 分支标志,
//          branch_target_address 分支目标地址, new_pc 异常入口地址
//    输出: pc (当前指令地址), ce (Flash 片选使能)
//    复位后: ce=0, pc=0x30000000 (Flash 基地址)
//==========================================================================
module pc_reg(

	input  wire	   clk,
	input  wire	   rst,

	//À´×Ô¿ØÖÆÄ£¿éµÄÐÅÏ¢
	input wire[5:0]               stall,
	input wire                    flush,
	input wire[`RegBus]           new_pc,

	//À´×ÔÒëÂë½×¶ÎµÄÐÅÏ¢
	input wire                    branch_flag_i,
	input wire[`RegBus]           branch_target_address_i,
	
	output reg[`InstAddrBus]			pc,
	output reg                    ce
	
);

	always @ (posedge clk) begin
		if (ce == `ChipDisable) begin
			pc <= 32'h30000000;
		end else begin
			if(flush == 1'b1) begin
				pc <= new_pc;
			end else if(stall[0] == `NoStop) begin
				if(branch_flag_i == `Branch) begin
					pc <= branch_target_address_i;
				end else begin
		  		pc <= pc + 4'h4;
		  	end
			end
		end
	end

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			ce <= `ChipDisable;
		end else begin
			ce <= `ChipEnable;
		end
	end

endmodule
//==========================================================================
// 2. HI/LO 寄存器
//    功能: 保存乘法和除法运算的高/低 32 位结果
//    HI 寄存器 — 存放乘法高 32 位或除法余数
//    LO 寄存器 — 存放乘法低 32 位或除法商
//    写使能来自回写阶段 (wb_whilo_i), 数据来自回写总线
//==========================================================================
module hilo_reg(

	input	wire										clk,
	input wire										rst,
	
	//Ð´¶Ë¿Ú
	input wire										we,
	input wire[`RegBus]				    hi_i,
	input wire[`RegBus]						lo_i,
	
	//¶Á¶Ë¿Ú1
	output reg[`RegBus]           hi_o,
	output reg[`RegBus]           lo_o
	
);

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
					hi_o <= `ZeroWord;
					lo_o <= `ZeroWord;
		end else if((we == `WriteEnable)) begin
					hi_o <= hi_i;
					lo_o <= lo_i;
		end
	end

endmodule
//==========================================================================
// 3. LLbit 寄存器 (Load-Linked Bit)
//    功能: 保存 LL (Load-Linked) 指令设置的链接标志位
//    用途: 配合 SC (Store-Conditional) 指令实现原子操作
//          LL 指令执行时置 1, SC 指令检查此位决定是否写回
//          flush 信号会将 LLbit 清零 (异常/中断时放弃原子操作)
//==========================================================================
module LLbit_reg(

	input	wire										clk,
	input wire										rst,
	
	input wire                    flush,
	//Ð´¶Ë¿Ú
	input wire										LLbit_i,
	input wire                    we,
	
	//¶Á¶Ë¿Ú1
	output reg                    LLbit_o
	
);


	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
					LLbit_o <= 1'b0;
		end else if((flush == 1'b1)) begin
					LLbit_o <= 1'b0;
		end else if((we == `WriteEnable)) begin
					LLbit_o <= LLbit_i;
		end
	end

endmodule
//==========================================================================
// 4. 流水线控制器 (Pipeline Controller)
//    功能: 根据各阶段的 stall 请求和异常类型，产生全局控制信号
//    输出信号:
//      stall[5:0] — 各流水线阶段暂停控制 (bit0→PC, bit1→IF/ID, ...)
//      flush      — 流水线冲刷信号 (异常/中断时冲刷前序指令)
//      new_pc     — 异常/中断入口地址
//    异常向量:
//      0x20 — 中断入口    (excepttype=1)
//      0x40 — 异常入口    (syscall/trap/ov/inst_invalid)
//      cp0_epc — ERET 返回地址
//==========================================================================
module ctrl(

	input wire					  rst,

	input wire[31:0]             excepttype_i,
	input wire[`RegBus]          cp0_epc_i,

	input wire                   stallreq_from_if,
	input wire                   stallreq_from_id,

	input wire                   stallreq_from_ex,
	input wire                   stallreq_from_mem,	

	output reg[`RegBus]          new_pc,
	output reg                   flush,	
	output reg[5:0]              stall       
	
);


	always @ (*) begin
		if(rst == `RstEnable) begin
			stall <= 6'b000000;
			flush <= 1'b0;
			new_pc <= `ZeroWord;
		end else if(excepttype_i != `ZeroWord) begin
		  flush <= 1'b1;
		  stall <= 6'b000000;
			case (excepttype_i)
				32'h00000001:		begin   //interrupt
					new_pc <= 32'h00000020;
				end
				32'h00000008:		begin   //syscall
					new_pc <= 32'h00000040;
				end
				32'h0000000a:		begin   //inst_invalid
					new_pc <= 32'h00000040;
				end
				32'h0000000d:		begin   //trap
					new_pc <= 32'h00000040;
				end
				32'h0000000c:		begin   //ov
					new_pc <= 32'h00000040;
				end
				32'h0000000e:		begin   //eret
					new_pc <= cp0_epc_i;
				end
				default	: begin
				end
			endcase 						
		end else if(stallreq_from_mem == `Stop) begin
			stall <= 6'b011111;
			flush <= 1'b0;					
		end else if(stallreq_from_ex == `Stop) begin
			stall <= 6'b001111;
			flush <= 1'b0;		
		end else if(stallreq_from_id == `Stop) begin
			stall <= 6'b000111;	
			flush <= 1'b0;		
    end else if(stallreq_from_if == `Stop) begin
			stall <= 6'b000111;
			flush <= 1'b0;						
		end else begin
			stall <= 6'b000000;
			flush <= 1'b0;
			new_pc <= `ZeroWord;		
		end    //if
	end      //always
			

endmodule
//==========================================================================
// 5. 除法器 (Divider)
//    功能: 32 位有符号/无符号除法，多周期执行 (最多 32+ 个时钟周期)
//    状态机:
//      DivFree    — 空闲，等待 start 信号
//      DivByZero  — 除数为 0，直接结束
//      DivOn      — 正在执行除法 (32 轮迭代)
//      DivEnd     — 除法完成，输出结果 {余数, 商}，等待 start 撤销
//==========================================================================
module div(

	input	wire										clk,
	input wire										rst,
	
	input wire                    signed_div_i,
	input wire[31:0]              opdata1_i,
	input wire[31:0]		   				opdata2_i,
	input wire                    start_i,
	input wire                    annul_i,
	
	output reg[63:0]             result_o,
	output reg			             ready_o
);

	wire[32:0] div_temp;
	reg[5:0] cnt;
	reg[64:0] dividend;
	reg[1:0] state;
	reg[31:0] divisor;	 
	reg[31:0] temp_op1;
	reg[31:0] temp_op2;
	
	assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			state <= `DivFree;
			ready_o <= `DivResultNotReady;
			result_o <= {`ZeroWord,`ZeroWord};
		end else begin
		  case (state)
		  	`DivFree:			begin               //DivFree×´Ì¬
		  		if(start_i == `DivStart && annul_i == 1'b0) begin
		  			if(opdata2_i == `ZeroWord) begin
		  				state <= `DivByZero;
		  			end else begin
		  				state <= `DivOn;
		  				cnt <= 6'b000000;
		  				if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1 ) begin
		  					temp_op1 = ~opdata1_i + 1;
		  				end else begin
		  					temp_op1 = opdata1_i;
		  				end
		  				if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin
		  					temp_op2 = ~opdata2_i + 1;
		  				end else begin
		  					temp_op2 = opdata2_i;
		  				end
		  				dividend <= {`ZeroWord,`ZeroWord};
              dividend[32:1] <= temp_op1;
              divisor <= temp_op2;
             end
          end else begin
						ready_o <= `DivResultNotReady;
						result_o <= {`ZeroWord,`ZeroWord};
				  end          	
		  	end
		  	`DivByZero:		begin               //DivByZero×´Ì¬
         	dividend <= {`ZeroWord,`ZeroWord};
          state <= `DivEnd;		 		
		  	end
		  	`DivOn:				begin               //DivOn×´Ì¬
		  		if(annul_i == 1'b0) begin
		  			if(cnt != 6'b100000) begin
               if(div_temp[32] == 1'b1) begin
                  dividend <= {dividend[63:0] , 1'b0};
               end else begin
                  dividend <= {div_temp[31:0] , dividend[31:0] , 1'b1};
               end
               cnt <= cnt + 1;
             end else begin
               if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                  dividend[31:0] <= (~dividend[31:0] + 1);
               end
               if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin              
                  dividend[64:33] <= (~dividend[64:33] + 1);
               end
               state <= `DivEnd;
               cnt <= 6'b000000;            	
             end
		  		end else begin
		  			state <= `DivFree;
		  		end	
		  	end
		  	`DivEnd:			begin               //DivEnd×´Ì¬
        	result_o <= {dividend[64:33], dividend[31:0]};  
          ready_o <= `DivResultReady;
          if(start_i == `DivStop) begin
          	state <= `DivFree;
						ready_o <= `DivResultNotReady;
						result_o <= {`ZeroWord,`ZeroWord};       	
          end		  	
		  	end
		  endcase
		end
	end

endmodule