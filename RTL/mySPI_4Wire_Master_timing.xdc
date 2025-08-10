# mySPI_4Wire_Master_timing.xdc


# 约束MISO信号输入延迟（假设实测延迟=15ns）
set_input_delay -clock [get_clocks spi_clk] -max 15 [get_ports spi_miso]
set_input_delay -clock [get_clocks spi_clk] -min 5  [get_ports spi_miso]