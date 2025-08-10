/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-06-27 14:56:50
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-07-02 00:36:52
 * @Filename     : mySPI_4Wire_LoopBack_tb.sv
 * @Description  : SPI主机和从机回环测试仿真
*/

/*
! 模块功能: SPI主机和从机回环测试仿真
* 思路:
  1.
*/

module mySPI_4Wire_LoopBack_tb();

//++ 仿真时间尺度 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
timeunit 1ns;
timeprecision 1ps;
//-- 仿真时间尺度 ------------------------------------------------------------


//++ 被测模块实例化 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam integer SPI_MODE                     = 3;   // SPI模式, 可选0, 1, 2, 3 (默认)
localparam integer DATA_WIDTH                   = 16;  // 单次通信发送或接收数据的位宽, 最小为2, 常见8/16
localparam integer SCLK_PERIOD_CLK_NUM          = 4;  // fSCLK, SCLK周期对应CLK数, 必须为偶数, 最小为2
localparam integer CS_EDGE_TO_SCLK_EDGE_CLK_NUM = 4;   // TCC, CS_N下降沿到SCLK的第一个边沿对应CLK数, 最小为1
localparam integer SCLK_EDGE_TO_CS_EDGE_CLK_NUM = 5;   // TCCH, 最后一个SCLK边沿到CS_N上升沿对应CLK数, 最小为1
localparam integer CS_KEEP_HIGH_CLK_NUM         = 6;   // TCWH, CS_N低电平后保持高电平的时间对应CLK数, 最小为1
localparam integer CLK_FREQ_MHZ                 = 120; // 模块工作时钟, 常用100/120

logic clk;
logic rstn;

mySPI_4Wire_LoopBack # (
  .SPI_MODE                     (SPI_MODE                    ),
  .DATA_WIDTH                   (DATA_WIDTH                  ),
  .SCLK_PERIOD_CLK_NUM          (SCLK_PERIOD_CLK_NUM         ),
  .CS_EDGE_TO_SCLK_EDGE_CLK_NUM (CS_EDGE_TO_SCLK_EDGE_CLK_NUM),
  .SCLK_EDGE_TO_CS_EDGE_CLK_NUM (SCLK_EDGE_TO_CS_EDGE_CLK_NUM),
  .CS_KEEP_HIGH_CLK_NUM         (CS_KEEP_HIGH_CLK_NUM        ),
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ                )
) mySPI_4Wire_LoopBack_inst (.*);
//-- 被测模块实例化 ------------------------------------------------------------


//++ 生成时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLKT = 1000 / CLK_FREQ_MHZ;
initial begin
  clk = 0;
  forever #(CLKT / 2) clk = ~clk;
end
//-- 生成时钟 ------------------------------------------------------------


//++ 测试输入 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
initial begin
  rstn = 0;
  #(CLKT * 1);
  rstn = 1;
  #(CLKT * (SCLK_PERIOD_CLK_NUM * DATA_WIDTH * 2));
  #(CLKT * 30);
  $stop;
end
//-- 测试输入 ------------------------------------------------------------


endmodule