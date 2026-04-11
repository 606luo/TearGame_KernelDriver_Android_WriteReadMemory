#!/bin/bash
# ============================================================================
# 泪心开源驱动 - TearGame Open Source Driver
# ============================================================================
# 作者 (Author): 泪心 (Tear)
# QQ: 2254013571
# 邮箱 (Email): tearhacker@outlook.com
# 电报 (Telegram): t.me/TearGame
# GitHub: github.com/tearhacker
# ============================================================================
# 本项目完全免费开源，代码明文公开
# This project is completely free and open source with clear code
# 
# 禁止用于引流盈利，保留开源版权所有
# Commercial use for profit is prohibited, all open source rights reserved
# 
# 凡是恶意盈利者需承担法律责任
# Those who maliciously profit will bear legal responsibility
# ============================================================================
# Kernel_driver_hack 快速编译启动脚本

echo "=============================================="
echo "  Kernel_driver_hack 快速编译工具"
echo "=============================================="
echo ""

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置权限
chmod +x "$SCRIPT_DIR/编译Kernel_driver_hack_优化版.sh"

echo "正在启动 Kernel_driver_hack 专用编译脚本..."
echo ""

# 执行编译脚本
exec "$SCRIPT_DIR/编译Kernel_driver_hack_优化版.sh" "$@"