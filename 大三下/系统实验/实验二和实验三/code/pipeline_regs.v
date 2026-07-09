//////////////////////////////////////////////////////////////////////
// File:    pipeline_regs.v
// Description: OpenMIPS 五级流水线寄存器组 — 合并文件
//             包含: IF/ID、ID/EX、EX/MEM、MEM/WB 四个流水线阶段寄存器
//
// 五级流水线数据通路示意:
//   PC → [IF] → if_id → [ID] → id_ex → [EX] → ex_mem → [MEM] → mem_wb → [WB]
//        取指         译码          执行           访存          回写
//
// 各流水线寄存器负责在时钟上升沿锁存本阶段输出，传递给下一阶段
// 同时支持 stall (流水线暂停) 和 flush (流水线冲刷) 控制
//////////////////////////////////////////////////////////////////////

`include "defines.v"

//==========================================================================
// 1. IF/ID 流水线寄存器 — 锁存取指阶段结果，传递给译码阶段
//    输入: PC值(if_pc)、指令字(if_inst)
//    输出: id_pc、id_inst
//    控制: stall[1:2] 用于暂停, flush 用于冲刷
//==========================================================================
module if_id(

	input	wire										clk,
	input wire										rst,

	//À´×Ô¿ØÖÆÄ£¿éµÄÐÅÏ¢
	input wire[5:0]               stall,	
	input wire                    flush,

	input wire[`InstAddrBus]			if_pc,
	input wire[`InstBus]          if_inst,
	output reg[`InstAddrBus]      id_pc,
	output reg[`InstBus]          id_inst  
	
);

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			id_pc <= `ZeroWord;
			id_inst <= `ZeroWord;
		end else if(flush == 1'b1 ) begin
			id_pc <= `ZeroWord;
			id_inst <= `ZeroWord;					
		end else if(stall[1] == `Stop && stall[2] == `NoStop) begin
			id_pc <= `ZeroWord;
			id_inst <= `ZeroWord;	
	  end else if(stall[1] == `NoStop) begin
		  id_pc <= if_pc;
		  id_inst <= if_inst;
		end
	end

endmodule
//==========================================================================
// 2. ID/EX 流水线寄存器 — 锁存译码阶段结果，传递给执行阶段
//    输入: 译码产生的操作码(aluop)、操作数选择(alusel)、
//          源操作数(reg1/reg2)、目的寄存器(wd)、写使能(wreg)、
//          链接地址(link_address)、延迟槽标志(is_in_delayslot)、
//          指令字(inst)、异常类型(excepttype)、当前指令地址
//    输出: 同上，传递至执行阶段
//    控制: stall[2:3] 用于暂停, flush 用于冲刷
//==========================================================================
module id_ex(

	input	wire										clk,
	input wire										rst,

	//À´×Ô¿ØÖÆÄ£¿éµÄÐÅÏ¢
	input wire[5:0]							 stall,
	input wire                   flush,
	
	//´ÓÒëÂë½×¶Î´«µÝµÄÐÅÏ¢
	input wire[`AluOpBus]         id_aluop,
	input wire[`AluSelBus]        id_alusel,
	input wire[`RegBus]           id_reg1,
	input wire[`RegBus]           id_reg2,
	input wire[`RegAddrBus]       id_wd,
	input wire                    id_wreg,
	input wire[`RegBus]           id_link_address,
	input wire                    id_is_in_delayslot,
	input wire                    next_inst_in_delayslot_i,		
	input wire[`RegBus]           id_inst,		
	input wire[`RegBus]           id_current_inst_address,
	input wire[31:0]              id_excepttype,
	
	//´«µÝµ½Ö´ÐÐ½×¶ÎµÄÐÅÏ¢
	output reg[`AluOpBus]         ex_aluop,
	output reg[`AluSelBus]        ex_alusel,
	output reg[`RegBus]           ex_reg1,
	output reg[`RegBus]           ex_reg2,
	output reg[`RegAddrBus]       ex_wd,
	output reg                    ex_wreg,
	output reg[`RegBus]           ex_link_address,
  output reg                    ex_is_in_delayslot,
	output reg                    is_in_delayslot_o,
	output reg[`RegBus]           ex_inst,
	output reg[31:0]              ex_excepttype,
	output reg[`RegBus]          ex_current_inst_address	
	
);

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			ex_aluop <= `EXE_NOP_OP;
			ex_alusel <= `EXE_RES_NOP;
			ex_reg1 <= `ZeroWord;
			ex_reg2 <= `ZeroWord;
			ex_wd <= `NOPRegAddr;
			ex_wreg <= `WriteDisable;
			ex_link_address <= `ZeroWord;
			ex_is_in_delayslot <= `NotInDelaySlot;
	    is_in_delayslot_o <= `NotInDelaySlot;		
	    ex_inst <= `ZeroWord;	
	    ex_excepttype <= `ZeroWord;
	    ex_current_inst_address <= `ZeroWord;
		end else if(flush == 1'b1 ) begin
			ex_aluop <= `EXE_NOP_OP;
			ex_alusel <= `EXE_RES_NOP;
			ex_reg1 <= `ZeroWord;
			ex_reg2 <= `ZeroWord;
			ex_wd <= `NOPRegAddr;
			ex_wreg <= `WriteDisable;
			ex_excepttype <= `ZeroWord;
			ex_link_address <= `ZeroWord;
			ex_inst <= `ZeroWord;
			ex_is_in_delayslot <= `NotInDelaySlot;
	    ex_current_inst_address <= `ZeroWord;	
	    is_in_delayslot_o <= `NotInDelaySlot;		    
		end else if(stall[2] == `Stop && stall[3] == `NoStop) begin
			ex_aluop <= `EXE_NOP_OP;
			ex_alusel <= `EXE_RES_NOP;
			ex_reg1 <= `ZeroWord;
			ex_reg2 <= `ZeroWord;
			ex_wd <= `NOPRegAddr;
			ex_wreg <= `WriteDisable;	
			ex_link_address <= `ZeroWord;
			ex_is_in_delayslot <= `NotInDelaySlot;
	    ex_inst <= `ZeroWord;			
	    ex_excepttype <= `ZeroWord;
	    ex_current_inst_address <= `ZeroWord;	
		end else if(stall[2] == `NoStop) begin		
			ex_aluop <= id_aluop;
			ex_alusel <= id_alusel;
			ex_reg1 <= id_reg1;
			ex_reg2 <= id_reg2;
			ex_wd <= id_wd;
			ex_wreg <= id_wreg;		
			ex_link_address <= id_link_address;
			ex_is_in_delayslot <= id_is_in_delayslot;
	    is_in_delayslot_o <= next_inst_in_delayslot_i;
	    ex_inst <= id_inst;			
	    ex_excepttype <= id_excepttype;
	    ex_current_inst_address <= id_current_inst_address;		
		end
	end
	
endmodule
//==========================================================================
// 3. EX/MEM 流水线寄存器 — 锁存执行阶段结果，传递给访存阶段
//    输入: 执行结果(wdata)、HI/LO值、目的寄存器(wd)、写使能(wreg)、
//          ALU操作码、访存地址(mem_addr)、源操作数2(reg2)、
//          CP0写信息、异常类型、延迟槽标志、HI/LO临时值(hilo_i/cnt_i)
//    输出: 同上，传递至访存阶段
//    控制: stall[3:4] 用于暂停, flush 用于冲刷
//==========================================================================
module ex_mem(

	input	wire										clk,
	input wire										rst,

	//À´×Ô¿ØÖÆÄ£¿éµÄÐÅÏ¢
	input wire[5:0]							 stall,	
	input wire                   flush,
	
	//À´×ÔÖ´ÐÐ½×¶ÎµÄÐÅÏ¢	
	input wire[`RegAddrBus]       ex_wd,
	input wire                    ex_wreg,
	input wire[`RegBus]					 ex_wdata, 	
	input wire[`RegBus]           ex_hi,
	input wire[`RegBus]           ex_lo,
	input wire                    ex_whilo, 	

  //ÎªÊµÏÖ¼ÓÔØ¡¢·Ã´æÖ¸Áî¶øÌí¼Ó
  input wire[`AluOpBus]        ex_aluop,
	input wire[`RegBus]          ex_mem_addr,
	input wire[`RegBus]          ex_reg2,

	input wire[`DoubleRegBus]     hilo_i,	
	input wire[1:0]               cnt_i,	

	input wire                   ex_cp0_reg_we,
	input wire[4:0]              ex_cp0_reg_write_addr,
	input wire[`RegBus]          ex_cp0_reg_data,	

  input wire[31:0]             ex_excepttype,
	input wire                   ex_is_in_delayslot,
	input wire[`RegBus]          ex_current_inst_address,
	
	//ËÍµ½·Ã´æ½×¶ÎµÄÐÅÏ¢
	output reg[`RegAddrBus]      mem_wd,
	output reg                   mem_wreg,
	output reg[`RegBus]					 mem_wdata,
	output reg[`RegBus]          mem_hi,
	output reg[`RegBus]          mem_lo,
	output reg                   mem_whilo,

  //ÎªÊµÏÖ¼ÓÔØ¡¢·Ã´æÖ¸Áî¶øÌí¼Ó
  output reg[`AluOpBus]        mem_aluop,
	output reg[`RegBus]          mem_mem_addr,
	output reg[`RegBus]          mem_reg2,
	
	output reg                   mem_cp0_reg_we,
	output reg[4:0]              mem_cp0_reg_write_addr,
	output reg[`RegBus]          mem_cp0_reg_data,
	
	output reg[31:0]            mem_excepttype,
  output reg                  mem_is_in_delayslot,
	output reg[`RegBus]         mem_current_inst_address,
		
	output reg[`DoubleRegBus]    hilo_o,
	output reg[1:0]              cnt_o	
	
	
);


	always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			mem_wd <= `NOPRegAddr;
			mem_wreg <= `WriteDisable;
		  mem_wdata <= `ZeroWord;	
		  mem_hi <= `ZeroWord;
		  mem_lo <= `ZeroWord;
		  mem_whilo <= `WriteDisable;		
	    hilo_o <= {`ZeroWord, `ZeroWord};
			cnt_o <= 2'b00;	
  		mem_aluop <= `EXE_NOP_OP;
			mem_mem_addr <= `ZeroWord;
			mem_reg2 <= `ZeroWord;	
			mem_cp0_reg_we <= `WriteDisable;
			mem_cp0_reg_write_addr <= 5'b00000;
			mem_cp0_reg_data <= `ZeroWord;	
			mem_excepttype <= `ZeroWord;
			mem_is_in_delayslot <= `NotInDelaySlot;
	    mem_current_inst_address <= `ZeroWord;
		end else if(flush == 1'b1 ) begin
			mem_wd <= `NOPRegAddr;
			mem_wreg <= `WriteDisable;
		  mem_wdata <= `ZeroWord;
		  mem_hi <= `ZeroWord;
		  mem_lo <= `ZeroWord;
		  mem_whilo <= `WriteDisable;
  		mem_aluop <= `EXE_NOP_OP;
			mem_mem_addr <= `ZeroWord;
			mem_reg2 <= `ZeroWord;
			mem_cp0_reg_we <= `WriteDisable;
			mem_cp0_reg_write_addr <= 5'b00000;
			mem_cp0_reg_data <= `ZeroWord;
			mem_excepttype <= `ZeroWord;
			mem_is_in_delayslot <= `NotInDelaySlot;
	    mem_current_inst_address <= `ZeroWord;
	    hilo_o <= {`ZeroWord, `ZeroWord};
			cnt_o <= 2'b00;	    	    				
		end else if(stall[3] == `Stop && stall[4] == `NoStop) begin
			mem_wd <= `NOPRegAddr;
			mem_wreg <= `WriteDisable;
		  mem_wdata <= `ZeroWord;
		  mem_hi <= `ZeroWord;
		  mem_lo <= `ZeroWord;
		  mem_whilo <= `WriteDisable;
	    hilo_o <= hilo_i;
			cnt_o <= cnt_i;	
  		mem_aluop <= `EXE_NOP_OP;
			mem_mem_addr <= `ZeroWord;
			mem_reg2 <= `ZeroWord;		
			mem_cp0_reg_we <= `WriteDisable;
			mem_cp0_reg_write_addr <= 5'b00000;
			mem_cp0_reg_data <= `ZeroWord;	
			mem_excepttype <= `ZeroWord;
			mem_is_in_delayslot <= `NotInDelaySlot;
	    mem_current_inst_address <= `ZeroWord;						  				    
		end else if(stall[3] == `NoStop) begin
			mem_wd <= ex_wd;
			mem_wreg <= ex_wreg;
			mem_wdata <= ex_wdata;	
			mem_hi <= ex_hi;
			mem_lo <= ex_lo;
			mem_whilo <= ex_whilo;	
	    hilo_o <= {`ZeroWord, `ZeroWord};
			cnt_o <= 2'b00;	
  		mem_aluop <= ex_aluop;
			mem_mem_addr <= ex_mem_addr;
			mem_reg2 <= ex_reg2;
			mem_cp0_reg_we <= ex_cp0_reg_we;
			mem_cp0_reg_write_addr <= ex_cp0_reg_write_addr;
			mem_cp0_reg_data <= ex_cp0_reg_data;	
			mem_excepttype <= ex_excepttype;
			mem_is_in_delayslot <= ex_is_in_delayslot;
	    mem_current_inst_address <= ex_current_inst_address;						
		end else begin
	    hilo_o <= hilo_i;
			cnt_o <= cnt_i;											
		end    //if
	end      //always
			

endmodule
//==========================================================================
// 4. MEM/WB 流水线寄存器 — 锁存访存阶段结果，传递给回写阶段
//    输入: 访存结果(wdata)、HI/LO值、目的寄存器(wd)、写使能(wreg)、
//          LLbit写信息、CP0写信息
//    输出: 同上，传递至回写阶段 (连接 regfile、hilo_reg、LLbit_reg、cp0_reg)
//    控制: stall[4:5] 用于暂停, flush 用于冲刷
//==========================================================================
module mem_wb(

	input	wire										clk,
	input wire										rst,

  //À´×Ô¿ØÖÆÄ£¿éµÄÐÅÏ¢
	input wire[5:0]               stall,
	input wire                    flush,	

	//À´×Ô·Ã´æ½×¶ÎµÄÐÅÏ¢	
	input wire[`RegAddrBus]       mem_wd,
	input wire                    mem_wreg,
	input wire[`RegBus]					 mem_wdata,
	input wire[`RegBus]           mem_hi,
	input wire[`RegBus]           mem_lo,
	input wire                    mem_whilo,	
	
	input wire                  mem_LLbit_we,
	input wire                  mem_LLbit_value,	

	input wire                   mem_cp0_reg_we,
	input wire[4:0]              mem_cp0_reg_write_addr,
	input wire[`RegBus]          mem_cp0_reg_data,			

	//ËÍµ½»ØÐ´½×¶ÎµÄÐÅÏ¢
	output reg[`RegAddrBus]      wb_wd,
	output reg                   wb_wreg,
	output reg[`RegBus]					 wb_wdata,
	output reg[`RegBus]          wb_hi,
	output reg[`RegBus]          wb_lo,
	output reg                   wb_whilo,

	output reg                  wb_LLbit_we,
	output reg                  wb_LLbit_value,

	output reg                   wb_cp0_reg_we,
	output reg[4:0]              wb_cp0_reg_write_addr,
	output reg[`RegBus]          wb_cp0_reg_data								       
	
);


	always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			wb_wd <= `NOPRegAddr;
			wb_wreg <= `WriteDisable;
		  wb_wdata <= `ZeroWord;	
		  wb_hi <= `ZeroWord;
		  wb_lo <= `ZeroWord;
		  wb_whilo <= `WriteDisable;
		  wb_LLbit_we <= 1'b0;
		  wb_LLbit_value <= 1'b0;		
			wb_cp0_reg_we <= `WriteDisable;
			wb_cp0_reg_write_addr <= 5'b00000;
			wb_cp0_reg_data <= `ZeroWord;		
		end else if(flush == 1'b1 ) begin
			wb_wd <= `NOPRegAddr;
			wb_wreg <= `WriteDisable;
		  wb_wdata <= `ZeroWord;
		  wb_hi <= `ZeroWord;
		  wb_lo <= `ZeroWord;
		  wb_whilo <= `WriteDisable;
		  wb_LLbit_we <= 1'b0;
		  wb_LLbit_value <= 1'b0;	
			wb_cp0_reg_we <= `WriteDisable;
			wb_cp0_reg_write_addr <= 5'b00000;
			wb_cp0_reg_data <= `ZeroWord;				    					  	  	
		end else if(stall[4] == `Stop && stall[5] == `NoStop) begin
			wb_wd <= `NOPRegAddr;
			wb_wreg <= `WriteDisable;
		  wb_wdata <= `ZeroWord;
		  wb_hi <= `ZeroWord;
		  wb_lo <= `ZeroWord;
		  wb_whilo <= `WriteDisable;	
		  wb_LLbit_we <= 1'b0;
		  wb_LLbit_value <= 1'b0;	
			wb_cp0_reg_we <= `WriteDisable;
			wb_cp0_reg_write_addr <= 5'b00000;
			wb_cp0_reg_data <= `ZeroWord;					  		  	  	  
		end else if(stall[4] == `NoStop) begin
			wb_wd <= mem_wd;
			wb_wreg <= mem_wreg;
			wb_wdata <= mem_wdata;
			wb_hi <= mem_hi;
			wb_lo <= mem_lo;
			wb_whilo <= mem_whilo;		
		  wb_LLbit_we <= mem_LLbit_we;
		  wb_LLbit_value <= mem_LLbit_value;		
			wb_cp0_reg_we <= mem_cp0_reg_we;
			wb_cp0_reg_write_addr <= mem_cp0_reg_write_addr;
			wb_cp0_reg_data <= mem_cp0_reg_data;			  		
		end    //if
	end      //always
			

endmodule