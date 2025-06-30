/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-06-28 22:21:41
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-06-30 01:31:46
 * @Filename     : mySPI_4Wire_Slave.v
 * @Description  : 通用SPI-4线通信从机
*/

/*
! 模块功能: 通用SPI-4线通信从机
* 思路:
* 1.支持所有4种SPI模式，通过SPI_MODE参数配置
* 2.数据位宽通过DATA_WIDTH参数可配置(1-32位)
* 3.使用sclk作为工作时钟, 故采用异步复位设计
* 4.片选无效时spi_miso输出高阻态，支持多从机系统
~ 注意:
~ 1.设置SPI_MODE参数与主机模式匹配
~ 2.在片选下降沿前提供稳定的spi_slave_tx_data
~ 3.spi_slave_tx_is_busy为高时, 外部不允许变更spi_slave_tx_data
~ 4.MSB优先传输
~ 5.异步复位(低电平有效), 复位信号(arstn)应在上电后至少激活一次
~ 6.在spi_slave_rx_data_valid高电平时读取spi_slave_rx_data
~ 7.如果外部模块需要接收此模块的输出信号, 注意这些信号是基于sclk时钟的,
~   对于外部模块工作时钟clk, 这些信号属于异步信号, 使用时需要做同步处理
% 其它
% SPI通信模式配置参考表
% +---------+------+------+------------+--------------+-------------+
% | SPI模式 | CPOL | CPHA | SCK空闲状态 | 数据采样边沿  | 数据移位边沿 |
% +---------+------+----- +------------+--------------+-------------+
% | 模式0   | 0    | 0    | 低电平      | 上升沿       | 下降沿       |
% | 模式1   | 0    | 1    | 低电平      | 下降沿       | 上升沿       |
% | 模式2   | 1    | 0    | 高电平      | 下降沿       | 上升沿       |
% | 模式3   | 1    | 1    | 高电平      | 上升沿       | 下降沿       |
% +---------+------+------+------------+--------------+-------------+
% 1.CPOL: 时钟极性, 定义SCK时钟线空闲状态
%   - 0: 空闲时低电平
%   - 1: 空闲时高电平
% 2.CPHA: 时钟相位, 定义数据采样时机
%   - 0: 在时钟的第一个边沿采样数据
%   - 1: 在时钟的第二个边沿采样数据
*/

module mySPI_4Wire_Slave #(
  parameter integer SPI_MODE   = 3, // SPI模式, 可选0, 1, 2, 3 (默认)
  parameter integer DATA_WIDTH = 16 // 单次通信发送或接收数据的位宽, 最小为1, 常见8/16
)(
  // SPI从机外部控制信号
  output wire spi_slave_tx_is_busy, // 指示SPI从机正在发送, 高电平有效
  input  wire [DATA_WIDTH-1:0] spi_slave_tx_data,        // 发送数据
  output reg  [DATA_WIDTH-1:0] spi_slave_rx_data,        // 接收数据
  output reg                   spi_slave_rx_data_valid,  // 接收数据有效

  // SPI硬线连接
  input  wire spi_cs_n, // 片选, 低电平有效
  input  wire spi_sclk, // SPI时钟, 主机提供
  input  wire spi_mosi, // 主机输出从机输入
  output wire spi_miso, // 主机输入从机输出

  input  wire arstn // 异步复位, 低电平有效
);


//++ 参数有效性检查 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
initial begin
  if (SPI_MODE != 0 && SPI_MODE != 1 && SPI_MODE != 2 && SPI_MODE != 3)
    $error("SPI_MODE must be 0, 1, 2, 3");
  if (DATA_WIDTH <= 0)
    $error("DATA_WIDTH must be >= 1");
end
//-- 参数有效性检查 ------------------------------------------------------------


//++ SPI busy信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign spi_slave_tx_is_busy = ~spi_cs_n;
//-- SPI busy信号 ------------------------------------------------------------


//++ 片选状态跟踪 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg spi_cs_n_old; // 片选跳变前一瞬间的状态, 跳变结束后会变为新值
always @(posedge spi_cs_n or negedge spi_cs_n or negedge arstn) begin
  if (~arstn)
    spi_cs_n_old <= 1'b1;
  else
    spi_cs_n_old <= spi_cs_n;
end
//-- 片选状态跟踪 ------------------------------------------------------------


//++ 发送数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg [$clog2(DATA_WIDTH+1)-1:0] sample_cnt; // 采样计数
reg [DATA_WIDTH-1:0] tx_data_lsfr;// 移位寄存器

generate
if (SPI_MODE == 0 || SPI_MODE == 3) begin // 下降沿移位
  always @(negedge spi_sclk or negedge spi_cs_n) begin
    if (spi_cs_n_old)
      tx_data_lsfr <= spi_slave_tx_data;  // 片选下降沿加载发送数据
    else if (~spi_cs_n && sample_cnt != 'd0) // 首个下降沿不移位
      tx_data_lsfr <= tx_data_lsfr << 1;
    else
      tx_data_lsfr <= tx_data_lsfr;
  end
end else begin // 上升沿移位
  always @(posedge spi_sclk or negedge spi_cs_n) begin
    if (spi_cs_n_old)
      tx_data_lsfr <= spi_slave_tx_data;  // 片选下降沿加载发送数据
    else if (~spi_cs_n)
      tx_data_lsfr <= tx_data_lsfr << 1;
    else
      tx_data_lsfr <= tx_data_lsfr;
  end
end
endgenerate

assign spi_miso = spi_cs_n ? 1'bz : tx_data_lsfr[DATA_WIDTH-1]; // 三态输出控制
//-- 发送数据 ------------------------------------------------------------


//++ 接收数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
generate
if (SPI_MODE == 0 || SPI_MODE == 3) begin // 上升沿采样
  always @(posedge spi_sclk) begin
    if (~spi_cs_n)
      spi_slave_rx_data <= {spi_slave_rx_data[DATA_WIDTH-2:0], spi_mosi}; // MSB优先
    else
      spi_slave_rx_data <= spi_slave_rx_data;
  end

  always @(posedge spi_sclk or negedge spi_cs_n) begin
    if (spi_cs_n_old)
      sample_cnt <= 'd0;
    else if (~spi_cs_n)
      sample_cnt <= sample_cnt + 1;
    else
      sample_cnt <= sample_cnt;
  end

  always @(posedge spi_sclk or negedge arstn or posedge spi_cs_n) begin
    if (~arstn)
      spi_slave_rx_data_valid <= 1'b0;
    else if (~spi_cs_n && sample_cnt == DATA_WIDTH-1)
      spi_slave_rx_data_valid <= 1'b1;
    else
      spi_slave_rx_data_valid <= 1'b0;
  end
end else begin // 下降沿采样
  always @(negedge spi_sclk) begin
    if (~spi_cs_n)
      spi_slave_rx_data <= {spi_slave_rx_data[DATA_WIDTH-2:0], spi_mosi}; // MSB优先
    else
      spi_slave_rx_data <= spi_slave_rx_data;
  end

  always @(negedge spi_sclk or negedge spi_cs_n ) begin
    if (spi_cs_n_old)
      sample_cnt <= 'd0;
    else if (~spi_cs_n)
      sample_cnt <= sample_cnt + 1;
    else
      sample_cnt <= sample_cnt;
  end

  always @(negedge spi_sclk or negedge arstn or posedge spi_cs_n) begin
    if (~arstn)
      spi_slave_rx_data_valid <= 1'b0;
    else if (~spi_cs_n && sample_cnt == DATA_WIDTH-1)
      spi_slave_rx_data_valid <= 1'b1;
    else
      spi_slave_rx_data_valid <= 1'b0;
  end
end
endgenerate
//-- 接收数据 ------------------------------------------------------------


endmodule