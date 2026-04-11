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
# Kernel_driver_hack 内核驱动编译脚本 - 工具链精确匹配版
# ============================================================================
# 版本: 5.0
# 功能: 编译 JiangNight 的 Kernel_driver_hack 内核驱动模块
# 优化: 使用绝对路径指定 clang-r450784e 工具链，确保与目标设备内核一致
# 内核: GKI 5.15 (android-kernel-5.15)
# 目标设备: 小米13 (Android 13, 内核 5.15.178-android13-8)
# ============================================================================

set -eE

# ============================================================================
# 颜色定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# 脚本配置
# ============================================================================
SCRIPT_VERSION="5.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DATE=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$SCRIPT_DIR/build_${BUILD_DATE}.log"
STATE_FILE="$SCRIPT_DIR/.build_state"

# 路径配置 (修复: SCRIPT_DIR 就是内核根目录)
KERNEL_ROOT="$SCRIPT_DIR"
KERNEL_SRC="$KERNEL_ROOT/kernel"
# 驱动源码在工作区根目录的 hello_world_module
DRIVER_SRC="$(dirname "$KERNEL_ROOT")/hello_world_module"
OUTPUT_DIR="$SCRIPT_DIR/out_kernel_hack_v5"

# ============================================================================
# ⚠️ 关键: 工具链绝对路径配置 (clang-r450784e)
# ============================================================================
# 目标设备内核编译信息:
# Linux version 5.15.178-android13-8-00021-g6f2f96be86b9-ab13729987
# Android (8508608, based on r450784e) clang version 14.0.7
# 必须使用完全相同的工具链版本才能加载模块
# ============================================================================
CLANG_ROOT="$KERNEL_ROOT/toolchain/linux-x86/clang-r450784e"
CLANG_BIN="$CLANG_ROOT/bin"
# build-tools 不存在，使用系统 make
BUILD_TOOLS=""

# 工具链下载配置
CLANG_DOWNLOAD_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android13-release/clang-r450784e.tar.gz"
BUILD_TOOLS_DOWNLOAD_URL="https://android.googlesource.com/platform/prebuilts/build-tools/+archive/refs/heads/android13-release/linux-x86.tar.gz"

# 期望的 clang 版本标识
EXPECTED_CLANG_ID="r450784e"

# 所有 LLVM 工具使用绝对路径 (核心改动!)
TOOL_CC="$CLANG_BIN/clang"
TOOL_CXX="$CLANG_BIN/clang++"
TOOL_LD="$CLANG_BIN/ld.lld"
TOOL_AR="$CLANG_BIN/llvm-ar"
TOOL_NM="$CLANG_BIN/llvm-nm"
TOOL_STRIP="$CLANG_BIN/llvm-strip"
TOOL_OBJCOPY="$CLANG_BIN/llvm-objcopy"
TOOL_OBJDUMP="$CLANG_BIN/llvm-objdump"
TOOL_READELF="$CLANG_BIN/llvm-readelf"
# 使用系统 make (build-tools 不存在)
TOOL_MAKE="make"

# ⚠️ 重要: 目标设备的内核版本后缀
# 用户设备版本: 5.15.178-android13-8-00021-g6f2f96be86b9-ab13729987
# 需要精确匹配 vermagic
TARGET_LOCALVERSION="-android13-8"

# ============================================================================
# ⚠️ 关键: 小米13 真实内核配置 (从 configMi13 提取)
# ============================================================================
# LTO 类型: CONFIG_LTO_CLANG_FULL=y (Full LTO, 不是 ThinLTO!)
# CFI: CONFIG_CFI_CLANG=y (已启用)
# 模块签名: CONFIG_MODULE_SIG=y
# MODVERSIONS: CONFIG_MODVERSIONS=y
# ============================================================================
USE_FULL_LTO=true
# 如果要编译可加载的外部模块，需要禁用这些安全特性
# 如果要编译完整内核替换 boot.img，可以保持原样
DISABLE_SECURITY_FOR_MODULE=true

# 编译选项
JOBS=$(nproc)
SKIP_KERNEL_BUILD=false
FORCE_REBUILD=false
VERBOSE=false

# ============================================================================
# 错误处理
# ============================================================================
trap 'error_handler $? $LINENO' ERR

error_handler() {
    local exit_code=$1
    local line_number=$2
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ 编译失败！${NC}"
    echo -e "${RED}错误代码: $exit_code，行号: $line_number${NC}"
    echo -e "${YELLOW}📋 查看详细日志: $LOG_FILE${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    save_state "failed"
    exit $exit_code
}

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
        "DEBUG")   $VERBOSE && echo -e "${MAGENTA}🔍 $message${NC}" ;;
    esac
}

die() {
    log "ERROR" "$1"
    exit 1
}

# ============================================================================
# 进度显示
# ============================================================================
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}[${GREEN}"
    printf "%${filled}s" | tr ' ' '█'
    printf "${CYAN}"
    printf "%${empty}s" | tr ' ' '░'
    printf "${CYAN}] ${YELLOW}%3d%% ${NC}%s" "$percent" "$desc"
}

# ============================================================================
# 状态管理 (支持断点续编)
# ============================================================================
save_state() {
    local state=$1
    echo "$state:$(date +%s)" > "$STATE_FILE"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE" | cut -d: -f1
    else
        echo "none"
    fi
}

clear_state() {
    rm -f "$STATE_FILE"
}

# 仅下载工具链标志
DOWNLOAD_TOOLCHAIN_ONLY=false

# ============================================================================
# 参数解析
# ============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--skip-kernel)
                SKIP_KERNEL_BUILD=true
                shift
                ;;
            -f|--force)
                FORCE_REBUILD=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -j|--jobs)
                JOBS=$2
                shift 2
                ;;
            -l|--localversion)
                TARGET_LOCALVERSION="$2"
                shift 2
                ;;
            --full-lto)
                USE_FULL_LTO=true
                shift
                ;;
            --thin-lto)
                USE_FULL_LTO=false
                shift
                ;;
            --keep-security)
                DISABLE_SECURITY_FOR_MODULE=false
                shift
                ;;
            --download-toolchain)
                DOWNLOAD_TOOLCHAIN_ONLY=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo -e "${BOLD}Kernel_driver_hack 编译脚本 v${SCRIPT_VERSION}${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -s, --skip-kernel    跳过内核编译 (使用已有的 Module.symvers)"
    echo "  -f, --force          强制重新编译 (忽略缓存)"
    echo "  -v, --verbose        显示详细输出"
    echo "  -j, --jobs N         并行编译线程数 (默认: $(nproc))"
    echo "  -l, --localversion V 设置内核版本后缀 (默认: -android13-8)"
    echo "  --full-lto           使用 Full LTO (默认，匹配小米13)"
    echo "  --thin-lto           使用 ThinLTO"
    echo "  --keep-security      保持安全特性 (编译完整内核用)"
    echo "  --download-toolchain 仅下载工具链，不编译"
    echo "  -h, --help           显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                   # 完整编译 (Full LTO, 禁用安全特性)"
    echo "  $0 -s                # 跳过内核编译，只编译模块"
    echo "  $0 -f -j 8           # 强制重编，使用 8 线程"
    echo "  $0 --keep-security   # 编译完整内核 (保持 CFI/签名等)"
    echo "  $0 --thin-lto        # 使用 ThinLTO (不推荐，小米13 用 Full LTO)"
    echo "  $0 --download-toolchain  # 仅下载 clang-r450784e 工具链"
    echo ""
    echo "⚠️  重要信息:"
    echo "   小米13 内核配置: Full LTO + CFI + 模块签名 + MODVERSIONS"
    echo "   要加载外部模块，必须刷入自编译内核（禁用安全特性）"
    echo "   使用 adb shell uname -r 查看目标设备内核版本"
    echo ""
    echo "📦 工具链信息:"
    echo "   clang-r450784e 是 Android 13 内核编译所需的工具链"
    echo "   脚本会自动检测并下载缺失的工具链"
    echo "   工具链路径: prebuilts/clang/host/linux-x86/clang-r450784e"
}


# ============================================================================
# 下载编译工具链 (clang-r450784e)
# ============================================================================
download_toolchain() {
    log "STEP" "下载编译工具链 clang-r450784e"
    
    local PREBUILTS_DIR="$KERNEL_ROOT/prebuilts"
    local CLANG_DIR="$PREBUILTS_DIR/clang/host/linux-x86"
    local BUILD_TOOLS_DIR="$PREBUILTS_DIR/build-tools/linux-x86"
    
    # 创建目录结构
    mkdir -p "$CLANG_DIR"
    mkdir -p "$BUILD_TOOLS_DIR"
    
    # 检查必要工具
    local download_tool=""
    if command -v wget &> /dev/null; then
        download_tool="wget"
    elif command -v curl &> /dev/null; then
        download_tool="curl"
    else
        die "需要 wget 或 curl 来下载工具链，请先安装: apt install wget"
    fi
    
    # ============================================================================
    # 方案1: 从 Google 官方源下载 (推荐，但可能需要代理)
    # ============================================================================
    log "INFO" "尝试从 Google 官方源下载 clang-r450784e..."
    
    local CLANG_TAR="$CLANG_DIR/clang-r450784e.tar.gz"
    local CLANG_GOOGLE_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android13-release/clang-r450784e.tar.gz"
    
    # 下载 clang
    if [ ! -d "$CLANG_DIR/clang-r450784e" ]; then
        log "INFO" "下载 clang-r450784e (约 1.5GB)..."
        log "WARN" "如果下载缓慢，可以手动下载后放到: $CLANG_DIR/clang-r450784e/"
        
        cd "$CLANG_DIR"
        
        # 尝试多个下载源
        local download_success=false
        
        # 源1: Google 官方 (需要代理)
        if [ "$download_success" = false ]; then
            log "INFO" "尝试 Google 官方源..."
            if [ "$download_tool" = "wget" ]; then
                if wget --timeout=30 -q --show-progress -O "$CLANG_TAR" "$CLANG_GOOGLE_URL" 2>/dev/null; then
                    download_success=true
                fi
            else
                if curl -L --connect-timeout 30 -# -o "$CLANG_TAR" "$CLANG_GOOGLE_URL" 2>/dev/null; then
                    download_success=true
                fi
            fi
        fi
        
        # 源2: 镜像源 (国内可用)
        if [ "$download_success" = false ]; then
            log "INFO" "Google 源不可用，尝试镜像源..."
            local MIRROR_URLS=(
                "https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android13-release/clang-r450784e.tar.gz"
                "https://aosp.tuna.tsinghua.edu.cn/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android13-release/clang-r450784e.tar.gz"
            )
            
            for mirror_url in "${MIRROR_URLS[@]}"; do
                log "INFO" "尝试: $mirror_url"
                if [ "$download_tool" = "wget" ]; then
                    if wget --timeout=30 -q --show-progress -O "$CLANG_TAR" "$mirror_url" 2>/dev/null; then
                        download_success=true
                        break
                    fi
                else
                    if curl -L --connect-timeout 30 -# -o "$CLANG_TAR" "$mirror_url" 2>/dev/null; then
                        download_success=true
                        break
                    fi
                fi
            done
        fi
        
        # 源3: 使用 repo 同步 (最可靠但最慢)
        if [ "$download_success" = false ]; then
            log "WARN" "直接下载失败，尝试使用 repo 同步..."
            if command -v repo &> /dev/null; then
                cd "$KERNEL_ROOT"
                log "INFO" "使用 repo sync 同步 prebuilts/clang..."
                repo sync prebuilts/clang/host/linux-x86 -c --no-tags -j4 2>&1 | tee -a "$LOG_FILE" && download_success=true
            fi
        fi
        
        if [ "$download_success" = false ]; then
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}❌ 自动下载失败！请手动下载工具链${NC}"
            echo -e "${YELLOW}"
            echo "手动下载方法:"
            echo ""
            echo "方法1: 使用 repo 同步 (推荐)"
            echo "  cd $KERNEL_ROOT"
            echo "  repo sync prebuilts/clang/host/linux-x86 -c --no-tags"
            echo "  repo sync prebuilts/build-tools -c --no-tags"
            echo ""
            echo "方法2: 从 GitHub 镜像下载"
            echo "  git clone --depth=1 https://github.com/AcmeUI/AcmeUI_prebuilts_clang_host_linux-x86_clang-r450784e.git $CLANG_DIR/clang-r450784e"
            echo ""
            echo "方法3: 从 AOSP 镜像下载"
            echo "  访问: https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/"
            echo "  下载 prebuilts/clang/host/linux-x86/clang-r450784e"
            echo -e "${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            exit 1
        fi
        
        # 解压
        if [ -f "$CLANG_TAR" ]; then
            log "INFO" "解压 clang-r450784e..."
            mkdir -p "$CLANG_DIR/clang-r450784e"
            tar -xzf "$CLANG_TAR" -C "$CLANG_DIR/clang-r450784e" 2>&1 | tee -a "$LOG_FILE"
            rm -f "$CLANG_TAR"
            log "SUCCESS" "clang-r450784e 下载完成"
        fi
    else
        log "INFO" "clang-r450784e 已存在，跳过下载"
    fi
    
    # 下载 build-tools
    if [ ! -d "$BUILD_TOOLS_DIR/bin" ]; then
        log "INFO" "下载 build-tools..."
        cd "$BUILD_TOOLS_DIR"
        
        local BUILD_TOOLS_TAR="$BUILD_TOOLS_DIR/build-tools.tar.gz"
        local BUILD_TOOLS_URL="https://android.googlesource.com/platform/prebuilts/build-tools/+archive/refs/heads/android13-release/linux-x86.tar.gz"
        
        local bt_success=false
        
        if [ "$download_tool" = "wget" ]; then
            wget --timeout=30 -q --show-progress -O "$BUILD_TOOLS_TAR" "$BUILD_TOOLS_URL" 2>/dev/null && bt_success=true
        else
            curl -L --connect-timeout 30 -# -o "$BUILD_TOOLS_TAR" "$BUILD_TOOLS_URL" 2>/dev/null && bt_success=true
        fi
        
        if [ "$bt_success" = true ] && [ -f "$BUILD_TOOLS_TAR" ]; then
            tar -xzf "$BUILD_TOOLS_TAR" -C "$BUILD_TOOLS_DIR" 2>&1 | tee -a "$LOG_FILE"
            rm -f "$BUILD_TOOLS_TAR"
            log "SUCCESS" "build-tools 下载完成"
        else
            log "WARN" "build-tools 下载失败，将使用系统 make"
        fi
    else
        log "INFO" "build-tools 已存在，跳过下载"
    fi
    
    cd "$SCRIPT_DIR"
    log "SUCCESS" "工具链准备完成"
}

# ============================================================================
# 工具链检测和设置 (使用绝对路径)
# ============================================================================
detect_toolchain() {
    log "STEP" "检测编译工具链 (强制使用 clang-r450784e)"
    
    # 1. 检查工具链目录存在，不存在则自动下载
    if [ ! -d "$CLANG_BIN" ]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠️  工具链目录不存在: $CLANG_BIN${NC}"
        echo -e "${YELLOW}    将自动下载 clang-r450784e 工具链...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 调用下载函数
        download_toolchain
        
        # 再次检查
        if [ ! -d "$CLANG_BIN" ]; then
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}❌ 工具链下载后仍不存在: $CLANG_BIN${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            exit 1
        fi
    fi
    
    # 2. 验证 clang 版本包含 r450784e 标识
    local clang_version=$("$TOOL_CC" --version 2>/dev/null | head -1)
    if ! echo "$clang_version" | grep -q "$EXPECTED_CLANG_ID"; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ Clang 版本不匹配！${NC}"
        echo -e "${YELLOW}期望版本标识: $EXPECTED_CLANG_ID${NC}"
        echo -e "${YELLOW}实际版本: $clang_version${NC}"
        echo -e "${YELLOW}建议: 使用与目标设备内核相同的 clang-r450784e 工具链${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi
    
    # 3. 验证所有 LLVM 工具存在且可执行
    local tools=("$TOOL_CC" "$TOOL_CXX" "$TOOL_LD" "$TOOL_AR" "$TOOL_NM" 
                 "$TOOL_STRIP" "$TOOL_OBJCOPY" "$TOOL_OBJDUMP" "$TOOL_READELF")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if [ ! -x "$tool" ]; then
            missing_tools+=("$(basename "$tool")")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ 缺少工具: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}工具链目录: $CLANG_BIN${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi
    
    # 4. 检查 make 工具 (使用系统 make)
    if ! command -v make &> /dev/null; then
        die "系统 make 不存在，请安装: apt install build-essential"
    fi
    TOOL_MAKE="make"
    
    # 5. 显示工具链信息
    log "SUCCESS" "工具链验证通过！"
    log "INFO" "Clang: $clang_version"
    log "INFO" "工具链路径: $CLANG_BIN"
    
    # 显示所有工具的绝对路径
    if $VERBOSE; then
        log "DEBUG" "工具绝对路径:"
        log "DEBUG" "  CC:      $TOOL_CC"
        log "DEBUG" "  CXX:     $TOOL_CXX"
        log "DEBUG" "  LD:      $TOOL_LD"
        log "DEBUG" "  AR:      $TOOL_AR"
        log "DEBUG" "  NM:      $TOOL_NM"
        log "DEBUG" "  STRIP:   $TOOL_STRIP"
        log "DEBUG" "  OBJCOPY: $TOOL_OBJCOPY"
        log "DEBUG" "  OBJDUMP: $TOOL_OBJDUMP"
        log "DEBUG" "  READELF: $TOOL_READELF"
        log "DEBUG" "  MAKE:    $TOOL_MAKE"
    fi
}

setup_env() {
    log "STEP" "配置编译环境 (使用绝对路径)"
    
    # 基础环境变量
    export ARCH=arm64
    export SUBARCH=arm64
    export LLVM=1
    export LLVM_IAS=1
    
    # ⚠️ 关键: 不再使用 export CC=clang 等，而是在 make 命令中直接传递绝对路径
    # 这样可以确保不会意外使用系统工具链
    
    # 清除可能干扰的环境变量
    unset CC CXX LD AR NM STRIP OBJCOPY OBJDUMP READELF
    unset HOSTCC HOSTCXX HOSTLD HOSTAR
    
    # 设置 CROSS_COMPILE (虽然使用 LLVM=1 时不需要，但保留以防万一)
    export CROSS_COMPILE=aarch64-linux-gnu-
    
    # 获取 clang 版本用于编译选项
    local clang_version_str=$("$TOOL_CC" --version | head -1)
    local clang_version=$(echo "$clang_version_str" | grep -oP 'clang version \K\d+' | head -1)
    
    if [ -z "$clang_version" ] || ! [[ "$clang_version" =~ ^[0-9]+$ ]]; then
        clang_version=14
    fi
    log "INFO" "Clang 主版本: $clang_version"
    
    # 基础兼容性编译选项 (clang 14 支持)
    local COMPAT_FLAGS=(
        "-fno-sanitize=cfi"
        "-fno-sanitize=cfi-icall"
        "-fno-sanitize=cfi-derived-cast"
        "-fno-sanitize=cfi-unrelated-cast"
        "-fno-stack-protector"
        "-fno-sanitize=shadow-call-stack"
        "-fno-sanitize=address"
        "-fno-jump-tables"
        "-fno-asynchronous-unwind-tables"
        "-fno-strict-aliasing"
        "-fno-delete-null-pointer-checks"
    )
    
    # clang 15+ 才支持 kcfi
    if [ "$clang_version" -ge 15 ] 2>/dev/null; then
        COMPAT_FLAGS+=("-fno-sanitize=kcfi")
        log "INFO" "添加 -fno-sanitize=kcfi (clang 15+)"
    else
        log "INFO" "跳过 kcfi 参数 (clang $clang_version < 15)"
    fi
    
    # clang 12+ 支持 kernel-address
    if [ "$clang_version" -ge 12 ] 2>/dev/null; then
        COMPAT_FLAGS+=("-fno-sanitize=kernel-address")
    fi
    
    # 保存编译选项供后续使用
    MODULE_CFLAGS="${COMPAT_FLAGS[*]}"
    
    log "SUCCESS" "编译环境配置完成"
    log "INFO" "所有工具将使用绝对路径，不依赖 PATH 环境变量"
}

# ============================================================================
# 环境检查
# ============================================================================
check_env() {
    log "STEP" "检查编译环境"
    
    # 检查内核源码
    if [ ! -d "$KERNEL_SRC" ]; then
        die "内核源码不存在: $KERNEL_SRC"
    fi
    
    # 检查驱动源码
    if [ ! -d "$DRIVER_SRC" ]; then
        die "驱动源码不存在: $DRIVER_SRC"
    fi
    
    # 检查必要的驱动源文件
    local REQUIRED_FILES=("hello_world.c" "Makefile")
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$DRIVER_SRC/$file" ]; then
            die "驱动源文件不存在: $DRIVER_SRC/$file"
        fi
    done
    
    log "SUCCESS" "内核源码: $KERNEL_SRC"
    log "SUCCESS" "驱动源码: $DRIVER_SRC"
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
}

# ============================================================================
# 检查是否可以跳过内核编译
# ============================================================================
can_skip_kernel_build() {
    # 检查 Module.symvers 是否存在且有效
    if [ -f "$KERNEL_SRC/Module.symvers" ]; then
        local symvers_lines=$(wc -l < "$KERNEL_SRC/Module.symvers")
        if [ "$symvers_lines" -gt 1000 ]; then
            log "INFO" "发现有效的 Module.symvers ($symvers_lines 个符号)"
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# 内核配置 (使用绝对路径)
# ============================================================================
configure_kernel() {
    log "STEP" "配置内核"
    
    cd "$KERNEL_SRC"
    
    # 检查是否需要重新配置
    if [ -f ".config" ] && ! $FORCE_REBUILD; then
        log "INFO" "使用现有内核配置"
        return 0
    fi
    
    # 使用 GKI 配置 (使用绝对路径调用 make)
    # 配置文件优先级: config > defconfig > gki_defconfig
    local REAL_CONFIG=arch/arm64/configs/config
    local DEFAULT_CONFIG=arch/arm64/configs/defconfig
    
    if [ -f "$REAL_CONFIG" ]; then
        log "INFO" "使用真实配置文件: $REAL_CONFIG"
        cp "$REAL_CONFIG" .config
    elif [ -f "$DEFAULT_CONFIG" ]; then
        log "INFO" "使用默认配置文件: $DEFAULT_CONFIG"
        "$TOOL_MAKE" ARCH=arm64 LLVM=1 \
            CC="$TOOL_CC" \
            LD="$TOOL_LD" \
            AR="$TOOL_AR" \
            NM="$TOOL_NM" \
            OBJCOPY="$TOOL_OBJCOPY" \
            OBJDUMP="$TOOL_OBJDUMP" \
            READELF="$TOOL_READELF" \
            STRIP="$TOOL_STRIP" \
            HOSTCC="$TOOL_CC" \
            HOSTCXX="$TOOL_CXX" \
            HOSTLD="$TOOL_LD" \
            HOSTAR="$TOOL_AR" \
            defconfig 2>&1 | tee -a "$LOG_FILE"
    elif [ -f "arch/arm64/configs/gki_defconfig" ]; then
        log "INFO" "生成 gki_defconfig..."
        "$TOOL_MAKE" ARCH=arm64 LLVM=1 \
            CC="$TOOL_CC" \
            LD="$TOOL_LD" \
            AR="$TOOL_AR" \
            NM="$TOOL_NM" \
            OBJCOPY="$TOOL_OBJCOPY" \
            OBJDUMP="$TOOL_OBJDUMP" \
            READELF="$TOOL_READELF" \
            STRIP="$TOOL_STRIP" \
            HOSTCC="$TOOL_CC" \
            HOSTCXX="$TOOL_CXX" \
            HOSTLD="$TOOL_LD" \
            HOSTAR="$TOOL_AR" \
            gki_defconfig 2>&1 | tee -a "$LOG_FILE"
    else
        die "未找到任何可用的配置文件 (config/defconfig/gki_defconfig)"
    fi
    
    # 禁用 KMI 检测和所有模块验证机制
    # ⚠️ 关键: 根据编译目标决定是否禁用安全特性
    if $DISABLE_SECURITY_FOR_MODULE; then
        log "WARN" "编译外部模块模式：禁用安全特性以便加载模块"
        local DISABLE_CONFIGS=(
            "CONFIG_MODULE_SIG"
            "CONFIG_MODULE_SIG_FORCE"
            "CONFIG_MODULE_SIG_ALL"
            "CONFIG_MODULE_SIG_SHA512"
            "CONFIG_MODULE_SIG_SHA1"
            "CONFIG_MODULE_SIG_HASH"
            "CONFIG_MODULE_SIG_PROTECT"
            "CONFIG_CFI_CLANG"
            "CONFIG_CFI_CLANG_SHADOW"
            "CONFIG_CFI_PERMISSIVE"
            "CONFIG_MODVERSIONS"
            "CONFIG_ASM_MODVERSIONS"
            "CONFIG_MODULE_SRCVERSION_ALL"
            "CONFIG_MODULE_SCMVERSION"
            "CONFIG_TRIM_UNUSED_KSYMS"
            "CONFIG_UNUSED_SYMBOLS"
            "CONFIG_LOCALVERSION_AUTO"
            "CONFIG_SHADOW_CALL_STACK"
        )
    else
        log "INFO" "完整内核模式：保持安全特性（匹配小米13原始配置）"
        local DISABLE_CONFIGS=(
            "CONFIG_LOCALVERSION_AUTO"
        )
    fi
    
    # 启用模块加载
    local ENABLE_CONFIGS=(
        "CONFIG_MODULE_FORCE_LOAD"
        "CONFIG_MODULE_FORCE_UNLOAD"
        "CONFIG_MODULES"
        "CONFIG_MODULE_UNLOAD"
        "CONFIG_MODULE_ALLOW_MISSING_NAMESPACE_IMPORTS"
    )
    
    # ⚠️ 关键: LTO 配置 - 小米13 使用 Full LTO
    if $USE_FULL_LTO; then
        ENABLE_CONFIGS+=("CONFIG_LTO_CLANG_FULL")
        DISABLE_CONFIGS+=("CONFIG_LTO_CLANG_THIN")
        log "INFO" "使用 Full LTO（匹配小米13内核）"
    else
        ENABLE_CONFIGS+=("CONFIG_LTO_CLANG_THIN")
        DISABLE_CONFIGS+=("CONFIG_LTO_CLANG_FULL")
        log "INFO" "使用 ThinLTO"
    fi
    
    log "INFO" "禁用 ABI 和符号白名单配置..."
    for config in "${DISABLE_CONFIGS[@]}"; do
        ./scripts/config --disable "$config" 2>/dev/null || true
    done
    
    log "INFO" "启用模块加载配置..."
    for config in "${ENABLE_CONFIGS[@]}"; do
        ./scripts/config --enable "$config" 2>/dev/null || true
    done
    
    # ⚠️ 关键: 设置正确的 LOCALVERSION 以匹配目标设备 vermagic
    log "INFO" "设置 LOCALVERSION 为 ${TARGET_LOCALVERSION}..."
    ./scripts/config --set-str CONFIG_LOCALVERSION "${TARGET_LOCALVERSION}" 2>/dev/null || true
    
    # ⚠️ 重要: 禁用 LOCALVERSION_AUTO 防止添加 git 哈希后缀
    log "INFO" "禁用 LOCALVERSION_AUTO 防止版本号自动添加 git 哈希..."
    ./scripts/config --disable CONFIG_LOCALVERSION_AUTO 2>/dev/null || true
    
    # 删除 localversion 文件 (防止干扰)
    rm -f "$KERNEL_SRC/localversion"* 2>/dev/null || true
    
    # 更新配置 (使用绝对路径)
    "$TOOL_MAKE" ARCH=arm64 LLVM=1 \
        CC="$TOOL_CC" \
        LD="$TOOL_LD" \
        AR="$TOOL_AR" \
        NM="$TOOL_NM" \
        OBJCOPY="$TOOL_OBJCOPY" \
        OBJDUMP="$TOOL_OBJDUMP" \
        READELF="$TOOL_READELF" \
        STRIP="$TOOL_STRIP" \
        HOSTCC="$TOOL_CC" \
        HOSTCXX="$TOOL_CXX" \
        HOSTLD="$TOOL_LD" \
        HOSTAR="$TOOL_AR" \
        olddefconfig 2>&1 | tee -a "$LOG_FILE"
    
    # ⚠️ 重要: olddefconfig 可能会重新启用某些配置，需要再次禁用
    log "INFO" "再次禁用 CFI 和模块签名配置（防止 olddefconfig 重新启用）..."
    for config in "${DISABLE_CONFIGS[@]}"; do
        ./scripts/config --disable "$config" 2>/dev/null || true
    done
    
    # ⚠️ 关键: 确保 LTO 类型正确
    if $USE_FULL_LTO; then
        log "INFO" "强制设置 LTO 类型为 Full LTO（匹配小米13内核）..."
        ./scripts/config --disable CONFIG_LTO_CLANG_THIN 2>/dev/null || true
        ./scripts/config --enable CONFIG_LTO_CLANG_FULL 2>/dev/null || true
    else
        log "INFO" "强制设置 LTO 类型为 ThinLTO..."
        ./scripts/config --disable CONFIG_LTO_CLANG_FULL 2>/dev/null || true
        ./scripts/config --enable CONFIG_LTO_CLANG_THIN 2>/dev/null || true
    fi
    # 确保 LTO 已启用
    ./scripts/config --enable CONFIG_LTO 2>/dev/null || true
    ./scripts/config --enable CONFIG_LTO_CLANG 2>/dev/null || true
    
    # 验证配置
    log "INFO" "验证 LOCALVERSION 配置..."
    grep "CONFIG_LOCALVERSION" .config | head -3 || true
    
    log "INFO" "验证 LTO 配置..."
    if $USE_FULL_LTO; then
        if grep -q "^CONFIG_LTO_CLANG_FULL=y" .config; then
            log "SUCCESS" "Full LTO 已正确启用（匹配小米13）"
        else
            log "WARN" "⚠️  Full LTO 未启用！强制启用..."
            sed -i 's/^CONFIG_LTO_CLANG_THIN=y/# CONFIG_LTO_CLANG_THIN is not set/' .config 2>/dev/null || true
            sed -i 's/^# CONFIG_LTO_CLANG_FULL is not set/CONFIG_LTO_CLANG_FULL=y/' .config 2>/dev/null || true
            if ! grep -q "^CONFIG_LTO_CLANG_FULL=y" .config; then
                echo "CONFIG_LTO_CLANG_FULL=y" >> .config
            fi
        fi
    else
        if grep -q "^CONFIG_LTO_CLANG_THIN=y" .config; then
            log "SUCCESS" "ThinLTO 已正确启用"
        else
            log "WARN" "⚠️  ThinLTO 未启用！强制启用..."
            sed -i 's/^CONFIG_LTO_CLANG_FULL=y/# CONFIG_LTO_CLANG_FULL is not set/' .config 2>/dev/null || true
            sed -i 's/^# CONFIG_LTO_CLANG_THIN is not set/CONFIG_LTO_CLANG_THIN=y/' .config 2>/dev/null || true
            if ! grep -q "^CONFIG_LTO_CLANG_THIN=y" .config; then
                echo "CONFIG_LTO_CLANG_THIN=y" >> .config
            fi
        fi
    fi
    
    log "INFO" "验证 CFI 配置..."
    if $DISABLE_SECURITY_FOR_MODULE; then
        if grep -q "^CONFIG_CFI_CLANG=y" .config; then
            log "WARN" "⚠️  CFI 仍然启用！这可能导致模块加载时内核崩溃"
            log "WARN" "尝试强制禁用 CFI..."
            sed -i 's/^CONFIG_CFI_CLANG=y/# CONFIG_CFI_CLANG is not set/' .config
            sed -i 's/^CONFIG_CFI_CLANG_SHADOW=y/# CONFIG_CFI_CLANG_SHADOW is not set/' .config
        else
            log "SUCCESS" "CFI 已禁用（外部模块模式）"
        fi
    else
        log "INFO" "CFI 保持原始配置（完整内核模式）"
    fi
    
    log "INFO" "验证模块签名配置..."
    if $DISABLE_SECURITY_FOR_MODULE; then
        if grep -q "^CONFIG_MODULE_SIG=y" .config; then
            log "WARN" "⚠️  模块签名仍然启用！尝试强制禁用..."
            sed -i 's/^CONFIG_MODULE_SIG=y/# CONFIG_MODULE_SIG is not set/' .config
            sed -i 's/^CONFIG_MODULE_SIG_PROTECT=y/# CONFIG_MODULE_SIG_PROTECT is not set/' .config
            sed -i 's/^CONFIG_MODULE_SIG_ALL=y/# CONFIG_MODULE_SIG_ALL is not set/' .config
        else
            log "SUCCESS" "模块签名已禁用（外部模块模式）"
        fi
    else
        log "INFO" "模块签名保持原始配置（完整内核模式）"
    fi
    
    log "INFO" "验证模块版本检查配置..."
    if $DISABLE_SECURITY_FOR_MODULE; then
        if grep -q "^CONFIG_MODVERSIONS=y" .config; then
            log "WARN" "⚠️  MODVERSIONS 仍然启用！尝试强制禁用..."
            sed -i 's/^CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' .config
            sed -i 's/^CONFIG_ASM_MODVERSIONS=y/# CONFIG_ASM_MODVERSIONS is not set/' .config
        else
            log "SUCCESS" "MODVERSIONS 已禁用（外部模块模式）"
        fi
    else
        log "INFO" "MODVERSIONS 保持原始配置（完整内核模式）"
    fi
    
    log "INFO" "验证强制模块加载已启用..."
    if grep -q "^CONFIG_MODULE_FORCE_LOAD=y" .config; then
        log "SUCCESS" "MODULE_FORCE_LOAD 已启用（可绕过 KMI 检测）"
    else
        log "WARN" "MODULE_FORCE_LOAD 未启用，尝试强制启用..."
        echo "CONFIG_MODULE_FORCE_LOAD=y" >> .config
    fi
    
    log "INFO" "验证 KMI 检测相关配置..."
    if $DISABLE_SECURITY_FOR_MODULE; then
        grep -E "CONFIG_MODULE_SIG=|CONFIG_TRIM_UNUSED_KSYMS=|CONFIG_CFI_CLANG=|CONFIG_MODVERSIONS=" .config | grep -v "^#" || log "SUCCESS" "KMI 检测相关配置已禁用"
        
        # 禁用 Shadow Call Stack
        if grep -q "^CONFIG_SHADOW_CALL_STACK=y" .config; then
            log "WARN" "⚠️  Shadow Call Stack 仍然启用！尝试禁用..."
            sed -i 's/^CONFIG_SHADOW_CALL_STACK=y/# CONFIG_SHADOW_CALL_STACK is not set/' .config
        fi
    else
        log "INFO" "保持原始安全配置（完整内核模式）"
    fi
    
    # ⚠️ 额外检查：确保模块格式兼容性
    log "INFO" "验证模块格式兼容性配置..."
    # 确保使用 ELF_RELA (现代格式)
    ./scripts/config --enable CONFIG_MODULES_USE_ELF_RELA 2>/dev/null || true
    # 禁用可能导致格式不兼容的选项
    ./scripts/config --disable CONFIG_MODULE_COMPRESS_GZIP 2>/dev/null || true
    ./scripts/config --disable CONFIG_MODULE_COMPRESS_XZ 2>/dev/null || true
    
    log "SUCCESS" "内核配置完成"
}


# ============================================================================
# 智能内核编译 (使用绝对路径)
# ============================================================================
build_kernel() {
    log "STEP" "编译内核 (生成 Module.symvers)"
    
    cd "$KERNEL_SRC"
    
    # 检查是否可以跳过
    if $SKIP_KERNEL_BUILD && can_skip_kernel_build; then
        log "SUCCESS" "跳过内核编译，使用现有 Module.symvers"
        return 0
    fi
    
    if can_skip_kernel_build && ! $FORCE_REBUILD; then
        log "INFO" "检测到已编译的内核，跳过重复编译"
        log "INFO" "使用 -f 参数强制重新编译"
        return 0
    fi
    
    log "INFO" "开始编译内核，使用 $JOBS 个线程..."
    log "WARN" "首次编译可能需要 30-60 分钟，请耐心等待..."
    log "INFO" "使用工具链: $CLANG_BIN"
    
    local start_time=$(date +%s)
    
    # 编译内核 (使用绝对路径指定所有工具)
    "$TOOL_MAKE" -C "$KERNEL_SRC" \
         ARCH=arm64 \
         LLVM=1 \
         LLVM_IAS=1 \
         CC="$TOOL_CC" \
         LD="$TOOL_LD" \
         AR="$TOOL_AR" \
         NM="$TOOL_NM" \
         STRIP="$TOOL_STRIP" \
         OBJCOPY="$TOOL_OBJCOPY" \
         OBJDUMP="$TOOL_OBJDUMP" \
         READELF="$TOOL_READELF" \
         HOSTCC="$TOOL_CC" \
         HOSTCXX="$TOOL_CXX" \
         HOSTLD="$TOOL_LD" \
         HOSTAR="$TOOL_AR" \
         -j$JOBS 2>&1 | while IFS= read -r line; do
             echo "$line" >> "$LOG_FILE"
             # 显示编译进度
             if [[ "$line" =~ ^[[:space:]]*CC|LD|AR ]]; then
                 printf "\r${CYAN}⏳ 编译中: ${NC}%-60.60s" "${line:0:60}"
             fi
         done
    
    echo ""  # 换行
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # 检查 Module.symvers
    if [ -f "$KERNEL_SRC/Module.symvers" ]; then
        local symvers_count=$(wc -l < "$KERNEL_SRC/Module.symvers")
        log "SUCCESS" "内核编译完成！耗时: ${minutes}分${seconds}秒"
        log "SUCCESS" "Module.symvers 包含 $symvers_count 个符号"
        save_state "kernel_built"
    else
        die "内核编译失败，未生成 Module.symvers"
    fi
}

# ============================================================================
# 复制内核 Image 文件到输出目录
# ============================================================================
copy_kernel_images() {
    log "STEP" "复制内核 Image 文件"
    
    local BOOT_DIR="$KERNEL_SRC/arch/arm64/boot"
    local KERNEL_OUT_DIR="$OUTPUT_DIR/kernel_images"
    
    # 创建内核输出目录
    mkdir -p "$KERNEL_OUT_DIR"
    
    local copied_count=0
    
    # 复制 Image (主要内核镜像)
    if [ -f "$BOOT_DIR/Image" ]; then
        cp "$BOOT_DIR/Image" "$KERNEL_OUT_DIR/"
        local size=$(ls -lh "$KERNEL_OUT_DIR/Image" | awk '{print $5}')
        log "SUCCESS" "Image: $size"
        copied_count=$((copied_count + 1))
    else
        log "WARN" "Image 不存在: $BOOT_DIR/Image"
    fi
    
    # 复制 Image.lz4 (LZ4 压缩格式)
    if [ -f "$BOOT_DIR/Image.lz4" ]; then
        cp "$BOOT_DIR/Image.lz4" "$KERNEL_OUT_DIR/"
        local size=$(ls -lh "$KERNEL_OUT_DIR/Image.lz4" | awk '{print $5}')
        log "SUCCESS" "Image.lz4: $size"
        copied_count=$((copied_count + 1))
    fi
    
    # 复制 Image.gz (GZIP 压缩格式)
    if [ -f "$BOOT_DIR/Image.gz" ]; then
        cp "$BOOT_DIR/Image.gz" "$KERNEL_OUT_DIR/"
        local size=$(ls -lh "$KERNEL_OUT_DIR/Image.gz" | awk '{print $5}')
        log "SUCCESS" "Image.gz: $size"
        copied_count=$((copied_count + 1))
    fi
    
    # 复制 Image.lz4-dtb (带 DTB 的 LZ4 压缩格式)
    if [ -f "$BOOT_DIR/Image.lz4-dtb" ]; then
        cp "$BOOT_DIR/Image.lz4-dtb" "$KERNEL_OUT_DIR/"
        local size=$(ls -lh "$KERNEL_OUT_DIR/Image.lz4-dtb" | awk '{print $5}')
        log "SUCCESS" "Image.lz4-dtb: $size"
        copied_count=$((copied_count + 1))
    fi
    
    # 复制 Image.gz-dtb (带 DTB 的 GZIP 压缩格式)
    if [ -f "$BOOT_DIR/Image.gz-dtb" ]; then
        cp "$BOOT_DIR/Image.gz-dtb" "$KERNEL_OUT_DIR/"
        local size=$(ls -lh "$KERNEL_OUT_DIR/Image.gz-dtb" | awk '{print $5}')
        log "SUCCESS" "Image.gz-dtb: $size"
        copied_count=$((copied_count + 1))
    fi
    
    # 复制 DTB 文件 (设备树)
    if [ -d "$BOOT_DIR/dts" ]; then
        local dtb_count=$(find "$BOOT_DIR/dts" -name "*.dtb" 2>/dev/null | wc -l)
        if [ "$dtb_count" -gt 0 ]; then
            mkdir -p "$KERNEL_OUT_DIR/dts"
            find "$BOOT_DIR/dts" -name "*.dtb" -exec cp {} "$KERNEL_OUT_DIR/dts/" \; 2>/dev/null
            log "SUCCESS" "DTB 文件: $dtb_count 个"
            copied_count=$((copied_count + dtb_count))
        fi
    fi
    
    # 复制 dtbo.img (设备树覆盖)
    if [ -f "$BOOT_DIR/dtbo.img" ]; then
        cp "$BOOT_DIR/dtbo.img" "$KERNEL_OUT_DIR/"
        local size=$(ls -lh "$KERNEL_OUT_DIR/dtbo.img" | awk '{print $5}')
        log "SUCCESS" "dtbo.img: $size"
        copied_count=$((copied_count + 1))
    fi
    
    if [ "$copied_count" -eq 0 ]; then
        log "WARN" "未找到任何内核 Image 文件"
        log "WARN" "可能原因: 内核编译未完成或配置问题"
        return 1
    fi
    
    log "SUCCESS" "共复制 $copied_count 个内核文件到 $KERNEL_OUT_DIR"
    
    # 生成内核信息文件
    local kernel_ver=$(cd "$KERNEL_SRC" && "$TOOL_MAKE" kernelrelease 2>/dev/null || echo "5.15.x")
    cat > "$KERNEL_OUT_DIR/kernel_info.txt" << EOF
内核编译信息
============================================================
编译时间: $(date '+%Y-%m-%d %H:%M:%S')
内核版本: ${kernel_ver}
目标架构: arm64
目标设备: 小米13 (Android 13)

编译配置:
  LTO 类型: $($USE_FULL_LTO && echo 'Full LTO' || echo 'ThinLTO')
  安全特性: $($DISABLE_SECURITY_FOR_MODULE && echo '禁用 (外部模块模式)' || echo '启用 (完整内核模式)')
  LOCALVERSION: ${TARGET_LOCALVERSION}

工具链:
  Clang: $("$TOOL_CC" --version | head -1)
  路径: ${CLANG_BIN}

文件列表:
$(ls -lh "$KERNEL_OUT_DIR" 2>/dev/null | grep -v "^total" | grep -v "^d")

⚠️ 刷机警告:
  1. 刷入自编译内核有变砖风险，请确保有救砖方案
  2. 建议先备份原始 boot.img
  3. 使用 --keep-security 编译的内核更接近原始配置
  4. 使用默认配置（禁用安全特性）编译的内核可加载外部模块
EOF
    
    log "INFO" "内核信息已保存到 $KERNEL_OUT_DIR/kernel_info.txt"
}

# ============================================================================
# 创建优化的驱动 Makefile
# ============================================================================
create_driver_makefile() {
    log "STEP" "检查驱动 Makefile"
    
    # 如果 Makefile 已存在且包含 hello_world，则使用现有的
    if [ -f "$DRIVER_SRC/Makefile" ]; then
        if grep -q "hello_world" "$DRIVER_SRC/Makefile"; then
            log "INFO" "使用现有的 Makefile (包含 hello_world 模块)"
            return 0
        fi
    fi
    
    # 备份原始 Makefile
    if [ -f "$DRIVER_SRC/Makefile" ] && [ ! -f "$DRIVER_SRC/Makefile.original" ]; then
        cp "$DRIVER_SRC/Makefile" "$DRIVER_SRC/Makefile.original"
    fi
    
    # 使用绝对路径的 clang 检测版本
    local clang_version=$("$TOOL_CC" --version 2>/dev/null | head -1 | grep -oP 'clang version \K\d+' | head -1)
    if [ -z "$clang_version" ] || ! [[ "$clang_version" =~ ^[0-9]+$ ]]; then
        clang_version=14
    fi
    log "INFO" "检测到 Clang 版本: $clang_version"
    
    # 生成 hello_world 模块的 Makefile
    cat > "$DRIVER_SRC/Makefile" << 'MAKEFILE_EOF'
# Hello World 内核模块 Makefile - 优化版 v5.0
# 兼容 clang 14+ 版本

# 模块名称
obj-m := hello_world.o

# 基础编译选项
ccflags-y := -Wall -Wno-declaration-after-statement
ccflags-y += -Wno-unused-function -Wno-unused-variable
ccflags-y += -Wno-format -Wno-sign-compare
ccflags-y += -Wno-implicit-function-declaration

# 禁用 CFI/安全特性 (兼容 clang 14)
ccflags-y += -fno-sanitize=cfi -fno-sanitize=cfi-icall
ccflags-y += -fno-sanitize=cfi-derived-cast -fno-sanitize=cfi-unrelated-cast
ccflags-y += -fno-stack-protector
ccflags-y += -fno-sanitize=shadow-call-stack
ccflags-y += -fno-sanitize=address

# 移除内核默认安全标志
CFLAGS_REMOVE_hello_world.o := -fsanitize=cfi -fsanitize=cfi-icall
CFLAGS_REMOVE_hello_world.o += -fsanitize=shadow-call-stack
CFLAGS_REMOVE_hello_world.o += -fstack-protector-strong -fstack-protector

# 单独文件编译选项
CFLAGS_hello_world.o := -fno-stack-protector

# 额外兼容性选项
ccflags-y += -fno-jump-tables -fno-asynchronous-unwind-tables
ccflags-y += -fno-strict-aliasing -fno-delete-null-pointer-checks
ccflags-y += -O2 -g0

# 兼容性宏定义
ccflags-y += -DCOMPAT_MODE=1 -DUNIVERSAL_MODULE=1

KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.order *.symvers .*.cmd

.PHONY: all clean
MAKEFILE_EOF

    log "SUCCESS" "驱动 Makefile 已更新为 hello_world 模块"
}

# ============================================================================
# 编译外部驱动模块 (使用绝对路径)
# ============================================================================
build_module() {
    log "STEP" "编译 hello_world.ko 模块"
    
    cd "$KERNEL_SRC"
    
    # 清理驱动目录
    log "INFO" "清理旧的编译文件..."
    rm -f "$DRIVER_SRC"/*.o "$DRIVER_SRC"/*.ko "$DRIVER_SRC"/.*.cmd 2>/dev/null || true
    rm -f "$DRIVER_SRC"/Module.symvers "$DRIVER_SRC"/modules.order 2>/dev/null || true
    
    log "INFO" "使用编译选项: $MODULE_CFLAGS"
    log "INFO" "使用工具链: $CLANG_BIN"
    
    # 编译外部模块 (使用绝对路径指定所有工具)
    log "INFO" "编译外部模块..."
    "$TOOL_MAKE" -C "$KERNEL_SRC" \
        M="$DRIVER_SRC" \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC="$TOOL_CC" \
        LD="$TOOL_LD" \
        AR="$TOOL_AR" \
        NM="$TOOL_NM" \
        STRIP="$TOOL_STRIP" \
        OBJCOPY="$TOOL_OBJCOPY" \
        OBJDUMP="$TOOL_OBJDUMP" \
        READELF="$TOOL_READELF" \
        HOSTCC="$TOOL_CC" \
        HOSTCXX="$TOOL_CXX" \
        HOSTLD="$TOOL_LD" \
        HOSTAR="$TOOL_AR" \
        EXTRA_CFLAGS="$MODULE_CFLAGS" \
        -j$JOBS \
        modules 2>&1 | tee -a "$LOG_FILE"
    
    # 检查模块
    if [ -f "$DRIVER_SRC/hello_world.ko" ]; then
        cp "$DRIVER_SRC/hello_world.ko" "$OUTPUT_DIR/"
        local size=$(ls -lh "$OUTPUT_DIR/hello_world.ko" | awk '{print $5}')
        log "SUCCESS" "模块编译成功！大小: $size"
        save_state "module_built"
    else
        die "模块编译失败，未找到 hello_world.ko"
    fi
}

# ============================================================================
# 验证模块
# ============================================================================
verify_module() {
    log "STEP" "验证模块"
    
    local ko_file="$OUTPUT_DIR/hello_world.ko"
    
    # 检查架构
    local file_type=$(file "$ko_file")
    if echo "$file_type" | grep -q "ARM aarch64"; then
        log "SUCCESS" "架构正确: ARM64"
    else
        log "WARN" "架构信息: $file_type"
    fi
    
    # 使用绝对路径的 readelf 检查未定义符号
    log "INFO" "检查未解析符号..."
    local undefined_count=$("$TOOL_READELF" -s "$ko_file" 2>/dev/null | grep -c "UND" || echo "0")
    log "INFO" "未定义符号数量: $undefined_count (这是正常的，会在加载时解析)"
    
    # 显示模块信息
    if command -v modinfo &> /dev/null; then
        log "INFO" "模块信息:"
        modinfo "$ko_file" 2>/dev/null | head -15 || true
    fi
    
    # 显示 vermagic
    local vermagic=$(modinfo -F vermagic "$ko_file" 2>/dev/null || echo "未知")
    log "INFO" "Vermagic: $vermagic"
    
    # 显示编译时使用的工具链
    log "INFO" "编译工具链: clang-$EXPECTED_CLANG_ID"
    
    # ⚠️ 诊断信息：检查可能导致 "Exec Format Error" 的问题
    log "INFO" "模块格式诊断信息:"
    local file_info=$(file "$ko_file")
    log "INFO" "  文件类型: $file_info"
    
    # 检查 ELF 格式
    if command -v readelf &> /dev/null; then
        local elf_class=$("$TOOL_READELF" -h "$ko_file" 2>/dev/null | grep "Class:" | awk '{print $2}' || echo "未知")
        local elf_machine=$("$TOOL_READELF" -h "$ko_file" 2>/dev/null | grep "Machine:" | awk '{print $2}' || echo "未知")
        local elf_type=$("$TOOL_READELF" -h "$ko_file" 2>/dev/null | grep "Type:" | awk '{print $2}' || echo "未知")
        log "INFO" "  ELF Class: $elf_class"
        log "INFO" "  ELF Machine: $elf_machine"
        log "INFO" "  ELF Type: $elf_type"
        
        # 检查是否有 BTF 段
        if "$TOOL_READELF" -S "$ko_file" 2>/dev/null | grep -q "\.BTF"; then
            log "INFO" "  BTF: 已包含"
        else
            log "WARN" "  BTF: 未包含（某些内核可能需要）"
        fi
    fi
    
    # 显示关键配置状态
    log "INFO" "编译配置状态:"
    if [ -f "$KERNEL_SRC/.config" ]; then
        local lto_type=$(grep "^CONFIG_LTO_CLANG" "$KERNEL_SRC/.config" | grep -v "^#" | head -1 || echo "未设置")
        log "INFO" "  LTO 类型: $lto_type"
        local cfi_status=$(grep "^CONFIG_CFI_CLANG" "$KERNEL_SRC/.config" | grep -v "^#" || echo "# CONFIG_CFI_CLANG is not set")
        log "INFO" "  CFI 状态: $cfi_status"
    fi
    
    log "WARN" "如果遇到 'Exec Format Error'，请检查:"
    log "WARN" "  1. 手机内核的 LTO 类型（小米13 使用 Full LTO）"
    log "WARN" "  2. 手机内核是否启用了 CFI（小米13 启用了 CFI）"
    log "WARN" "  3. 使用 'adb shell dmesg | tail -50' 查看详细错误"
    log "WARN" "  4. 如果要加载外部模块，需要刷入自编译的内核（禁用安全特性）"
}


# ============================================================================
# 生成辅助脚本
# ============================================================================
generate_scripts() {
    log "STEP" "生成辅助脚本"
    
    local kernel_ver=$(cd "$KERNEL_SRC" && "$TOOL_MAKE" kernelrelease 2>/dev/null || echo "5.15.x")
    local module_size=$(ls -lh "$OUTPUT_DIR/hello_world.ko" | awk '{print $5}')
    local module_md5=$(md5sum "$OUTPUT_DIR/hello_world.ko" | awk '{print $1}')
    local clang_version=$("$TOOL_CC" --version | head -1)
    
    # 模块信息文件
    cat > "$OUTPUT_DIR/module_info.txt" << EOF
Kernel_driver_hack 模块信息 v${SCRIPT_VERSION}
============================================================

模块信息:
  模块名称: hello_world.ko
  作者: JiangNight
  设备节点: 无 (hello_world 模块不创建设备节点)
  编译时间: $(date '+%Y-%m-%d %H:%M:%S')
  内核版本: ${kernel_ver}
  模块大小: ${module_size}
  MD5校验: ${module_md5}

编译工具链:
  Clang: ${clang_version}
  工具链路径: ${CLANG_BIN}
  期望版本标识: ${EXPECTED_CLANG_ID}

IOCTL 接口:
  - OP_INIT_KEY (0x800): 初始化验证密钥
  - OP_READ_MEM (0x801): 读取进程内存
  - OP_WRITE_MEM (0x802): 写入进程内存
  - OP_MODULE_BASE (0x803): 获取模块基址

使用方法:
  1. adb push hello_world.ko /data/local/tmp/
  2. adb push load.sh /data/local/tmp/
  3. adb shell chmod +x /data/local/tmp/load.sh
  4. adb shell su -c "/data/local/tmp/load.sh"

⚠️ 仅供学习研究使用，请遵守法律法规！
EOF

    # 智能加载脚本
    cat > "$OUTPUT_DIR/load.sh" << 'LOADER_EOF'
#!/system/bin/sh
# Kernel_driver_hack 智能加载脚本 v4.0

MODULE="/data/local/tmp/hello_world.ko"
# hello_world 模块不创建设备节点
# DEVICE="/dev/JiangNight"
LOG="/data/local/tmp/kernel_hack.log"

# 颜色支持
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "$1" | tee -a "$LOG"; }

# 清理日志
> "$LOG"

echo "=============================================="
echo "  Kernel_driver_hack 加载器 v4.0"
echo "=============================================="

# 检查 Root
[ "$(id -u)" != "0" ] && { log "${RED}❌ 需要 Root 权限${NC}"; exit 1; }

# 检查模块文件
[ ! -f "$MODULE" ] && { log "${RED}❌ 模块不存在: $MODULE${NC}"; exit 1; }

# 设备信息
log "${YELLOW}📱 设备信息:${NC}"
log "  型号: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
log "  Android: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
log "  内核: $(uname -r)"
log "  SELinux: $(getenforce 2>/dev/null || echo 'Unknown')"

# 卸载旧模块
if lsmod 2>/dev/null | grep -q hello_world; then
    log "${YELLOW}⏳ 卸载旧模块...${NC}"
    rmmod hello_world 2>/dev/null || true
fi

# 删除旧设备节点
# hello_world 模块不创建设备节点，无需删除
# [ -e "$DEVICE" ] && rm -f "$DEVICE" 2>/dev/null

# 临时禁用 SELinux
SELINUX_CHANGED=0
if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
    log "${YELLOW}⏳ 临时禁用 SELinux...${NC}"
    setenforce 0 2>/dev/null && SELINUX_CHANGED=1
fi

# 尝试加载（使用强制加载绕过 KMI 检测）
log "${YELLOW}⏳ 加载模块（绕过 KMI 检测）...${NC}"

METHODS=(
    "insmod -f $MODULE"
    "insmod --force $MODULE"
    "insmod $MODULE"
)

for method in "${METHODS[@]}"; do
    log "  尝试: $method"
    if eval "$method" 2>>"$LOG"; then
        if lsmod 2>/dev/null | grep -q hello_world; then
            log "${GREEN}✅ 模块加载成功！${NC}"
            lsmod | grep hello_world
            
            # hello_world 模块不创建设备节点，无需检查
            # sleep 1
            # if [ -e "$DEVICE" ]; then
            #     log "${GREEN}✅ 设备节点: $DEVICE${NC}"
            #     ls -l "$DEVICE"
            # fi
            
            # 恢复 SELinux
            [ "$SELINUX_CHANGED" = "1" ] && setenforce 1 2>/dev/null
            
            log ""
            log "${GREEN}🎉 加载完成！${NC}"
            exit 0
        fi
    fi
done

# 失败
log "${RED}❌ 所有加载方法都失败${NC}"
log ""
log "可能原因:"
log "  1. 内核版本不匹配"
log "  2. 设备不支持外部模块"
log "  3. 安全策略阻止"
log ""
log "查看日志: dmesg | tail -30"

[ "$SELINUX_CHANGED" = "1" ] && setenforce 1 2>/dev/null
exit 1
LOADER_EOF
    chmod +x "$OUTPUT_DIR/load.sh"

    # 卸载脚本
    cat > "$OUTPUT_DIR/unload.sh" << 'UNLOADER_EOF'
#!/system/bin/sh
# Kernel_driver_hack 卸载脚本

[ "$(id -u)" != "0" ] && { echo "需要 Root 权限"; exit 1; }

if lsmod 2>/dev/null | grep -q hello_world; then
    echo "卸载 hello_world..."
    rmmod hello_world 2>/dev/null || rmmod -f hello_world 2>/dev/null
    # hello_world 模块不创建设备节点，无需删除
    echo "✅ 卸载完成"
else
    echo "模块未加载"
fi
UNLOADER_EOF
    chmod +x "$OUTPUT_DIR/unload.sh"

    # 测试脚本
    cat > "$OUTPUT_DIR/test.sh" << 'TEST_EOF'
#!/system/bin/sh
# Kernel_driver_hack 测试脚本

echo "Kernel_driver_hack 状态检查"
echo "============================"

if lsmod 2>/dev/null | grep -q hello_world; then
    echo "✅ 模块已加载"
    lsmod | grep hello_world
else
    echo "❌ 模块未加载"
fi

# hello_world 模块不创建设备节点
if [ -e "/dev/JiangNight" ]; then
    echo "✅ 设备节点存在"
    ls -l /dev/JiangNight
else
    echo "❌ 设备节点不存在"
fi

echo ""
echo "设备信息:"
echo "  型号: $(getprop ro.product.model 2>/dev/null)"
echo "  内核: $(uname -r)"
TEST_EOF
    chmod +x "$OUTPUT_DIR/test.sh"

    # 一键部署脚本 (在主机上运行)
    cat > "$OUTPUT_DIR/deploy.sh" << 'DEPLOY_EOF'
#!/bin/bash
# 一键部署脚本 (在电脑上运行)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Kernel_driver_hack 一键部署"
echo "============================"

# 检查 ADB
if ! command -v adb &> /dev/null; then
    echo "❌ 未找到 adb 命令"
    exit 1
fi

# 检查设备连接
if ! adb devices | grep -q "device$"; then
    echo "❌ 未检测到设备"
    exit 1
fi

echo "📱 推送文件..."
adb push "$SCRIPT_DIR/hello_world.ko" /data/local/tmp/
adb push "$SCRIPT_DIR/load.sh" /data/local/tmp/
adb push "$SCRIPT_DIR/unload.sh" /data/local/tmp/
adb push "$SCRIPT_DIR/test.sh" /data/local/tmp/

echo "🔧 设置权限..."
adb shell chmod +x /data/local/tmp/*.sh

echo ""
echo "✅ 部署完成！"
echo ""
echo "加载模块: adb shell su -c '/data/local/tmp/load.sh'"
echo "测试模块: adb shell su -c '/data/local/tmp/test.sh'"
echo "卸载模块: adb shell su -c '/data/local/tmp/unload.sh'"
DEPLOY_EOF
    chmod +x "$OUTPUT_DIR/deploy.sh"
    
    log "SUCCESS" "辅助脚本已生成"
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    # 解析参数
    parse_args "$@"
    
    # 显示横幅
    echo -e "${BOLD}${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Kernel_driver_hack 编译脚本 v${SCRIPT_VERSION}"
    echo "  核心特性: 使用绝对路径指定 clang-r450784e 工具链"
    echo "  目标设备: 小米13 (Android 13, 内核 5.15.178-android13-8)"
    echo "  LTO 类型: $($USE_FULL_LTO && echo 'Full LTO' || echo 'ThinLTO')"
    echo "  安全特性: $($DISABLE_SECURITY_FOR_MODULE && echo '禁用 (外部模块模式)' || echo '启用 (完整内核模式)')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}\n"
    
    # 初始化日志
    echo "编译开始: $(date)" > "$LOG_FILE"
    echo "参数: $*" >> "$LOG_FILE"
    
    # 仅下载工具链模式
    if $DOWNLOAD_TOOLCHAIN_ONLY; then
        log "INFO" "仅下载工具链模式"
        download_toolchain
        log "SUCCESS" "工具链下载完成！"
        log "INFO" "工具链路径: $CLANG_ROOT"
        exit 0
    fi
    
    local start_time=$(date +%s)
    
    # 执行编译流程
    detect_toolchain        # 1. 检测工具链 (自动下载)
    setup_env               # 2. 设置环境变量
    check_env               # 3. 检查环境
    configure_kernel        # 4. 配置内核
    build_kernel            # 5. 编译内核 (智能跳过)
    copy_kernel_images      # 6. 复制内核 Image 文件
    create_driver_makefile  # 7. 创建驱动 Makefile
    build_module            # 8. 编译外部模块
    verify_module           # 9. 验证模块
    generate_scripts        # 10. 生成辅助脚本
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local minutes=$((total_time / 60))
    local seconds=$((total_time % 60))
    
    # 清理状态
    clear_state
    
    # 完成
    echo -e "\n${BOLD}${GREEN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ 编译完成！总耗时: ${minutes}分${seconds}秒"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}\n"
    
    echo -e "${CYAN}📦 输出目录: $OUTPUT_DIR${NC}"
    ls -lah "$OUTPUT_DIR"
    
    # 显示内核 Image 文件
    if [ -d "$OUTPUT_DIR/kernel_images" ]; then
        echo -e "\n${CYAN}🔧 内核 Image 文件:${NC}"
        ls -lah "$OUTPUT_DIR/kernel_images" 2>/dev/null | grep -v "^total" | grep -v "^d" || true
    fi
    
    echo -e "\n${YELLOW}🚀 快速部署模块:${NC}"
    echo "  cd $OUTPUT_DIR && ./deploy.sh"
    echo ""
    echo -e "${YELLOW}📱 手动部署（强制加载绕过 KMI）:${NC}"
    echo "  adb push $OUTPUT_DIR/hello_world.ko /data/local/tmp/"
    echo "  adb push $OUTPUT_DIR/load.sh /data/local/tmp/"
    echo "  adb shell chmod +x /data/local/tmp/load.sh"
    echo "  adb shell su -c '/data/local/tmp/load.sh'"
    echo ""
    echo -e "${YELLOW}💡 直接强制加载:${NC}"
    echo "  adb shell su -c 'insmod -f /data/local/tmp/hello_world.ko'"
    echo ""
    echo -e "${YELLOW}� 志内核 Image 文件位置:${NC}"
    echo "  $OUTPUT_DIR/kernel_images/"
    echo "  - Image: 原始内核镜像 (用于刷机)"
    echo "  - Image.lz4: LZ4 压缩格式 (部分设备使用)"
    echo "  - Image.gz: GZIP 压缩格式"
    echo ""
    echo -e "${GREEN}📋 日志: $LOG_FILE${NC}"
    echo ""
    echo -e "${RED}⚠️  仅供学习研究使用，请遵守法律法规！${NC}"
}

main "$@"
