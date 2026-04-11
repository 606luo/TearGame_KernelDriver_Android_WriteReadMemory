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
# 使用 AnyKernel3 打包小米13内核 ZIP 刷机包

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/out_xiaomi13"
AK3_DIR="$OUTPUT_DIR/AnyKernel3-master"
IMAGE_GZ="$OUTPUT_DIR/Image.gz"

echo -e "${CYAN}=========================================="
echo "  AnyKernel3 内核 ZIP 打包工具"
echo "  设备: 小米13 (Fuxi)"
echo -e "==========================================${NC}\n"

# 检查 AnyKernel3 目录
if [ ! -d "$AK3_DIR" ]; then
    echo -e "${RED}错误: 找不到 AnyKernel3 目录${NC}"
    echo -e "${YELLOW}请确保 AnyKernel3-master 在 out_xiaomi13/ 目录下${NC}"
    exit 1
fi

# 检查内核镜像
if [ ! -f "$IMAGE_GZ" ]; then
    echo -e "${RED}错误: 找不到编译好的内核镜像${NC}"
    echo -e "${YELLOW}请先运行: ./编译小米13内核.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 AnyKernel3 工具${NC}"
echo -e "${GREEN}✓ 找到内核镜像: Image.gz ($(ls -lh $IMAGE_GZ | awk '{print $5}'))${NC}\n"

# 进入 AnyKernel3 目录
cd "$AK3_DIR"

echo -e "${YELLOW}=========================================="
echo "  步骤 1/5: 配置 AnyKernel3"
echo -e "==========================================${NC}\n"

# 备份原始配置
if [ -f "anykernel.sh" ] && [ ! -f "anykernel.sh.backup" ]; then
    cp anykernel.sh anykernel.sh.backup
    echo -e "${BLUE}已备份原始配置${NC}"
fi

# 创建小米13专用配置
cat > anykernel.sh << 'EOF'
### AnyKernel3 Ramdisk Mod Script
## 小米13 (Fuxi) 自定义内核 - 只刷写 boot 分区

### AnyKernel setup
# global properties
properties() { '
kernel.string=Xiaomi 13 Custom Kernel by @tear
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=fuxi
device.name2=xiaomi13
device.name3=
device.name4=
device.name5=
supported.versions=13-14
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
# 明确指定操作 boot 分区（不是 init_boot）
BLOCK=/dev/block/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# 强制使用 boot 分区，跳过 init_boot
BOOTMODE=false;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
# 使用 split_boot 跳过 ramdisk 解包（适用于 GKI 设备）
# 对于小米13，内核在 boot 分区，ramdisk 在 init_boot 分区
split_boot;

# 只替换内核镜像，不修改 ramdisk
# 使用 flash_boot 跳过 ramdisk 重新打包
flash_boot;
## end boot install

EOF

echo -e "${GREEN}✓ 已配置 anykernel.sh for 小米13${NC}\n"

echo -e "${YELLOW}=========================================="
echo "  步骤 2/5: 清理旧文件"
echo -e "==========================================${NC}\n"

# 删除旧的内核镜像
rm -f Image.gz-dtb Image.gz Image Image-dtb zImage zImage-dtb
echo -e "${GREEN}✓ 已清理旧文件${NC}\n"

echo -e "${YELLOW}=========================================="
echo "  步骤 3/5: 复制内核镜像"
echo -e "==========================================${NC}\n"

# 复制内核镜像
cp "$IMAGE_GZ" Image.gz
echo -e "${GREEN}✓ 已复制 Image.gz${NC}"

# 检查是否需要 dtb（小米13通常不需要单独的dtb）
if [ -f "$OUTPUT_DIR/sm8450*.dtb" ]; then
    echo -e "${BLUE}发现 SM8450 设备树文件${NC}"
    # 如果需要可以复制
fi

echo ""

echo -e "${YELLOW}=========================================="
echo "  步骤 4/5: 打包 ZIP"
echo -e "==========================================${NC}\n"

# 获取内核版本
KERNEL_VERSION=$(strings "$IMAGE_GZ" | grep -oP "Linux version \K[0-9]+\.[0-9]+\.[0-9]+" | head -n 1 || echo "5.15.196")
BUILD_DATE=$(date +%Y%m%d)
ZIP_NAME="Xiaomi13-Custom-Kernel-${KERNEL_VERSION}-${BUILD_DATE}.zip"

echo -e "${CYAN}内核版本: ${KERNEL_VERSION}${NC}"
echo -e "${CYAN}打包日期: ${BUILD_DATE}${NC}"
echo -e "${CYAN}ZIP 文件名: ${ZIP_NAME}${NC}\n"

# 删除旧的 ZIP
rm -f "$OUTPUT_DIR"/*.zip 2>/dev/null || true

# 打包 ZIP
echo -e "${BLUE}正在打包...${NC}"

# 确保所有文件都有正确的权限
chmod 755 tools/*
chmod 644 Image.gz

# 使用 zip 命令打包
if command -v zip &> /dev/null; then
    zip -r9 "$OUTPUT_DIR/$ZIP_NAME" \
        META-INF/ \
        tools/ \
        anykernel.sh \
        Image.gz \
        -x "*.git*" "*.backup" 2>/dev/null
    
    echo -e "${GREEN}✓ ZIP 打包成功${NC}\n"
else
    echo -e "${RED}错误: 未找到 zip 命令${NC}"
    echo -e "${YELLOW}安装 zip: sudo apt install zip${NC}"
    exit 1
fi

echo -e "${YELLOW}=========================================="
echo "  步骤 5/5: 生成校验和"
echo -e "==========================================${NC}\n"

cd "$OUTPUT_DIR"

# 生成 MD5
if command -v md5sum &> /dev/null; then
    MD5=$(md5sum "$ZIP_NAME" | awk '{print $1}')
    echo "$MD5  $ZIP_NAME" > "${ZIP_NAME}.md5"
    echo -e "${GREEN}MD5:    ${MD5}${NC}"
fi

# 生成 SHA256
if command -v sha256sum &> /dev/null; then
    SHA256=$(sha256sum "$ZIP_NAME" | awk '{print $1}')
    echo "$SHA256  $ZIP_NAME" > "${ZIP_NAME}.sha256"
    echo -e "${GREEN}SHA256: ${SHA256}${NC}"
fi

# 获取文件大小
ZIP_SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')

echo ""
echo -e "${GREEN}=========================================="
echo "  ✅ 内核 ZIP 包制作完成！"
echo -e "==========================================${NC}\n"

echo -e "${CYAN}刷机包信息:${NC}"
echo -e "  文件名: ${YELLOW}${ZIP_NAME}${NC}"
echo -e "  大小:   ${YELLOW}${ZIP_SIZE}${NC}"
echo -e "  位置:   ${YELLOW}${OUTPUT_DIR}/${NC}"
echo ""

echo -e "${BLUE}=========================================="
echo "  📱 刷入说明"
echo -e "==========================================${NC}\n"

echo -e "${CYAN}方法1: TWRP Recovery 刷入 (推荐)${NC}"
echo ""
echo "1. 将 ZIP 推送到手机"
echo -e "   ${BLUE}adb push $ZIP_NAME /sdcard/${NC}"
echo ""
echo "2. 重启到 TWRP Recovery"
echo -e "   ${BLUE}adb reboot recovery${NC}"
echo ""
echo "3. 在 TWRP 中操作"
echo "   - 点击 Install"
echo "   - 选择 $ZIP_NAME"
echo "   - 滑动确认刷入"
echo "   - 刷入完成后重启"
echo ""

echo -e "${CYAN}方法2: 其他 Recovery (如 OrangeFox)${NC}"
echo "操作步骤与 TWRP 类似"
echo ""

echo -e "${CYAN}方法3: 从电脑直接 sideload${NC}"
echo "1. 进入 Recovery 的 ADB Sideload 模式"
echo -e "2. ${BLUE}adb sideload $ZIP_NAME${NC}"
echo ""

echo -e "${RED}⚠️  重要提示:${NC}"
echo "  ✓ 刷机前建议备份当前系统"
echo "  ✓ 确保已解锁 Bootloader"
echo "  ✓ 确保电量充足 (>50%)"
echo "  ✓ 准备好官方线刷包以防万一"
echo "  ✓ 首次刷入建议清除 Cache/Dalvik"
echo ""

echo -e "${YELLOW}验证刷入:${NC}"
echo "刷入后重启系统，在终端中执行："
echo -e "  ${BLUE}adb shell uname -r${NC}"
echo "应该显示: 5.15.196-gxxxxx"
echo ""

echo -e "${GREEN}=========================================="
echo "  🎉 准备就绪，可以刷入了！"
echo -e "==========================================${NC}\n"

echo -e "${CYAN}完整路径:${NC}"
echo "$OUTPUT_DIR/$ZIP_NAME"
echo ""

# 询问是否立即推送到手机
read -p "是否现在推送到手机？(需要连接 ADB) [y/N]: " push_now

if [ "$push_now" = "y" ] || [ "$push_now" = "Y" ]; then
    echo ""
    echo -e "${BLUE}检查 ADB 连接...${NC}"
    
    if adb devices | grep -q "device$"; then
        echo -e "${GREEN}✓ 设备已连接${NC}"
        echo -e "${BLUE}推送文件到手机...${NC}"
        
        if adb push "$ZIP_NAME" /sdcard/; then
            echo -e "${GREEN}✓ 推送成功${NC}"
            echo -e "${YELLOW}文件位置: /sdcard/$ZIP_NAME${NC}"
            echo ""
            
            read -p "是否立即重启到 Recovery？[y/N]: " reboot_recovery
            if [ "$reboot_recovery" = "y" ] || [ "$reboot_recovery" = "Y" ]; then
                echo -e "${BLUE}重启到 Recovery...${NC}"
                adb reboot recovery
            fi
        else
            echo -e "${RED}✗ 推送失败${NC}"
        fi
    else
        echo -e "${RED}✗ 未检测到 ADB 设备${NC}"
        echo -e "${YELLOW}请确保:${NC}"
        echo "  - 手机已连接电脑"
        echo "  - 已启用 USB 调试"
        echo "  - 已授权 ADB 连接"
    fi
fi

echo ""
echo -e "${CYAN}=========================================="
echo "  完成！"
echo -e "==========================================${NC}"

