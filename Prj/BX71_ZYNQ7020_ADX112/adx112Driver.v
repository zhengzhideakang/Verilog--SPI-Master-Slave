/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-08-07 16:10:27
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-08-09 12:55:56
 * @Filename     : adx112Driver.v
 * @Description  : ADX112驱动
*/

/*
! 模块功能: ADX112驱动
* 思路:
* 1.此芯片数字接口为SPI接口, 故只需编写驱动SPI通用主机模块的外层逻辑即可
* 2.此芯片的SPI有两种读取方式:
*   - 一次读32位, 这时dout的前16位为转换结果, 后16位为配置寄存器数据
*   - 一次读16位, 这时dout只输出转换结果
* 3.din用于设置配置寄存器, 如果不需要更改配置寄存器, 那么保持din=全0或者全1即可
~ 注意:
~ 1.
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
% 此芯片SPI时序
* 1.SCLK时钟周期最小为250ns, 对应最大频率为4MHz. 此处用1MHz, 此芯片最高采样率860SPS, 1MHz绰绰有余
* 2.CS下降沿到第一个SCLK上升沿的延迟, 最小为100ns, 此处默认设为200ns
* 3.SCLK空闲为低电平，即CPOL=0
* 4.最后一个SCLK下降沿到CS上升沿的延迟, 最小为100ns, 此处默认设为200ns
* 5.CS高电平持续时间, 最小为200ns, 此处默认设为400ns
* 6.SCLK低电平持续28ms后, 芯片SPI接口将被复位
* 7.din有效到sclk下降沿的时间, 最小为50ns, 此为建立时间, 意味着芯片在sclk下降沿采样
* 8.sclk下降沿是时钟的第二个边沿, 故CPHA=1, 所以SPI_MODE={CPOL, CPHA}=2‘b01=1
* 9.sclk下降沿之后, din保持有效的时间, 最小值为50ns, 此为保持时间
* 10.CS下降沿到DOUT输出有效的延迟, 最大为100ns
* 11.SCLK上升沿到new dout有效的延迟, 最大为50ns
* 12.CS上升沿到DOUT高阻态的延迟, 最大为100ns
*/

`default_nettype none

module adx112Driver
#(
  parameter integer SCLK_PERIOD_CLK_NUM          = 100, // fSCLK, SCLK周期对应CLK数, 必须为偶数, 最小为2
  parameter integer CS_EDGE_TO_SCLK_EDGE_CLK_NUM = 20,  // TCC, CS_N下降沿到SCLK的第一个边沿对应CLK数, 最小为1
  parameter integer SCLK_EDGE_TO_CS_EDGE_CLK_NUM = 20,  // TCCH, 最后一个SCLK边沿到CS_N上升沿对应CLK数, 最小为3
  parameter integer CS_KEEP_HIGH_CLK_NUM         = 40,  // TCWH, CS_N低电平后保持高电平的时间对应CLK数, 最小为2
  parameter integer CLK_FREQ_MHZ = 100 // 100MHz对应单周期10ns
)(
  input  wire        adx112_begin,           // 上升沿有效,使芯片读取一次数据
  output wire        adx112_is_busy,         // 高电平指示芯片正在工作, 此时不响应begin信号
  input  wire [15:0] adx112_config_value,    // 待写入配置寄存器的值, 在有效的begin上升沿锁存
  output wire [15:0] adx112_dout,            // 芯片输出, 16bit
  output wire        adx112_dout_valid,      // 芯片输出有效指示, 高电平有效, 只会持续一个时钟周期的高电平
  output wire [15:0] adx112_rd_config_value, // 回读的配置寄存器值

  // SPI硬线链接
  output wire spi_cs_n, // 片选, 低电平有效
  output wire spi_sclk, // SPI时钟, 主机提供
  output wire spi_mosi, // 主机输出从机输入
  input  wire spi_miso, // 主机输入从机输出

  input  wire clk,
  input  wire rstn
);



//++ SPI读写控制 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adx112_begin_r1;
always @(posedge clk) begin
  adx112_begin_r1 <= adx112_begin;
end

wire adx112_begin_pedge = adx112_begin && ~adx112_begin_r1;

localparam integer DATA_WIDTH = 32;  // 单次通信发送或接收数据的位宽, 16/32(默认)

wire spi_begin;
// wire spi_end;
wire spi_is_busy;
wire [DATA_WIDTH-1:0] spi_master_tx_data;
wire [DATA_WIDTH-1:0] spi_master_rx_data;
wire        spi_master_rx_data_valid;

assign spi_begin = adx112_begin_pedge && ~spi_is_busy;
assign adx112_is_busy = spi_is_busy;
assign adx112_dout = spi_master_rx_data[DATA_WIDTH-1:DATA_WIDTH-16];
assign adx112_dout_valid = spi_master_rx_data_valid;
assign spi_master_tx_data = {adx112_config_value, 16'b0};

assign adx112_rd_config_value = spi_master_rx_data[DATA_WIDTH-17:DATA_WIDTH-32];
//-- SPI读写控制 ------------------------------------------------------------


//++ 实例化SPI主机模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
mySPI_4Wire_Master #(
  .SPI_MODE                     (1                           ),
  .DATA_WIDTH                   (DATA_WIDTH                  ),
  .SCLK_PERIOD_CLK_NUM          (SCLK_PERIOD_CLK_NUM         ),
  .CS_EDGE_TO_SCLK_EDGE_CLK_NUM (CS_EDGE_TO_SCLK_EDGE_CLK_NUM),
  .SCLK_EDGE_TO_CS_EDGE_CLK_NUM (SCLK_EDGE_TO_CS_EDGE_CLK_NUM),
  .CS_KEEP_HIGH_CLK_NUM         (CS_KEEP_HIGH_CLK_NUM        ),
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ                )
) mySPI_4Wire_Master_u0 (
  .spi_begin                (spi_begin               ),
  .spi_end                  (                        ),
  .spi_is_busy              (spi_is_busy             ),
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
//-- 实例化SPI主机模块 ------------------------------------------------------------


endmodule
`resetall