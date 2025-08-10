/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-06-27 15:02:38
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-08-10 12:46:26
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: MAX31865驱动模块, 通过SPI通信对芯片进行配置以及读取芯片输出
* 思路:
* 1.MAX31865通过SPI写入/读取寄存器来完成对芯片的配置和数据读取
* 2.MAX31865需要先进行配置, 再进行数据读取
* 3.配置分为两种类型, 一为配置寄存器(读地址8'h00, 写地址8'h80), 包括:
*   - 启用或禁用偏置VBIAS
*   - 设置转换模式：自动或常态关闭
*   - 设置是否开启单次触发
*   - 选择 RTD 连接方式：三线或四线
*   - 清除故障状态寄存器
*   - 选择滤波器频率
* 4.二为配置故障阈值寄存器，包括:
*   - 高故障阈值寄存器MSB (读地址8'h03, 写地址8'h83)
*   - 高故障阈值寄存器LSB (读地址8'h04, 写地址8'h84)
*   - 低故障阈值寄存器MSB (读地址8'h05, 写地址8'h85)
*   - 低故障阈值寄存器LSB (读地址8'h06, 写地址8'h86)
* 5.配置完成后, 可以读取ADC码, 该码前15位表示温度值, 第16位(LSB)为故障指示, 1=有故障; 0=无故障
*   无故障时, max31865_adc_dout_valid有效, 指示读到了新的ADC码
*   有故障时, max31865_fault_status_valid有效, 此时max31865_adc_dout仍然会更新, 但此时值是不可靠的
* 6.有故障时, 还会更新故障状态寄存器的值, 上层模块可根据ADC码和故障寄存值来判断究竟是哪种故障,
* 7.除MAX31865输出的故障外, 本模块还定义了 max31865_drive_error_code 用于指示驱动故障
*   本驱动模块对各个寄存器都采用的先写后读操作, 正常情况下, 读取出的数据和写入的数据是一致的,
*   若不一致, 则可能是SPI驱动功能故障 或 芯片响应故障, 进行故障上报
*   不同的max31865_drive_error_code代表不同类型的故障, 见下文驱动错误的说明
* 8.本模块为demo, 并非完整的max31865驱动模块, 仅进行配置寄存器与故障阈值寄存器的读写测试, 已验证SPI主机模块功能
% 驱动错误
* max31865_drive_error_code[1:0]: 表示发生了某项驱动错误
* 2'b00: 表示配置寄存器读出数据不等于前一步骤写入的数据, 可能是SPI时序问题, 或者芯片本身的响应问题
* 2'b01: 表示故障阈值寄存器读出数据不等于前一步骤写入的数据, 可能原因同上
* 2'b10: 表示读取16位时读取到了故障, 但读取故障状态寄存器值为全0, 没有故障, 这可能是SPI链路问题或者芯片响应问题
* 2'b11: 保留
~ 注意:
~ 1.
% 其它
% MAX31865的SPI时序分析
* 1.时序特性参考: 数据手册--交流电气特性：SPI接口
* 2.MAX31865的SCLK频率最大为5MHz, 实际使用建议最大fSCLK设定为4MHz, 占空比固定为50%, 这里设为1MHz
* 3.SCLK空闲时为高电平, 对应 CPOL=1
* 4.MAX31865在SCLK的上升沿采样SDI引脚上的数据, 结合SCLK空闲高电平, 即在第二个时钟边沿采样, 对应CPHA = 1
* 5.综合来看 SPI_MODE = {CPOL, CPHA} = 2'b11 = 3
* 6.tCC: CS_N下降沿到SCLK的第一个下降沿, 最小值为400ns, 这里设为500ns
* 7.tCCH: 最后一个SCLK上升沿到CS_N上升沿, 最小值100ns, 这里设为200ns
* 8.tCWH: CS_N无效时间, CS_N低电平有效到下一次低电平有效的时间, 最小值为400ns, 这里设为500ns
* 9.tCDZ: CS_N上升沿到SDO引脚高阻的时间, 最大值40ns
* 10.SPI的读写时序是确定的, 芯片SDI先接收8位数据, 根据地址值决定是读还是写:
*    如果是读, 则芯片SDO输出16位数据
*    如果是写, 则芯片SDI接收16位数据
*    单次通讯结束
*/

`default_nettype none

module MAX31865Driver_demo
#(
  parameter integer SCLK_PERIOD_CLK_NUM          = 100, // fSCLK, SCLK周期对应CLK数, 必须为偶数, 最小为2
  parameter integer CS_EDGE_TO_SCLK_EDGE_CLK_NUM = 50,  // TCC, CS_N下降沿到SCLK的第一个边沿对应CLK数, 最小为1
  parameter integer SCLK_EDGE_TO_CS_EDGE_CLK_NUM = 20,  // TCCH, 最后一个SCLK边沿到CS_N上升沿对应CLK数, 最小为3
  parameter integer CS_KEEP_HIGH_CLK_NUM         = 50,  // TCWH, CS_N低电平后保持高电平的时间对应CLK数, 最小为2
  parameter integer CLK_FREQ_MHZ = 100
)(
  /* max31865控制 */
  input  wire        max31865_begin, // 上升沿有效, 进行一次配置寄存器和故障阈值寄存器的读写
  output reg         max31865_is_busy, // 高电平指示芯片正在工作, 此时不响应begin信号
  input  wire [7 :0] max31865_config_data, // 待写入配置寄存器的值, 在有效的begin上升沿锁存
  output reg  [7 :0] max31865_rd_config_data, // 读出的配置寄存器的值
  output wire max31865_rd_config_data_valid, // 指示读出的配置寄存器的值有效, 高电平有效, 只会持续一个时钟周期的高电平

  input  wire [15:0] max31865_high_threshold, // 写入的高故障阈值
  input  wire [15:0] max31865_low_threshold,  // 写入的低故障阈值
  output reg  [15:0] max31865_rd_high_threshold, // 读取的高故障阈值
  output reg  [15:0] max31865_rd_low_threshold,  // 读取的低故障阈值
  output wire        max31865_rd_threshold_valid, // 读取的故障阈值有效信号, 高电平有效, 只会持续一个时钟的高电平

  // SPI硬线连接
  output wire spi_cs_n,
  output wire spi_sclk,
  output wire spi_mosi,
  input  wire spi_miso,

  input  wire clk,
  input  wire rstn
);


//++ 实例化通用SPI主机模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam integer DATA_WIDTH = 16;  // 单次通信发送或接收数据的位宽, 最小为2, 常见8/16

(* mark_debug *)reg  spi_begin;
(* mark_debug *)wire spi_end;
// wire spi_is_busy;
(* mark_debug *)reg  [DATA_WIDTH-1:0] spi_master_tx_data;
(* mark_debug *)wire [DATA_WIDTH-1:0] spi_master_rx_data;
(* mark_debug *)wire spi_master_rx_data_valid;

mySPI_4Wire_Master #(
  .SPI_MODE                     (1                    ),
  .DATA_WIDTH                   (DATA_WIDTH                  ),
  .SCLK_PERIOD_CLK_NUM          (SCLK_PERIOD_CLK_NUM         ),
  .CS_EDGE_TO_SCLK_EDGE_CLK_NUM (CS_EDGE_TO_SCLK_EDGE_CLK_NUM),
  .SCLK_EDGE_TO_CS_EDGE_CLK_NUM (SCLK_EDGE_TO_CS_EDGE_CLK_NUM),
  .CS_KEEP_HIGH_CLK_NUM         (CS_KEEP_HIGH_CLK_NUM        ),
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ)
) mySPI_4Wire_Master_u0 (
  .spi_begin                (spi_begin               ),
  .spi_end                  (spi_end                 ),
  .spi_is_busy              (             ),
  .spi_master_tx_data       (spi_master_tx_data      ),
  .spi_master_rx_data       (spi_master_rx_data      ),
  .spi_master_rx_data_valid (spi_master_rx_data_valid),
  .spi_cs_n                 (spi_cs_n                ),
  .spi_sclk                 (spi_sclk                ),
  .spi_mosi                 (spi_mosi                ),
  .spi_miso                 (spi_miso                ),
  .clk                      (clk                     ),
  .rstn                     (rstn                    )
);
//-- 实例化通用SPI主机模块 ------------------------------------------------------------


//++ 寄存器读写地址 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/* 配置寄存器 读写*/
localparam [7:0] CONFIG_REG_RADDR = 8'h00; // 配置寄存器读地址
localparam [7:0] CONFIG_REG_WADDR = CONFIG_REG_RADDR + 8'h80; // 配置寄存器写地址

/* 故障阈值寄存器 读写*/
localparam [7:0] HIGH_FAULT_THRESHOLD_MSB_REG_RADDR = 8'h03; // 高故障阈值MSB读地址
localparam [7:0] HIGH_FAULT_THRESHOLD_LSB_REG_RADDR = 8'h04; // 高故障阈值LSB读地址
localparam [7:0] LOW_FAULT_THRESHOLD_MSB_REG_RADDR = 8'h05; // 低故障阈值MSB读地址
localparam [7:0] LOW_FAULT_THRESHOLD_LSB_REG_RADDR = 8'h06; // 低故障阈值LSB读地址
localparam [7:0] HIGH_FAULT_THRESHOLD_MSB_REG_WADDR = HIGH_FAULT_THRESHOLD_MSB_REG_RADDR
                                                    + 8'h80; // 高故障阈值MSB写地址
localparam [7:0] HIGH_FAULT_THRESHOLD_LSB_REG_WADDR = HIGH_FAULT_THRESHOLD_LSB_REG_RADDR
                                                    + 8'h80; // 高故障阈值LSB写地址
localparam [7:0] LOW_FAULT_THRESHOLD_MSB_REG_WADDR = LOW_FAULT_THRESHOLD_MSB_REG_RADDR
                                                   + 8'h80; // 低故障阈值MSB写地址
localparam [7:0] LOW_FAULT_THRESHOLD_LSB_REG_WADDR = LOW_FAULT_THRESHOLD_LSB_REG_RADDR
                                                   + 8'h80; // 低故障阈值LSB写地址
//-- 寄存器读写地址 ------------------------------------------------------------


//++ busy信号生成 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg max31865_begin_r1;
always @(posedge clk) begin
  max31865_begin_r1 <= max31865_begin;
end

wire max31865_begin_pedge = max31865_begin && ~max31865_begin_r1;

//* busy固定逻辑, 上升沿比begin上升沿慢一个时钟, 下降沿与end下降沿对齐
wire max31865_end;
always @(posedge clk) begin
  if (~rstn)
    max31865_is_busy <= 1'b0;
  else if (max31865_is_busy && max31865_end)
    max31865_is_busy <= 1'b0;
  else if (~max31865_is_busy && max31865_begin_pedge)
    max31865_is_busy <= 1'b1;
  else
    max31865_is_busy <= max31865_is_busy;
end
//-- busy信号生成 ------------------------------------------------------------


//++ 读写配置与故障阈值寄存器 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg [3:0] spi_end_cnt; // spi_end计数, 作为下一次spi_begin的开始
always @(posedge clk) begin
  if (~rstn)
    spi_end_cnt <= 'd0;
  else if (max31865_is_busy)
    if (spi_end)
      spi_end_cnt <= spi_end_cnt + 1'b1;
    else
      spi_end_cnt <= spi_end_cnt;
  else
    spi_end_cnt <= 'd0;
end

localparam SPI_END_CNT_MAX = 9;
assign max31865_end = spi_end && spi_end_cnt == SPI_END_CNT_MAX;

always @(posedge clk) begin
  if (~rstn)
    spi_begin <= 1'b0;
  else if (max31865_begin_pedge && ~max31865_is_busy)
    spi_begin <= 1'b1;
  else if (spi_end && spi_end_cnt < SPI_END_CNT_MAX)
    spi_begin <= 1'b1;
  else
    spi_begin <= 1'b0;
end

// spi写入
always @(*) begin
  if (~rstn)
    spi_master_tx_data = 'd0;
  else
    case (spi_end_cnt)
      0: spi_master_tx_data = {CONFIG_REG_WADDR, max31865_config_data};
      1: spi_master_tx_data = {CONFIG_REG_RADDR, max31865_config_data};
      2: spi_master_tx_data = {HIGH_FAULT_THRESHOLD_MSB_REG_WADDR, max31865_high_threshold[15:8]};
      3: spi_master_tx_data = {HIGH_FAULT_THRESHOLD_MSB_REG_RADDR, max31865_high_threshold[15:8]};
      4: spi_master_tx_data = {HIGH_FAULT_THRESHOLD_LSB_REG_WADDR, max31865_high_threshold[7:0]};
      5: spi_master_tx_data = {HIGH_FAULT_THRESHOLD_LSB_REG_RADDR, max31865_high_threshold[7:0]};
      6: spi_master_tx_data = {LOW_FAULT_THRESHOLD_MSB_REG_WADDR, max31865_low_threshold[15:8]};
      7: spi_master_tx_data = {LOW_FAULT_THRESHOLD_MSB_REG_RADDR, max31865_low_threshold[15:8]};
      8: spi_master_tx_data = {LOW_FAULT_THRESHOLD_LSB_REG_WADDR, max31865_low_threshold[7:0]};
      9: spi_master_tx_data = {LOW_FAULT_THRESHOLD_LSB_REG_RADDR, max31865_low_threshold[7:0]};
      default: ;
    endcase
end

// 读取配置数据
always @(posedge clk) begin
  if (~rstn)
    max31865_rd_config_data <= 'd0;
  else if (spi_end)
    case (spi_end_cnt)
      1: max31865_rd_config_data <= spi_master_rx_data[7:0];
      default: ;
    endcase
  else
    max31865_rd_config_data <= max31865_rd_config_data;
end

assign max31865_rd_config_data_valid = spi_end && spi_end_cnt == 'd1;

// 读取高故障阈值
always @(posedge clk) begin
  if (~rstn)
    max31865_rd_high_threshold <= 'd0;
  else if (spi_end)
    case (spi_end_cnt)
      3: max31865_rd_high_threshold[15:8] <= spi_master_rx_data[7:0];
      5: max31865_rd_high_threshold[7:0]  <= spi_master_rx_data[7:0];
      default: ;
    endcase
  else
    max31865_rd_high_threshold <= max31865_rd_high_threshold;
end

// 读取低故障阈值
always @(posedge clk) begin
  if (~rstn)
    max31865_rd_low_threshold <= 'd0;
  else if (spi_end)
    case (spi_end_cnt)
      7: max31865_rd_low_threshold[15:8] <= spi_master_rx_data[7:0];
      9: max31865_rd_low_threshold[7:0]  <= spi_master_rx_data[7:0];
      default: ;
    endcase
  else
    max31865_rd_low_threshold <= max31865_rd_low_threshold;
end

assign max31865_rd_threshold_valid = spi_end && spi_end_cnt == 'd9;
//-- 读写配置与故障阈值寄存器 ------------------------------------------------------------


endmodule
`resetall