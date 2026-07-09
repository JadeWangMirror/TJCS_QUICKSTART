//////////////////////////////////////////////////////////////////////
// Module:  openmips
// File:    openmips.v
// Description: OpenMIPS 处理器顶层 — 五级流水线 MIPS32 处理器核心
//             流水线结构:
//               IF  (取指):  pc_reg → Flash ROM → if_id
//               ID  (译码):  id (指令译码、寄存器读取、数据前推检测)
//               EX  (执行):  ex (ALU/乘除/跳转) + div (除法器)
//               MEM (访存):  mem (加载/存储、LL/SC、异常判断)
//               WB  (回写):  写 regfile / HI·LO / LLbit / CP0
//             内部互联:
//               - 两条 Wishbone 总线接口 (取指总线 + 数据总线)
//               - wishbone_bus_if × 2 实例
//               - ctrl 模块: 全局流水线控制 (stall/flush/new_pc)
//               - cp0_reg: 协处理器 0 (异常处理、定时器中断)
//             支持: 57 条 MIPS32 指令、异常/中断处理、延迟槽
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module openmips(

	input	wire										clk,
	input wire										rst,
	
  input wire[5:0]                int_i,
  
  //Ö¸Áîwishbone×ÜÏß
	input wire[`RegBus]           iwishbone_data_i,
	input wire                    iwishbone_ack_i,
	output wire[`RegBus]           iwishbone_addr_o,
	output wire[`RegBus]           iwishbone_data_o,
	output wire                    iwishbone_we_o,
	output wire[3:0]               iwishbone_sel_o,
	output wire                    iwishbone_stb_o,
	output wire                    iwishbone_cyc_o, 
	
  //Êý¾Ýwishbone×ÜÏß
	input wire[`RegBus]           dwishbone_data_i,
	input wire                    dwishbone_ack_i,
	output wire[`RegBus]           dwishbone_addr_o,
	output wire[`RegBus]           dwishbone_data_o,
	output wire                    dwishbone_we_o,
	output wire[3:0]               dwishbone_sel_o,
	output wire                    dwishbone_stb_o,
	output wire                    dwishbone_cyc_o,
	
	output wire                    timer_int_o
	
);
	wire[5:0] stall;
	wire[`InstAddrBus] pc;

//    assign cpu_stall = pc;

	wire[`InstBus] inst_i;	
	wire[`InstAddrBus] id_pc_i;
	wire[`InstBus] id_inst_i;
	
	//Á¬½ÓÒëÂë½×¶ÎIDÄ£¿éµÄÊä³öÓëID/EXÄ£¿éµÄÊäÈë
	wire[`AluOpBus] id_aluop_o;
	wire[`AluSelBus] id_alusel_o;
	wire[`RegBus] id_reg1_o;
	wire[`RegBus] id_reg2_o;
	wire id_wreg_o;
	wire[`RegAddrBus] id_wd_o;
	wire id_is_in_delayslot_o;
  wire[`RegBus] id_link_address_o;	
  wire[`RegBus] id_inst_o;
  wire[31:0] id_excepttype_o;
  wire[`RegBus] id_current_inst_address_o;
	
	//Á¬½ÓID/EXÄ£¿éµÄÊä³öÓëÖ´ÐÐ½×¶ÎEXÄ£¿éµÄÊäÈë
	wire[`AluOpBus] ex_aluop_i;
	wire[`AluSelBus] ex_alusel_i;
	wire[`RegBus] ex_reg1_i;
	wire[`RegBus] ex_reg2_i;
	wire ex_wreg_i;
	wire[`RegAddrBus] ex_wd_i;
	wire ex_is_in_delayslot_i;	
  wire[`RegBus] ex_link_address_i;	
  wire[`RegBus] ex_inst_i;
  wire[31:0] ex_excepttype_i;	
  wire[`RegBus] ex_current_inst_address_i;	
	
	//Á¬½ÓÖ´ÐÐ½×¶ÎEXÄ£¿éµÄÊä³öÓëEX/MEMÄ£¿éµÄÊäÈë
	wire ex_wreg_o;
	wire[`RegAddrBus] ex_wd_o;
	wire[`RegBus] ex_wdata_o;
	wire[`RegBus] ex_hi_o;
	wire[`RegBus] ex_lo_o;
	wire ex_whilo_o;
	wire[`AluOpBus] ex_aluop_o;
	wire[`RegBus] ex_mem_addr_o;
	wire[`RegBus] ex_reg2_o;
	wire ex_cp0_reg_we_o;
	wire[4:0] ex_cp0_reg_write_addr_o;
	wire[`RegBus] ex_cp0_reg_data_o; 	
	wire[31:0] ex_excepttype_o;
	wire[`RegBus] ex_current_inst_address_o;
	wire ex_is_in_delayslot_o;

	//Á¬½ÓEX/MEMÄ£¿éµÄÊä³öÓë·Ã´æ½×¶ÎMEMÄ£¿éµÄÊäÈë
	wire mem_wreg_i;
	wire[`RegAddrBus] mem_wd_i;
	wire[`RegBus] mem_wdata_i;
	wire[`RegBus] mem_hi_i;
	wire[`RegBus] mem_lo_i;
	wire mem_whilo_i;		
	wire[`AluOpBus] mem_aluop_i;
	wire[`RegBus] mem_mem_addr_i;
	wire[`RegBus] mem_reg2_i;		
	wire mem_cp0_reg_we_i;
	wire[4:0] mem_cp0_reg_write_addr_i;
	wire[`RegBus] mem_cp0_reg_data_i;	
	wire[31:0] mem_excepttype_i;	
	wire mem_is_in_delayslot_i;
	wire[`RegBus] mem_current_inst_address_i;	

	//Á¬½Ó·Ã´æ½×¶ÎMEMÄ£¿éµÄÊä³öÓëMEM/WBÄ£¿éµÄÊäÈë
	wire mem_wreg_o;
	wire[`RegAddrBus] mem_wd_o;
	wire[`RegBus] mem_wdata_o;
	wire[`RegBus] mem_hi_o;
	wire[`RegBus] mem_lo_o;
	wire mem_whilo_o;	
	wire mem_LLbit_value_o;
	wire mem_LLbit_we_o;
	wire mem_cp0_reg_we_o;
	wire[4:0] mem_cp0_reg_write_addr_o;
	wire[`RegBus] mem_cp0_reg_data_o;	
	wire[31:0] mem_excepttype_o;
	wire mem_is_in_delayslot_o;
	wire[`RegBus] mem_current_inst_address_o;			
	
	//Á¬½ÓMEM/WBÄ£¿éµÄÊä³öÓë»ØÐ´½×¶ÎµÄÊäÈë	
	wire wb_wreg_i;
	wire[`RegAddrBus] wb_wd_i;
	wire[`RegBus] wb_wdata_i;
	wire[`RegBus] wb_hi_i;
	wire[`RegBus] wb_lo_i;
	wire wb_whilo_i;	
	wire wb_LLbit_value_i;
	wire wb_LLbit_we_i;	
	wire wb_cp0_reg_we_i;
	wire[4:0] wb_cp0_reg_write_addr_i;
	wire[`RegBus] wb_cp0_reg_data_i;		
	wire[31:0] wb_excepttype_i;
	wire wb_is_in_delayslot_i;
	wire[`RegBus] wb_current_inst_address_i;
	
	//Á¬½ÓÒëÂë½×¶ÎIDÄ£¿éÓëÍ¨ÓÃ¼Ä´æÆ÷RegfileÄ£¿é
  wire reg1_read;
  wire reg2_read;
  wire[`RegBus] reg1_data;
  wire[`RegBus] reg2_data;
  wire[`RegAddrBus] reg1_addr;
  wire[`RegAddrBus] reg2_addr;

	//Á¬½ÓÖ´ÐÐ½×¶ÎÓëhiloÄ£¿éµÄÊä³ö£¬¶ÁÈ¡HI¡¢LO¼Ä´æÆ÷
	wire[`RegBus] 	hi;
	wire[`RegBus]   lo;

  //Á¬½ÓÖ´ÐÐ½×¶ÎÓëex_regÄ£¿é£¬ÓÃÓÚ¶àÖÜÆÚµÄMADD¡¢MADDU¡¢MSUB¡¢MSUBUÖ¸Áî
	wire[`DoubleRegBus] hilo_temp_o;
	wire[1:0] cnt_o;
	
	wire[`DoubleRegBus] hilo_temp_i;
	wire[1:0] cnt_i;

	wire[`DoubleRegBus] div_result;
	wire div_ready;
	wire[`RegBus] div_opdata1;
	wire[`RegBus] div_opdata2;
	wire div_start;
	wire div_annul;
	wire signed_div;

	wire is_in_delayslot_i;
	wire is_in_delayslot_o;
	wire next_inst_in_delayslot_o;
	wire id_branch_flag_o;
	wire[`RegBus] branch_target_address;

	wire stallreq_from_ex;
	wire stallreq_from_id;
  wire stallreq_from_if;
	wire stallreq_from_mem;

	wire LLbit_o;

  wire[`RegBus] cp0_data_o;
  wire[4:0] cp0_raddr_i;
 
  wire flush;
  wire[`RegBus] new_pc;

	wire[`RegBus] cp0_count;
	wire[`RegBus]	cp0_compare;
	wire[`RegBus]	cp0_status;
	wire[`RegBus]	cp0_cause;
	wire[`RegBus]	cp0_epc;
	wire[`RegBus]	cp0_config;
	wire[`RegBus]	cp0_prid; 

  wire[`RegBus] latest_epc;

	wire rom_ce;

	wire[31:0] ram_addr_o;
	wire ram_we_o;
  wire[3:0] ram_sel_o;
	wire[`RegBus] ram_data_o;
	wire ram_ce_o;
  wire[`RegBus] ram_data_i;
  
  //pc_regÀý»¯
	pc_reg pc_reg0(
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.flush(flush),
	  .new_pc(new_pc),
		.branch_flag_i(id_branch_flag_o),
		.branch_target_address_i(branch_target_address),		
		.pc(pc),
		.ce(rom_ce)					
			
	);
	
  //IF/IDÄ£¿éÀý»¯
	if_id if_id0(
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.flush(flush),
		.if_pc(pc),
		.if_inst(inst_i),
		.id_pc(id_pc_i),
		.id_inst(id_inst_i)      	
	);
	
	//ÒëÂë½×¶ÎIDÄ£¿é
	id id0(
		.rst(rst),
		.pc_i(id_pc_i),
		.inst_i(id_inst_i),

  	.ex_aluop_i(ex_aluop_o),

		.reg1_data_i(reg1_data),
		.reg2_data_i(reg2_data),

	  //´¦ÓÚÖ´ÐÐ½×¶ÎµÄÖ¸ÁîÒªÐ´ÈëµÄÄ¿µÄ¼Ä´æÆ÷ÐÅÏ¢
		.ex_wreg_i(ex_wreg_o),
		.ex_wdata_i(ex_wdata_o),
		.ex_wd_i(ex_wd_o),

	  //´¦ÓÚ·Ã´æ½×¶ÎµÄÖ¸ÁîÒªÐ´ÈëµÄÄ¿µÄ¼Ä´æÆ÷ÐÅÏ¢
		.mem_wreg_i(mem_wreg_o),
		.mem_wdata_i(mem_wdata_o),
		.mem_wd_i(mem_wd_o),

	  .is_in_delayslot_i(is_in_delayslot_i),

		//ËÍµ½regfileµÄÐÅÏ¢
		.reg1_read_o(reg1_read),
		.reg2_read_o(reg2_read), 	  

		.reg1_addr_o(reg1_addr),
		.reg2_addr_o(reg2_addr), 
	  
		//ËÍµ½ID/EXÄ£¿éµÄÐÅÏ¢
		.aluop_o(id_aluop_o),
		.alusel_o(id_alusel_o),
		.reg1_o(id_reg1_o),
		.reg2_o(id_reg2_o),
		.wd_o(id_wd_o),
		.wreg_o(id_wreg_o),
		.excepttype_o(id_excepttype_o),
		.inst_o(id_inst_o),

	 	.next_inst_in_delayslot_o(next_inst_in_delayslot_o),	
		.branch_flag_o(id_branch_flag_o),
		.branch_target_address_o(branch_target_address),       
		.link_addr_o(id_link_address_o),
		
		.is_in_delayslot_o(id_is_in_delayslot_o),
		.current_inst_address_o(id_current_inst_address_o),
		
		.stallreq(stallreq_from_id)		
	);

  //Í¨ÓÃ¼Ä´æÆ÷RegfileÀý»¯
	regfile regfile1(
		.clk (clk),
		.rst (rst),
		.we	(wb_wreg_i),
		.waddr (wb_wd_i),
		.wdata (wb_wdata_i),
		.re1 (reg1_read),
		.raddr1 (reg1_addr),
		.rdata1 (reg1_data),
		.re2 (reg2_read),
		.raddr2 (reg2_addr),
		.rdata2 (reg2_data)
	);

	//ID/EXÄ£¿é
	id_ex id_ex0(
		.clk(clk),
		.rst(rst),
		
		.stall(stall),
		.flush(flush),
		
		//´ÓÒëÂë½×¶ÎIDÄ£¿é´«µÝµÄÐÅÏ¢
		.id_aluop(id_aluop_o),
		.id_alusel(id_alusel_o),
		.id_reg1(id_reg1_o),
		.id_reg2(id_reg2_o),
		.id_wd(id_wd_o),
		.id_wreg(id_wreg_o),
		.id_link_address(id_link_address_o),
		.id_is_in_delayslot(id_is_in_delayslot_o),
		.next_inst_in_delayslot_i(next_inst_in_delayslot_o),		
		.id_inst(id_inst_o),		
		.id_excepttype(id_excepttype_o),
		.id_current_inst_address(id_current_inst_address_o),
	
		//´«µÝµ½Ö´ÐÐ½×¶ÎEXÄ£¿éµÄÐÅÏ¢
		.ex_aluop(ex_aluop_i),
		.ex_alusel(ex_alusel_i),
		.ex_reg1(ex_reg1_i),
		.ex_reg2(ex_reg2_i),
		.ex_wd(ex_wd_i),
		.ex_wreg(ex_wreg_i),
		.ex_link_address(ex_link_address_i),
  	.ex_is_in_delayslot(ex_is_in_delayslot_i),
		.is_in_delayslot_o(is_in_delayslot_i),
		.ex_inst(ex_inst_i),
		.ex_excepttype(ex_excepttype_i),
		.ex_current_inst_address(ex_current_inst_address_i)		
	);		
	
	//EXÄ£¿é
	ex ex0(
		.rst(rst),
	
		//ËÍµ½Ö´ÐÐ½×¶ÎEXÄ£¿éµÄÐÅÏ¢
		.aluop_i(ex_aluop_i),
		.alusel_i(ex_alusel_i),
		.reg1_i(ex_reg1_i),
		.reg2_i(ex_reg2_i),
		.wd_i(ex_wd_i),
		.wreg_i(ex_wreg_i),
		.hi_i(hi),
		.lo_i(lo),
		.inst_i(ex_inst_i),

	  .wb_hi_i(wb_hi_i),
	  .wb_lo_i(wb_lo_i),
	  .wb_whilo_i(wb_whilo_i),
	  .mem_hi_i(mem_hi_o),
	  .mem_lo_i(mem_lo_o),
	  .mem_whilo_i(mem_whilo_o),

	  .hilo_temp_i(hilo_temp_i),
	  .cnt_i(cnt_i),

		.div_result_i(div_result),
		.div_ready_i(div_ready), 

	  .link_address_i(ex_link_address_i),
		.is_in_delayslot_i(ex_is_in_delayslot_i),	  
		
		.excepttype_i(ex_excepttype_i),
		.current_inst_address_i(ex_current_inst_address_i),

		//·Ã´æ½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´CP0£¬ÓÃÀ´¼ì²âÊý¾ÝÏà¹Ø
  	.mem_cp0_reg_we(mem_cp0_reg_we_o),
		.mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
		.mem_cp0_reg_data(mem_cp0_reg_data_o),
	
		//»ØÐ´½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´CP0£¬ÓÃÀ´¼ì²âÊý¾ÝÏà¹Ø
  	.wb_cp0_reg_we(wb_cp0_reg_we_i),
		.wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
		.wb_cp0_reg_data(wb_cp0_reg_data_i),

		.cp0_reg_data_i(cp0_data_o),
		.cp0_reg_read_addr_o(cp0_raddr_i),
		
		//ÏòÏÂÒ»Á÷Ë®¼¶´«µÝ£¬ÓÃÓÚÐ´CP0ÖÐµÄ¼Ä´æÆ÷
		.cp0_reg_we_o(ex_cp0_reg_we_o),
		.cp0_reg_write_addr_o(ex_cp0_reg_write_addr_o),
		.cp0_reg_data_o(ex_cp0_reg_data_o),	  
			  
	  //EXÄ£¿éµÄÊä³öµ½EX/MEMÄ£¿éÐÅÏ¢
		.wd_o(ex_wd_o),
		.wreg_o(ex_wreg_o),
		.wdata_o(ex_wdata_o),

		.hi_o(ex_hi_o),
		.lo_o(ex_lo_o),
		.whilo_o(ex_whilo_o),

		.hilo_temp_o(hilo_temp_o),
		.cnt_o(cnt_o),

		.div_opdata1_o(div_opdata1),
		.div_opdata2_o(div_opdata2),
		.div_start_o(div_start),
		.signed_div_o(signed_div),	

		.aluop_o(ex_aluop_o),
		.mem_addr_o(ex_mem_addr_o),
		.reg2_o(ex_reg2_o),
		
		.excepttype_o(ex_excepttype_o),
		.is_in_delayslot_o(ex_is_in_delayslot_o),
		.current_inst_address_o(ex_current_inst_address_o),	
		
		.stallreq(stallreq_from_ex)     				
		
	);

  //EX/MEMÄ£¿é
  ex_mem ex_mem0(
		.clk(clk),
		.rst(rst),
	  
	  .stall(stall),
	  .flush(flush),
	  
		//À´×ÔÖ´ÐÐ½×¶ÎEXÄ£¿éµÄÐÅÏ¢	
		.ex_wd(ex_wd_o),
		.ex_wreg(ex_wreg_o),
		.ex_wdata(ex_wdata_o),
		.ex_hi(ex_hi_o),
		.ex_lo(ex_lo_o),
		.ex_whilo(ex_whilo_o),		

  	.ex_aluop(ex_aluop_o),
		.ex_mem_addr(ex_mem_addr_o),
		.ex_reg2(ex_reg2_o),			
	
		.ex_cp0_reg_we(ex_cp0_reg_we_o),
		.ex_cp0_reg_write_addr(ex_cp0_reg_write_addr_o),
		.ex_cp0_reg_data(ex_cp0_reg_data_o),	

    .ex_excepttype(ex_excepttype_o),
		.ex_is_in_delayslot(ex_is_in_delayslot_o),
		.ex_current_inst_address(ex_current_inst_address_o),	

		.hilo_i(hilo_temp_o),
		.cnt_i(cnt_o),	

		//ËÍµ½·Ã´æ½×¶ÎMEMÄ£¿éµÄÐÅÏ¢
		.mem_wd(mem_wd_i),
		.mem_wreg(mem_wreg_i),
		.mem_wdata(mem_wdata_i),
		.mem_hi(mem_hi_i),
		.mem_lo(mem_lo_i),
		.mem_whilo(mem_whilo_i),
	
		.mem_cp0_reg_we(mem_cp0_reg_we_i),
		.mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_i),
		.mem_cp0_reg_data(mem_cp0_reg_data_i),

  	.mem_aluop(mem_aluop_i),
		.mem_mem_addr(mem_mem_addr_i),
		.mem_reg2(mem_reg2_i),
		
		.mem_excepttype(mem_excepttype_i),
  	.mem_is_in_delayslot(mem_is_in_delayslot_i),
		.mem_current_inst_address(mem_current_inst_address_i),
				
		.hilo_o(hilo_temp_i),
		.cnt_o(cnt_i)
						       	
	);
	
  //MEMÄ£¿éÀý»¯
	mem mem0(
		.rst(rst),
	
		//À´×ÔEX/MEMÄ£¿éµÄÐÅÏ¢	
		.wd_i(mem_wd_i),
		.wreg_i(mem_wreg_i),
		.wdata_i(mem_wdata_i),
		.hi_i(mem_hi_i),
		.lo_i(mem_lo_i),
		.whilo_i(mem_whilo_i),		

  	.aluop_i(mem_aluop_i),
		.mem_addr_i(mem_mem_addr_i),
		.reg2_i(mem_reg2_i),
	
		//À´×ÔmemoryµÄÐÅÏ¢
		.mem_data_i(ram_data_i),

		//LLbit_iÊÇLLbit¼Ä´æÆ÷µÄÖµ
		.LLbit_i(LLbit_o),
		//µ«²»Ò»¶¨ÊÇ×îÐÂÖµ£¬»ØÐ´½×¶Î¿ÉÄÜÒªÐ´LLbit£¬ËùÒÔ»¹Òª½øÒ»²½ÅÐ¶Ï
		.wb_LLbit_we_i(wb_LLbit_we_i),
		.wb_LLbit_value_i(wb_LLbit_value_i),

		.cp0_reg_we_i(mem_cp0_reg_we_i),
		.cp0_reg_write_addr_i(mem_cp0_reg_write_addr_i),
		.cp0_reg_data_i(mem_cp0_reg_data_i),

    .excepttype_i(mem_excepttype_i),
		.is_in_delayslot_i(mem_is_in_delayslot_i),
		.current_inst_address_i(mem_current_inst_address_i),	
		
		.cp0_status_i(cp0_status),
		.cp0_cause_i(cp0_cause),
		.cp0_epc_i(cp0_epc),
		
		//»ØÐ´½×¶ÎµÄÖ¸ÁîÊÇ·ñÒªÐ´CP0£¬ÓÃÀ´¼ì²âÊý¾ÝÏà¹Ø
  	.wb_cp0_reg_we(wb_cp0_reg_we_i),
		.wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
		.wb_cp0_reg_data(wb_cp0_reg_data_i),	  

		.LLbit_we_o(mem_LLbit_we_o),
		.LLbit_value_o(mem_LLbit_value_o),

		.cp0_reg_we_o(mem_cp0_reg_we_o),
		.cp0_reg_write_addr_o(mem_cp0_reg_write_addr_o),
		.cp0_reg_data_o(mem_cp0_reg_data_o),			
	  
		//ËÍµ½MEM/WBÄ£¿éµÄÐÅÏ¢
		.wd_o(mem_wd_o),
		.wreg_o(mem_wreg_o),
		.wdata_o(mem_wdata_o),
		.hi_o(mem_hi_o),
		.lo_o(mem_lo_o),
		.whilo_o(mem_whilo_o),
		
		//ËÍµ½memoryµÄÐÅÏ¢
		.mem_addr_o(ram_addr_o),
		.mem_we_o(ram_we_o),
		.mem_sel_o(ram_sel_o),
		.mem_data_o(ram_data_o),
		.mem_ce_o(ram_ce_o),
		
		.excepttype_o(mem_excepttype_o),
		.cp0_epc_o(latest_epc),
		.is_in_delayslot_o(mem_is_in_delayslot_o),
		.current_inst_address_o(mem_current_inst_address_o)		
	);

  //MEM/WBÄ£¿é
	mem_wb mem_wb0(
		.clk(clk),
		.rst(rst),

    .stall(stall),
    .flush(flush),

		//À´×Ô·Ã´æ½×¶ÎMEMÄ£¿éµÄÐÅÏ¢	
		.mem_wd(mem_wd_o),
		.mem_wreg(mem_wreg_o),
		.mem_wdata(mem_wdata_o),
		.mem_hi(mem_hi_o),
		.mem_lo(mem_lo_o),
		.mem_whilo(mem_whilo_o),		

		.mem_LLbit_we(mem_LLbit_we_o),
		.mem_LLbit_value(mem_LLbit_value_o),	
	
		.mem_cp0_reg_we(mem_cp0_reg_we_o),
		.mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
		.mem_cp0_reg_data(mem_cp0_reg_data_o),					
	
		//ËÍµ½»ØÐ´½×¶ÎµÄÐÅÏ¢
		.wb_wd(wb_wd_i),
		.wb_wreg(wb_wreg_i),
		.wb_wdata(wb_wdata_i),
		.wb_hi(wb_hi_i),
		.wb_lo(wb_lo_i),
		.wb_whilo(wb_whilo_i),

		.wb_LLbit_we(wb_LLbit_we_i),
		.wb_LLbit_value(wb_LLbit_value_i),
		
		.wb_cp0_reg_we(wb_cp0_reg_we_i),
		.wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
		.wb_cp0_reg_data(wb_cp0_reg_data_i)						
									       	
	);

	hilo_reg hilo_reg0(
		.clk(clk),
		.rst(rst),
	
		//Ð´¶Ë¿Ú
		.we(wb_whilo_i),
		.hi_i(wb_hi_i),
		.lo_i(wb_lo_i),
	
		//¶Á¶Ë¿Ú1
		.hi_o(hi),
		.lo_o(lo)	
	);
	
	ctrl ctrl0(
		.rst(rst),
	
	  .excepttype_i(mem_excepttype_o),
	  .cp0_epc_i(latest_epc),
 
    .stallreq_from_if(stallreq_from_if),	  
		.stallreq_from_id(stallreq_from_id),
	
  	//À´×ÔÖ´ÐÐ½×¶ÎµÄÔÝÍ£ÇëÇó
		.stallreq_from_ex(stallreq_from_ex),
		.stallreq_from_mem(stallreq_from_mem),
	  .new_pc(new_pc),
	  .flush(flush),
		.stall(stall)       	
	);

	div div0(
		.clk(clk),
		.rst(rst),
	
		.signed_div_i(signed_div),
		.opdata1_i(div_opdata1),
		.opdata2_i(div_opdata2),
		.start_i(div_start),
		.annul_i(flush),
	
		.result_o(div_result),
		.ready_o(div_ready)
	);

	LLbit_reg LLbit_reg0(
		.clk(clk),
		.rst(rst),
	  .flush(flush),
	  
		//Ð´¶Ë¿Ú
		.LLbit_i(wb_LLbit_value_i),
		.we(wb_LLbit_we_i),
	
		//¶Á¶Ë¿Ú1
		.LLbit_o(LLbit_o)
	
	);

	cp0_reg cp0_reg0(
		.clk(clk),
		.rst(rst),
		
		.we_i(wb_cp0_reg_we_i),
		.waddr_i(wb_cp0_reg_write_addr_i),
		.raddr_i(cp0_raddr_i),
		.data_i(wb_cp0_reg_data_i),
		
		.excepttype_i(mem_excepttype_o),
		.int_i(int_i),
		.current_inst_addr_i(mem_current_inst_address_o),
		.is_in_delayslot_i(mem_is_in_delayslot_o),
		
		.data_o(cp0_data_o),
		.count_o(cp0_count),
		.compare_o(cp0_compare),
		.status_o(cp0_status),
		.cause_o(cp0_cause),
		.epc_o(cp0_epc),
		.config_o(cp0_config),
		.prid_o(cp0_prid),
		
		
		.timer_int_o(timer_int_o)  			
	);

///////////////////////////////////////////////////////////////////////////////////
	wishbone_bus_if dwishbone_bus_if(  //·Ã´æwb
		.clk(clk),
		.rst(rst),
	
		//À´×Ô¿ØÖÆÄ£¿éctrl
		.stall_i(stall),
		.flush_i(flush),

	
		//CPU²à¶ÁÐ´²Ù×÷ÐÅÏ¢
		.cpu_ce_i(ram_ce_o),
		.cpu_data_i(ram_data_o),
		.cpu_addr_i(ram_addr_o),
		.cpu_we_i(ram_we_o),
		.cpu_sel_i(ram_sel_o),
		.cpu_data_o(ram_data_i),
	
		//Wishbone×ÜÏß²à½Ó¿Ú
		.wishbone_data_i(dwishbone_data_i),
		.wishbone_ack_i(dwishbone_ack_i),
		.wishbone_addr_o(dwishbone_addr_o),
		.wishbone_data_o(dwishbone_data_o),
		.wishbone_we_o(dwishbone_we_o),
		.wishbone_sel_o(dwishbone_sel_o),
		.wishbone_stb_o(dwishbone_stb_o),
		.wishbone_cyc_o(dwishbone_cyc_o),

		.stallreq(stallreq_from_mem)	       
    );

	wishbone_bus_if iwishbone_bus_if(  //È¡Ö¸wb
		.clk(clk),
		.rst(rst),
	
		//À´×Ô¿ØÖÆÄ£¿éctrl
		.stall_i(stall),
		.flush_i(flush),
	
		//CPU²à¶ÁÐ´²Ù×÷ÐÅÏ¢
		.cpu_ce_i(rom_ce),
		.cpu_data_i(32'h00000000),
		.cpu_addr_i(pc),
		.cpu_we_i(1'b0),
		.cpu_sel_i(4'b1111),
		.cpu_data_o(inst_i),
	
		//Wishbone×ÜÏß²à½Ó¿Ú
		.wishbone_data_i(iwishbone_data_i),
		.wishbone_ack_i(iwishbone_ack_i),
		.wishbone_addr_o(iwishbone_addr_o),
		.wishbone_data_o(iwishbone_data_o),
		.wishbone_we_o(iwishbone_we_o),
		.wishbone_sel_o(iwishbone_sel_o),
		.wishbone_stb_o(iwishbone_stb_o),
		.wishbone_cyc_o(iwishbone_cyc_o),

		.stallreq(stallreq_from_if)	       
    );
	
endmodule