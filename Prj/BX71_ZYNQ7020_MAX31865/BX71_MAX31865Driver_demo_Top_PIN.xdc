# BX71_MAX31865Driver_demo_Top_PIN.xdc
# 代码压缩与烧写速度
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# 时钟与复位 50MHz
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports fpga_clk]

# 扩展口P3 31(V15) 33(Y14) 35(W13) 37(V12)
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports spi_cs_n]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports spi_sclk]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports spi_miso]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports spi_mosi]



