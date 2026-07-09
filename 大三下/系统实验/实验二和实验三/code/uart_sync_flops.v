//////////////////////////////////////////////////////////////////////
// File:    uart_sync_flops.v
// Description: UART 同步触发器 — 参数化宽度、两级同步
//             用于异步输入信号 (如串口 RX) 到系统时钟域的同步
//             第一级: 采样异步输入
//             第二级: 同步输出，支持同步复位 (stage1_rst_i) 和门控 (stage1_clk_en_i)
//             参数: width (位宽), init_value (初始值)
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  uart_sync_flops.v                                             ////
////                                                              ////
////                                                              ////
////  This file is part of the "UART 16550 compatible" project    ////
////  http://www.opencores.org/cores/uart16550/                   ////
////                                                              ////
////  Documentation related to this project:                      ////
////  - http://www.opencores.org/cores/uart16550/                 ////
////                                                              ////
////  Projects compatibility:                                     ////
////  - WISHBONE                                                  ////
////  RS232 Protocol                                              ////
////  16550D uart (mostly supported)                              ////
////                                                              ////
////  Overview (main Features):                                   ////
////  UART core receiver logic                                    ////
////                                                              ////
////  Known problems (limits):                                    ////
////  None known                                                  ////
////                                                              ////
////  To Do:                                                      ////
////  Thourough testing.                                          ////
////                                                              ////
////                                                              ////
////  Created:        2004/05/20                                  ////
////  Last Updated:   2004/05/20                                  ////
////                                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
//
// $Log: not supported by cvs2svn $
//


`include "timescale.v"


module uart_sync_flops
(
  // internal signals
  rst_i,
  clk_i,
  stage1_rst_i,
  stage1_clk_en_i,
  async_dat_i,
  sync_dat_o
);

parameter Tp            = 1;        // 传播延时参数 (Propagation delay) — 仿真中模拟门级延时，综合时被忽略
parameter width         = 1;        // 同步器位宽 — 参数化以支持多bit信号的同步
parameter init_value    = 1'b0;     // 复位初始值 — 异步复位时两级触发器均被设置为此值

input                           rst_i;                  // 异步复位输入 (高有效) — 复位后两级触发器均回到init_value
input                           clk_i;                  // 系统时钟输入 — 驱动两级同步触发器
input                           stage1_rst_i;           // 第一级同步复位 (高有效) — 在时钟沿将第二级触发器复位到init_value
input                           stage1_clk_en_i;        // 第一级时钟使能 (高有效) — 为高时第二级触发器采样flop_0; 为低时保持
input   [width-1:0]             async_dat_i;            // 异步数据输入 — 来自异步时钟域的信号 (例如UART RX引脚)
output  [width-1:0]             sync_dat_o;             // 同步数据输出 — 已同步到clk_i时钟域的信号，可直接用于后续逻辑



//
// 内部信号声明
// flop_0: 第一级触发器输出 — 直接采样异步输入，此时可能处于亚稳态
// sync_dat_o: 第二级触发器输出 — 经两级同步后的稳定信号
//

reg     [width-1:0]             sync_dat_o; // 同步后的输出寄存器 — 连接到模块输出端口
reg     [width-1:0]             flop_0;     // 第一级触发器寄存器 — 捕获异步输入信号


// ============================================================
// 第一级同步触发器 (first stage synchronizer)
// 触发条件: clk_i上升沿 或 rst_i上升沿
// 功能: 在时钟沿采样异步输入信号 async_dat_i
// 复位: rst_i为高时将flop_0复位为 init_value (默认为1'b0)
// 注意: 此级输出flop_0可能仍处于亚稳态，需第二级进一步稳定
// ============================================================
begin
    if (rst_i)
        flop_0 <= #Tp {width{init_value}};  // 异步复位: 所有位设置为init_value
    else
        flop_0 <= #Tp async_dat_i;          // 采样异步输入 (此输出可能为亚稳态)
end

// ============================================================
// 第二级同步触发器 (second stage synchronizer)
// 触发条件: clk_i上升沿 或 rst_i上升沿
// 功能: 对flop_0再次采样，消除第一级可能存在的亚稳态
// 复位优先级: rst_i (异步复位) > stage1_rst_i (同步复位) > stage1_clk_en_i (使能采样)
// 原理: 标准两级同步器 (2-FF synchronizer)
//       异步信号经过两级触发器后，亚稳态发生概率极低，
//       MTBF (Mean Time Between Failures) 可达数年至数十年量级
// ============================================================
begin
    if (rst_i)
        sync_dat_o <= #Tp {width{init_value}};       // 异步复位: 输出初始值init_value
    else if (stage1_rst_i)
        sync_dat_o <= #Tp {width{init_value}};       // 同步复位: 在时钟沿将输出复位到init_value
    else if (stage1_clk_en_i)
        sync_dat_o <= #Tp flop_0;                    // 使能有效: 采样第一级输出flop_0
end

endmodule
