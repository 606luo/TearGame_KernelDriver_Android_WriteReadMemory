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
# Kernel_driver_hack 内核驱动编译脚本 - 简化优化版
# ============================================================================
# 版本: 3.0
# 功能: 编译 JiangNight 的 Kernel_driver_hack 内核驱动模块
# 流程: 1. 完整编译内核 -> 2. 编译外部模块
# 内核: GKI 5.15 (android13-5.15-2024-11)
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 脚本配置
SCRIPT_VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DATE=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$SCRIPT_DIR/build_${BUILD_DATE}.log"

# 路径配置
KERNEL_ROOT="$SCRIPT_DIR/android13-5.15-2024-11"
KERNEL_SRC="$KERNEL_ROOT/common"
DRIVER_SRC="$SCRIPT_DIR/Kernel_driver_hack-main/kernel"
OUTPUT_DIR="$SCRIPT_DIR/out_kernel_hack_v3"

# 预编译工具链路径
CLANG_PATH="$KERNEL_ROOT/prebuilts/clang/host/linux-x86/clang-r450784e"
LLVM_BINUTILS="$KERNEL_ROOT/prebuilts/clang/host/linux-x86/llvm-binutils-stable"
BUILD_TOOLS="$KERNEL_ROOT/prebuilts/build-tools/linux-x86/bin"

# CPU 核心数
JOBS=$(nproc)

# ============================================================================
# 日志函数
# ============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO")    echo -e "${CYAN}ℹ️  $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR")   echo -e "${RED}❌ $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "STEP")    echo -e "\n${BOLD}${BLUE}🔧 $message${NC}\n" ;;
    esac
}

die() {
    log "ERROR" "$1"
    exit 1
}

# ============================================================================
# 设置工具链
# ============================================================================

setup_toolchain() {
    log "STEP" "设置编译工具链"
    
    # 设置 PATH
    export PATH="$CLANG_PATH/bin:$LLVM_BINUTILS/bin:$BUILD_TOOLS:$PATH"
    
    # 验证 clang
    if ! command -v clang &> /dev/null; then
        die "未找到 clang，请检查工具链路径"
    fi
    
    log "SUCCESS" "Clang: $(clang --version | head -1)"
}

# ============================================================================
# 设置编译环境变量
# ============================================================================

setup_env() {
    export ARCH=arm64
    export SUBARCH=arm64
    export LLVM=1
    export LLVM_IAS=1
    export CC=clang
    export LD=ld.lld
    export AR=llvm-ar
    export NM=llvm-nm
    export STRIP=llvm-strip
    export OBJCOPY=llvm-objcopy
    export OBJDUMP=llvm-objdump
    export READELF=llvm-readelf
    export HOSTCC=clang
    export HOSTCXX=clang++
    export HOSTLD=ld.lld
    export HOSTAR=llvm-ar
    export CROSS_COMPILE=aarch64-linux-gnu-
}

# ============================================================================
# 检查环境
# ============================================================================

check_env() {
    log "STEP" "检查编译环境"
    
    [ -d "$KERNEL_SRC" ] || die "内核源码不存在: $KERNEL_SRC"
    [ -d "$DRIVER_SRC" ] || die "驱动源码不存在: $DRIVER_SRC"
    [ -f "$DRIVER_SRC/entry.c" ] || die "驱动源文件不存在: entry.c"
    
    log "SUCCESS" "内核源码: $KERNEL_SRC"
    log "SUCCESS" "驱动源码: $DRIVER_SRC"
    
    mkdir -p "$OUTPUT_DIR"
}

# ============================================================================
# 第一步: 配置内核
# ============================================================================

configure_kernel() {
    log "STEP" "配置内核"
    
    cd "$KERNEL_SRC"
    
    # 使用 GKI 配置
    if [ -f "arch/arm64/configs/gki_defconfig" ]; then
        log "INFO" "使用 gki_defconfig..."
        make ARCH=arm64 LLVM=1 gki_defconfig 2>&1 | tee -a "$LOG_FILE"
    else
        log "INFO" "使用 defconfig..."
        make ARCH=arm64 LLVM=1 defconfig 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 禁用模块签名和安全选项 (方便加载外部模块)
    log "INFO" "调整内核配置..."
    ./scripts/config --disable CONFIG_MODVERSIONS
    ./scripts/config --disable CONFIG_MODULE_SIG
    ./scripts/config --disable CONFIG_MODULE_SIG_FORCE
    ./scripts/config --enable CONFIG_MODULE_FORCE_LOAD
    ./scripts/config --enable CONFIG_MODULE_FORCE_UNLOAD
    ./scripts/config --disable CONFIG_TRIM_UNUSED_KSYMS
    
    # 更新配置
    make ARCH=arm64 LLVM=1 olddefconfig 2>&1 | tee -a "$LOG_FILE"
    
    log "SUCCESS" "内核配置完成"
}

# ============================================================================
# 第二步: 完整编译内核 (生成 Module.symvers)
# ============================================================================

build_kernel() {
    log "STEP" "编译完整内核 (生成 Module.symvers)"
    
    cd "$KERNEL_SRC"
    
    log "INFO" "开始编译内核，使用 $JOBS 个线程..."
    log "INFO" "这可能需要 30-60 分钟，请耐心等待..."
    
    # 完整编译内核
    make ARCH=arm64 \
         LLVM=1 \
         LLVM_IAS=1 \
         CC=clang \
         LD=ld.lld \
         AR=llvm-ar \
         NM=llvm-nm \
         STRIP=llvm-strip \
         OBJCOPY=llvm-objcopy \
         OBJDUMP=llvm-objdump \
         READELF=llvm-readelf \
         HOSTCC=clang \
         HOSTCXX=clang++ \
         HOSTLD=ld.lld \
         HOSTAR=llvm-ar \
         -j$JOBS 2>&1 | tee -a "$LOG_FILE"
    
    # 检查 Module.symvers 是否生成
    if [ -f "$KERNEL_SRC/Module.symvers" ]; then
        local symvers_count=$(wc -l < "$KERNEL_SRC/Module.symvers")
        log "SUCCESS" "内核编译完成！Module.symvers 包含 $symvers_count 个符号"
    else
        die "内核编译失败，未生成 Module.symvers"
    fi
    
    # 检查 vmlinux
    if [ -f "$KERNEL_SRC/vmlinux" ]; then
        log "SUCCESS" "vmlinux 已生成"
    fi
}

# ============================================================================
# 第三步: 编译外部驱动模块
# ============================================================================

build_module() {
    log "STEP" "编译 kernel_hack.ko 外部模块"
    
    cd "$KERNEL_SRC"
    
    # 清理驱动目录
    log "INFO" "清理驱动目录..."
    make -C "$KERNEL_SRC" M="$DRIVER_SRC" clean 2>/dev/null || true
    
    # 编译外部模块
    log "INFO" "编译外部模块..."
    make -C "$KERNEL_SRC" \
        M="$DRIVER_SRC" \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        STRIP=llvm-strip \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        READELF=llvm-readelf \
        HOSTCC=clang \
        HOSTCXX=clang++ \
        HOSTLD=ld.lld \
        HOSTAR=llvm-ar \
        -j$JOBS \
        modules 2>&1 | tee -a "$LOG_FILE"
    
    # 检查模块是否生成
    if [ -f "$DRIVER_SRC/kernel_hack.ko" ]; then
        cp "$DRIVER_SRC/kernel_hack.ko" "$OUTPUT_DIR/"
        local size=$(ls -lh "$OUTPUT_DIR/kernel_hack.ko" | awk '{print $5}')
        log "SUCCESS" "模块编译成功！大小: $size"
    else
        die "模块编译失败，未找到 kernel_hack.ko"
    fi
}

# ============================================================================
# 验证模块
# ============================================================================

verify_module() {
    log "STEP" "验证模块"
    
    local ko_file="$OUTPUT_DIR/kernel_hack.ko"
    
    # 检查架构
    local file_type=$(file "$ko_file")
    if echo "$file_type" | grep -q "ARM aarch64"; then
        log "SUCCESS" "架构正确: ARM64"
    else
        log "WARN" "架构可能不正确: $file_type"
    fi
    
    # 显示模块信息
    if command -v modinfo &> /dev/null; then
        log "INFO" "模块信息:"
        modinfo "$ko_file" 2>/dev/null | head -10
    fi
}

# ============================================================================
# 生成辅助脚本
# ============================================================================

generate_scripts() {
    log "STEP" "生成辅助脚本"
    
    # 模块信息
    cat > "$OUTPUT_DIR/module_info.txt" << EOF
Kernel_driver_hack 模块信息
============================
编译时间: $(date '+%Y-%m-%d %H:%M:%S')
内核版本: $(cd "$KERNEL_SRC" && make kernelrelease 2>/dev/null || echo "5.15.x")
模块大小: $(ls -lh "$OUTPUT_DIR/kernel_hack.ko" | awk '{print $5}')
MD5: $(md5sum "$OUTPUT_DIR/kernel_hack.ko" | awk '{print $1}')

使用方法:
  adb push kernel_hack.ko /data/local/tmp/
  adb shell su -c "insmod /data/local/tmp/kernel_hack.ko"
  adb shell lsmod | grep kernel_hack
EOF

    # 加载脚本
    cat > "$OUTPUT_DIR/load.sh" << 'EOF'
#!/system/bin/sh
MODULE="/data/local/tmp/kernel_hack.ko"
[ "$(id -u)" != "0" ] && echo "需要 Root 权限" && exit 1
[ ! -f "$MODULE" ] && echo "模块不存在: $MODULE" && exit 1
rmmod kernel_hack 2>/dev/null
insmod "$MODULE" && echo "加载成功" || insmod -f "$MODULE" && echo "强制加载成功"
lsmod | grep kernel_hack
EOF
    chmod +x "$OUTPUT_DIR/load.sh"

    # 部署脚本
    cat > "$OUTPUT_DIR/deploy.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
adb push "$SCRIPT_DIR/kernel_hack.ko" /data/local/tmp/
adb push "$SCRIPT_DIR/load.sh" /data/local/tmp/
adb shell chmod +x /data/local/tmp/load.sh
echo "部署完成！运行: adb shell su -c '/data/local/tmp/load.sh'"
EOF
    chmod +x "$OUTPUT_DIR/deploy.sh"
    
    log "SUCCESS" "辅助脚本已生成"
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    echo -e "${BOLD}${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Kernel_driver_hack 编译脚本 v${SCRIPT_VERSION}"
    echo "  流程: 配置内核 -> 编译内核 -> 编译模块"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}\n"
    
    # 初始化日志
    echo "编译开始: $(date)" > "$LOG_FILE"
    
    # 执行编译流程
    setup_toolchain      # 1. 设置工具链
    setup_env            # 2. 设置环境变量
    check_env            # 3. 检查环境
    configure_kernel     # 4. 配置内核
    build_kernel         # 5. 完整编译内核 (生成 Module.symvers)
    build_module         # 6. 编译外部模块
    verify_module        # 7. 验证模块
    generate_scripts     # 8. 生成辅助脚本
    
    # 完成
    echo -e "\n${BOLD}${GREEN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ 编译完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}\n"
    
    echo -e "${CYAN}输出目录: $OUTPUT_DIR${NC}"
    ls -lah "$OUTPUT_DIR"
    
    echo -e "\n${YELLOW}快速部署:${NC}"
    echo "  cd $OUTPUT_DIR && ./deploy.sh"
    echo ""
    echo -e "${GREEN}日志: $LOG_FILE${NC}"
}

main "$@"
