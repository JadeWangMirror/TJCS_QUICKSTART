/*********************************************************************

  This file is part of the sdram controller project
  http://www.opencores.org/cores/sdr_ctrl/

  Description: SYNC FIFO
  Parameters:
      W : Width (integer)
      D : Depth (integer, power of 2, 4 to 256)

  To Do:
    nothing



 This source file may be used and distributed without
 restriction provided that this copyright statement is not
 removed from the file and that any derivative work contains
 the original copyright notice and the associated disclaimer.

 This source file is free software; you can redistribute it
 and/or modify it under the terms of the GNU Lesser General
 Public License as published by the Free Software Foundation;
 either version 2.1 of the License, or (at your option) any
later version.

 This source is distributed in the hope that it will be
 useful, but WITHOUT ANY WARRANTY; without even the implied
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.  See the GNU Lesser General Public License for more
 details.

 You should have received a copy of the GNU Lesser General
 Public License along with this source; if not, download it
 from http://www.opencores.org/lgpl.shtml

*******************************************************************/

// 模块名：sync_fifo — 同步FIFO（先入先出队列）
module sync_fifo (clk,         // 时钟输入
	          reset_n,         // 异步复位，低有效
		  wr_en,            // 写使能，高有效
		  wr_data,          // 写数据总线
		  full,             // 满标志输出
		  empty,            // 空标志输出
		  rd_en,            // 读使能，高有效
		  rd_data);         // 读数据总线

   parameter W = 8;            // 数据宽度参数，默认8位
   parameter D = 4;            // FIFO深度参数，默认4（必须为4~256中2的幂）

   // 根据深度D自动计算地址位宽AW
   parameter AW = (D == 4)   ? 2 :
		  (D == 8)   ? 3 :
		  (D == 16)  ? 4 :
		  (D == 32)  ? 5 :
		  (D == 64)  ? 6 :
		  (D == 128) ? 7 :
		  (D == 256) ? 8 : 0;

   output [W-1 : 0]  rd_data;  // 读数据输出端口
   input [W-1 : 0]   wr_data;  // 写数据输入端口
   input 	     clk, reset_n, wr_en, rd_en;  // 控制信号输入
   output 	     full, empty;  // 状态标志输出

   // synopsys translate_off   （综合工具忽略以下仿真代码）

   initial begin               // 仿真初始化块
      if (AW == 0) begin       // 若地址位宽为0，说明深度参数无效
	 $display ("%m : ERROR!!! Fifo depth %d not in range 4 to 256", D);  // 打印错误信息
      end // if (AW == 0)
   end // initial begin

   // synopsys translate_on    （综合工具恢复综合以下代码）


   reg [W-1 : 0]    mem[D-1 : 0];   // FIFO存储阵列，深度D、宽度W
   reg [AW-1 : 0]   rd_ptr, wr_ptr; // 读指针和写指针寄存器
   reg	 	    full, empty;     // 满标志和空标志寄存器

   wire [W-1 : 0]   rd_data;  // 读数据声明为wire（连续赋值驱动）

   // 写指针更新逻辑
   always @ (posedge clk or negedge reset_n)
      if (reset_n == 1'b0) begin         // 异步复位：复位信号为低
         wr_ptr <= {AW{1'b0}} ;          // 写指针清零
      end
      else begin                          // 正常工作状态
         if (wr_en & !full) begin         // 写使能有效且FIFO未满
            wr_ptr <= wr_ptr + 1'b1 ;     // 写指针加1
         end
      end

   // 读指针更新逻辑
   always @ (posedge clk or negedge reset_n)
      if (reset_n == 1'b0) begin         // 异步复位：复位信号为低
         rd_ptr <= {AW{1'b0}} ;          // 读指针清零
      end
      else begin                          // 正常工作状态
         if (rd_en & !empty) begin        // 读使能有效且FIFO非空
            rd_ptr <= rd_ptr + 1'b1 ;     // 读指针加1
         end
      end

   // 空标志更新逻辑
   always @ (posedge clk or negedge reset_n)
      if (reset_n == 1'b0) begin         // 异步复位时
         empty <= 1'b1 ;                 // 空标志置为1（FIFO初始为空）
      end
      else begin                          // 正常工作状态
         // 若写指针-读指针==1，且正在读、未在写，则变空
         // 若写指针==读指针，且正在写、未在读，则变非空
         // 否则保持原值
         empty <= (((wr_ptr - rd_ptr) == {{(AW-1){1'b0}}, 1'b1}) & rd_en & ~wr_en) ? 1'b1 :
                   ((wr_ptr == rd_ptr) & ~rd_en & wr_en) ? 1'b0 : empty ;
      end

   // 满标志更新逻辑
   always @ (posedge clk or negedge reset_n)
      if (reset_n == 1'b0) begin         // 异步复位时
         full <= 1'b0 ;                  // 满标志清零（FIFO初始非满）
      end
      else begin                          // 正常工作状态
         // 若写指针-读指针==容量-1，且正在写、未在读，则变满
         // 若写指针-读指针==容量，且正在读、未在写，则变非满
         // 否则保持原值
         full <= (((wr_ptr - rd_ptr) == {{(AW-1){1'b1}}, 1'b0}) & ~rd_en & wr_en) ? 1'b1 :
                 (((wr_ptr - rd_ptr) == {AW{1'b1}}) & rd_en & ~wr_en) ? 1'b0 : full ;
      end

   // 写数据到FIFO存储阵列
   always @ (posedge clk)
      if (wr_en)                // 写使能有效时
	 mem[wr_ptr] <= wr_data; // 将写数据存入写指针对应的存储单元

assign  rd_data = mem[rd_ptr];  // 异步读：将读指针对应的存储数据输出


// synopsys translate_off       （综合工具忽略以下仿真代码）
   // 写溢出检测：写使能有效且FIFO已满时报错
   always @(posedge clk) begin
      if (wr_en && full) begin
         $display("%m : Error! sfifo overflow!");
      end
   end

   // 读下溢检测：读使能有效且FIFO已空时报错
   always @(posedge clk) begin
      if (rd_en && empty) begin
         $display("%m : error! sfifo underflow!");
      end
   end

// synopsys translate_on        （综合工具恢复综合以下代码）
//---------------------------------------

endmodule  // 模块定义结束
