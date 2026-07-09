//////////////////////////////////////////////////////////////////////
// File:    wb_conmax_defines.v
// Description: Wishbone ConMax 互联矩阵参数定义
//             基于 OpenCores wb_conmax 项目
//             本项目中配置: 8 主设备 × 16 从设备
//             主设备 0: CPU 数据访存 (dwishbone)
//             主设备 1: CPU 指令取指 (iwishbone)
//             从设备 0: DDR2 SDRAM
//             从设备 1: UART 串口
//             从设备 2: GPIO
//             从设备 3: Flash ROM
//////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE Connection Matrix Definitions                     ////
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
//
//

// ---------------------------------------------------------------------
// 本文件是 Wishbone ConMax 互联矩阵的参数/配置包含文件 (include file)
// 作用: 集中定义所有 wb_conmax 模块共用的编译参数和时序单位
// 该文件通过 `include 指令被 wb_conmax_top.v、wb_arb.v、wb_pri_arb.v
// 以及 wb_mux.v 等模块包含，确保整个设计使用统一的时序精度
// ---------------------------------------------------------------------
// `timescale 指令: 设置仿真时间单位为 1ns，时间精度为 1ps
// 时间单位 (1ns): 仿真器中所有延时值 (#delay) 的默认单位，例如 #5 表示 5ns
// 时间精度 (1ps): 仿真器记录事件的最小时间步长，用于处理非整数延时
// 所有包含本文件的模块都将继承此时序设置，保证仿真结果的一致性
// ---------------------------------------------------------------------

`timescale 1ns / 1ps

