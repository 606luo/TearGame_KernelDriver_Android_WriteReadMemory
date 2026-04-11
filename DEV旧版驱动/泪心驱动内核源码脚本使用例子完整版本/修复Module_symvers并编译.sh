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
# 修复 Module.symvers 并编译 Kernel_driver_hack 模块
# 解决 modpost 阶段 "undefined symbol" 错误

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="$SCRIPT_DIR/android13-5.15-2024-11/common"
DRIVER_SRC="$SCRIPT_DIR/Kernel_driver_hack-main/kernel"
OUTPUT_DIR="$SCRIPT_DIR/out_kernel_hack_v3"
LOG_FILE="$SCRIPT_DIR/build_$(date +%Y%m%d_%H%M%S).log"

# 设置工具链
CLANG_PATH="$SCRIPT_DIR/android13-5.15-2024-11/prebuilts/clang/host/linux-x86/clang-r450784e"
export PATH="$CLANG_PATH/bin:$PATH"

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  修复 Module.symvers 并编译模块${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# 检查目录
if [ ! -d "$KERNEL_SRC" ]; then
    echo -e "${RED}错误: 内核源码目录不存在: $KERNEL_SRC${NC}"
    exit 1
fi

if [ ! -d "$DRIVER_SRC" ]; then
    echo -e "${RED}错误: 驱动源码目录不存在: $DRIVER_SRC${NC}"
    exit 1
fi

cd "$KERNEL_SRC"

echo -e "${YELLOW}步骤 1: 检查 Module.symvers 状态${NC}"
if [ -f "Module.symvers" ] && [ -s "Module.symvers" ]; then
    SYMVERS_LINES=$(wc -l < Module.symvers)
    echo -e "${GREEN}✓ Module.symvers 存在，包含 $SYMVERS_LINES 个符号${NC}"
else
    echo -e "${YELLOW}⚠ Module.symvers 为空或不存在${NC}"
    echo ""
    echo -e "${YELLOW}步骤 2: 生成内核符号表 (这需要一些时间...)${NC}"
    echo -e "${CYAN}正在编译内核以生成符号表...${NC}"
    
    # 使用小米13配置
    if [ -f "$SCRIPT_DIR/515内核小米13手机真实配置文件/.config" ]; then
        cp "$SCRIPT_DIR/515内核小米13手机真实配置文件/.config" .config
        echo -e "${GREEN}✓ 使用小米13配置文件${NC}"
    fi
    
    # 禁用不需要的安全特性
    scripts/config --disable CONFIG_TRIM_UNUSED_KSYMS 2>/dev/null || true
    scripts/config --disable CONFIG_CFI_CLANG 2>/dev/null || true
    scripts/config --disable CONFIG_SHADOW_CALL_STACK 2>/dev/null || true
    scripts/config --disable CONFIG_MODVERSIONS 2>/dev/null || true
    
    # 生成配置
    make ARCH=arm64 LLVM=1 olddefconfig >> "$LOG_FILE" 2>&1
    
    # 编译 vmlinux 和模块以生成 Module.symvers
    echo -e "${CYAN}编译内核 (仅生成符号表，约需 10-30 分钟)...${NC}"
    make ARCH=arm64 LLVM=1 LLVM_IAS=1 \
        CROSS_COMPILE=aarch64-linux-gnu- \
        -j$(nproc) vmlinux modules >> "$LOG_FILE" 2>&1 || {
        echo -e "${RED}内核编译失败，查看日志: $LOG_FILE${NC}"
        exit 1
    }
    
    if [ -f "Module.symvers" ] && [ -s "Module.symvers" ]; then
        SYMVERS_LINES=$(wc -l < Module.symvers)
        echo -e "${GREEN}✓ Module.symvers 生成成功，包含 $SYMVERS_LINES 个符号${NC}"
    else
        echo -e "${RED}✗ Module.symvers 生成失败${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}步骤 3: 准备模块编译环境${NC}"
make ARCH=arm64 LLVM=1 modules_prepare >> "$LOG_FILE" 2>&1
echo -e "${GREEN}✓ 模块编译环境准备完成${NC}"

echo ""
echo -e "${YELLOW}步骤 4: 清理旧的编译产物${NC}"
rm -f "$DRIVER_SRC"/*.o "$DRIVER_SRC"/*.ko "$DRIVER_SRC"/.*.cmd 2>/dev/null || true
rm -f "$DRIVER_SRC"/Module.symvers "$DRIVER_SRC"/modules.order 2>/dev/null || true
echo -e "${GREEN}✓ 清理完成${NC}"

echo ""
echo -e "${YELLOW}步骤 5: 编译 kernel_hack.ko 模块${NC}"

# 创建优化的 Makefile
cat > "$DRIVER_SRC/Makefile" << 'MAKEFILE_EOF'
MODULE_NAME = kernel_hack
obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-objs := entry.o memory.o process.o

# 禁用所有安全特性
ccflags-y := -fno-sanitize=cfi -fno-sanitize=cfi-icall
ccflags-y += -fno-sanitize=shadow-call-stack -fno-stack-protector
ccflags-y += -fno-sanitize=address -fno-sanitize=kcfi
ccflags-y += -Wno-unused-function -Wno-unused-variable
ccflags-y += -DMODULE_VERMAGIC_DISABLE -DCOMPAT_MODE=1

CFLAGS_REMOVE_entry.o := -fsanitize=cfi -fsanitize=shadow-call-stack
CFLAGS_REMOVE_memory.o := -fsanitize=cfi -fsanitize=shadow-call-stack
CFLAGS_REMOVE_process.o := -fsanitize=cfi -fsanitize=shadow-call-stack
MAKEFILE_EOF

# 编译模块
make -C "$KERNEL_SRC" M="$DRIVER_SRC" \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    modules >> "$LOG_FILE" 2>&1

# 检查结果
if [ -f "$DRIVER_SRC/kernel_hack.ko" ]; then
    echo -e "${GREEN}✓ kernel_hack.ko 编译成功！${NC}"
    
    mkdir -p "$OUTPUT_DIR"
    cp "$DRIVER_SRC/kernel_hack.ko" "$OUTPUT_DIR/"
    
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  编译成功！${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "模块位置: ${CYAN}$OUTPUT_DIR/kernel_hack.ko${NC}"
    echo -e "模块大小: $(ls -lh "$OUTPUT_DIR/kernel_hack.ko" | awk '{print $5}')"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  adb push $OUTPUT_DIR/kernel_hack.ko /data/local/tmp/"
    echo "  adb shell su -c 'insmod /data/local/tmp/kernel_hack.ko'"
else
    echo -e "${RED}✗ 编译失败，查看日志: $LOG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}最后 50 行日志:${NC}"
    tail -50 "$LOG_FILE"
    exit 1
fi
