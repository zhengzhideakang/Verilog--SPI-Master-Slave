/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-06-27 14:56:50
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-06-29 23:26:53
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能:
* 思路:
  1.
*/

module mySPI_4Wire_tb();

//++ 仿真时间尺度 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
timeunit 1ns;
timeprecision 1ps;
//-- 仿真时间尺度 ------------------------------------------------------------


//++ 被测模块实例化 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam DATA_WIDTH      = 16 ; // 单次通信的SCLK周期数
localparam SPI_MODE        = 3  ; // SPI模式, 可选0, 1, 2, 3 (默认)
localparam SCLK_FREQ_MHZ   = 10 ; // SCLK频率
localparam TCC_NS          = 500; // CS_N下降沿到SCLK的第一个边沿, 单位ns
localparam TCCH_NS         = 100; // 最后一个SCLK边沿到CS_N上升沿, 单位ns
localparam TCWH_NS         = 400; // CS_N低电平有效到下一次低电平有效的时间, 单位ns
localparam CLK_FREQ_MHZ    = 100;

logic clk;
logic rstn;

mySPI_4Wire_LoopBack # (
  .SPI_MODE      (SPI_MODE     ),
  .DATA_WIDTH    (DATA_WIDTH   ),
  .SCLK_FREQ_MHZ (SCLK_FREQ_MHZ),
  .TCC_NS        (TCC_NS       ),
  .TCCH_NS       (TCCH_NS      ),
  .TCWH_NS       (TCWH_NS      ),
  .CLK_FREQ_MHZ  (CLK_FREQ_MHZ)
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
  #(CLKT * (CLK_FREQ_MHZ / SCLK_FREQ_MHZ) * DATA_WIDTH * 10);
  $stop;
end
//-- 测试输入 ------------------------------------------------------------


endmodule