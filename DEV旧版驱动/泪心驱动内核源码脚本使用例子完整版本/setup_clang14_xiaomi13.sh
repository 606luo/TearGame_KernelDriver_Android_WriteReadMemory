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
# 小米13内核模块编译环境设置脚本
# 下载并配置 clang 14.0.7 (r450784e) - 与小米13内核匹配

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  小米13内核模块编译环境设置${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
echo "目标: 下载 clang 14.0.7 (r450784e)"
echo "用途: 编译与小米13内核兼容的模块"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_DIR="$SCRIPT_DIR/toolchain"
CLANG14_DIR="$TOOLCHAIN_DIR/clang-r450784e"

# ============================================================================
# 方法 1: 使用 apt 安装 clang-14 (最简单)
# ============================================================================
install_clang14_apt() {
    echo -e "${YELLOW}方法 1: 使用 apt 安装 clang-14${NC}"
    
    # 添加 LLVM 官方源
    if ! grep -q "apt.llvm.org" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        echo -e "${CYAN}添加 LLVM 官方源...${NC}"
        wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
        
        # 获取 Ubuntu 版本
        UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
        echo "deb http://apt.llvm.org/$UBUNTU_CODENAME/ llvm-toolchain-$UBUNTU_CODENAME-14 main" | \
            sudo tee /etc/apt/sources.list.d/llvm-14.list
    fi
    
    sudo apt update
    sudo apt install -y clang-14 lld-14 llvm-14
    
    # 创建符号链接
    mkdir -p "$CLANG14_DIR/bin"
    for tool in clang clang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-strip llvm-readelf; do
        base_tool=$(echo $tool | sed 's/llvm-//')
        if [ -f "/usr/lib/llvm-14/bin/$tool" ]; then
            ln -sf "/usr/lib/llvm-14/bin/$tool" "$CLANG14_DIR/bin/$tool"
        elif [ -f "/usr/bin/${tool}-14" ]; then
            ln -sf "/usr/bin/${tool}-14" "$CLANG14_DIR/bin/$tool"
        fi
    done
    
    echo -e "${GREEN}✓ clang-14 安装完成${NC}"
}

# ============================================================================
# 方法 2: 下载 Android prebuilt clang (推荐，版本完全匹配)
# ============================================================================
download_android_clang14() {
    echo -e "${YELLOW}方法 2: 下载 Android prebuilt clang 14.0.7${NC}"
    
    mkdir -p "$TOOLCHAIN_DIR"
    cd "$TOOLCHAIN_DIR"
    
    # 检查是否已下载
    if [ -d "clang-r450784e" ] && [ -f "clang-r450784e/bin/clang" ]; then
        echo -e "${GREEN}✓ clang-r450784e 已存在${NC}"
        return 0
    fi
    
    echo -e "${CYAN}从清华镜像下载 Android clang...${NC}"
    echo "这可能需要几分钟，文件较大 (~1GB)"
    echo ""
    
    # 使用 git sparse-checkout 只下载需要的目录
    if [ -d "android-clang-temp" ]; then
        rm -rf android-clang-temp
    fi
    
    git clone --filter=blob:none --sparse \
        https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/prebuilts/clang/host/linux-x86.git \
        android-clang-temp \
        -b android13-release --depth 1
    
    cd android-clang-temp
    git sparse-checkout set clang-r450784e
    
    # 移动到目标位置
    mv clang-r450784e ../
    cd ..
    rm -rf android-clang-temp
    
    echo -e "${GREEN}✓ clang-r450784e 下载完成${NC}"
}

# ============================================================================
# 方法 3: 手动下载指引
# ============================================================================
manual_download_guide() {
    echo -e "${YELLOW}方法 3: 手动下载${NC}"
    echo ""
    echo "如果自动下载失败，请手动执行以下步骤:"
    echo ""
    echo "1. 访问: https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/android13-release"
    echo ""
    echo "2. 或使用 repo 工具:"
    echo "   mkdir aosp-clang && cd aosp-clang"
    echo "   repo init -u https://android.googlesource.com/platform/manifest -b android13-release"
    echo "   repo sync prebuilts/clang/host/linux-x86"
    echo ""
    echo "3. 将 clang-r450784e 目录复制到: $TOOLCHAIN_DIR/"
}

# ============================================================================
# 主逻辑
# ============================================================================
echo "请选择安装方法:"
echo "  1) apt 安装 clang-14 (简单快速，版本接近)"
echo "  2) 下载 Android prebuilt (推荐，版本完全匹配)"
echo "  3) 显示手动下载指引"
echo ""
read -p "请输入选项 [1/2/3]: " choice

case $choice in
    1)
        install_clang14_apt
        ;;
    2)
        download_android_clang14
        ;;
    3)
        manual_download_guide
        exit 0
        ;;
    *)
        echo "无效选项，使用默认方法 2"
        download_android_clang14
        ;;
esac

# 验证安装
echo ""
echo -e "${YELLOW}验证安装...${NC}"

if [ -f "$CLANG14_DIR/bin/clang" ]; then
    VERSION=$("$CLANG14_DIR/bin/clang" --version | head -1)
    echo -e "${GREEN}✓ Clang 已安装: $VERSION${NC}"
    echo ""
    echo -e "${CYAN}环境变量设置:${NC}"
    echo "export CLANG14_BIN=$CLANG14_DIR/bin"
    echo ""
    echo -e "${CYAN}现在可以运行编译脚本:${NC}"
    echo "cd $SCRIPT_DIR/Kernel_driver_hack-main/hello_world"
    echo "./build_xiaomi13.sh"
elif [ -f "/usr/lib/llvm-14/bin/clang" ]; then
    VERSION=$("/usr/lib/llvm-14/bin/clang" --version | head -1)
    echo -e "${GREEN}✓ Clang 已安装: $VERSION${NC}"
    echo ""
    echo "export CLANG14_BIN=/usr/lib/llvm-14/bin"
else
    echo -e "${RED}✗ 安装验证失败${NC}"
    exit 1
fi
