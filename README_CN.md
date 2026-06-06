WinCrashAnalyzer

一个基于 PowerShell 的 Windows 异常重启与硬件故障诊断工具。

WinCrashAnalyzer 通过分析 Windows 事件日志中的关键证据，包括 Kernel-Power、WHEA、内存诊断、磁盘错误和温度保护事件，对导致系统异常重启、蓝屏（BSOD）、死机或瞬间断电的潜在硬件问题进行分析，并生成排查建议。

本工具并不直接判断某个硬件已经损坏，而是基于系统日志提供证据分析和故障风险排序，帮助用户快速定位问题方向。

⸻

功能特点

事件日志分析

自动分析以下系统日志：

* Kernel-Power（Event ID 41）
* WHEA-Logger
* Windows Memory Diagnostics
* NTFS 文件系统错误
* Disk 磁盘错误
* 温度保护与热关机事件

蓝屏（BSOD）分析

自动提取并分析：

* Bugcheck Code
* 蓝屏错误代码
* 系统崩溃事件

支持将十进制 Bugcheck 代码转换为十六进制格式，并根据常见蓝屏类型关联对应硬件风险。

硬件风险评分

根据日志证据对以下硬件进行评分：

* 内存（RAM）
* 处理器（CPU）
* 存储设备（SSD / HDD）
* 电源与散热系统
* 显卡（GPU）

最终输出风险排序，帮助快速确定优先排查对象。

基于证据的诊断报告

生成详细诊断报告，包括：

* 系统异常事件统计
* 关键故障证据
* 硬件风险评分
* 初步诊断结论
* 排查建议

自动保存报告

诊断报告默认保存至桌面。

如果桌面目录不可写入，则自动保存至系统临时目录（Temp），避免诊断结果丢失。

⸻

输出示例

==================================================
Windows 硬件诊断报告
==================================================
疑似故障来源：
内存（RAM）
硬件风险评分：
RAM:       12
CPU:        4
存储设备:   2
电源散热:   1
GPU:        0
关键证据：
- Kernel-Power Event ID 41
- Bugcheck 0x1A
- Memory Diagnostics Error
建议：
- 运行 Windows 内存诊断
- 使用 MemTest86 深度检测
- 重新插拔内存条

⸻

运行环境

* Windows 10
* Windows 11
* PowerShell 5.1 或更高版本
* 管理员权限

⸻

使用方法

1. 以管理员身份打开 PowerShell

右键点击开始菜单：

* Windows Terminal（管理员）
* PowerShell（管理员）

2. 允许当前会话执行脚本

Set-ExecutionPolicy RemoteSigned -Scope Process

3. 运行脚本

.\WinCrashAnalyzer.ps1

执行完成后，系统将自动生成诊断报告。

⸻

免责声明

本工具基于 Windows 事件日志进行分析，仅用于辅助诊断。

诊断结果不应被视为硬件故障的最终结论。

建议结合以下方式进行进一步确认：

* 压力测试
* 厂商官方检测工具
* BIOS 硬件检测
* 实际硬件检查

开发者不对因误判、误操作或硬件损坏造成的任何损失承担责任。

⸻

参与贡献

欢迎提交：

* Bug 反馈
* 功能建议
* Issue
* Pull Request

如果发现：

* 错误的事件映射
* 未支持的 Bugcheck 代码
* 更准确的诊断逻辑

欢迎参与改进项目。
