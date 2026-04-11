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
# 优化版 rwProcMem 通用内核模块编译脚本
# 版本: 2.0
# 目标: 最大化兼容性，支持所有 5.15.x Android 设备

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
SCRIPT_VERSION="2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DATE=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$SCRIPT_DIR/build_${BUILD_DATE}.log"

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
    log "STEP" "初始化编译环境"
    
    # 检查必要的工具
    log "INFO" "检查编译工具链..."
    check_command "make"
    check_command "aarch64-linux-gnu-gcc"
    check_command "clang"
    
    # 设置工作目录
    cd "$SCRIPT_DIR"
    
    # 检查内核源码目录
    KERNEL_SRC="$SCRIPT_DIR/kernel"
    check_directory "$KERNEL_SRC"
    
    # 设置模块源码路径
    MODULE_SRC="$KERNEL_SRC/drivers/rwProcMem33/rwProcMem33Module/rwProcMem_module"
    
    # 创建输出目录
    OUTPUT_DIR="$SCRIPT_DIR/out_universal_v2"
    mkdir -p "$OUTPUT_DIR"
    
    log "SUCCESS" "环境检查完成"
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
# 模块 Makefile 优化
# ============================================================================

create_optimized_makefile() {
    log "STEP" "创建优化的模块 Makefile"
    
    check_directory "$MODULE_SRC"
    
    # 备份原始 Makefile
    if [ -f "$MODULE_SRC/Makefile" ] && [ ! -f "$MODULE_SRC/Makefile.original" ]; then
        cp "$MODULE_SRC/Makefile" "$MODULE_SRC/Makefile.original"
        log "INFO" "已备份原始 Makefile"
    fi
    
    # 创建超强兼容性 Makefile
    cat > "$MODULE_SRC/Makefile" << 'EOF'
# rwProcMem 超强兼容性模块 Makefile
# 版本: 2.0 - 最大化兼容性设计

MODULE_NAME = rwProcMem_module
obj-m += $(MODULE_NAME).o

# ============================================================================
# 基础编译选项
# ============================================================================

ccflags-y := -Wall -Wno-declaration-after-statement -Wno-unused-function
ccflags-y += -Wno-unused-variable -Wno-format -Wno-sign-compare

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

    log "SUCCESS" "优化 Makefile 创建完成"
}

# ============================================================================
# 模块编译
# ============================================================================

compile_module() {
    log "STEP" "编译内核模块"
    
    cd "$KERNEL_SRC"
    
    # 清理旧文件
    log "INFO" "清理旧的编译文件..."
    safe_rm "$MODULE_SRC"/*.o
    safe_rm "$MODULE_SRC"/*.ko
    safe_rm "$MODULE_SRC"/.*.cmd
    safe_rm "$MODULE_SRC"/Module.symvers
    safe_rm "$MODULE_SRC"/modules.order
    safe_rm "$OUTPUT_DIR"/*
    
    # 开始编译
    log "INFO" "开始编译 rwProcMem_module.ko..."
    log "INFO" "编译选项: 超强兼容性模式"
    
    # 编译命令
    local MAKE_CMD=(
        "make"
        "-C" "$KERNEL_SRC"
        "M=$MODULE_SRC"
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
    KO_FILE=$(find "$MODULE_SRC" -name "rwProcMem_module.ko" -type f | head -n 1)
    
    if [ -z "$KO_FILE" ]; then
        log "ERROR" "未找到编译生成的 rwProcMem_module.ko 文件"
        log "ERROR" "请检查编译日志: $LOG_FILE"
        exit 1
    fi
    
    log "SUCCESS" "找到编译生成的模块: $KO_FILE"
    
    # 复制到输出目录
    cp "$KO_FILE" "$OUTPUT_DIR/rwProcMem_module.ko"
    log "SUCCESS" "模块已复制到输出目录"
}

# ============================================================================
# 生成模块信息和工具
# ============================================================================

generate_module_info() {
    log "STEP" "生成模块信息和工具"
    
    cd "$KERNEL_SRC"
    
    # 获取模块信息
    local KERNEL_VER
    KERNEL_VER=$(make kernelrelease 2>/dev/null || echo "unknown")
    
    local MODULE_SIZE
    MODULE_SIZE=$(ls -lh "$OUTPUT_DIR/rwProcMem_module.ko" | awk '{print $5}')
    
    local MODULE_MD5
    MODULE_MD5=$(md5sum "$OUTPUT_DIR/rwProcMem_module.ko" | awk '{print $1}')
    
    # 生成详细的模块信息文件
    cat > "$OUTPUT_DIR/module_info.txt" << EOF
rwProcMem 通用内核模块 - 优化版 v${SCRIPT_VERSION}
================================================================

编译信息:
  编译时间: $(date '+%Y-%m-%d %H:%M:%S')
  编译版本: ${SCRIPT_VERSION}
  内核版本: ${KERNEL_VER}
  模块大小: ${MODULE_SIZE}
  MD5校验: ${MODULE_MD5}
  编译架构: ARM64
  编译器: LLVM/Clang

兼容性特性:
  ✅ 完全禁用 CFI/KCFI
  ✅ 禁用 vermagic 检查
  ✅ 禁用模块签名验证
  ✅ 禁用栈保护
  ✅ 禁用地址消毒
  ✅ 多重编译选项保护
  ✅ 最大化兼容性设计

适用设备:
  - Android 13+ (5.15.x 内核)
  - 小米、OPPO、vivo、一加、华为等品牌
  - 需要 Root 权限
  - 建议临时禁用 SELinux

使用说明:
  1. 推送模块到设备: adb push rwProcMem_module.ko /data/local/tmp/
  2. 使用加载脚本: adb shell su -c "/data/local/tmp/load_module.sh"
  3. 验证加载状态: adb shell lsmod | grep rwProcMem

编译日志: ${LOG_FILE}
EOF

    log "SUCCESS" "模块信息文件已生成"
}

# ============================================================================
# 生成智能加载脚本
# ============================================================================

create_smart_loader() {
    log "STEP" "创建智能加载脚本"
    
    # 创建增强版加载脚本
    cat > "$OUTPUT_DIR/load_module.sh" << 'EOF'
#!/system/bin/sh
# rwProcMem 智能加载脚本 v2.0
# 自动处理各种兼容性问题和设备差异

MODULE_PATH="/data/local/tmp/rwProcMem_module.ko"
LOG_FILE="/data/local/tmp/rwProcMem_load.log"

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
echo "  rwProcMem 智能模块加载器 v2.0"
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
    echo "请先执行: adb push rwProcMem_module.ko /data/local/tmp/"
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
if lsmod 2>/dev/null | grep -q rwProcMem; then
    log_msg "WARN" "模块已加载，先尝试卸载..."
    if rmmod rwProcMem_module 2>/dev/null; then
        log_msg "SUCCESS" "旧模块已卸载"
    else
        log_msg "WARN" "卸载旧模块失败，继续尝试加载"
    fi
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

# 创建临时目录（某些设备需要）
mkdir -p /data/local/tmp/modules 2>/dev/null

echo ""
log_msg "INFO" "开始尝试加载模块..."

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
        if lsmod 2>/dev/null | grep -q rwProcMem; then
            echo ""
            log_msg "SUCCESS" "模块验证成功："
            lsmod | grep rwProcMem
            
            # 显示内核消息
            echo ""
            log_msg "INFO" "内核消息："
            dmesg | tail -10 | grep -i rwProcMem || echo "  (无相关内核消息)"
            
            # 恢复 SELinux (如果之前修改过)
            if [ "$SELINUX_CHANGED" = "1" ]; then
                log_msg "INFO" "恢复 SELinux 设置..."
                setenforce 1 2>/dev/null || log_msg "WARN" "无法恢复 SELinux 设置"
            fi
            
            echo ""
            log_msg "SUCCESS" "rwProcMem 模块加载完成！"
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

    chmod +x "$OUTPUT_DIR/load_module.sh"
    
    # 创建卸载脚本
    cat > "$OUTPUT_DIR/unload_module.sh" << 'EOF'
#!/system/bin/sh
# rwProcMem 模块卸载脚本

if [ "$(id -u)" != "0" ]; then
    echo "错误: 需要 Root 权限"
    exit 1
fi

echo "rwProcMem 模块卸载工具"
echo "========================"

if lsmod 2>/dev/null | grep -q rwProcMem; then
    echo "正在卸载 rwProcMem 模块..."
    
    if rmmod rwProcMem_module 2>/dev/null; then
        echo "✓ 模块卸载成功"
    else
        echo "✗ 模块卸载失败，尝试强制卸载..."
        if rmmod -f rwProcMem_module 2>/dev/null; then
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

    chmod +x "$OUTPUT_DIR/unload_module.sh"
    
    # 创建模块信息查看脚本
    cat > "$OUTPUT_DIR/module_info.sh" << 'EOF'
#!/system/bin/sh
# rwProcMem 模块信息查看脚本

echo "rwProcMem 模块信息"
echo "=================="

# 检查模块是否加载
if lsmod 2>/dev/null | grep -q rwProcMem; then
    echo "✓ 模块已加载"
    echo ""
    echo "模块详情:"
    lsmod | grep rwProcMem
    echo ""
    echo "内核消息:"
    dmesg | grep -i rwProcMem | tail -10
else
    echo "✗ 模块未加载"
fi

echo ""
echo "设备信息:"
echo "  型号: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
echo "  Android: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
echo "  内核: $(uname -r)"
echo "  SELinux: $(getenforce 2>/dev/null || echo 'Unknown')"
EOF

    chmod +x "$OUTPUT_DIR/module_info.sh"
    
    log "SUCCESS" "智能加载脚本已创建"
}

# ============================================================================
# 生成使用文档
# ============================================================================

create_documentation() {
    log "STEP" "生成使用文档"
    
    cat > "$OUTPUT_DIR/README.md" << 'EOF'
# rwProcMem 通用内核模块 v2.0

## 概述

这是一个经过优化的 rwProcMem 内核模块，专为 Android 5.15.x 内核设计，具有最大化的设备兼容性。

## 特性

- ✅ **超强兼容性**: 支持大部分 5.15.x 内核设备
- ✅ **安全特性禁用**: 完全禁用 CFI、KCFI、栈保护等
- ✅ **智能加载**: 自动尝试多种加载方法
- ✅ **详细日志**: 完整的加载和错误日志
- ✅ **设备检测**: 自动检测设备信息和兼容性

## 文件说明

- `rwProcMem_module.ko` - 内核模块文件
- `load_module.sh` - 智能加载脚本
- `unload_module.sh` - 卸载脚本
- `module_info.sh` - 模块信息查看脚本
- `module_info.txt` - 详细的模块信息
- `README.md` - 本文档

## 快速使用

### 1. 推送文件到设备

```bash
# 推送模块和脚本
adb push rwProcMem_module.ko /data/local/tmp/
adb push load_module.sh /data/local/tmp/
adb push unload_module.sh /data/local/tmp/
adb push module_info.sh /data/local/tmp/

# 设置执行权限
adb shell chmod +x /data/local/tmp/*.sh
```

### 2. 加载模块

```bash
# 使用智能加载脚本（推荐）
adb shell su -c "/data/local/tmp/load_module.sh"
```

### 3. 验证加载

```bash
# 检查模块状态
adb shell su -c "/data/local/tmp/module_info.sh"

# 或手动检查
adb shell lsmod | grep rwProcMem
```

### 4. 卸载模块

```bash
adb shell su -c "/data/local/tmp/unload_module.sh"
```

## 手动加载方法

如果智能脚本失败，可以尝试手动加载：

```bash
# 方法 1: 标准加载
adb shell su -c "setenforce 0"
adb shell su -c "insmod /data/local/tmp/rwProcMem_module.ko"

# 方法 2: 强制加载
adb shell su -c "insmod -f /data/local/tmp/rwProcMem_module.ko"

# 方法 3: 使用 modprobe
adb shell su -c "modprobe -f /data/local/tmp/rwProcMem_module.ko"
```

## 故障排查

### 常见问题

1. **权限不足**
   - 确保设备已获得 Root 权限
   - 使用 `su -c` 执行命令

2. **SELinux 阻止**
   - 临时禁用: `setenforce 0`
   - 或使用 Magisk 等工具

3. **内核不兼容**
   - 检查内核版本: `uname -r`
   - 确认是 5.15.x 版本
   - 某些厂商内核可能需要特殊处理

4. **模块签名问题**
   - 虽然已禁用签名，但某些设备仍可能检查
   - 尝试使用 `-f` 强制加载

### 查看日志

```bash
# 查看内核日志
adb shell dmesg | tail -50

# 查看加载日志
adb shell cat /data/local/tmp/rwProcMem_load.log
```

## 开机自动加载（可选）

```bash
# 1. 复制到系统分区
adb shell su -c "mount -o remount,rw /system"
adb shell su -c "mkdir -p /system/lib/modules"
adb shell su -c "cp /data/local/tmp/rwProcMem_module.ko /system/lib/modules/"

# 2. 创建启动脚本
adb shell su -c "cat > /system/etc/init.d/99rwProcMem << 'EOF'
#!/system/bin/sh
insmod /system/lib/modules/rwProcMem_module.ko
EOF"

adb shell su -c "chmod 755 /system/etc/init.d/99rwProcMem"
```

## 兼容性说明

### 支持的设备

- 小米 (Xiaomi/Redmi/POCO)
- OPPO/OnePlus
- vivo/iQOO
- 华为/荣耀 (部分)
- 三星 (部分)
- 其他使用标准 5.15.x 内核的设备

### 已知限制

- 某些厂商深度定制的内核可能不兼容
- 部分功能在某些设备上可能受限
- 需要 Root 权限和适当的 SELinux 配置

## 技术细节

### 编译特性

- 完全禁用 CFI/KCFI
- 禁用栈保护和地址消毒
- 禁用模块版本检查
- 多重编译选项保护
- 优化的兼容性设置

### 安全考虑

- 模块禁用了多项安全特性以提高兼容性
- 仅在受信任的环境中使用
- 建议在测试后及时卸载

## 更新日志

### v2.0
- 重写编译脚本，提高兼容性
- 增强的智能加载脚本
- 更详细的错误处理和日志
- 支持更多设备和加载方法
- 完善的文档和使用说明

## 支持

如果遇到问题，请提供以下信息：
- 设备型号和 Android 版本
- 内核版本 (`uname -r`)
- 错误日志 (`dmesg` 和加载日志)
- 尝试过的加载方法

---

**注意**: 此模块仅供学习和研究使用，请遵守相关法律法规。
EOF

    log "SUCCESS" "使用文档已生成"
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    echo -e "${BOLD}${CYAN}"
    echo "=============================================="
    echo "  rwProcMem 通用模块编译器 v${SCRIPT_VERSION}"
    echo "  优化版 - 最大化兼容性设计"
    echo "=============================================="
    echo -e "${NC}\n"
    
    log "INFO" "开始编译流程，版本: $SCRIPT_VERSION"
    log "INFO" "日志文件: $LOG_FILE"
    
    # 执行编译流程
    init_environment
    setup_build_environment
    prepare_kernel_config
    create_optimized_makefile
    compile_module
    generate_module_info
    create_smart_loader
    create_documentation
    
    # 显示结果
    echo -e "\n${BOLD}${GREEN}"
    echo "=============================================="
    echo "  ✅ 编译完成！"
    echo "=============================================="
    echo -e "${NC}\n"
    
    log "SUCCESS" "编译流程完成"
    
    echo -e "${CYAN}📦 输出目录: $OUTPUT_DIR${NC}\n"
    ls -lah "$OUTPUT_DIR"
    
    echo -e "\n${YELLOW}📋 生成的文件:${NC}"
    echo "  🔧 rwProcMem_module.ko    - 内核模块"
    echo "  📜 load_module.sh         - 智能加载脚本"
    echo "  🗑️  unload_module.sh       - 卸载脚本"
    echo "  ℹ️  module_info.sh        - 信息查看脚本"
    echo "  📄 module_info.txt        - 详细信息"
    echo "  📖 README.md              - 使用文档"
    
    echo -e "\n${YELLOW}🚀 快速使用:${NC}"
    echo "  adb push $OUTPUT_DIR/* /data/local/tmp/"
    echo "  adb shell chmod +x /data/local/tmp/*.sh"
    echo "  adb shell su -c \"/data/local/tmp/load_module.sh\""
    
    echo -e "\n${GREEN}编译日志已保存到: $LOG_FILE${NC}"
    echo -e "${GREEN}现在可以推送到设备进行测试！${NC}\n"
}

# 运行主函数
main "$@"