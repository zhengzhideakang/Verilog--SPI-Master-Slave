# Verilog功能模块--SPI主机和从机

## 一. 介绍

本模块实现了全功能的Verilog的SPI主机与从机，仓库中包含SPI主从回环仿真、AXD112 SPI驱动测试与MAX31865 Demo SPI驱动测试。

## 二. 模块功能

本Verilog功能模块——SPI主机实现了SPI协议要求的完整时序控制，具体功能如下：

1. 支持所有4种SPI工作模式

2. 支持任意数据位宽

3. 支持任意串行时钟频率fsclk

4. 支持指定CS下降沿到第一个SCLK边沿的延时

5. 支持指定最后SCLK边沿到CS上升沿的延时

6. 支持指定CS高电平持续时间

## 二、模块框图

<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/Verilog%E5%8A%9F%E8%83%BD%E6%A8%A1%E5%9D%97--SPI%E4%B8%BB%E6%9C%BA%E5%92%8C%E4%BB%8E%E6%9C%BA(02)--SPI%E4%B8%BB%E6%9C%BA%E8%AE%BE%E8%AE%A1%E6%80%9D%E8%B7%AF%E4%B8%8E%E4%BB%A3%E7%A0%81%E8%A7%A3%E6%9E%90-2.svg" />

## 四. 更多参考

[Verilog功能模块–SPI主机和从机(01)–SPI简介 – 徐晓康的博客](https://www.myhardware.top/verilog功能模块-spi主机和从机01-spi简介/)

[Verilog功能模块–SPI主机和从机(02)–SPI主机设计思路与代码解析 – 徐晓康的博客](https://www.myhardware.top/verilog功能模块-spi主机和从机02-spi主机设计思路与代码解/)

[Verilog功能模块–SPI从机和从机(03)–SPI从机设计思路与代码解析 – 徐晓康的博客](https://www.myhardware.top/verilog功能模块-spi从机和从机03-spi从机设计思路与代码解/)

[Verilog功能模块–SPI主机和从机(04)–SPI主机从机回环仿真 – 徐晓康的博客](https://www.myhardware.top/verilog功能模块-spi主机和从机04-spi主机从机回环仿真/)

[Verilog功能模块–SPI主机和从机(05)–ADX112 SPI驱动实测 – 徐晓康的博客](https://www.myhardware.top/verilog功能模块-spi主机和从机05-adx112-spi驱动实测/)

[Verilog功能模块–SPI主机和从机(06)–MAX31865 Demo SPI驱动实测 – 徐晓康的博客](https://www.myhardware.top/verilog功能模块-spi主机和从机06-max31865-demo-spi驱动实测/)

## 其它平台

微信公众号：`徐晓康的博客`

<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/%E5%BE%90%E6%99%93%E5%BA%B7%E7%9A%84%E5%8D%9A%E5%AE%A2%E5%85%AC%E4%BC%97%E5%8F%B7%E4%BA%8C%E7%BB%B4%E7%A0%81.jpg" alt="徐晓康的博客公众号二维码" />

