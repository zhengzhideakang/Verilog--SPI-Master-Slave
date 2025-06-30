/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-06-29 17:51:21
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-06-29 22:45:22
 * @Filename     : mySPI_4Wire_LoopBack.v
 * @Description  : SPI-4线主机和从机回环测试
*/

/*
! 模块功能: SPI-4线主机和从机回环测试
* 思路:
* 1.
~ 注意:
~ 1.
% 其它
*/

`default_nettype none

module mySPI_4Wire_LoopBack
#(
  parameter integer SPI_MODE      = 3,   // SPI模式, 可选0, 1, 2, 3 (默认)
  parameter integer DATA_WIDTH    = 16,  // 单次通信发送或接收数据的位宽, 最小为1, 常见8/16
  parameter integer SCLK_FREQ_MHZ = 4,   // SCLK频率, 单位MHz, 最小为1, 一般不大于60
  parameter integer TCC_NS        = 500, // CS_N下降沿到SCLK的第一个边沿, 单位ns, 最小为0
  parameter integer TCCH_NS       = 100, // 最后一个SCLK边沿到CS_N上升沿, 单位ns, 最小为0
  parameter integer TCWH_NS       = 400, // CS_N低电平有效到下一次低电平有效的时间, 单位ns, 最小为0
  parameter integer CLK_FREQ_MHZ  = 100  // 本模块工作时钟, 要求最小为SCLK_FREQ_MHZ的2倍, 常用100/120
)(
  input  wire clk,
  input  wire rstn
);


//++ 实例化SPI主机 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire spi_begin;
wire spi_end;
wire spi_is_busy;
reg  [DATA_WIDTH-1:0] spi_master_tx_data;
wire [DATA_WIDTH-1:0] spi_master_rx_data;
wire spi_master_rx_data_valid;
wire spi_cs_n;
wire spi_sclk;
wire spi_mosi;
wire spi_miso;

mySPI_4Wire_Master #(
  .SPI_MODE      (SPI_MODE     ),
  .DATA_WIDTH    (DATA_WIDTH   ),
  .SCLK_FREQ_MHZ (SCLK_FREQ_MHZ),
  .TCC_NS        (TCC_NS       ),
  .TCCH_NS       (TCCH_NS      ),
  .TCWH_NS       (TCWH_NS      ),
  .CLK_FREQ_MHZ  (CLK_FREQ_MHZ)
) mySPI_4Wire_Master_inst (
  .spi_begin                (spi_begin               ),
  .spi_end                  (spi_end                 ),
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
//-- 实例化SPI主机 ------------------------------------------------------------


//++ 实例化SPI从机 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire spi_slave_tx_is_busy;
reg  [DATA_WIDTH-1:0] spi_slave_tx_data;
wire [DATA_WIDTH-1:0] spi_slave_rx_data;
wire spi_slave_rx_data_valid;
wire arstn = rstn;

mySPI_4Wire_Slave #(
  .SPI_MODE   (SPI_MODE),
  .DATA_WIDTH (DATA_WIDTH)
) mySPI_4Wire_Slave_inst (
  .spi_slave_tx_is_busy    (spi_slave_tx_is_busy   ),
  .spi_slave_tx_data       (spi_slave_tx_data      ),
  .spi_slave_rx_data       (spi_slave_rx_data      ),
  .spi_slave_rx_data_valid (spi_slave_rx_data_valid),
  .spi_cs_n                (spi_cs_n               ),
  .spi_sclk                (spi_sclk               ),
  .spi_mosi                (spi_mosi               ),
  .spi_miso                (spi_miso               ),
  .arstn                   (arstn                  )
);
//-- 实例化SPI从机 ------------------------------------------------------------


//++ 回环测试控制 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg rstn_r1;
always @(posedge clk) begin
  rstn_r1 <= rstn;
end

assign spi_begin = rstn_r1;

always @(posedge clk) begin
  if (~rstn)
    spi_master_tx_data <= 'hAB;
  else if (spi_master_rx_data_valid)
    spi_master_tx_data <= spi_master_rx_data + 1'b1;
  else
    spi_master_tx_data <= spi_master_tx_data;
end

reg spi_slave_rx_data_valid_r1;
reg spi_slave_rx_data_valid_r2;
always @(posedge clk) begin
  spi_slave_rx_data_valid_r1 <= spi_slave_rx_data_valid;
  spi_slave_rx_data_valid_r2 <= spi_slave_rx_data_valid_r1;
end

wire spi_slave_rx_data_valid_pedge = spi_slave_rx_data_valid_r1 && ~spi_slave_rx_data_valid_r2;

always @(posedge clk) begin
  if (~rstn)
    spi_slave_tx_data <= 'hCD;
  else if (spi_slave_rx_data_valid_pedge)
    spi_slave_tx_data <= spi_slave_rx_data + 1'b1;
  else
    spi_slave_tx_data <= spi_slave_tx_data;
end
//-- 回环测试控制 ------------------------------------------------------------


endmodule
`resetall