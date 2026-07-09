`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Looper
// Module Name:    looper1_1.v 
// Project Name: Looper Project
// Target Devices: Nexys4 DDR
// Tool versions: Vivado 2015.1
// Description: This project turns your Nexys4 DDR into a guitar/piano/aux input looper. Plug input into XADC3
//
// Dependencies: 
//
//  0.01 - File Created
//  1.0 - Finished with 8 external buttons on JC, 4 memory banks
//  1.1 - Changed addressing, bug fixes
//  1.2 - Moved to different control scheme using 4 onboard buttons, banks doubled to 8 banks, 3 minutes each
//
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`include"defines.v"

//////////////////////////////////////////////////////////////////////
// Module:  DDR2
// Description: DDR2 SDRAM 控制器 — Wishbone 从设备接口
//             将 Wishbone 总线读写转换为 DDR2 内存访问
//             内部状态机: IDLE → START → WRITE/READ → ENDING
//               - IDLE:  等待 Wishbone 周期 (cyc & stb)
//               - START: 锁存地址和读写方向
//               - WRITE: 写操作 (等待 ~80 周期完成)
//               - READ:  读操作 (等待 ~80 周期完成)
//               - ENDING: 事务结束，发送 ack
//             依赖 Ram2Ddr 模块进行底层 DDR2 PHY 控制
//             复位后需等待 init_calib_complete 校准完成
//////////////////////////////////////////////////////////////////////

module DDR2(
    input wire wb_clk_i,
    input wire clk_200MHz_i,
    input wire wb_rst_i,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    input wire [3:0] wb_sel_i,
    input wire [26:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    output reg        wb_ack_o,
    output reg init_calib_complete,
    
    //memory signals
    output   [12:0] ddr2_addr,
    output   [2:0] ddr2_ba,
    output   ddr2_ras_n,
    output   ddr2_cas_n,
    output   ddr2_we_n,
    output   ddr2_ck_p,
    output   ddr2_ck_n,
    output   ddr2_cke,
    output   ddr2_cs_n,
    output   [1:0] ddr2_dm,
    output   ddr2_odt,
    inout    [15:0] ddr2_dq,
    inout    [1:0] ddr2_dqs_p,
    inout    [1:0] ddr2_dqs_n
);


   
    parameter tenhz = 10000000;
    
    // Max_block = 64,000,000 / 8 = 8,000,000 or 0111 1010 0001 0010 0000 0000
    // 22:0
    //8 banks
    
    
    reg [22:0] max_block=0;
    reg [26:0] timercnt=0;
    reg [11:0] timerval=0;
        
    wire set_max;
    wire reset_max;
    wire p;//Bank is playing
    wire r;//Bank is recording
    (* Mark_debug = "TRUE" *)reg p_r;
    (* Mark_debug = "TRUE" *)reg r_r;
    wire del_mem;//Clear delete flag
    wire delete;//Delete flag
    wire [2:0] delete_bank;//Bank to delete
    wire [2:0] mem_bank;//Bank
    wire write_zero;//Used when deleting
    wire [22:0]current_block;//Block address
    wire [3:0] buttons_db;//Debounced buttons
    wire [7:0] active;//Bank is recorded on
    
    wire [2:0] current_bank;
    
    wire [26:0] mem_a_w;   
    reg  [26:0] mem_a;
    assign mem_a_w=mem_a;

    //So address cycles through 0 - 1 - 2 - 3 - 4 - 5 - 6 - 7, then current block is inremented by 1 and mem_bank goes back to 0: mem_a = 8
    reg [31:0] mem_dq_i;
    wire [31:0] mem_dq_i_w;
    assign mem_dq_i_w=mem_dq_i;
    wire [31:0] mem_dq_o;

    reg mem_cen;
    reg mem_oen;
    reg mem_wen;
    wire mem_cen_w;
    wire mem_oen_w;
    wire mem_wen_w;
    assign mem_cen_w=mem_cen;
    assign mem_oen_w=mem_oen;
    assign mem_wen_w=mem_wen;
    
    
    wire mem_ub;
    wire mem_lb;
    wire [3:0]mem_sel;
    assign mem_ub = 0;
    assign mem_lb = 0;
    assign mem_sel= ~wb_sel_i;
    
    wire [15:0] chipTemp;

    wire data_flag;

    wire data_ready;
    
    wire mix_data;
    wire [22:0] block44KHz;
    
// clk_wiz_0 moved to top-level (openmips_min_sopc.v); clk_200MHz_i comes from port

////////////////////////////////////////////////////////////////////////////////////////////////////////
////    Memory instantiation
//////////////////////////////////////////////////////////////////////////////////////////////////////// 
    //sel 0 ???? 1 ????
    //????32??????
    wire init_calib_complete_w;
    Ram2Ddr Ram(
        .clk_200MHz_i          (clk_200MHz_i),
        .rst_i                 (wb_rst_i),
        .device_temp_i         (chipTemp[11:0]),
        .init_calib_complete_o (init_calib_complete_w),
        // RAM interface
        .ram_a                 (mem_a_w),
        .ram_dq_i              (mem_dq_i_w),
        .ram_dq_o              (mem_dq_o),
        .ram_cen               (mem_cen_w),
        .ram_oen               (mem_oen_w),
        .ram_wen               (mem_wen_w),
        .ram_ub                (mem_ub),
        .ram_lb                (mem_lb),
        .ram_sel               (mem_sel),
        // DDR2 interface
        .ddr2_addr             (ddr2_addr),
        .ddr2_ba               (ddr2_ba),
        .ddr2_ras_n            (ddr2_ras_n),
        .ddr2_cas_n            (ddr2_cas_n),
        .ddr2_we_n             (ddr2_we_n),
        .ddr2_ck_p             (ddr2_ck_p),
        .ddr2_ck_n             (ddr2_ck_n),
        .ddr2_cke              (ddr2_cke),
        .ddr2_cs_n             (ddr2_cs_n),
        .ddr2_dm               (ddr2_dm),
        .ddr2_odt              (ddr2_odt),
        .ddr2_dq               (ddr2_dq),
        .ddr2_dqs_p            (ddr2_dqs_p),
        .ddr2_dqs_n            (ddr2_dqs_n)
    );
          


////////////////////////////////////////////////////////////////////////////////////////////////////////
////    Data in latch
//////////////////////////////////////////////////////////////////////////////////////////////////////// 
  
 
                             
    //Data in is assigned the latched data input from sound_data, or .5V (16'h7444) if write zero is on      



    //----------------------------wishbone -------------------------------------
    parameter IDLE = 5'd0;
    parameter START = 5'd1;
    parameter WRITE = 5'd2;
    parameter READ = 5'd3;
    parameter WAIT = 5'd4;
    parameter ENDING = 5'd5;

    reg [4:0] state;
    reg [4:0] next_state;
    reg [15:0] wait_count;
    // change state 
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
       if(wb_rst_i)begin
           state<=IDLE;
           wb_ack_o<=1'b0;
           init_calib_complete<=1'b0;
       end
       else begin
           init_calib_complete<=init_calib_complete_w;
           if(wb_cyc_i&wb_stb_i)begin
               state<=next_state;
               if(state==ENDING&&!wb_ack_o)begin
                   wb_ack_o<=1'b1;
               end
           end
           else begin
               state<=IDLE;
               wb_ack_o<=1'b0;
           end
       end
    end

    //set sign by state 
    always@(posedge wb_clk_i or posedge wb_rst_i)begin
        if(wb_rst_i)begin
            next_state<=IDLE;
            mem_cen<=1'b1;
            mem_oen<=1'b1;
            mem_wen<=1'b1;
        end
        else begin
            case(state)
            IDLE:
            begin
                mem_cen<=1'b1;
                mem_oen<=1'b1;
                mem_wen<=1'b1;
                wait_count<=16'b0;
                next_state<=START;
            end
            START:
            begin
                mem_a<=wb_adr_i;
                if(wb_we_i)
                begin
                    next_state<=WRITE;
                end
                else 
                begin
                    next_state<=READ;
                end
            end 
            WRITE:
            begin
                mem_cen<=1'b0;
                mem_oen<=1'b1;
                mem_wen<=1'b0;
                mem_a<=wb_adr_i;
                mem_dq_i<=wb_dat_i;
                wait_count<=wait_count+16'd1;
                if(wait_count>=16'd80)
                begin
                    mem_cen<=1'b1;
                    mem_oen<=1'b1;
                    mem_wen<=1'b1;
                    next_state<=ENDING;
                end
            end
            READ:
            begin
                mem_cen<=1'b0;
                mem_oen<=1'b0;
                mem_wen<=1'b1;
                mem_a<=wb_adr_i;
                wait_count<=wait_count+16'd1;
                if(wait_count>=16'd80)
                begin
                    mem_cen<=1'b1;
                    mem_oen<=1'b1;
                    mem_wen<=1'b1;
                    wb_dat_o<=mem_dq_o;
                    next_state<=ENDING;
                end
            end
            ENDING:
            begin
            end

            endcase
        end 

    end




    //---------------------------------------------------------------------------------
    
endmodule