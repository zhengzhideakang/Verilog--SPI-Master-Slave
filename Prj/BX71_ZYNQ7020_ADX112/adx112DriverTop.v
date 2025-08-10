/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-08-07 22:16:19
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-08-09 01:44:27
 * @Filename     : adx112DriverTop.v
 * @Description  : ADX112驱动顶层模块
*/

/*
! 模块功能: ADX112驱动顶层模块
* 思路:
* 1.
~ 注意:
~ 1.
% 其它
*/

`default_nettype none

module adx112DriverTop
(
  // SPI硬线链接
  (* mark_debug *)output wire spi_cs_n, // 片选, 低电平有效
  (* mark_debug *)output wire spi_sclk, // SPI时钟, 主机提供
  (* mark_debug *)output wire spi_mosi, // 主机输出从机输入
  (* mark_debug *)input  wire spi_miso, // 主机输入从机输出

  // FPGA时钟输入
  input  wire fpga_clk // 50MHz
);


//++ 时钟与复位 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire clk;
wire locked;
localparam CLK_FREQ_MHZ = 100;
clk_wiz_0 clk_wiz_0_u0 (
  .clk_out1 (clk     ),
  .locked   (locked  ),
  .clk_in1  (fpga_clk)
);

localparam RSTN_CLK_WIDTH = 3;
reg [RSTN_CLK_WIDTH + 1 : 0] rstn_cnt;
always @(posedge clk) begin // 使用最慢的时钟
  if (locked)
    if (~(&rstn_cnt))
      rstn_cnt <= rstn_cnt + 1'b1;
    else
      rstn_cnt <= rstn_cnt;
  else
    rstn_cnt <= 'd0;
end

/*
  初始为0, locked为高后经过2^RSTN_CLK_WIDTH个clk周期, rstn为1
  再过2^RSTN_CLK_WIDTH个clk周期, rstn为0
  在过2^RSTN_CLK_WIDTH个clk周期后, rstn为1, 后续会保持1
  总的来说, 复位低电平有效持续(2^RSTN_CLK_WIDTH)个clk周期
*/
wire rstn = rstn_cnt[RSTN_CLK_WIDTH];
//-- 时钟与复位 ------------------------------------------------------------


//++ 实例化ADX112驱动模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg  adx112_begin;
(* mark_debug *)wire adx112_is_busy;
(* mark_debug *)wire [15:0] adx112_config_value;
(* mark_debug *)wire [15:0] adx112_dout;
(* mark_debug *)wire adx112_dout_valid;

(* mark_debug *)wire [15:0] adx112_rd_config_value;

adx112Driver # (
  .CLK_FREQ_MHZ(CLK_FREQ_MHZ)
) adx112Driver_inst (
  .adx112_begin           (adx112_begin          ),
  .adx112_is_busy         (adx112_is_busy        ),
  .adx112_config_value    (adx112_config_value   ),
  .adx112_dout            (adx112_dout           ),
  .adx112_dout_valid      (adx112_dout_valid     ),
  .adx112_rd_config_value (adx112_rd_config_value),
  .spi_cs_n               (spi_cs_n              ),
  .spi_sclk               (spi_sclk              ),
  .spi_mosi               (spi_mosi              ),
  .spi_miso               (spi_miso              ),
  .clk                    (clk                   ),
  .rstn                   (rstn                  )
);
//-- 实例化ADX112驱动模块 ------------------------------------------------------------


//++ 配置寄存器设置 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*
* 工作状态或单次转换启动
* 该位决定器件的工作状态。
* 仅在掉电状态下可写入工作状态，在转换进行时写入无效。
* 写入时：
* 0 = 无效果
* 1 = 启动单次转换（在掉电状态下）
* 读取时：
* 0 = 器件当前正在执行转换
* 1 = 器件当前未执行转换（默认）
*/
localparam [0:0] SS = 1'b1; //* 对配置寄存器的设置值只关注写入, 下同

/*
* 输入多路复用器配置
* 这些位配置输入多路复用器。
* 000 = 正输入端为AIN0，负输入端为AIN1（默认）
* 001 = 正输入端为AIN0，负输入端为AIN3
* 010 = 正输入端为AIN1，负输入端为AIN3
* 011 = 正输入端为AIN2，负输入端为AIN3
* 100 = 正输入端为AIN0，负输入端为地
* 101 = 正输入端为AIN1，负输入端为地
* 110 = 正输入端为AIN2，负输入端为地
* 111 = 正输入端为AIN3，负输入端为地
*/
localparam [2:0] MUX = 3'b100;

/*
* 可编程增益放大器配置
* 这些位配置可编程增益放大器。
* 000 = 满量程为±6.144V(1)
* 001 = 满量程为±4.096V(1)
* 010 = 满量程为±2.048V（默认）
* 011 = 满量程为±1.024V
* 100 = 满量程为±0.512V
* 101 = 满量程为±0.256V
* 110 = 满量程为±0.256V
* 111 = 满量程为±0.256V
*/
localparam [2:0] PGA = 3'b001;

/*
* 器件工作模式
* 该位控制ADX112(Q)的工作模式。
* 0 = 连续转换模式
* 1 = 掉电和单次模式（默认）
*/
localparam [0:0] MODE = 1'b1;

/*
* 数据速率
* 这些位控制数据速率设置。
* 000 = 8SPS
* 001 = 16SPS
* 010 = 32SPS
* 011 = 64SPS
* 100 = 128SPS（默认）
* 101 = 250SPS
* 110 = 475SPS
* 111 = 860SPS
*/
localparam [2:0] DR = 3'b100;

/*
* 温度传感器模式
* 该位配置ADC是转换温度信号还是输入信号。
* 0 = ADC模式（默认）
* 1 = 温度传感器模式
*/
localparam [0:0] TS_MODE = 1'b0;

/*
* 上拉使能
* 仅当CS为高电平时，该位使能DOUT/DRDY引脚上的弱内部上拉电阻。
* 使能时，一个内部400kΩ电阻将总线连接到电源；禁用时，DOUT/DRDY引脚浮空。
* 0 = DOUT/DRDY引脚上拉电阻禁用
* 1 = DOUT/DRDY引脚上拉电阻使能（默认）
*/
localparam [0:0] PULL_UP_EN = 1'b1;

/*
* 无操作
* NOP[1:0]位控制是否向配置寄存器写入数据。
* 要向配置寄存器写入数据，NOP[1:0]位必须为“01”；其他任何值都将产生NOP命令。
* 在SCLK脉冲期间，DIN可保持高电平或低电平，且不会有数据写入配置寄存器。
* 00 = 无效数据，不更新配置寄存器内容
* 01 = 有效数据，更新配置寄存器（默认）
* 10 = 无效数据，不更新配置寄存器内容
* 11 = 无效数据，不更新配置寄存器内容
*/
localparam [1:0] NOP = 2'b01;

/*
* 保留位
* 向该位写入0或1均无效果，读取时始终为1
*/
localparam [0:0] RESERVED = 1'b1;

assign adx112_config_value = {
  SS,
  MUX,
  PGA,
  MODE,
  DR,
  TS_MODE,
  PULL_UP_EN,
  NOP,
  RESERVED
};

/*
* 如果不设置仅读取配置寄存器则会读到其默认值 = 16'h858B
* 手册里写的是058B, 经分析是错误的, 最高位SS应读到1, 表示器件当前未执行转换（默认）
*/
// assign adx112_config_value = 'd0;
//-- 配置寄存器设置 ------------------------------------------------------------


//++ ADX112控制 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam ADX112_BEGIN_DELAY_CNT_MAX = CLK_FREQ_MHZ * 1000 * 1000 / 128;
reg [$clog2(ADX112_BEGIN_DELAY_CNT_MAX+1)-1 : 0] adx112_begin_delay_cnt;
always @(posedge clk) begin
  if (~rstn)
    adx112_begin_delay_cnt <= 'd0;
  else if (adx112_begin_delay_cnt < ADX112_BEGIN_DELAY_CNT_MAX)
    adx112_begin_delay_cnt <= adx112_begin_delay_cnt + 1'b1;
  else
    adx112_begin_delay_cnt <= 'd0;
end

always @(posedge clk) begin
  if (~rstn)
    adx112_begin <= 1'b0;
  else if (~adx112_is_busy && adx112_begin_delay_cnt == ADX112_BEGIN_DELAY_CNT_MAX)
    adx112_begin <= 1'b1;
  else
    adx112_begin <= 1'b0;
end
//-- ADX112控制 ------------------------------------------------------------


endmodule
`resetall