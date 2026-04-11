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
# Kernel_driver_hack 编译依赖安装脚本

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}"
echo "=============================================="
echo "  Kernel_driver_hack 编译依赖安装工具"
echo "=============================================="
echo -e "${NC}\n"

# 检查系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}无法检测系统类型${NC}"
    exit 1
fi

echo -e "${CYAN}检测到系统: $OS $VER${NC}\n"

# 更新包管理器
echo -e "${YELLOW}正在更新包管理器...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    sudo apt update
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    sudo yum update -y || sudo dnf update -y
elif [[ "$OS" == *"Arch"* ]]; then
    sudo pacman -Sy
else
    echo -e "${YELLOW}未知系统，请手动安装依赖${NC}"
fi

# 安装基础编译工具
echo -e "\n${YELLOW}正在安装基础编译工具...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    sudo apt install -y \
        build-essential \
        make \
        gcc \
        g++ \
        git \
        wget \
        curl \
        python3 \
        python3-pip \
        flex \
        bison \
        libssl-dev \
        libelf-dev \
        bc \
        kmod \
        cpio \
        rsync
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    sudo yum groupinstall -y "Development Tools" || sudo dnf groupinstall -y "Development Tools"
    sudo yum install -y \
        make \
        gcc \
        gcc-c++ \
        git \
        wget \
        curl \
        python3 \
        python3-pip \
        flex \
        bison \
        openssl-devel \
        elfutils-libelf-devel \
        bc \
        kmod \
        cpio \
        rsync || \
    sudo dnf install -y \
        make \
        gcc \
        gcc-c++ \
        git \
        wget \
        curl \
        python3 \
        python3-pip \
        flex \
        bison \
        openssl-devel \
        elfutils-libelf-devel \
        bc \
        kmod \
        cpio \
        rsync
elif [[ "$OS" == *"Arch"* ]]; then
    sudo pacman -S --noconfirm \
        base-devel \
        make \
        gcc \
        git \
        wget \
        curl \
        python \
        python-pip \
        flex \
        bison \
        openssl \
        libelf \
        bc \
        kmod \
        cpio \
        rsync
fi
# 安装 LLVM/Clang 工具链
echo -e "\n${YELLOW}正在安装 LLVM/Clang 工具链...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    # 添加 LLVM 官方源
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
    
    # 根据 Ubuntu 版本添加源
    if [[ "$VER" == "22.04" ]]; then
        echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-15 main" | sudo tee /etc/apt/sources.list.d/llvm.list
    elif [[ "$VER" == "20.04" ]]; then
        echo "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-15 main" | sudo tee /etc/apt/sources.list.d/llvm.list
    fi
    
    sudo apt update
    sudo apt install -y \
        clang-15 \
        llvm-15 \
        llvm-15-dev \
        llvm-15-tools \
        lld-15 \
        libc++-15-dev \
        libc++abi-15-dev
    
    # 创建符号链接
    sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 100
    sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100
    sudo update-alternatives --install /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-15 100
    sudo update-alternatives --install /usr/bin/llvm-nm llvm-nm /usr/bin/llvm-nm-15 100
    sudo update-alternatives --install /usr/bin/llvm-strip llvm-strip /usr/bin/llvm-strip-15 100
    sudo update-alternatives --install /usr/bin/llvm-objcopy llvm-objcopy /usr/bin/llvm-objcopy-15 100
    sudo update-alternatives --install /usr/bin/llvm-objdump llvm-objdump /usr/bin/llvm-objdump-15 100
    sudo update-alternatives --install /usr/bin/llvm-readelf llvm-readelf /usr/bin/llvm-readelf-15 100
    sudo update-alternatives --install /usr/bin/lld lld /usr/bin/lld-15 100
    
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    sudo yum install -y clang llvm llvm-devel || sudo dnf install -y clang llvm llvm-devel
elif [[ "$OS" == *"Arch"* ]]; then
    sudo pacman -S --noconfirm clang llvm lld
fi

# 安装 ARM64 交叉编译工具链
echo -e "\n${YELLOW}正在安装 ARM64 交叉编译工具链...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    sudo apt install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        binutils-aarch64-linux-gnu
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    sudo yum install -y gcc-aarch64-linux-gnu || sudo dnf install -y gcc-aarch64-linux-gnu
elif [[ "$OS" == *"Arch"* ]]; then
    sudo pacman -S --noconfirm aarch64-linux-gnu-gcc
fi

# 验证工具安装
echo -e "\n${YELLOW}验证工具安装...${NC}"

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓ $1 已安装${NC}"
        $1 --version | head -1
    else
        echo -e "${RED}✗ $1 未找到${NC}"
        return 1
    fi
}

echo -e "\n${CYAN}基础工具:${NC}"
check_tool "make"
check_tool "gcc"
check_tool "git"

echo -e "\n${CYAN}LLVM/Clang 工具链:${NC}"
check_tool "clang"
check_tool "llvm-ar"
check_tool "llvm-nm"
check_tool "lld"

echo -e "\n${CYAN}ARM64 交叉编译工具:${NC}"
check_tool "aarch64-linux-gnu-gcc"

# 检查内核编译相关工具
echo -e "\n${CYAN}内核编译工具:${NC}"
check_tool "flex"
check_tool "bison"
check_tool "bc"
# 创建环境配置文件
echo -e "\n${YELLOW}创建环境配置文件...${NC}"
cat > ~/.kernel_build_env << 'EOF'
# Kernel_driver_hack 编译环境配置
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LLVM=1
export LLVM_IAS=1
export CC=clang
export CXX=clang++
export AR=llvm-ar
export NM=llvm-nm
export STRIP=llvm-strip
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf

echo "Kernel_driver_hack 编译环境已加载"
EOF

# 添加到 bashrc
if ! grep -q "kernel_build_env" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Kernel_driver_hack 编译环境" >> ~/.bashrc
    echo "source ~/.kernel_build_env" >> ~/.bashrc
fi

echo -e "\n${GREEN}✓ 依赖安装完成！${NC}"
echo -e "\n${CYAN}使用说明:${NC}"
echo "1. 重新打开终端或运行: source ~/.bashrc"
echo "2. 进入项目目录: cd android-kernel-5.15"
echo "3. 运行编译脚本: ./快速编译Kernel_driver_hack.sh"
echo ""
echo -e "${YELLOW}注意事项:${NC}"
echo "- 确保有足够的磁盘空间 (至少 20GB)"
echo "- 编译过程可能需要较长时间"
echo "- 如遇问题请查看编译日志"
echo ""
echo -e "${GREEN}现在可以开始编译 Kernel_driver_hack 驱动了！${NC}"