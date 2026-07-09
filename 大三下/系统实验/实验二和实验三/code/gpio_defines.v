//////////////////////////////////////////////////////////////////////
// File:    gpio_defines.v
// Description: GPIO IP 核参数定义 — 基于 OpenCores GPIO 项目
//             主要参数:
//               - GPIO_IOS: GPIO I/O 信号数量 (默认 32)
//               - 寄存器地址定义 (RGPIO_IN/OUT/OE/INTE/PTRIG/CTRL/INTS)
//               - 同步策略定义 (GPIO_SYNC_IN_WB, GPIO_SYNC_CLK_WB)
//               - Wishbone 地址解码选项
//////////////////////////////////////////////////////////////////////

//
// Number of GPIO I/O signals
//
// This is the most important parameter of the GPIO IP core. It defines how many
// I/O signals core has. Range is from 1 to 32. If more than 32 I/O signals are
// required, use several instances of GPIO IP core.
//
// Default is 16.
//
`define GPIO_IOS 32    // GPIO I/O 信号数量：定义GPIO核的I/O引脚总数，范围1~32，默认16，此处设为32

//depending on number of GPIO_IOS, define this...
// for example: if there is 26 GPIO_IOS, define GPIO_LINES26
//

`define GPIO_LINES 32   // GPIO 线数量：与GPIO_IOS保持一致，用于标识已实现GPIO线数(如GPIO_LINES32)

//
// Undefine this one if you don't want to remove GPIO block from your design
// but you also don't need it. When it is undefined, all GPIO ports still
// remain valid and the core can be synthesized however internally there is
// no GPIO funationality.
//
// Defined by default (duhh !).
//
`define GPIO_IMPLEMENTED             // 使能GPIO功能：定义后GPIO核具备完整GPIO功能，取消定义则仅保留端口但无内部逻辑

//
// Define to register all WISHBONE outputs.
//
// Register outputs if you are using GPIO core as a block and synthesizing
// and place&routing it separately from the rest of the system.
//
// If you do not need registered outputs, you can save some area by not defining
// this macro. By default it is defined.
//
`define GPIO_REGISTERED_WB_OUTPUTS    // 寄存WISHBONE输出：将所有WISHBONE总线输出信号经过寄存器打拍，适用于IP核独立综合与布局布线

//
// Define to register all GPIO pad outputs.
//
// Register outputs if you are using GPIO core as a block and synthesizing
// and place&routing it separately from the rest of the system.
//
// If you do not need registered outputs, you can save some area by not defining
// this macro. By default it is defined.
//
`define GPIO_REGISTERED_IO_OUTPUTS    // 寄存GPIO焊盘输出：将所有GPIO焊盘输出信号经过寄存器打拍，适用于IP核独立综合与布局布线

//
// Implement aux feature. If this define is not defined also aux_i port and 
// RGPIO_AUX register will be removed
//
// Defined by default.
//
//`define GPIO_AUX_IMPLEMENT           // [可选] 实现AUX辅助寄存器：定义后包含aux_i端口和RGPIO_AUX寄存器(地址0x14)，此处注释即禁用

//
// If this is not defined clk_pad_i will be removed. Input lines will be lached on 
// positive edge of system clock
// if disabled defines GPIO_NO_NEGEDGE_FLOPS, GPIO_NO_CLKPAD_LOGIC will have no effect.
//
// Defined by default.
//
//`define GPIO_CLKPAD                  // [可选] 外部时钟焊盘：定义后包含clk_pad_i端口，输入线在系统时钟上升沿锁存；禁用则GPIO_NO_NEGEDGE_FLOPS和GPIO_NO_CLKPAD_LOGIC无效

//
// Define to avoid using negative edge clock flip-flops for external clock
// (caused by NEC register. Instead an inverted external clock with
// positive edge clock flip-flops will be used.
// This define don't have any effect if GPIO_CLKPAD is not defined and if GPIO_SYNC_IN_CLK is defined
//
// By default it is not defined.
//
//`define GPIO_NO_NEGEDGE_FLOPS        // [可选] 避免负沿触发器：定义后用反相时钟+正沿触发器替代NEC寄存器所需的负沿触发器，仅在GPIO_CLKPAD定义且GPIO_SYNC_IN_CLK未定义时生效

//
// If GPIO_NO_NEGEDGE_FLOPS is defined, a mux needs to be placed on external clock
// clk_pad_i to implement RGPIO_CTRL[NEC] functionality. If no mux is allowed on
// clock signal, enable the following define.
// This define don't have any effect if GPIO_CLKPAD is not defined and if GPIO_SYNC_IN_CLK is defined
//
// By default it is not defined.
//
//`define GPIO_NO_CLKPAD_LOGIC        // [可选] 避免时钟路径上的MUX：定义后不使用MUX选择外部时钟极性(需配合GPIO_NO_NEGEDGE_FLOPS)，仅在GPIO_CLKPAD定义且GPIO_SYNC_IN_CLK未定义时生效


//
// synchronization defines
//
// Two synchronization flops to input lineis added.
// system clock synchronization.
//
`define GPIO_SYNC_IN_WB               // 同步策略：输入线添加两级同步触发器，以WISHBONE系统时钟(wb_clk_i)同步，防止亚稳态

//
// Add synchronization flops to external clock input line. Gpio will have just one clock domain, 
// everithing will be synchronized to wishbone clock. External clock muas be at least 2-3x slower 
// as systam clock.
//
`define GPIO_SYNC_CLK_WB              // 同步策略：外部时钟输入线添加同步触发器，整个GPIO统一到WISHBONE时钟域；要求外部时钟频率≤系统时钟的1/2~1/3

//
// Add synchronization to input pads. synchronization to external clock.
// Don't hawe any effect if GPIO_SYNC_CLK_WB is defined.
//
//`define GPIO_SYNC_IN_CLK             // [可选] 同步策略：输入焊盘同步到外部时钟域(clk_pad_i)，仅在GPIO_SYNC_CLK_WB未定义时有效，此处注释即禁用

//
// Add synchronization flops between system clock and external clock.
// Only possible if external clock is enabled and clock synchroization is disabled.
//
//`define GPIO_SYNC_IN_CLK_WB          // [可选] 同步策略：在系统时钟与外部时钟之间添加同步触发器，仅在外部时钟使能且GPIO_SYNC_CLK_WB禁用时可行，此处注释即禁用



// 
// Undefine if you don't need to read GPIO registers except for RGPIO_IN register.
// When it is undefined all reads of GPIO registers return RGPIO_IN register. This
// is usually useful if you want really small area (for example when implemented in
// FPGA).
//
// To follow GPIO IP core specification document this one must be defined. Also to
// successfully run the test bench it must be defined. By default it is defined.
//
`define GPIO_READREGS                 // 使能读取所有寄存器：定义后可读除RGPIO_IN外的所有GPIO寄存器；取消定义则所有读操作均返回RGPIO_IN(节省面积)

//
// Full WISHBONE address decoding
//
// It is is undefined, partial WISHBONE address decoding is performed.
// Undefine it if you need to save some area.
//
// By default it is defined.
//
`define GPIO_FULL_DECODE               // 全地址解码：定义后对WISHBONE地址进行完整解码；取消定义则使用部分解码(可节省面积)

//
// Strict 32-bit WISHBONE access
//
// If this one is defined, all WISHBONE accesses must be 32-bit. If it is
// not defined, err_o is asserted whenever 8- or 16-bit access is made.
// Undefine it if you need to save some area.
//
// By default it is defined.
//
//`define GPIO_STRICT_32BIT_ACCESS      // [可选] 严格32位访问：定义后所有WISHBONE访问必须32位宽；取消定义时允许8/16位访问但会触发err_o，此处注释即禁用
//
`ifdef GPIO_STRICT_32BIT_ACCESS       // 若启用严格32位访问，则无需定义字节宽度宏
`else
// added by gorand :
// if GPIO_STRICT_32BIT_ACCESS is not defined,
// depending on number of gpio I/O lines, the following are defined :
// if the number of I/O lines is in range 1-8,   GPIO_WB_BYTES1 is defined,
// if the number of I/O lines is in range 9-16,  GPIO_WB_BYTES2 is defined,
// if the number of I/O lines is in range 17-24, GPIO_WB_BYTES3 is defined,
// if the number of I/O lines is in range 25-32, GPIO_WB_BYTES4 is defined,
// GPIO_WB_BYTESx 表示允许的WISHBONE字节访问宽度：BYTES1(8位)、BYTES2(16位)、BYTES3(24位)、BYTES4(32位)

`define GPIO_WB_BYTES4                // 32位字节访问使能(对应25~32根I/O线)
//`define GPIO_WB_BYTES3              // [可选] 24位字节访问使能(对应17~24根I/O线)，此处注释即禁用
//`define GPIO_WB_BYTES2              // [可选] 16位字节访问使能(对应9~16根I/O线)，此处注释即禁用
//`define GPIO_WB_BYTES1              // [可选] 8位字节访问使能(对应1~8根I/O线)，此处注释即禁用

`endif

//
// WISHBONE address bits used for full decoding of GPIO registers.
//
// WISHBONE地址解码位定义：用于全地址解码时提取寄存器地址
`define GPIO_ADDRHH 7                 // 地址高位(最高)，用于全解码的最高地址位
`define GPIO_ADDRHL 6                 // 地址高位(次高)，用于全解码的次高地址位
`define GPIO_ADDRLH 1                 // 地址低位(次低)，用于全解码的次低地址位
`define GPIO_ADDRLL 0                 // 地址低位(最低)，用于全解码的最低地址位

//
// Bits of WISHBONE address used for partial decoding of GPIO registers.
//
// Default 5:2.
//
// 部分地址解码位范围：使用位[5:2]进行部分解码(默认)，即GPIO_ADDRHL-1=5, GPIO_ADDRLH+1=2
`define GPIO_OFS_BITS	`GPIO_ADDRHL-1:`GPIO_ADDRLH+1

//
// Addresses of GPIO registers
//
// To comply with GPIO IP core specification document they must go from
// address 0 to address 0x18 in the following order: RGPIO_IN, RGPIO_OUT,
// RGPIO_OE, RGPIO_INTE, RGPIO_PTRIG, RGPIO_AUX and RGPIO_CTRL
//
// If particular register is not needed, it's address definition can be omitted
// and the register will not be implemented. Instead a fixed default value will
// be used.
//
// --- GPIO寄存器地址定义(4位内部地址，对应字节地址左移2位) ---
`define GPIO_RGPIO_IN		  4'h0	// RGPIO_IN   (0x00): 输入数据寄存器 — 读取GPIO引脚当前电平状态
`define GPIO_RGPIO_OUT		4'h1	// RGPIO_OUT  (0x04): 输出数据寄存器 — 设置GPIO引脚输出电平
`define GPIO_RGPIO_OE		  4'h2	// RGPIO_OE   (0x08): 输出使能寄存器 — 控制每个GPIO引脚方向(1=输出,0=输入)
`define GPIO_RGPIO_INTE		4'h3	// RGPIO_INTE (0x0c): 中断使能寄存器 — 控制每个GPIO引脚的中断使能
`define GPIO_RGPIO_PTRIG	4'h4	// RGPIO_PTRIG (0x10): 边沿触发寄存器 — 配置中断触发方式(电平/边沿)

`ifdef GPIO_AUX_IMPLEMENT
`define GPIO_RGPIO_AUX		4'h5	// RGPIO_AUX  (0x14): 辅助功能寄存器 — 额外的GPIO控制功能(条件编译，当前禁用)
`endif // GPIO_AUX_IMPLEMENT

`define GPIO_RGPIO_CTRL		4'h6	// RGPIO_CTRL  (0x18): 控制寄存器 — 全局中断使能(INTE)和中断状态(INTS)
`define GPIO_RGPIO_INTS		4'h7	// RGPIO_INTS  (0x1c): 中断状态寄存器 — 读取各引脚中断挂起状态

`ifdef GPIO_CLKPAD
`define GPIO_RGPIO_ECLK   4'h8  // RGPIO_ECLK  (0x20): 外部时钟寄存器 — 与外部时钟clk_pad_i相关的配置(条件编译，当前禁用)
`define GPIO_RGPIO_NEC    4'h9  // RGPIO_NEC   (0x24): 负沿时钟使能寄存器 — 控制外部时钟负沿触发(条件编译，当前禁用)
`endif //  GPIO_CLKPAD

//
// Default values for unimplemented GPIO registers
//
// --- 未实现寄存器的默认值：当某寄存器因条件编译被移除时，使用对应的默认全0值 ---
`define GPIO_DEF_RGPIO_IN	`GPIO_IOS'h0   // RGPIO_IN 默认值：32'h0000_0000
`define GPIO_DEF_RGPIO_OUT	`GPIO_IOS'h0   // RGPIO_OUT 默认值：32'h0000_0000
`define GPIO_DEF_RGPIO_OE	`GPIO_IOS'h0   // RGPIO_OE 默认值：32'h0000_0000 (全部为输入)
`define GPIO_DEF_RGPIO_INTE	`GPIO_IOS'h0   // RGPIO_INTE 默认值：32'h0000_0000 (全部中断禁用)
`define GPIO_DEF_RGPIO_PTRIG	`GPIO_IOS'h0   // RGPIO_PTRIG 默认值：32'h0000_0000 (电平触发)
`define GPIO_DEF_RGPIO_AUX	`GPIO_IOS'h0   // RGPIO_AUX 默认值：32'h0000_0000
`define GPIO_DEF_RGPIO_CTRL	`GPIO_IOS'h0   // RGPIO_CTRL 默认值：32'h0000_0000 (全局中断禁用)
`define GPIO_DEF_RGPIO_ECLK `GPIO_IOS'h0   // RGPIO_ECLK 默认值：32'h0000_0000
`define GPIO_DEF_RGPIO_NEC `GPIO_IOS'h0    // RGPIO_NEC 默认值：32'h0000_0000


//
// RGPIO_CTRL bits
//
// To comply with the GPIO IP core specification document they must go from
// bit 0 to bit 1 in the following order: INTE, INT
//
// --- RGPIO_CTRL控制寄存器的位定义 ---
`define GPIO_RGPIO_CTRL_INTE		0  // INTE (bit 0): 全局中断使能位 — 1=允许GPIO产生中断，0=禁止所有GPIO中断
`define GPIO_RGPIO_CTRL_INTS		1  // INTS (bit 1): 全局中断状态位 — 1=有GPIO中断挂起(读清0)，反映各引脚中断的或结果


