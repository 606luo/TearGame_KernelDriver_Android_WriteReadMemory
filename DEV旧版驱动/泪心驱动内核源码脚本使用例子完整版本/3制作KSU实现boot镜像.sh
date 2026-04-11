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
# 制作小米13 boot.img 脚本
# 将编译好的内核打包成可刷入的 boot.img

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/out_xiaomi13"
BOOT_DIR="$SCRIPT_DIR/boot_workspace"

echo -e "${CYAN}=========================================="
echo "  小米13 Boot镜像制作工具"
echo -e "==========================================${NC}\n"

# 检查编译产物
if [ ! -f "$OUTPUT_DIR/Image.gz" ]; then
    echo -e "${RED}错误: 找不到编译好的内核镜像${NC}"
    echo -e "${YELLOW}请先运行: ./编译小米13内核.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到内核镜像: $OUTPUT_DIR/Image.gz${NC}\n"

# 创建工作目录
mkdir -p "$BOOT_DIR"

echo -e "${YELLOW}=========================================="
echo "  制作 boot.img 需要以下文件:"
echo -e "==========================================${NC}"
echo "1. 原始 boot.img (从手机提取)"
echo "2. 新编译的 Image.gz (已准备)"
echo "3. mkbootimg 工具 (需要安装)"
echo ""

# 检查是否有原始 boot.img
if [ ! -f "$BOOT_DIR/boot_original.img" ]; then
    echo -e "${YELLOW}>>> 需要提取原始 boot.img${NC}\n"
    echo -e "${CYAN}方法1: 通过 ADB 提取 (需要 Root)${NC}"
    echo -e "${BLUE}手机连接电脑后运行:${NC}"
    echo ""
    echo "  adb shell su -c \"dd if=/dev/block/by-name/boot of=/sdcard/boot_original.img\""
    echo "  adb pull /sdcard/boot_original.img $BOOT_DIR/boot_original.img"
    echo ""
    echo -e "${CYAN}方法2: 从线刷包提取${NC}"
    echo "  从小米官方线刷包中解压 boot.img"
    echo "  复制到: $BOOT_DIR/boot_original.img"
    echo ""
    read -p "按回车键继续（确认已放置 boot_original.img）..." 
    
    if [ ! -f "$BOOT_DIR/boot_original.img" ]; then
        echo -e "${RED}未找到 boot_original.img，退出${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ 找到原始 boot.img${NC}\n"

# 检查 mkbootimg 和解包工具
echo -e "${YELLOW}>>> 检查工具${NC}"

# 检查是否安装了 Android Image Kitchen
AIK_DIR="$SCRIPT_DIR/AIK"
if [ ! -d "$AIK_DIR" ]; then
    echo -e "${YELLOW}未找到 Android Image Kitchen${NC}"
    echo -e "${CYAN}是否下载并安装？(y/n)${NC}"
    read -p "> " install_aik
    
    if [ "$install_aik" = "y" ] || [ "$install_aik" = "Y" ]; then
        echo -e "${BLUE}下载 Android Image Kitchen...${NC}"
        cd "$SCRIPT_DIR"
        
        # 下载 AIK
        if command -v wget &> /dev/null; then
            wget -O AIK-Linux.tar.gz "https://github.com/osm0sis/Android-Image-Kitchen/archive/refs/heads/master.tar.gz" 2>/dev/null || \
            wget -O AIK-Linux.tar.gz "https://androidfilehost.com/?fid=890278863836285937" 2>/dev/null || {
                echo -e "${RED}下载失败，请手动下载 Android Image Kitchen${NC}"
                echo "下载地址: https://github.com/osm0sis/Android-Image-Kitchen"
                exit 1
            }
            
            tar -xzf AIK-Linux.tar.gz
            mv Android-Image-Kitchen-master AIK
            rm AIK-Linux.tar.gz
            chmod +x AIK/*.sh
            
            echo -e "${GREEN}✓ Android Image Kitchen 已安装${NC}\n"
        else
            echo -e "${RED}未找到 wget，请手动安装 Android Image Kitchen${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}跳过工具安装${NC}"
        echo ""
        echo -e "${CYAN}请手动安装以下工具之一:${NC}"
        echo "1. Android Image Kitchen: https://github.com/osm0sis/Android-Image-Kitchen"
        echo "2. mkbootimg (在 Android SDK 中)"
        echo "3. Magisk (可以用于打包)"
        exit 1
    fi
fi

# 使用 AIK 解包和重新打包
echo -e "${YELLOW}=========================================="
echo "  开始制作 boot.img"
echo -e "==========================================${NC}\n"

cd "$AIK_DIR"

# 复制原始 boot.img
cp "$BOOT_DIR/boot_original.img" ./boot.img

# 清理之前的解包
if [ -d "ramdisk" ] || [ -d "split_img" ]; then
    echo -e "${BLUE}清理旧的解包文件...${NC}"
    ./cleanup.sh
fi

# 解包 boot.img
echo -e "${BLUE}[1/3] 解包原始 boot.img...${NC}"
if ./unpackimg.sh boot.img; then
    echo -e "${GREEN}✓ 解包成功${NC}\n"
else
    echo -e "${RED}解包失败${NC}"
    exit 1
fi

# 替换内核
echo -e "${BLUE}[2/3] 替换内核镜像...${NC}"

# 查找内核镜像文件
KERNEL_FILE=$(find split_img -name "boot.img-zImage" -o -name "boot.img-kernel" | head -n 1)

if [ -z "$KERNEL_FILE" ]; then
    KERNEL_FILE="split_img/boot.img-zImage"
fi

# 备份原内核
if [ -f "$KERNEL_FILE" ]; then
    cp "$KERNEL_FILE" "$KERNEL_FILE.backup"
fi

# 复制新内核
cp "$OUTPUT_DIR/Image.gz" "$KERNEL_FILE"
echo -e "${GREEN}✓ 内核已替换${NC}\n"

# 显示镜像信息
echo -e "${CYAN}Boot 镜像信息:${NC}"
if [ -f "split_img/boot.img-cmdline" ]; then
    echo -e "${YELLOW}内核命令行:${NC}"
    cat split_img/boot.img-cmdline
    echo ""
fi

# 重新打包
echo -e "${BLUE}[3/3] 重新打包 boot.img...${NC}"
if ./repackimg.sh; then
    echo -e "${GREEN}✓ 打包成功${NC}\n"
else
    echo -e "${RED}打包失败${NC}"
    exit 1
fi

# 移动新镜像到输出目录
if [ -f "image-new.img" ]; then
    mv image-new.img "$OUTPUT_DIR/boot-xiaomi13-new.img"
    echo -e "${GREEN}=========================================="
    echo "  ✅ boot.img 制作成功！"
    echo -e "==========================================${NC}\n"
    
    SIZE=$(ls -lh "$OUTPUT_DIR/boot-xiaomi13-new.img" | awk '{print $5}')
    echo -e "${GREEN}新 boot.img:${NC} $OUTPUT_DIR/boot-xiaomi13-new.img"
    echo -e "${GREEN}文件大小:${NC} $SIZE"
    echo ""
    
    # 计算 SHA256
    if command -v sha256sum &> /dev/null; then
        SHA256=$(sha256sum "$OUTPUT_DIR/boot-xiaomi13-new.img" | awk '{print $1}')
        echo -e "${CYAN}SHA256:${NC} $SHA256"
        echo "$SHA256  boot-xiaomi13-new.img" > "$OUTPUT_DIR/boot-xiaomi13-new.img.sha256"
    fi
    
    echo ""
    echo -e "${YELLOW}=========================================="
    echo "  📱 刷入说明"
    echo -e "==========================================${NC}\n"
    
    echo -e "${CYAN}方法1: Fastboot 刷入 (推荐)${NC}"
    echo "1. 手机进入 Fastboot 模式"
    echo "   (关机后同时按 音量- + 电源键)"
    echo ""
    echo "2. 连接电脑，刷入 boot"
    echo "   fastboot flash boot boot-xiaomi13-new.img"
    echo ""
    echo "3. 重启手机"
    echo "   fastboot reboot"
    echo ""
    
    echo -e "${CYAN}方法2: 临时启动测试 (推荐先测试)${NC}"
    echo "fastboot boot boot-xiaomi13-new.img"
    echo ""
    
    echo -e "${CYAN}方法3: 通过 TWRP/Recovery 刷入${NC}"
    echo "1. 将 boot-xiaomi13-new.img 推送到手机"
    echo "   adb push boot-xiaomi13-new.img /sdcard/"
    echo ""
    echo "2. 在 TWRP 中选择 Install Image"
    echo "3. 选择 boot-xiaomi13-new.img"
    echo "4. 选择 Boot 分区刷入"
    echo ""
    
    echo -e "${RED}⚠️  重要提示:${NC}"
    echo "  ✓ 刷机前务必备份当前 boot 分区"
    echo "  ✓ 建议先用 'fastboot boot' 临时启动测试"
    echo "  ✓ 确保有线刷包以防万一"
    echo "  ✓ 如果无法启动，刷回原 boot.img"
    echo ""
    
    echo -e "${BLUE}备份命令:${NC}"
    echo "  fastboot flash boot_a boot_original.img"
    echo "  fastboot flash boot_b boot_original.img"
    echo ""
    
    echo -e "${GREEN}=========================================="
    echo "  🎉 准备就绪，可以刷入了！"
    echo -e "==========================================${NC}"
    
else
    echo -e "${RED}未找到打包后的镜像文件${NC}"
    exit 1
fi

# 清理
echo ""
read -p "是否清理工作文件？(y/n): " cleanup
if [ "$cleanup" = "y" ] || [ "$cleanup" = "Y" ]; then
    ./cleanup.sh
    rm -f boot.img
    echo -e "${GREEN}✓ 已清理工作文件${NC}"
fi

