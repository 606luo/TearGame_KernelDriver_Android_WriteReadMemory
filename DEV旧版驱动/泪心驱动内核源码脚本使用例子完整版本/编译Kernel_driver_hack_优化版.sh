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
# Kernel_driver_hack 专用编译脚本 - 优化版
# 版本: 3.0
# 目标: 编译 JiangNight 的 Kernel_driver_hack 驱动模块
# 适用: Android 5.15.x 内核 (谷歌通用内核源码)

# ============================================================================
# 颜色定义和基础配置
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 脚本配置
SCRIPT_VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DATE=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$SCRIPT_DIR/kernel_hack_build_${BUILD_DATE}.log"

# 错误处理
set -eE
trap 'error_handler $? $LINENO' ERR

# ============================================================================
# 工具函数
# ============================================================================

# 错误处理函数
error_handler() {
    local exit_code=$1
    local line_number=$2
    echo -e "\n${RED}❌ 编译失败！${NC}"
    echo -e "${RED}错误代码: $exit_code，行号: $line_number${NC}"
    echo -e "${YELLOW}查看详细日志: $LOG_FILE${NC}"
    exit $exit_code
}

# 日志函数
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO")  echo -e "${CYAN}ℹ️  $message${NC}" ;;
        "WARN")  echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "STEP") echo -e "\n${BOLD}${BLUE}🔧 $message${NC}\n" ;;
    esac
}
# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "ERROR" "命令 '$1' 未找到，请安装相关工具"
        exit 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        log "ERROR" "文件不存在: $1"
        exit 1
    fi
}

# 检查目录是否存在
check_directory() {
    if [ ! -d "$1" ]; then
        log "ERROR" "目录不存在: $1"
        exit 1
    fi
}

# 安全删除函数
safe_rm() {
    if [ -n "$1" ] && [ "$1" != "/" ] && [ "$1" != "$HOME" ]; then
        rm -rf "$1" 2>/dev/null || true
    fi
}

# ============================================================================
# 环境检查和初始化
# ============================================================================

init_environment() {
    log "STEP" "初始化 Kernel_driver_hack 编译环境"
    
    # 检查必要的工具
    log "INFO" "检查编译工具链..."
    check_command "make"
    
    # 检查交叉编译工具链（更灵活的检查）
    HAS_CROSS_COMPILE=false
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        HAS_CROSS_COMPILE=true
        log "SUCCESS" "找到 GCC 交叉编译工具链: $(aarch64-linux-gnu-gcc --version | head -1)"
    elif command -v clang &> /dev/null; then
        HAS_CROSS_COMPILE=true
        log "INFO" "找到 Clang 编译器，将使用 LLVM 工具链"
    else
        log "ERROR" "未找到交叉编译工具链（aarch64-linux-gnu-gcc 或 clang）"
        log "ERROR" "请运行: sudo apt install gcc-aarch64-linux-gnu clang llvm"
        exit 1
    fi
    
    check_command "clang"
    
    # 设置工作目录
    cd "$SCRIPT_DIR"
    
    # 检查内核源码目录
    KERNEL_SRC="$SCRIPT_DIR/kernel"
    check_directory "$KERNEL_SRC"
    
    # 设置驱动源码路径
    DRIVER_SRC="$SCRIPT_DIR/Kernel_driver_hack-main/kernel"
    check_directory "$DRIVER_SRC"
    
    # 检查驱动源文件
    check_file "$DRIVER_SRC/entry.c"
    check_file "$DRIVER_SRC/memory.c"
    check_file "$DRIVER_SRC/process.c"
    check_file "$DRIVER_SRC/comm.h"
    
    # 创建输出目录
    OUTPUT_DIR="$SCRIPT_DIR/out_kernel_hack_v3"
    mkdir -p "$OUTPUT_DIR"
    
    log "SUCCESS" "环境检查完成"
    log "INFO" "内核源码: $KERNEL_SRC"
    log "INFO" "驱动源码: $DRIVER_SRC"
    log "INFO" "输出目录: $OUTPUT_DIR"
}
# ============================================================================
# 编译环境配置
# ============================================================================

setup_build_environment() {
    log "STEP" "配置编译环境"
    
    # 基础环境变量
    export ARCH=arm64
    export SUBARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export LLVM=1
    export LLVM_IAS=1
    
    # 编译器优化选项
    export CC=clang
    export CXX=clang++
    export AR=llvm-ar
    export NM=llvm-nm
    export STRIP=llvm-strip
    export OBJCOPY=llvm-objcopy
    export OBJDUMP=llvm-objdump
    export READELF=llvm-readelf
    
    # 超强兼容性编译选项
    local COMPAT_FLAGS=(
        "-fno-sanitize=cfi"
        "-fno-sanitize=cfi-icall"
        "-fno-sanitize=kcfi"
        "-fno-stack-protector"
        "-fno-sanitize=shadow-call-stack"
        "-fno-jump-tables"
        "-fno-asynchronous-unwind-tables"
        "-fno-strict-aliasing"
        "-fno-delete-null-pointer-checks"
        "-fno-PIE"
        "-fno-pie"
        "-mcmodel=large"
        "-mno-implicit-float"
        "-Wno-unused-function"
        "-Wno-unused-variable"
        "-Wno-format"
        "-Wno-sign-compare"
    )
    
    export KCFLAGS="${COMPAT_FLAGS[*]}"
    export KAFLAGS="${COMPAT_FLAGS[*]}"
    export CFLAGS_MODULE="${COMPAT_FLAGS[*]}"
    export EXTRA_CFLAGS="${COMPAT_FLAGS[*]}"
    
    # 禁用内核安全检查
    export CONFIG_MODVERSIONS=n
    export CONFIG_MODULE_SIG=n
    export CONFIG_MODULE_SIG_FORCE=n
    export CONFIG_MODULE_SIG_ALL=n
    export CONFIG_CFI_CLANG=n
    export CONFIG_SHADOW_CALL_STACK=n
    
    log "SUCCESS" "编译环境配置完成"
}
# ============================================================================
# 内核配置优化
# ============================================================================

prepare_kernel_config() {
    log "STEP" "准备内核配置"
    
    cd "$KERNEL_SRC"
    
    # 备份现有配置
    if [ -f ".config" ]; then
        cp .config ".config.backup.$(date +%s)"
        log "INFO" "已备份现有内核配置"
    fi
    
    # 生成基础配置
    log "INFO" "生成 GKI 基础配置..."
    make ARCH=arm64 gki_defconfig &>> "$LOG_FILE"
    
    # 应用兼容性配置
    log "INFO" "应用兼容性优化配置..."
    
    # 禁用模块签名和版本检查
    local DISABLE_CONFIGS=(
        "CONFIG_MODVERSIONS"
        "CONFIG_MODULE_SIG"
        "CONFIG_MODULE_SIG_FORCE"
        "CONFIG_MODULE_SIG_ALL"
        "CONFIG_MODULE_SRCVERSION_ALL"
        "CONFIG_CFI_CLANG"
        "CONFIG_SHADOW_CALL_STACK"
        "CONFIG_KASAN"
        "CONFIG_UBSAN"
        "CONFIG_KCOV"
        "CONFIG_DEBUG_INFO_BTF"
        "CONFIG_SECURITY_LOADPIN"
        "CONFIG_HARDENED_USERCOPY"
    )
    
    for config in "${DISABLE_CONFIGS[@]}"; do
        scripts/config --disable "$config" &>> "$LOG_FILE" || true
    done
    
    # 启用兼容性选项
    local ENABLE_CONFIGS=(
        "CONFIG_CFI_PERMISSIVE"
        "CONFIG_MODULES"
        "CONFIG_MODULE_UNLOAD"
        "CONFIG_MODULE_FORCE_UNLOAD"
        "CONFIG_MISC_FILESYSTEMS"
    )
    
    for config in "${ENABLE_CONFIGS[@]}"; do
        scripts/config --enable "$config" &>> "$LOG_FILE" || true
    done
    
    # 重新生成配置
    make ARCH=arm64 olddefconfig &>> "$LOG_FILE"
    
    # 准备模块编译环境
    log "INFO" "准备模块编译环境..."
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 modules_prepare &>> "$LOG_FILE"
    
    log "SUCCESS" "内核配置准备完成"
}
# ============================================================================
# 创建驱动模块 Makefile
# ============================================================================

create_driver_makefile() {
    log "STEP" "创建 Kernel_driver_hack 模块 Makefile"
    
    # 备份原始 Makefile
    if [ -f "$DRIVER_SRC/Makefile" ] && [ ! -f "$DRIVER_SRC/Makefile.original" ]; then
        cp "$DRIVER_SRC/Makefile" "$DRIVER_SRC/Makefile.original"
        log "INFO" "已备份原始 Makefile"
    fi
    
    # 创建优化的 Makefile
    cat > "$DRIVER_SRC/Makefile" << 'EOF'
# Kernel_driver_hack 模块 Makefile
# 版本: 3.0 - JiangNight 驱动专用优化版

MODULE_NAME = kernel_hack
obj-m += $(MODULE_NAME).o

# 模块源文件
$(MODULE_NAME)-objs := entry.o memory.o process.o

# ============================================================================
# 基础编译选项
# ============================================================================

ccflags-y := -Wall -Wno-declaration-after-statement -Wno-unused-function
ccflags-y += -Wno-unused-variable -Wno-format -Wno-sign-compare
ccflags-y += -Wno-implicit-function-declaration -Wno-int-conversion

# ============================================================================
# 超强 CFI/安全特性禁用 (多重保险)
# ============================================================================

# 方法 1: 直接禁用所有 CFI 相关
ccflags-y += -fno-sanitize=cfi
ccflags-y += -fno-sanitize=cfi-icall
ccflags-y += -fno-sanitize=cfi-derived-cast
ccflags-y += -fno-sanitize=cfi-unrelated-cast
ccflags-y += -fno-sanitize=kcfi
ccflags-y += -fno-stack-protector
ccflags-y += -fno-sanitize=shadow-call-stack
ccflags-y += -fno-sanitize=address
ccflags-y += -fno-sanitize=kernel-address

# 方法 2: 移除内核默认标志
CFLAGS_REMOVE_$(MODULE_NAME).o := -fsanitize=cfi
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=cfi-icall
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=cfi-derived-cast
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=cfi-unrelated-cast
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=kcfi
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=shadow-call-stack
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=address
CFLAGS_REMOVE_$(MODULE_NAME).o += -fsanitize=kernel-address
CFLAGS_REMOVE_$(MODULE_NAME).o += -fstack-protector-strong
CFLAGS_REMOVE_$(MODULE_NAME).o += -fstack-protector

# 方法 3: 对象文件级别强制设置
CFLAGS_$(MODULE_NAME).o := -fno-sanitize=all
CFLAGS_$(MODULE_NAME).o += -fno-stack-protector
CFLAGS_$(MODULE_NAME).o += -fno-sanitize=shadow-call-stack

# 单独文件的编译选项
CFLAGS_entry.o := -fno-sanitize=all -fno-stack-protector
CFLAGS_memory.o := -fno-sanitize=all -fno-stack-protector
CFLAGS_process.o := -fno-sanitize=all -fno-stack-protector

# ============================================================================
# 额外兼容性优化
# ============================================================================

# ============================================================================
# 额外兼容性优化
# ============================================================================

# 禁用各种优化和检查
ccflags-y += -fno-jump-tables
ccflags-y += -fno-asynchronous-unwind-tables
ccflags-y += -fno-strict-aliasing
ccflags-y += -fno-delete-null-pointer-checks
ccflags-y += -fno-PIE -fno-pie
ccflags-y += -mcmodel=large
ccflags-y += -mno-implicit-float

# 禁用调试信息生成
ccflags-y += -g0
ccflags-y += -fno-dwarf2-cfi-asm

# 优化级别设置
ccflags-y += -O2
ccflags-y += -fno-omit-frame-pointer

# ============================================================================
# 内核版本兼容性处理
# ============================================================================

# 禁用版本魔数检查
ccflags-y += -DMODULE_VERMAGIC_DISABLE
ccflags-y += -DCONFIG_MODVERSIONS_DISABLE

# 定义兼容性宏
ccflags-y += -DCOMPAT_MODE=1
ccflags-y += -DUNIVERSAL_MODULE=1
ccflags-y += -DKERNEL_HACK_DRIVER=1

# ============================================================================
# 全局级别设置 (最后保险)
# ============================================================================

KBUILD_CFLAGS += -fno-sanitize=all
KBUILD_CFLAGS += -fno-stack-protector
KBUILD_AFLAGS += -fno-sanitize=all

# ============================================================================
# 编译目标
# ============================================================================

KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.order *.symvers .*.cmd
	rm -f Module.markers modules.order Module.symvers

install: all
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) modules_install

.PHONY: all clean install
EOF

    log "SUCCESS" "Kernel_driver_hack Makefile 创建完成"
}
# ============================================================================
# 模块编译
# ============================================================================

compile_driver_module() {
    log "STEP" "编译 Kernel_driver_hack 模块"
    
    cd "$KERNEL_SRC"
    
    # 清理旧文件
    log "INFO" "清理旧的编译文件..."
    safe_rm "$DRIVER_SRC"/*.o
    safe_rm "$DRIVER_SRC"/*.ko
    safe_rm "$DRIVER_SRC"/.*.cmd
    safe_rm "$DRIVER_SRC"/Module.symvers
    safe_rm "$DRIVER_SRC"/modules.order
    safe_rm "$OUTPUT_DIR"/*
    
    # 开始编译
    log "INFO" "开始编译 kernel_hack.ko..."
    log "INFO" "编译选项: 超强兼容性模式 + JiangNight 驱动优化"
    
    # 编译命令
    local MAKE_CMD=(
        "make"
        "-C" "$KERNEL_SRC"
        "M=$DRIVER_SRC"
        "ARCH=arm64"
        "CROSS_COMPILE=aarch64-linux-gnu-"
        "LLVM=1"
        "LLVM_IAS=1"
        "CC=clang"
        "EXTRA_CFLAGS=$EXTRA_CFLAGS"
        "-j$(nproc)"
    )
    
    log "INFO" "执行编译命令: ${MAKE_CMD[*]}"
    
    if "${MAKE_CMD[@]}" &>> "$LOG_FILE"; then
        log "SUCCESS" "模块编译完成"
    else
        log "WARN" "编译可能有警告，检查输出..."
        # 即使有警告也继续，因为可能只是非致命警告
    fi
    
    # 查找生成的模块文件
    local KO_FILE
    KO_FILE=$(find "$DRIVER_SRC" -name "kernel_hack.ko" -type f | head -n 1)
    
    if [ -z "$KO_FILE" ]; then
        log "ERROR" "未找到编译生成的 kernel_hack.ko 文件"
        log "ERROR" "请检查编译日志: $LOG_FILE"
        exit 1
    fi
    
    log "SUCCESS" "找到编译生成的模块: $KO_FILE"
    
    # 复制到输出目录
    cp "$KO_FILE" "$OUTPUT_DIR/kernel_hack.ko"
    log "SUCCESS" "模块已复制到输出目录"
}
# ============================================================================
# 生成模块信息和工具
# ============================================================================

generate_driver_info() {
    log "STEP" "生成 Kernel_driver_hack 模块信息"
    
    cd "$KERNEL_SRC"
    
    # 获取模块信息
    local KERNEL_VER
    KERNEL_VER=$(make kernelrelease 2>/dev/null || echo "unknown")
    
    local MODULE_SIZE
    MODULE_SIZE=$(ls -lh "$OUTPUT_DIR/kernel_hack.ko" | awk '{print $5}')
    
    local MODULE_MD5
    MODULE_MD5=$(md5sum "$OUTPUT_DIR/kernel_hack.ko" | awk '{print $1}')
    
    # 生成详细的模块信息文件
    cat > "$OUTPUT_DIR/module_info.txt" << EOF
Kernel_driver_hack 驱动模块 - 优化版 v${SCRIPT_VERSION}
================================================================

模块信息:
  模块名称: kernel_hack.ko
  作者: JiangNight
  功能: Android/Linux 内核驱动读写内存
  设备名: JiangNight (/dev/JiangNight)

编译信息:
  编译时间: $(date '+%Y-%m-%d %H:%M:%S')
  编译版本: ${SCRIPT_VERSION}
  内核版本: ${KERNEL_VER}
  模块大小: ${MODULE_SIZE}
  MD5校验: ${MODULE_MD5}
  编译架构: ARM64
  编译器: LLVM/Clang

功能特性:
  ✅ 进程内存读取 (OP_READ_MEM)
  ✅ 进程内存写入 (OP_WRITE_MEM)
  ✅ 模块基址获取 (OP_MODULE_BASE)
  ✅ 初始化密钥验证 (OP_INIT_KEY)
  ✅ 支持任意进程 PID
  ✅ 支持任意内存地址

兼容性特性:
  ✅ 完全禁用 CFI/KCFI
  ✅ 禁用 vermagic 检查
  ✅ 禁用模块签名验证
  ✅ 禁用栈保护
  ✅ 禁用地址消毒
  ✅ 多重编译选项保护
  ✅ 最大化兼容性设计

IOCTL 接口:
  - OP_INIT_KEY (0x800): 初始化验证密钥
  - OP_READ_MEM (0x801): 读取进程内存
  - OP_WRITE_MEM (0x802): 写入进程内存
  - OP_MODULE_BASE (0x803): 获取模块基址

适用设备:
  - Android 13+ (5.15.x 内核)
  - 小米、OPPO、vivo、一加、华为等品牌
  - 需要 Root 权限
  - 建议临时禁用 SELinux

使用说明:
  1. 推送模块到设备: adb push kernel_hack.ko /data/local/tmp/
  2. 使用加载脚本: adb shell su -c "/data/local/tmp/load_kernel_hack.sh"
  3. 验证加载状态: adb shell lsmod | grep kernel_hack
  4. 设备节点: /dev/JiangNight

安全提醒:
  ⚠️  本模块仅供学习和研究使用
  ⚠️  请遵守相关法律法规
  ⚠️  不得用于非法用途或商业用途
  ⚠️  使用前请备份重要数据

编译日志: ${LOG_FILE}
EOF

    log "SUCCESS" "模块信息文件已生成"
}
# ============================================================================
# 生成智能加载脚本
# ============================================================================

create_kernel_hack_loader() {
    log "STEP" "创建 Kernel_driver_hack 智能加载脚本"
    
    # 创建增强版加载脚本
    cat > "$OUTPUT_DIR/load_kernel_hack.sh" << 'EOF'
#!/system/bin/sh
# Kernel_driver_hack 智能加载脚本 v3.0
# 专为 JiangNight 的内核驱动设计

MODULE_PATH="/data/local/tmp/kernel_hack.ko"
LOG_FILE="/data/local/tmp/kernel_hack_load.log"
DEVICE_NODE="/dev/JiangNight"

# 颜色定义 (如果支持)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    NC=''
fi

# 日志函数
log_msg() {
    local level=$1
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    
    case $level in
        "INFO")  echo -e "${CYAN}[INFO]${NC} $msg" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $msg" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $msg" ;;
    esac
}

# 清理日志
> "$LOG_FILE"

echo "=============================================="
echo "  Kernel_driver_hack 智能加载器 v3.0"
echo "  作者: JiangNight"
echo "=============================================="
echo ""

# 检查 Root 权限
if [ "$(id -u)" != "0" ]; then
    log_msg "ERROR" "需要 Root 权限才能加载内核模块"
    echo "请使用: su -c \"$0\""
    exit 1
fi

# 检查模块文件
if [ ! -f "$MODULE_PATH" ]; then
    log_msg "ERROR" "找不到模块文件: $MODULE_PATH"
    echo "请先执行: adb push kernel_hack.ko /data/local/tmp/"
    exit 1
fi

# 获取设备信息
KERNEL_VER=$(uname -r)
DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Unknown")

log_msg "INFO" "设备信息:"
log_msg "INFO" "  型号: $DEVICE_MODEL"
log_msg "INFO" "  Android版本: $ANDROID_VER"
log_msg "INFO" "  内核版本: $KERNEL_VER"
log_msg "INFO" "  SELinux状态: $SELINUX_STATUS"

# 检查是否已加载
if lsmod 2>/dev/null | grep -q kernel_hack; then
    log_msg "WARN" "模块已加载，先尝试卸载..."
    if rmmod kernel_hack 2>/dev/null; then
        log_msg "SUCCESS" "旧模块已卸载"
    else
        log_msg "WARN" "卸载旧模块失败，继续尝试加载"
    fi
fi

# 删除旧的设备节点
if [ -e "$DEVICE_NODE" ]; then
    log_msg "INFO" "删除旧的设备节点..."
    rm -f "$DEVICE_NODE" 2>/dev/null || true
fi

# SELinux 处理
if [ "$SELINUX_STATUS" = "Enforcing" ]; then
    log_msg "INFO" "检测到 SELinux 处于强制模式，尝试临时禁用..."
    if setenforce 0 2>/dev/null; then
        log_msg "SUCCESS" "SELinux 已临时禁用"
        SELINUX_CHANGED=1
    else
        log_msg "WARN" "无法禁用 SELinux，可能影响模块加载"
    fi
fi

echo ""
log_msg "INFO" "开始尝试加载 Kernel_driver_hack 模块..."

# 加载方法数组
LOAD_METHODS=(
    "insmod $MODULE_PATH"
    "insmod -f $MODULE_PATH"
    "modprobe -f $MODULE_PATH"
    "busybox insmod $MODULE_PATH"
    "toybox insmod $MODULE_PATH"
)

# 尝试各种加载方法
for i in "${!LOAD_METHODS[@]}"; do
    method_num=$((i + 1))
    method="${LOAD_METHODS[$i]}"
    
    log_msg "INFO" "方法 $method_num: $method"
    
    if eval "$method" 2>>"$LOG_FILE"; then
        log_msg "SUCCESS" "模块加载成功！(方法 $method_num)"
        
        # 验证加载状态
        if lsmod 2>/dev/null | grep -q kernel_hack; then
            echo ""
            log_msg "SUCCESS" "模块验证成功："
            lsmod | grep kernel_hack
            
            # 检查设备节点
            sleep 1
            if [ -e "$DEVICE_NODE" ]; then
                log_msg "SUCCESS" "设备节点创建成功: $DEVICE_NODE"
                ls -l "$DEVICE_NODE"
            else
                log_msg "WARN" "设备节点未创建，可能需要手动创建"
            fi
            
            # 显示内核消息
            echo ""
            log_msg "INFO" "内核消息："
            dmesg | tail -10 | grep -i "driver_entry\|JiangNight\|kernel_hack" || echo "  (无相关内核消息)"
            
            # 恢复 SELinux (如果之前修改过)
            if [ "$SELINUX_CHANGED" = "1" ]; then
                log_msg "INFO" "恢复 SELinux 设置..."
                setenforce 1 2>/dev/null || log_msg "WARN" "无法恢复 SELinux 设置"
            fi
            
            echo ""
            log_msg "SUCCESS" "Kernel_driver_hack 模块加载完成！"
            echo ""
            echo "使用说明:"
            echo "  设备节点: $DEVICE_NODE"
            echo "  支持的操作:"
            echo "    - OP_READ_MEM (0x801): 读取进程内存"
            echo "    - OP_WRITE_MEM (0x802): 写入进程内存"
            echo "    - OP_MODULE_BASE (0x803): 获取模块基址"
            echo "    - OP_INIT_KEY (0x800): 初始化验证密钥"
            echo ""
            echo "⚠️  请遵守法律法规，仅用于学习研究！"
            exit 0
        else
            log_msg "ERROR" "模块加载命令成功但验证失败"
        fi
    else
        log_msg "WARN" "方法 $method_num 失败"
    fi
done

# 所有方法都失败
echo ""
log_msg "ERROR" "所有加载方法都失败"
echo ""
echo "可能的原因和解决方案："
echo "1. 内核版本不兼容"
echo "   - 当前内核: $KERNEL_VER"
echo "   - 需要使用对应设备的官方内核源码重新编译"
echo ""
echo "2. 内核配置不支持外部模块"
echo "   - 检查内核是否启用 CONFIG_MODULES"
echo "   - 某些设备厂商禁用了外部模块支持"
echo ""
echo "3. 安全策略阻止"
echo "   - 尝试在开发者选项中禁用相关安全功能"
echo "   - 使用 Magisk 等工具绕过限制"
echo ""
echo "4. 模块签名问题"
echo "   - 虽然已禁用签名检查，但某些设备仍可能验证"
echo ""
echo "详细错误信息请查看："
echo "  内核日志: dmesg | tail -50"
echo "  加载日志: $LOG_FILE"

# 恢复 SELinux
if [ "$SELINUX_CHANGED" = "1" ]; then
    setenforce 1 2>/dev/null
fi

exit 1
EOF

    chmod +x "$OUTPUT_DIR/load_kernel_hack.sh"
    
    log "SUCCESS" "Kernel_driver_hack 智能脚本已创建"
}
# 创建卸载脚本
    cat > "$OUTPUT_DIR/unload_kernel_hack.sh" << 'EOF'
#!/system/bin/sh
# Kernel_driver_hack 模块卸载脚本

DEVICE_NODE="/dev/JiangNight"

if [ "$(id -u)" != "0" ]; then
    echo "错误: 需要 Root 权限"
    exit 1
fi

echo "Kernel_driver_hack 模块卸载工具"
echo "================================="

if lsmod 2>/dev/null | grep -q kernel_hack; then
    echo "正在卸载 kernel_hack 模块..."
    
    # 删除设备节点
    if [ -e "$DEVICE_NODE" ]; then
        echo "删除设备节点: $DEVICE_NODE"
        rm -f "$DEVICE_NODE" 2>/dev/null || true
    fi
    
    if rmmod kernel_hack 2>/dev/null; then
        echo "✓ 模块卸载成功"
    else
        echo "✗ 模块卸载失败，尝试强制卸载..."
        if rmmod -f kernel_hack 2>/dev/null; then
            echo "✓ 强制卸载成功"
        else
            echo "✗ 强制卸载也失败"
            echo "可能需要重启设备"
            exit 1
        fi
    fi
else
    echo "模块未加载"
fi

echo "卸载完成"
EOF

    chmod +x "$OUTPUT_DIR/unload_kernel_hack.sh"
    
    # 创建模块测试脚本
    cat > "$OUTPUT_DIR/test_kernel_hack.sh" << 'EOF'
#!/system/bin/sh
# Kernel_driver_hack 模块测试脚本

DEVICE_NODE="/dev/JiangNight"

echo "Kernel_driver_hack 模块测试"
echo "==========================="

# 检查模块是否加载
if lsmod 2>/dev/null | grep -q kernel_hack; then
    echo "✓ 模块已加载"
    echo ""
    echo "模块详情:"
    lsmod | grep kernel_hack
else
    echo "✗ 模块未加载"
    echo "请先运行: /data/local/tmp/load_kernel_hack.sh"
    exit 1
fi

# 检查设备节点
if [ -e "$DEVICE_NODE" ]; then
    echo ""
    echo "✓ 设备节点存在: $DEVICE_NODE"
    ls -l "$DEVICE_NODE"
    
    # 检查设备权限
    if [ -r "$DEVICE_NODE" ] && [ -w "$DEVICE_NODE" ]; then
        echo "✓ 设备节点权限正常"
    else
        echo "⚠️  设备节点权限可能有问题"
        echo "尝试修复权限..."
        chmod 666 "$DEVICE_NODE" 2>/dev/null || echo "权限修复失败"
    fi
else
    echo "✗ 设备节点不存在: $DEVICE_NODE"
    echo "模块可能加载失败或设备节点创建失败"
fi

echo ""
echo "内核消息:"
dmesg | grep -i "driver_entry\|JiangNight\|kernel_hack" | tail -5

echo ""
echo "设备信息:"
echo "  型号: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
echo "  Android: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
echo "  内核: $(uname -r)"
echo "  SELinux: $(getenforce 2>/dev/null || echo 'Unknown')"

echo ""
echo "支持的 IOCTL 操作:"
echo "  - OP_INIT_KEY (0x800): 初始化验证密钥"
echo "  - OP_READ_MEM (0x801): 读取进程内存"
echo "  - OP_WRITE_MEM (0x802): 写入进程内存"
echo "  - OP_MODULE_BASE (0x803): 获取模块基址"
EOF

    chmod +x "$OUTPUT_DIR/test_kernel_hack.sh"
# ============================================================================
# 复制用户态测试程序
# ============================================================================

copy_user_tools() {
    log "STEP" "复制用户态测试工具"
    
    # 检查用户态目录
    USER_SRC="$SCRIPT_DIR/Kernel_driver_hack-main/user"
    if [ -d "$USER_SRC" ]; then
        log "INFO" "发现用户态测试工具，复制到输出目录..."
        
        # 复制用户态文件
        cp -r "$USER_SRC" "$OUTPUT_DIR/user_tools"
        
        # 创建用户态编译说明
        cat > "$OUTPUT_DIR/user_tools/README_USER.md" << 'EOF'
# 用户态测试工具

## 文件说明

- `main.cpp` - 主测试程序
- `driver.hpp` - 驱动接口头文件
- `Makefile` - 编译脚本
- `test.sh` - 测试脚本

## 编译方法

```bash
# 在 Android 设备上编译 (需要 NDK)
cd /data/local/tmp/user_tools
make

# 或在 Linux 主机上交叉编译
export CC=aarch64-linux-gnu-g++
make
```

## 使用方法

```bash
# 推送到设备
adb push test_program /data/local/tmp/

# 运行测试
adb shell su -c "/data/local/tmp/test_program"
```

注意: 运行前请确保 kernel_hack.ko 模块已正确加载。
EOF
        
        log "SUCCESS" "用户态测试工具已复制"
    else
        log "INFO" "未找到用户态测试工具目录"
    fi
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    echo -e "${BOLD}${CYAN}"
    echo "=============================================="
    echo "  Kernel_driver_hack 专用编译器 v${SCRIPT_VERSION}"
    echo "  优化版 - JiangNight 驱动专用"
    echo "=============================================="
    echo -e "${NC}\n"
    
    log "INFO" "开始 Kernel_driver_hack 编译流程，版本: $SCRIPT_VERSION"
    log "INFO" "日志文件: $LOG_FILE"
    
    # 执行编译流程
    init_environment
    setup_build_environment
    prepare_kernel_config
    create_driver_makefile
    compile_driver_module
    generate_driver_info
    create_kernel_hack_loader
    copy_user_tools
    
    # 显示结果
    echo -e "\n${BOLD}${GREEN}"
    echo "=============================================="
    echo "  ✅ Kernel_driver_hack 编译完成！"
    echo "=============================================="
    echo -e "${NC}\n"
    
    log "SUCCESS" "Kernel_driver_hack 编译流程完成"
    
    echo -e "${CYAN}📦 输出目录: $OUTPUT_DIR${NC}\n"
    ls -lah "$OUTPUT_DIR"
    
    echo -e "\n${YELLOW}📋 生成的文件:${NC}"
    echo "  🔧 kernel_hack.ko           - JiangNight 内核驱动模块"
    echo "  📜 load_kernel_hack.sh      - 智能加载脚本"
    echo "  🗑️  unload_kernel_hack.sh    - 卸载脚本"
    echo "  🧪 test_kernel_hack.sh      - 模块测试脚本"
    echo "  ℹ️  module_info.txt          - 详细信息"
    echo "  👨‍💻 user_tools/              - 用户态测试工具"
    
    echo -e "\n${YELLOW}🚀 快速使用:${NC}"
    echo "  adb push $OUTPUT_DIR/kernel_hack.ko /data/local/tmp/"
    echo "  adb push $OUTPUT_DIR/*.sh /data/local/tmp/"
    echo "  adb shell chmod +x /data/local/tmp/*.sh"
    echo "  adb shell su -c \"/data/local/tmp/load_kernel_hack.sh\""
    
    echo -e "\n${YELLOW}🧪 测试模块:${NC}"
    echo "  adb shell su -c \"/data/local/tmp/test_kernel_hack.sh\""
    
    echo -e "\n${CYAN}📱 设备节点: /dev/JiangNight${NC}"
    echo -e "${CYAN}🔧 支持操作: 内存读写、模块基址获取${NC}"
    
    echo -e "\n${GREEN}编译日志已保存到: $LOG_FILE${NC}"
    echo -e "${GREEN}现在可以推送到设备进行测试！${NC}\n"
    
    echo -e "${RED}⚠️  安全提醒: 仅供学习研究使用，请遵守法律法规！${NC}\n"
}

# 运行主函数
main "$@"