/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-07-28 23:28:35
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-08-07 16:39:46
 * @Filename     : template.v
 * @Description  : 实例化模板
*/


//++ 实例化SPI主机模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam integer SPI_MODE                     = 3;   // SPI模式, 可选0, 1, 2, 3 (默认)
localparam integer DATA_WIDTH                   = 16;  // 单次通信发送或接收数据的位宽, 最小为2, 常见8/16
localparam integer SCLK_PERIOD_CLK_NUM          = 4;   // fSCLK, SCLK周期对应CLK数, 必须为偶数, 最小为2
localparam integer CS_EDGE_TO_SCLK_EDGE_CLK_NUM = 1;   // TCC, CS_N下降沿到SCLK的第一个边沿对应CLK数, 最小为1
localparam integer SCLK_EDGE_TO_CS_EDGE_CLK_NUM = 3;   // TCCH, 最后一个SCLK边沿到CS_N上升沿对应CLK数, 最小为3
localparam integer CS_KEEP_HIGH_CLK_NUM         = 2;   // TCWH, CS_N低电平后保持高电平的时间对应CLK数, 最小为2
localparam integer CLK_FREQ_MHZ                 = 100; // 模块工作时钟, 常用100/120


wire spi_begin;
wire spi_end;
wire spi_is_busy;
wire [DATA_WIDTH-1:0] spi_master_tx_data;
wire [DATA_WIDTH-1:0] spi_master_rx_data;
wire                  spi_master_rx_data_valid;

mySPI_4Wire_Master #(
  .SPI_MODE                     (SPI_MODE                    ),
  .DATA_WIDTH                   (DATA_WIDTH                  ),
  .SCLK_PERIOD_CLK_NUM          (SCLK_PERIOD_CLK_NUM         ),
  .CS_EDGE_TO_SCLK_EDGE_CLK_NUM (CS_EDGE_TO_SCLK_EDGE_CLK_NUM),
  .SCLK_EDGE_TO_CS_EDGE_CLK_NUM (SCLK_EDGE_TO_CS_EDGE_CLK_NUM),
  .CS_KEEP_HIGH_CLK_NUM         (CS_KEEP_HIGH_CLK_NUM        ),
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ)
) mySPI_4Wire_Master_u0 (
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
//-- 实例化SPI主机模块 ------------------------------------------------------------