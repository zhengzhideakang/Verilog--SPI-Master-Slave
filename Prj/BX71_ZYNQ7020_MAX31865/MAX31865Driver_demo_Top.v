/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-08-09 22:31:51
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-08-10 12:47:49
 * @Filename     : MAX31865Driver_demo_Top.v
 * @Description  : MAX31865Driver_demo顶层模块
*/

/*
! 模块功能: MAX31865Driver_demo顶层模块
* 思路:
* 1.
~ 注意:
~ 1.
% 其它
*/

`default_nettype none

module MAX31865Driver_demo_Top
(
  // SPI硬线连接
  (* mark_debug *)output wire spi_cs_n,
  (* mark_debug *)output wire spi_sclk,
  (* mark_debug *)output wire spi_mosi,
  (* mark_debug *)input  wire spi_miso,

  input  wire fpga_clk
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


//++ 实例化MAX31865驱动demo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg  max31865_begin;
(* mark_debug *)wire max31865_is_busy;
(* mark_debug *)wire [7 :0] max31865_config_data;
(* mark_debug *)wire [7 :0] max31865_rd_config_data;
(* mark_debug *)wire max31865_rd_config_data_valid;
(* mark_debug *)wire [15:0] max31865_high_threshold;
(* mark_debug *)wire [15:0] max31865_rd_high_threshold;
(* mark_debug *)wire [15:0] max31865_low_threshold;
(* mark_debug *)wire [15:0] max31865_rd_low_threshold;
(* mark_debug *)wire max31865_rd_threshold_valid;

MAX31865Driver_demo # (
  .CLK_FREQ_MHZ(CLK_FREQ_MHZ)
) MAX31865Driver_demo_inst (
  .max31865_begin                (max31865_begin               ),
  .max31865_is_busy              (max31865_is_busy             ),
  .max31865_config_data          (max31865_config_data         ),
  .max31865_rd_config_data       (max31865_rd_config_data      ),
  .max31865_rd_config_data_valid (max31865_rd_config_data_valid),
  .max31865_high_threshold       (max31865_high_threshold      ),
  .max31865_rd_high_threshold    (max31865_rd_high_threshold   ),
  .max31865_low_threshold        (max31865_low_threshold       ),
  .max31865_rd_low_threshold     (max31865_rd_low_threshold    ),
  .max31865_rd_threshold_valid   (max31865_rd_threshold_valid  ),
  .spi_cs_n(spi_cs_n),
  .spi_sclk(spi_sclk),
  .spi_mosi(spi_mosi),
  .spi_miso(spi_miso),
  .clk(clk),
  .rstn(rstn)
);
//-- 实例化MAX31865驱动demo ------------------------------------------------------------


//++ 设置配置寄存器值 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*
* 配置寄存器位定义:
*   D7: V_BIAS       - 偏置电压(1:开启, 0:关闭)
*   D6: CONV_MODE    - 转换模式(1:自动, 0:正常关闭)
*   D5: SINGLE_SHOT  - 单次触发(1:1-shot, 0:无)
*   D4: WIRE_MODE    - 线制选择(1:三线, 0:四线)
*   D3: FAULT_DETECT_H - 故障检测周期高位(与D2组合)
*   D2: FAULT_DETECT_L - 故障检测周期低位(见表3)
*   D1: FAULT_CLR    - 故障清除(1:清除状态, 0:无操作)
*   D0: FILTER_SEL   - 工频滤波(1:60Hz, 0:50Hz)
*/
/*
* 故障检测周期控制 (D3-D2):
*   00: 无操作                        | 读取: 故障检测完成
*   01: 带自动延迟的故障检测             | 读取: 自动故障检测仍在运行
*   10: 带手动延迟的故障检测（周期 1）    | 读取: 手动周期1仍在运行；等待用户写入11
*   11: 带手动延迟的故障检测（周期 2）    | 读取: 手动周期2仍在运行
*/
localparam [0: 0] V_BIAS         = 1'b1;
localparam [0: 0] CONV_MODE      = 1'b0;
localparam [0: 0] SINGLE_SHOT    = 1'b1;
localparam [0: 0] WIRE_MODE      = 1'b1;
localparam [0: 0] FAULT_DETECT_H = 1'b0;
localparam [0: 0] FAULT_DETECT_L = 1'b0;
localparam [0: 0] FAULT_CLR      = 1'b0;
localparam [0: 0] FILTER_SEL     = 1'b0;
assign max31865_config_data = {
  V_BIAS,
  CONV_MODE,
  SINGLE_SHOT,
  WIRE_MODE,
  FAULT_DETECT_H,
  FAULT_DETECT_L,
  FAULT_CLR,
  FILTER_SEL
};
//-- 设置配置寄存器值 ------------------------------------------------------------


//++ 设置阈值寄存器值 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam [15:0] MAX31865_HIGH_THRESHOLD = 16'hFF77;
localparam [15:0] MAX31865_LOW_THRESHOLD  = 16'h0101;
assign max31865_high_threshold = MAX31865_HIGH_THRESHOLD;
assign max31865_low_threshold  = MAX31865_LOW_THRESHOLD;
//-- 设置阈值寄存器值 ------------------------------------------------------------


//++ 生成MAX31865驱动demo控制信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam MAX31865_SAMPLE_FREQ_HZ = 10;
localparam MAX31865_BEGIN_CLK_CNT_MAX = CLK_FREQ_MHZ * 1000 * 1000 / MAX31865_SAMPLE_FREQ_HZ;
reg [$clog2(MAX31865_BEGIN_CLK_CNT_MAX+1)-1 : 0] max31865_begin_clk_cnt;
always @(posedge clk) begin
  if (~rstn)
    max31865_begin_clk_cnt <= 'd0;
  else if (max31865_begin_clk_cnt < MAX31865_BEGIN_CLK_CNT_MAX)
    max31865_begin_clk_cnt <= max31865_begin_clk_cnt + 1'b1;
  else
    max31865_begin_clk_cnt <= 'd0;
end

always @(posedge clk) begin
  if (~rstn)
    max31865_begin <= 1'b0;
  else if (max31865_begin_clk_cnt == MAX31865_BEGIN_CLK_CNT_MAX && ~max31865_is_busy)
    max31865_begin <= 1'b1;
  else
    max31865_begin <= 1'b0;
end
//-- 生成MAX31865驱动demo控制信号 ------------------------------------------------------------


endmodule
`resetall