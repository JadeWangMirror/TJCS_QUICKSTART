//////////////////////////////////////////////////////////////////////
// Module:  ex
// File:    ex.v
// Description: 执行阶段 — OpenMIPS 五级流水线第三级
//             主要功能:
//               - 逻辑运算: AND/OR/XOR/NOR
//               - 移位运算: SLL/SRL/SRA
//               - 算术运算: 加减法、比较 (SLT/SLTU)、前导零/一计数 (CLZ/CLO)
//               - 乘法: MULT/MULTU/MUL/MADD/MADDU/MSUB/MSUBU (多周期)
//               - 除法: DIV/DIVU (多周期, 控制 div 模块)
//               - 移动: MFHI/MFLO/MOVZ/MOVN/MFC0/MTC0
//               - 跳转分支: 计算分支目标地址
//               - 陷阱检测: TEQ/TGE/TLT/TNE 等
//               - 溢出检测: ADD/ADDI/SUB 指令
//             内部运算单元:
//               - logicout:      逻辑运算结果
//               - shiftres:      移位运算结果
//               - arithmeticres: 算术运算结果
//               - moveres:       数据移动结果 (含 MFC0)
//               - mulres:        乘法结果 (64 位)
//               - HI/LO:         当前 HI/LO 值 (含数据前推)
//             输出: ALU 结果、访存地址、HI/LO 写值、CP0 写信息
//             产生 stallreq 用于多周期指令 (乘累加/除法)
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module ex(

	input wire										rst,
	
	//ËÍµ½Ö´ÐÐ½×¶ÎµÄÐÅÏ¢
	input wire[`AluOpBus]         aluop_i,  // ALU操作码 (8bit), 来自ID阶段
	input wire[`AluSelBus]        alusel_i,  // ALU结果选择码 (3bit)
	input wire[`RegBus]           reg1_i,  // 源操作数1
	input wire[`RegBus]           reg2_i,  // 源操作数2
	input wire[`RegAddrBus]       wd_i,  // 目的寄存器地址
	input wire                    wreg_i,  // 目的寄存器写使能
	input wire[`RegBus]           inst_i,  // 原始指令字
	input wire[31:0]              excepttype_i,  // 异常类型编码
	input wire[`RegBus]          current_inst_address_i,  // 当前指令地址
	
	//HI¡¢LO¼Ä´æÆ÷µÄÖµ
	input wire[`RegBus]           hi_i,  // HI寄存器当前值
	input wire[`RegBus]           lo_i,  // LO寄存器当前值

	//»ØÐ´½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´HI¡¢LO£¬ÓÃÓÚ¼ì²âHI¡¢LOµÄÊý¾ÝÏà¹Ø
	input wire[`RegBus]           wb_hi_i,  // WB级HI写值 (前推)
	input wire[`RegBus]           wb_lo_i,  // WB级LO写值 (前推)
	input wire                    wb_whilo_i,  // WB级HI/LO写使能 (前推)
	
	//·Ã´æ½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´HI¡¢LO£¬ÓÃÓÚ¼ì²âHI¡¢LOµÄÊý¾ÝÏà¹Ø
	input wire[`RegBus]           mem_hi_i,  // MEM级HI写值 (前推)
	input wire[`RegBus]           mem_lo_i,  // MEM级LO写值 (前推)
	input wire                    mem_whilo_i,  // MEM级HI/LO写使能 (前推)

	input wire[`DoubleRegBus]     hilo_temp_i,  // 乘累加临时结果 (64bit)
	input wire[1:0]               cnt_i,  // 乘累加/除法 Multi-cycle计数器

	//Óë³ý·¨Ä£¿éÏàÁ¬
	input wire[`DoubleRegBus]     div_result_i,  // 除法模块计算结果 {HI,LO}
	input wire                    div_ready_i,  // 除法模块就绪标志

	//ÊÇ·ñ×ªÒÆ¡¢ÒÔ¼°link address
	input wire[`RegBus]           link_address_i,  // 链接地址 (PC+8)
	input wire                    is_in_delayslot_i,	  // 当前指令是否在延迟槽中

	//·Ã´æ½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´CP0£¬ÓÃÀ´¼ì²âÊý¾ÝÏà¹Ø
  input wire                    mem_cp0_reg_we,  // MEM级CP0写使能 (前推)
	input wire[4:0]               mem_cp0_reg_write_addr,  // MEM级CP0写地址 (前推)
	input wire[`RegBus]           mem_cp0_reg_data,  // MEM级CP0写数据 (前推)
	
	//»ØÐ´½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´CP0£¬ÓÃÀ´¼ì²âÊý¾ÝÏà¹Ø
  input wire                    wb_cp0_reg_we,  // WB级CP0写使能 (前推)
	input wire[4:0]               wb_cp0_reg_write_addr,  // WB级CP0写地址 (前推)
	input wire[`RegBus]           wb_cp0_reg_data,  // WB级CP0写数据 (前推)

	//ÓëCP0ÏàÁ¬£¬¶ÁÈ¡ÆäÖÐCP0¼Ä´æÆ÷µÄÖµ
	input wire[`RegBus]           cp0_reg_data_i,  // CP0寄存器读数据
	output reg[4:0]               cp0_reg_read_addr_o,  // CP0寄存器读地址

	//ÏòÏÂÒ»Á÷Ë®¼¶´«µÝ£¬ÓÃÓÚÐ´CP0ÖÐµÄ¼Ä´æÆ÷
	output reg                    cp0_reg_we_o,  // CP0写使能
	output reg[4:0]               cp0_reg_write_addr_o,  // CP0写地址
	output reg[`RegBus]           cp0_reg_data_o,  // CP0写数据
	
	output reg[`RegAddrBus]       wd_o,  // 目的寄存器地址 (传到MEM级)
	output reg                    wreg_o,  // 目的寄存器写使能
	output reg[`RegBus]						wdata_o,

	output reg[`RegBus]           hi_o,  // HI寄存器写值
	output reg[`RegBus]           lo_o,  // LO寄存器写值
	output reg                    whilo_o,  // HI/LO写使能
	
	output reg[`DoubleRegBus]     hilo_temp_o,  // 乘累加/减临时结果
	output reg[1:0]               cnt_o,  // 乘累加/除法 Multi-cycle计数器输出

	output reg[`RegBus]           div_opdata1_o,  // 除法模块: 被除数
	output reg[`RegBus]           div_opdata2_o,  // 除法模块: 除数
	output reg                    div_start_o,  // 除法模块: 启动信号
	output reg                    signed_div_o,  // 除法模块: 有符号除法标志

	//ÏÂÃæÐÂÔöµÄ¼¸¸öÊä³öÊÇÎª¼ÓÔØ¡¢´æ´¢Ö¸Áî×¼±¸µÄ
	output wire[`AluOpBus]        aluop_o,  // ALU操作码 (传到MEM级, 用于load/store识别)
	output wire[`RegBus]          mem_addr_o,  // 访存地址 (传到MEM级)
	output wire[`RegBus]          reg2_o,  // 源寄存器2 (传到MEM级, store数据)
	
	output wire[31:0]             excepttype_o,  // 异常类型编码输出
	output wire                   is_in_delayslot_o,  // 延迟槽标志输出
	output wire[`RegBus]          current_inst_address_o,	  // 当前指令地址输出

	output reg										stallreq       			
	
);

	reg[`RegBus] logicout;  // 逻辑运算结果 (OR/AND/NOR/XOR)
	reg[`RegBus] shiftres;  // 移位运算结果 (SLL/SRL/SRA)
	reg[`RegBus] moveres;  // 数据移动结果 (MFHI/MFLO/MOVZ/MOVN/MFC0)
	reg[`RegBus] arithmeticres;  // 算术运算结果 (ADD/SUB/SLT/CLZ/CLO)
	reg[`DoubleRegBus] mulres;	  // 乘法结果 (64bit, 含符号处理)
	reg[`RegBus] HI;  // HI寄存器当前值 (经前推后)
	reg[`RegBus] LO;  // LO寄存器当前值 (经前推后)
	wire[`RegBus] reg2_i_mux;  // 源操作数2多路选择 (减法时取补码)
	wire[`RegBus] reg1_i_not;	  // 源操作数1按位取反 (用于CLO)
	wire[`RegBus] result_sum;  // 加法/减法结果 (reg1 + reg2_mux)
	wire ov_sum;  // 求和溢出标志 (用于ADD/ADDI/SUB)
	wire reg1_eq_reg2;  // reg1==reg2 (未使用)
	wire reg1_lt_reg2;  // reg1<reg2 (有符号或无符号比较)
	wire[`RegBus] opdata1_mult;  // 乘法操作数1 (有符号时取绝对值)
	wire[`RegBus] opdata2_mult;  // 乘法操作数2 (有符号时取绝对值)
	wire[`DoubleRegBus] hilo_temp;  // 乘法临时乘积 (opdata1 * opdata2)
	reg[`DoubleRegBus] hilo_temp1;  // MADD/MSUB中间累加结果
	reg stallreq_for_madd_msub;			  // MADD/MSUB多周期暂停请求
	reg stallreq_for_div;  // DIV多周期暂停请求
	reg trapassert;  // Trap断言 (TEQ/TGE/TLT/TNE等)
	reg ovassert;  // 溢出断言 (ADD/ADDI/SUB溢出时置1)

  //aluop_o´«µÝµ½·Ã´æ½×¶Î£¬ÓÃÓÚ¼ÓÔØ¡¢´æ´¢Ö¸Áî
  assign aluop_o = aluop_i;  // ALU操作码直通到MEM级 (load/store识别)
  
  //mem_addr´«µÝµ½·Ã´æ½×¶Î£¬ÊÇ¼ÓÔØ¡¢´æ´¢Ö¸Áî¶ÔÓ¦µÄ´æ´¢Æ÷µØÖ·
  assign mem_addr_o = reg1_i + {{16{inst_i[15]}},inst_i[15:0]};  // 访存地址 = reg1 + sign_ext(imm16), load/store用

  //½«Á½¸ö²Ù×÷ÊýÒ²´«µÝµ½·Ã´æ½×¶Î£¬Ò²ÊÇÎª¼ÇÔØ¡¢´æ´¢Ö¸Áî×¼±¸µÄ
  assign reg2_o = reg2_i;  // 源操作数2直通到MEM级 (store数据)
 
  assign excepttype_o = {excepttype_i[31:12],ovassert,trapassert,excepttype_i[9:8],8'h00};  // 合并异常类型: 加入溢出和陷阱标志
  
	assign is_in_delayslot_o = is_in_delayslot_i;  // 延迟槽标志直通
	assign current_inst_address_o = current_inst_address_i;  // 指令地址直通

	always @ (*) begin
		if(rst == `RstEnable) begin
			logicout <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_OR_OP:			begin  // OR: reg1 | reg2
					logicout <= reg1_i | reg2_i;
				end
				`EXE_AND_OP:		begin  // AND: reg1 & reg2
					logicout <= reg1_i & reg2_i;
				end
				`EXE_NOR_OP:		begin  // NOR: ~(reg1 | reg2)
					logicout <= ~(reg1_i |reg2_i);
				end
				`EXE_XOR_OP:		begin  // XOR: reg1 ^ reg2
					logicout <= reg1_i ^ reg2_i;
				end
				default:				begin
					logicout <= `ZeroWord;
				end
			endcase
		end    //if
	end      //always

	always @ (*) begin
		if(rst == `RstEnable) begin
			shiftres <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_SLL_OP:			begin  // SLL: reg2 << reg1[4:0] (逻辑左移)
					shiftres <= reg2_i << reg1_i[4:0] ;
				end
				`EXE_SRL_OP:		begin  // SRL: reg2 >> reg1[4:0] (逻辑右移)
					shiftres <= reg2_i >> reg1_i[4:0];
				end
				`EXE_SRA_OP:		begin  // SRA: reg2 >>> reg1[4:0] (算术右移)
					shiftres <= ({32{reg2_i[31]}} << (6'd32-{1'b0, reg1_i[4:0]})) 
												| reg2_i >> reg1_i[4:0];
				end
				default:				begin
					shiftres <= `ZeroWord;
				end
			endcase
		end    //if
	end      //always

	assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SUBU_OP) ||  // 减法/比较指令: reg2取补码 (转为加法); 否则原值
											 (aluop_i == `EXE_SLT_OP)|| (aluop_i == `EXE_TLT_OP) ||
	                       (aluop_i == `EXE_TLTI_OP) || (aluop_i == `EXE_TGE_OP) ||
	                       (aluop_i == `EXE_TGEI_OP)) 
											 ? (~reg2_i)+1 : reg2_i;

	assign result_sum = reg1_i + reg2_i_mux;										   // 加法器: reg1 + reg2_mux (减法时reg2_mux=补码)

	assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) ||  // 带符号溢出检测: 正+正=负 或 负+负=正
									((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));  
									
	assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP) || (aluop_i == `EXE_TLT_OP) ||  // 有符号比较: 符号位+结果符号; 无符号比较: 直接 <
	                       (aluop_i == `EXE_TLTI_OP) || (aluop_i == `EXE_TGE_OP) ||
	                       (aluop_i == `EXE_TGEI_OP)) ?
												 ((reg1_i[31] && !reg2_i[31]) || 
												 (!reg1_i[31] && !reg2_i[31] && result_sum[31])||
			                   (reg1_i[31] && reg2_i[31] && result_sum[31]))
			                   :	(reg1_i < reg2_i);
  
  assign reg1_i_not = ~reg1_i;  // reg1按位取反 (用于CLO)
							
	always @ (*) begin
		if(rst == `RstEnable) begin
			arithmeticres <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_SLT_OP, `EXE_SLTU_OP:		begin  // SLT/SLTU: reg1 < reg2 ? 1 : 0
					arithmeticres <= reg1_lt_reg2 ;
				end
				`EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP:		begin  // ADD/ADDU/ADDI/ADDIU: result_sum
					arithmeticres <= result_sum; 
				end
				`EXE_SUB_OP, `EXE_SUBU_OP:		begin  // SUB/SUBU: result_sum
					arithmeticres <= result_sum; 
				end		
				`EXE_CLZ_OP:		begin  // CLZ: CountLeadingZeros (前导零计数)
					arithmeticres <= reg1_i[31] ? 0 : reg1_i[30] ? 1 : reg1_i[29] ? 2 :
													 reg1_i[28] ? 3 : reg1_i[27] ? 4 : reg1_i[26] ? 5 :
													 reg1_i[25] ? 6 : reg1_i[24] ? 7 : reg1_i[23] ? 8 : 
													 reg1_i[22] ? 9 : reg1_i[21] ? 10 : reg1_i[20] ? 11 :
													 reg1_i[19] ? 12 : reg1_i[18] ? 13 : reg1_i[17] ? 14 : 
													 reg1_i[16] ? 15 : reg1_i[15] ? 16 : reg1_i[14] ? 17 : 
													 reg1_i[13] ? 18 : reg1_i[12] ? 19 : reg1_i[11] ? 20 :
													 reg1_i[10] ? 21 : reg1_i[9] ? 22 : reg1_i[8] ? 23 : 
													 reg1_i[7] ? 24 : reg1_i[6] ? 25 : reg1_i[5] ? 26 : 
													 reg1_i[4] ? 27 : reg1_i[3] ? 28 : reg1_i[2] ? 29 : 
													 reg1_i[1] ? 30 : reg1_i[0] ? 31 : 32 ;
				end
				`EXE_CLO_OP:		begin  // CLO: CountLeadingOnes (前导一计数)
					arithmeticres <= (reg1_i_not[31] ? 0 : reg1_i_not[30] ? 1 : reg1_i_not[29] ? 2 :
													 reg1_i_not[28] ? 3 : reg1_i_not[27] ? 4 : reg1_i_not[26] ? 5 :
													 reg1_i_not[25] ? 6 : reg1_i_not[24] ? 7 : reg1_i_not[23] ? 8 : 
													 reg1_i_not[22] ? 9 : reg1_i_not[21] ? 10 : reg1_i_not[20] ? 11 :
													 reg1_i_not[19] ? 12 : reg1_i_not[18] ? 13 : reg1_i_not[17] ? 14 : 
													 reg1_i_not[16] ? 15 : reg1_i_not[15] ? 16 : reg1_i_not[14] ? 17 : 
													 reg1_i_not[13] ? 18 : reg1_i_not[12] ? 19 : reg1_i_not[11] ? 20 :
													 reg1_i_not[10] ? 21 : reg1_i_not[9] ? 22 : reg1_i_not[8] ? 23 : 
													 reg1_i_not[7] ? 24 : reg1_i_not[6] ? 25 : reg1_i_not[5] ? 26 : 
													 reg1_i_not[4] ? 27 : reg1_i_not[3] ? 28 : reg1_i_not[2] ? 29 : 
													 reg1_i_not[1] ? 30 : reg1_i_not[0] ? 31 : 32) ;
				end
				default:				begin
					arithmeticres <= `ZeroWord;
				end
			endcase
		end
	end

	always @ (*) begin
		if(rst == `RstEnable) begin
			trapassert <= `TrapNotAssert;
		end else begin
			trapassert <= `TrapNotAssert;
			case (aluop_i)
				`EXE_TEQ_OP, `EXE_TEQI_OP:		begin  // TEQ/TEQI: Trap if reg1==reg2
					if( reg1_i == reg2_i ) begin
						trapassert <= `TrapAssert;
					end
				end
				`EXE_TGE_OP, `EXE_TGEI_OP, `EXE_TGEIU_OP, `EXE_TGEU_OP:		begin  // TGE/TGEI/TGEIU/TGEU: Trap if reg1>=reg2
					if( ~reg1_lt_reg2 ) begin
						trapassert <= `TrapAssert;
					end
				end
				`EXE_TLT_OP, `EXE_TLTI_OP, `EXE_TLTIU_OP, `EXE_TLTU_OP:		begin  // TLT/TLTI/TLTIU/TLTU: Trap if reg1<reg2
					if( reg1_lt_reg2 ) begin
						trapassert <= `TrapAssert;
					end
				end
				`EXE_TNE_OP, `EXE_TNEI_OP:		begin  // TNE/TNEI: Trap if reg1!=reg2
					if( reg1_i != reg2_i ) begin
						trapassert <= `TrapAssert;
					end
				end
				default:				begin
					trapassert <= `TrapNotAssert;
				end
			endcase
		end
	end

  //È¡µÃ³Ë·¨²Ù×÷µÄ²Ù×÷Êý£¬Èç¹ûÊÇÓÐ·ûºÅ³ý·¨ÇÒ²Ù×÷ÊýÊÇ¸ºÊý£¬ÄÇÃ´È¡·´¼ÓÒ»
	assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ||  // 有符号乘法操作数1: 负数取补码 (绝对值)
													(aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP))
													&& (reg1_i[31] == 1'b1)) ? (~reg1_i + 1) : reg1_i;

  assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ||  // 有符号乘法操作数2: 负数取补码 (绝对值)
													(aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP))
													&& (reg2_i[31] == 1'b1)) ? (~reg2_i + 1) : reg2_i;	

  assign hilo_temp = opdata1_mult * opdata2_mult;																				  // 无符号乘法: 64bit乘积 = opdata1 * opdata2

	always @ (*) begin
		if(rst == `RstEnable) begin
			mulres <= {`ZeroWord,`ZeroWord};
		end else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP) ||  // MULT/MUL/MADD/MSUB: 有符号乘法, 符号不同时结果取反
									(aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP))begin
			if(reg1_i[31] ^ reg2_i[31] == 1'b1) begin
				mulres <= ~hilo_temp + 1;
			end else begin
			  mulres <= hilo_temp;
			end
		end else begin
				mulres <= hilo_temp;
		end
	end

  //µÃµ½×îÐÂµÄHI¡¢LO¼Ä´æÆ÷µÄÖµ£¬´Ë´¦Òª½â¾öÖ¸ÁîÊý¾ÝÏà¹ØÎÊÌâ
	always @ (*) begin
		if(rst == `RstEnable) begin
			{HI,LO} <= {`ZeroWord,`ZeroWord};
		end else if(mem_whilo_i == `WriteEnable) begin
			{HI,LO} <= {mem_hi_i,mem_lo_i};
		end else if(wb_whilo_i == `WriteEnable) begin
			{HI,LO} <= {wb_hi_i,wb_lo_i};
		end else begin
			{HI,LO} <= {hi_i,lo_i};			
		end
	end	

  always @ (*) begin
    stallreq = stallreq_for_madd_msub || stallreq_for_div;
  end

  //MADD¡¢MADDU¡¢MSUB¡¢MSUBUÖ¸Áî
	always @ (*) begin
		if(rst == `RstEnable) begin
			hilo_temp_o <= {`ZeroWord,`ZeroWord};
			cnt_o <= 2'b00;
			stallreq_for_madd_msub <= `NoStop;
		end else begin
			
			case (aluop_i) 
				`EXE_MADD_OP, `EXE_MADDU_OP:		begin  // MADD/MADDU: {HI,LO} = {HI,LO} + rs*rt
					if(cnt_i == 2'b00) begin
						hilo_temp_o <= mulres;
						cnt_o <= 2'b01;
						stallreq_for_madd_msub <= `Stop;
						hilo_temp1 <= {`ZeroWord,`ZeroWord};
					end else if(cnt_i == 2'b01) begin
						hilo_temp_o <= {`ZeroWord,`ZeroWord};						
						cnt_o <= 2'b10;
						hilo_temp1 <= hilo_temp_i + {HI,LO};
						stallreq_for_madd_msub <= `NoStop;
					end
				end
				`EXE_MSUB_OP, `EXE_MSUBU_OP:		begin  // MSUB/MSUBU: {HI,LO} = {HI,LO} - rs*rt
					if(cnt_i == 2'b00) begin
						hilo_temp_o <=  ~mulres + 1 ;
						cnt_o <= 2'b01;
						stallreq_for_madd_msub <= `Stop;
					end else if(cnt_i == 2'b01)begin
						hilo_temp_o <= {`ZeroWord,`ZeroWord};						
						cnt_o <= 2'b10;
						hilo_temp1 <= hilo_temp_i + {HI,LO};
						stallreq_for_madd_msub <= `NoStop;
					end				
				end
				default:	begin
					hilo_temp_o <= {`ZeroWord,`ZeroWord};
					cnt_o <= 2'b00;
					stallreq_for_madd_msub <= `NoStop;				
				end
			endcase
		end
	end	

  //DIV¡¢DIVUÖ¸Áî	
	always @ (*) begin
		if(rst == `RstEnable) begin
			stallreq_for_div <= `NoStop;
	    div_opdata1_o <= `ZeroWord;
			div_opdata2_o <= `ZeroWord;
			div_start_o <= `DivStop;
			signed_div_o <= 1'b0;
		end else begin
			stallreq_for_div <= `NoStop;
	    div_opdata1_o <= `ZeroWord;
			div_opdata2_o <= `ZeroWord;
			div_start_o <= `DivStop;
			signed_div_o <= 1'b0;	
			case (aluop_i) 
				`EXE_DIV_OP:		begin  // DIV: 有符号除法
					if(div_ready_i == `DivResultNotReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStart;
						signed_div_o <= 1'b1;
						stallreq_for_div <= `Stop;
					end else if(div_ready_i == `DivResultReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b1;
						stallreq_for_div <= `NoStop;
					end else begin						
	    			div_opdata1_o <= `ZeroWord;
						div_opdata2_o <= `ZeroWord;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `NoStop;
					end					
				end
				`EXE_DIVU_OP:		begin  // DIVU: 无符号除法
					if(div_ready_i == `DivResultNotReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStart;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `Stop;
					end else if(div_ready_i == `DivResultReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `NoStop;
					end else begin						
	    			div_opdata1_o <= `ZeroWord;
						div_opdata2_o <= `ZeroWord;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `NoStop;
					end					
				end
				default: begin
				end
			endcase
		end
	end	

	//MFHI¡¢MFLO¡¢MOVN¡¢MOVZÖ¸Áî
	always @ (*) begin
		if(rst == `RstEnable) begin
	  	moveres <= `ZeroWord;
	  end else begin
	   moveres <= `ZeroWord;
	   case (aluop_i)
	   	`EXE_MFHI_OP:		begin  // MFHI: moveres = HI
	   		moveres <= HI;
	   	end
	   	`EXE_MFLO_OP:		begin  // MFLO: moveres = LO
	   		moveres <= LO;
	   	end
	   	`EXE_MOVZ_OP:		begin  // MOVZ: moveres = reg1 (rt=0时ID级判断)
	   		moveres <= reg1_i;
	   	end
	   	`EXE_MOVN_OP:		begin  // MOVN: moveres = reg1 (rt!=0时ID级判断)
	   		moveres <= reg1_i;
	   	end
	   	`EXE_MFC0_OP:		begin  // MFC0: moveres = CP0[rd] (带MEM/WB前推)
	   	  cp0_reg_read_addr_o <= inst_i[15:11];
	   		moveres <= cp0_reg_data_i;
	   		if( mem_cp0_reg_we == `WriteEnable &&
	   				  mem_cp0_reg_write_addr == inst_i[15:11] ) begin
	   				moveres <= mem_cp0_reg_data;
	   		end else if( wb_cp0_reg_we == `WriteEnable &&
	   				 							 wb_cp0_reg_write_addr == inst_i[15:11] ) begin
	   				moveres <= wb_cp0_reg_data;
	   		end
	   	end	   	
	   	default : begin
	   	end
	   endcase
	  end
	end	 

 always @ (*) begin
	 wd_o <= wd_i;
	 	 	 	
	 if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) ||   // ADD/ADDI/SUB: 带溢出检测, 溢出时wreg_o=Disable
	      (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
	 	wreg_o <= `WriteDisable;
	 	ovassert <= 1'b1;
	 end else begin
	  wreg_o <= wreg_i;
	  ovassert <= 1'b0;
	 end
	 
	 case ( alusel_i ) 
	 	`EXE_RES_LOGIC:		begin  // 选择: 逻辑运算结果 (logicout)
	 		wdata_o <= logicout;
	 	end
	 	`EXE_RES_SHIFT:		begin  // 选择: 移位运算结果 (shiftres)
	 		wdata_o <= shiftres;
	 	end	 	
	 	`EXE_RES_MOVE:		begin  // 选择: 数据移动结果 (moveres)
	 		wdata_o <= moveres;
	 	end	 	
	 	`EXE_RES_ARITHMETIC:	begin  // 选择: 算术运算结果 (arithmeticres)
	 		wdata_o <= arithmeticres;
	 	end
	 	`EXE_RES_MUL:		begin  // 选择: 乘法结果低32位 (mulres[31:0])
	 		wdata_o <= mulres[31:0];
	 	end	 	
	 	`EXE_RES_JUMP_BRANCH:	begin  // 选择: 链接地址 (link_address_i)
	 		wdata_o <= link_address_i;
	 	end	 	
	 	default:					begin
	 		wdata_o <= `ZeroWord;
	 	end
	 endcase
 end	

	always @ (*) begin
		if(rst == `RstEnable) begin
			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
			lo_o <= `ZeroWord;		
		end else if((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin  // MULT/MULTU: HI=高32bit, LO=低32bit
			whilo_o <= `WriteEnable;
			hi_o <= mulres[63:32];
			lo_o <= mulres[31:0];			
		end else if((aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MADDU_OP)) begin  // MADD/MADDU: HI/LO = hilo_temp1 (累加结果)
			whilo_o <= `WriteEnable;
			hi_o <= hilo_temp1[63:32];
			lo_o <= hilo_temp1[31:0];
		end else if((aluop_i == `EXE_MSUB_OP) || (aluop_i == `EXE_MSUBU_OP)) begin  // MSUB/MSUBU: HI/LO = hilo_temp1 (累减结果)
			whilo_o <= `WriteEnable;
			hi_o <= hilo_temp1[63:32];
			lo_o <= hilo_temp1[31:0];		
		end else if((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP)) begin  // DIV/DIVU: HI/LO = div_result_i
			whilo_o <= `WriteEnable;
			hi_o <= div_result_i[63:32];
			lo_o <= div_result_i[31:0];							
		end else if(aluop_i == `EXE_MTHI_OP) begin  // MTHI: HI = reg1, LO不变
			whilo_o <= `WriteEnable;
			hi_o <= reg1_i;
			lo_o <= LO;
		end else if(aluop_i == `EXE_MTLO_OP) begin  // MTLO: LO = reg1, HI不变
			whilo_o <= `WriteEnable;
			hi_o <= HI;
			lo_o <= reg1_i;
		end else begin
			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
			lo_o <= `ZeroWord;
		end				
	end			

	always @ (*) begin
		if(rst == `RstEnable) begin
			cp0_reg_write_addr_o <= 5'b00000;
			cp0_reg_we_o <= `WriteDisable;
			cp0_reg_data_o <= `ZeroWord;
		end else if(aluop_i == `EXE_MTC0_OP) begin  // MTC0: CP0[rd] = reg1
			cp0_reg_write_addr_o <= inst_i[15:11];
			cp0_reg_we_o <= `WriteEnable;
			cp0_reg_data_o <= reg1_i;
	  end else begin
			cp0_reg_write_addr_o <= 5'b00000;
			cp0_reg_we_o <= `WriteDisable;
			cp0_reg_data_o <= `ZeroWord;
		end				
	end		

endmodule