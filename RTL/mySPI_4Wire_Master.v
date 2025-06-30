/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-06-27 09:18:49
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-06-30 00:06:54
 * @Filename     : mySPI_4Wire_Master.v
 * @Description  : 通用SPI-4线通信主机
*/

/*
! 模块功能: 通用SPI-4线通信主机
* 思路:
* 1.
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
*/

`default_nettype none

module mySPI_4Wire_Master
#(
  parameter integer SPI_MODE      = 3,   // SPI模式, 可选0, 1, 2, 3 (默认)
  parameter integer DATA_WIDTH    = 16,  // 单次通信发送或接收数据的位宽, 最小为1, 常见8/16
  parameter integer SCLK_FREQ_MHZ = 4,   // SCLK频率, 单位MHz, 最小为1, 一般不大于60
  parameter integer TCC_NS        = 500, // CS_N下降沿到SCLK的第一个边沿, 单位ns, 最小为0
  parameter integer TCCH_NS       = 100, // 最后一个SCLK边沿到CS_N上升沿, 单位ns, 最小为0
  parameter integer TCWH_NS       = 400, // CS_N低电平有效到下一次低电平有效的时间, 单位ns, 最小为0
  parameter integer CLK_FREQ_MHZ  = 100  // 本模块工作时钟, 要求最小为SCLK_FREQ_MHZ的2倍, 常用100/120
)(
  // 外部控制SPI信号
  input  wire spi_begin,   // SPI单次通信开始, 高电平有效, 仅在spi_is_busy为低时起作用
  output wire spi_end,     // SPI单次通信结束, 高电平有效, 只会持续一个时钟周期
  output wire spi_is_busy, // SPI繁忙指示, 高电平表示SPI正在工作
  input  wire [DATA_WIDTH-1:0] spi_master_tx_data, // SPI发送数据, 数据总是高位先发
  output reg  [DATA_WIDTH-1:0] spi_master_rx_data, // SPI接收数据, 最先读出的数据在最高位
  output reg                   spi_master_rx_data_valid, // SPI接收数据有效

  // SPI硬线链接
  output wire spi_cs_n, // 片选, 低电平有效
  output wire spi_sclk, // SPI时钟, 主机提供
  output wire spi_mosi, // 主机输出从机输入
  input  wire spi_miso, // 主机输入从机输出

  input  wire clk,
  input  wire rstn
);


//++ 参数有效性检查 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
initial begin
  if (SPI_MODE != 0 && SPI_MODE != 1 && SPI_MODE != 2 && SPI_MODE != 3)
    $error("SPI_MODE must be 0, 1, 2, 3");
  if (CLK_FREQ_MHZ / SCLK_FREQ_MHZ < 2)
    $error("CLK_FREQ_MHZ / SCLK_FREQ_MHZ must >= 2");
end
//-- 参数有效性检查 ------------------------------------------------------------


//++ 本地参数 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CPOL = (SPI_MODE == 2 || SPI_MODE == 3); // SCLK空闲值
// 0表示在时钟第一个边沿采样数据, 1表示在第二个边沿采样
localparam CPHA = (SPI_MODE == 1 || SPI_MODE == 3);
//-- 本地参数 ------------------------------------------------------------


//++ 三段式状态机-状态定义 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//~ 状态定义
localparam IDLE = 5'd1 << 0;// 空闲态, 'h1
localparam TCC  = 5'd1 << 1;// CS_N拉低到第一个SCLK边沿, 'h2
localparam SCLK = 5'd1 << 2;// SCLK输出, 此阶段进行数据读写, 'h4
localparam TCCH = 5'd1 << 3;// SCLK最后一个边沿到CS_N拉高, 'h8
localparam TCWH = 5'd1 << 4;// CS_N拉高最短持续时间, 'h10

localparam STATE_WIDTH = 5;
reg [STATE_WIDTH-1:0] state;
reg [STATE_WIDTH-1:0] next;
//~ 初始态与状态跳转
always @(posedge clk) begin
  if (~rstn)
    state <= IDLE;
  else
    state <= next;
end
//-- 三段式状态机-状态定义 ------------------------------------------------------------


//++ 三段式状态机-状态跳转 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire tcc_end;
reg  sclk_end;
wire tcch_end;
wire tcwh_end;

//~ 跳转到下一个状态的条件
always @(*) begin
  next = state;
  case (state)
    IDLE: if (spi_begin) next = TCC;
    TCC:  if (tcc_end  ) next = SCLK;
    SCLK: if (sclk_end ) next = TCCH;
    TCCH: if (tcch_end ) next = TCWH;
    TCWH: if (tcwh_end ) next = IDLE;
    default: next = IDLE;
  endcase
end
//-- 三段式状态机-状态跳转 ------------------------------------------------------------


//++ 生成SPI控制信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign spi_is_busy = state != IDLE;
//-- 生成SPI控制信号 ------------------------------------------------------------


//++ 生成cs_n ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg spi_cs_n_tmp = 1'b1; // 仿真初始态cs_n默认值为1
always @(posedge clk) begin
  spi_cs_n_tmp <= 1'b1;
  case (state)
    TCC, SCLK, TCCH: spi_cs_n_tmp <= 1'b0;
    default: ;
  endcase
end

assign spi_cs_n = spi_is_busy ? spi_cs_n_tmp : 1'bz;
//-- 生成cs_n ------------------------------------------------------------


//++ TCC状态计时 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam TCC_CLK_CNT_MAX = ((CLK_FREQ_MHZ * TCC_NS / 1000 < 1)
                              ? 1
                              : (CLK_FREQ_MHZ * TCC_NS / 1000)) - 1;
reg [$clog2((TCC_CLK_CNT_MAX == 0 ? 1 : TCC_CLK_CNT_MAX)+1)-1 : 0] tcc_clk_cnt;
always @(posedge clk) begin
  tcc_clk_cnt <= tcc_clk_cnt;
  case (state)
    TCC: if (tcc_clk_cnt < TCC_CLK_CNT_MAX) tcc_clk_cnt <= tcc_clk_cnt + 1'b1;
    default: tcc_clk_cnt <= 'd0;
  endcase
end

assign tcc_end = tcc_clk_cnt == TCC_CLK_CNT_MAX;
//-- TCC状态计时 ------------------------------------------------------------


//++ 生成sclk ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam SCLK_CLK_CNT_MAX = ((CLK_FREQ_MHZ / SCLK_FREQ_MHZ < 1)
                              ? 1
                              : (CLK_FREQ_MHZ / SCLK_FREQ_MHZ)) - 1;
reg [$clog2((SCLK_CLK_CNT_MAX == 0 ? 1 : SCLK_CLK_CNT_MAX)+1)-1 : 0] sclk_clk_cnt;
always @(posedge clk) begin
  sclk_clk_cnt <= 'd0;
  case (state)
    SCLK: if (sclk_clk_cnt < SCLK_CLK_CNT_MAX) sclk_clk_cnt <= sclk_clk_cnt + 1'b1;
    default: ;
  endcase
end

localparam SCLK_CNT_HALF = CLK_FREQ_MHZ / SCLK_FREQ_MHZ / 2;
reg spi_sclk_tmp = CPOL; // 仿真初始态spi_sclk默认值
always @(posedge clk) begin
  spi_sclk_tmp <= spi_sclk_tmp;
  case (state)
    SCLK: if (sclk_clk_cnt == 'd0 || sclk_clk_cnt == SCLK_CNT_HALF) spi_sclk_tmp <= ~spi_sclk_tmp;
    default: spi_sclk_tmp <= CPOL;
  endcase
end

assign spi_sclk = spi_is_busy ? spi_sclk_tmp : 1'bz;

localparam SCLK_CLK_MAX = DATA_WIDTH;
reg [$clog2(SCLK_CLK_MAX+1)-1 : 0] sclk_cnt;
always @(posedge clk) begin
  sclk_cnt <= sclk_cnt;
  case (state)
    SCLK: if (sclk_clk_cnt == 'd0) sclk_cnt <= sclk_cnt + 1'b1;
    default: sclk_cnt <= 'd0;
  endcase
end

always @(posedge clk) begin
  sclk_end <= 1'b0;
  case (state)
    SCLK: if (sclk_cnt == SCLK_CLK_MAX && sclk_clk_cnt == SCLK_CNT_HALF) sclk_end <= 1'b1;
    default: ;
  endcase
end
//-- 生成sclk ------------------------------------------------------------


//++ TCCH状态计时 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam TCCH_CLK_CNT_MAX = ((CLK_FREQ_MHZ * TCCH_NS / 1000 < 3)
                              ? 3
                              : (CLK_FREQ_MHZ * TCCH_NS / 1000)) - 3;
reg [$clog2((TCCH_CLK_CNT_MAX == 0 ? 1 : TCCH_CLK_CNT_MAX)+1)-1 : 0] tcch_clk_cnt;
always @(posedge clk) begin
  tcch_clk_cnt <= tcch_clk_cnt;
  case (state)
    TCCH: if (tcch_clk_cnt < TCCH_CLK_CNT_MAX) tcch_clk_cnt <= tcch_clk_cnt + 1'b1;
    default: tcch_clk_cnt <= 'd0;
  endcase
end

assign tcch_end = tcch_clk_cnt == TCCH_CLK_CNT_MAX;
//-- TCCH状态计时 ------------------------------------------------------------


//++ TCWH状态计时 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam TCWH_CLK_CNT_MAX = CLK_FREQ_MHZ * TCWH_NS / 1000;
reg [$clog2((TCWH_CLK_CNT_MAX == 0 ? 1 : TCWH_CLK_CNT_MAX)+1)-1 : 0] tcwh_clk_cnt;
always @(posedge clk) begin
  tcwh_clk_cnt <= tcwh_clk_cnt;
  case (state)
    TCWH: tcwh_clk_cnt <= tcwh_clk_cnt + 1'b1;
    default: tcwh_clk_cnt <= 'd0;
  endcase
end

assign tcwh_end = tcwh_clk_cnt == TCWH_CLK_CNT_MAX;
//-- TCWH状态计时 ------------------------------------------------------------


//++ SPI发送 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire spi_update_edge = CPHA
                      ? (sclk_cnt != 'd0 && sclk_clk_cnt == 'd0)
                      : sclk_clk_cnt == SCLK_CNT_HALF;
wire spi_sample_edge = CPHA
                      ? sclk_clk_cnt == SCLK_CNT_HALF
                      : sclk_clk_cnt == 'd0;

reg [DATA_WIDTH-1:0] spi_master_tx_data_lfsr;
always @(posedge clk) begin
  spi_master_tx_data_lfsr <= spi_master_tx_data_lfsr;
  case (state)
    IDLE: if (spi_begin) spi_master_tx_data_lfsr <= spi_master_tx_data;
    SCLK: if (spi_update_edge) spi_master_tx_data_lfsr <= spi_master_tx_data_lfsr << 1;
    default: ;
  endcase
end

assign spi_mosi = spi_is_busy ? spi_master_tx_data_lfsr[DATA_WIDTH-1] : 1'bz;
//-- SPI发送 ------------------------------------------------------------


//++ SPI接收 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(posedge clk) begin
  spi_master_rx_data <= spi_master_rx_data;
  case (state)
    SCLK: if (spi_sample_edge) spi_master_rx_data <= {spi_master_rx_data[DATA_WIDTH-2:0] , spi_miso};
    default: ;
  endcase
end

always @(posedge clk) begin
  spi_master_rx_data_valid <= 1'b0;
  case (state)
    SCLK: if (sclk_cnt == SCLK_CLK_MAX && spi_sample_edge) spi_master_rx_data_valid <= 1'b1;
    default: ;
  endcase
end
//-- SPI接收 ------------------------------------------------------------


//++ SPI结束 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign spi_end = tcwh_end;
//-- SPI结束 ------------------------------------------------------------

endmodule
`resetall