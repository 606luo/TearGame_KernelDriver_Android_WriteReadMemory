#!/bin/bash
# ============================================================
# 下载 Clang r383902 (11.0.1) 交叉编译工具链
# 适用于: 红米K40游戏增强版 (ares) 内核编译
# 内核源码: redmi_k40_gaming_kernel
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
CLANG_VERSION="r383902"
CLANG_BRANCH="android11-release"
TOOLCHAIN_DIR="${HOME}/toolchain"
CLANG_DIR="${TOOLCHAIN_DIR}/clang-${CLANG_VERSION}"

# 下载源 (Google官方)
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/${CLANG_BRANCH}/clang-${CLANG_VERSION}.tar.gz"

# 备用下载源 (GitHub镜像)
CLANG_URL_MIRROR="https://github.com/AcmeUI/AcmeUI-Clang/releases/download/clang-r383902/clang-r383902.tar.gz"

# 另一个备用源 (直接从Android CI)
CLANG_URL_CI="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/android-11.0.0_r1/clang-r383902.tar.gz"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Clang ${CLANG_VERSION} (11.0.1) 下载脚本${NC}"
echo -e "${BLUE}  适用于: 红米K40游戏增强版内核编译${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# 创建工具链目录
echo -e "${YELLOW}[1/5] 创建工具链目录...${NC}"
mkdir -p "${CLANG_DIR}"

# 检查是否已存在
if [ -f "${CLANG_DIR}/bin/clang" ]; then
    echo -e "${GREEN}Clang ${CLANG_VERSION} 已存在于 ${CLANG_DIR}${NC}"
    echo -e "${YELLOW}是否重新下载? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}跳过下载${NC}"
        exit 0
    fi
    rm -rf "${CLANG_DIR}"
    mkdir -p "${CLANG_DIR}"
fi

# 下载函数
download_clang() {
    local url=$1
    local desc=$2
    
    echo -e "${YELLOW}尝试从 ${desc} 下载...${NC}"
    echo -e "${BLUE}URL: ${url}${NC}"
    
    if curl -L --progress-bar -o "/tmp/clang-${CLANG_VERSION}.tar.gz" "${url}" 2>/dev/null; then
        # 验证下载的文件
        if file "/tmp/clang-${CLANG_VERSION}.tar.gz" | grep -q "gzip"; then
            return 0
        fi
    fi
    return 1
}

# 尝试下载
echo -e "${YELLOW}[2/5] 下载 Clang ${CLANG_VERSION}...${NC}"

downloaded=false

# 方法1: 从Google官方源下载
if download_clang "${CLANG_URL}" "Google官方源"; then
    downloaded=true
fi

# 方法2: 从Android CI下载
if [ "$downloaded" = false ]; then
    if download_clang "${CLANG_URL_CI}" "Android CI"; then
        downloaded=true
    fi
fi

# 方法3: 使用repo同步 (最可靠的方法)
if [ "$downloaded" = false ]; then
    echo -e "${YELLOW}尝试使用 repo 同步方式下载...${NC}"
    
    TEMP_REPO_DIR="/tmp/clang_repo_$$"
    mkdir -p "${TEMP_REPO_DIR}"
    cd "${TEMP_REPO_DIR}"
    
    # 初始化repo
    if command -v repo &> /dev/null; then
        repo init -u https://android.googlesource.com/platform/manifest -b android-11.0.0_r1 --depth=1 2>/dev/null || true
        
        # 只同步clang工具链
        mkdir -p .repo/local_manifests
        cat > .repo/local_manifests/clang.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project path="prebuilts/clang/host/linux-x86" name="platform/prebuilts/clang/host/linux-x86" revision="android-11.0.0_r1" clone-depth="1" />
</manifest>
EOF
        
        if repo sync -c -j$(nproc) --no-tags prebuilts/clang/host/linux-x86 2>/dev/null; then
            if [ -d "prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}" ]; then
                cp -r "prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}"/* "${CLANG_DIR}/"
                downloaded=true
            fi
        fi
    fi
    
    cd - > /dev/null
    rm -rf "${TEMP_REPO_DIR}"
fi

# 方法4: 直接git clone (精简版)
if [ "$downloaded" = false ]; then
    echo -e "${YELLOW}尝试 git clone 方式...${NC}"
    
    TEMP_GIT_DIR="/tmp/clang_git_$$"
    
    # 尝试从镜像仓库克隆
    if git clone --depth=1 --single-branch -b android-11.0.0_r1 \
        https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
        "${TEMP_GIT_DIR}" 2>/dev/null; then
        
        if [ -d "${TEMP_GIT_DIR}/clang-${CLANG_VERSION}" ]; then
            cp -r "${TEMP_GIT_DIR}/clang-${CLANG_VERSION}"/* "${CLANG_DIR}/"
            downloaded=true
        fi
    fi
    
    rm -rf "${TEMP_GIT_DIR}"
fi

# 检查下载结果
if [ "$downloaded" = false ]; then
    echo -e "${RED}所有下载方式都失败了${NC}"
    echo ""
    echo -e "${YELLOW}请手动下载:${NC}"
    echo "1. 访问: https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/android11-release"
    echo "2. 找到 clang-r383902 目录"
    echo "3. 下载并解压到: ${CLANG_DIR}"
    echo ""
    echo -e "${YELLOW}或者使用以下命令手动克隆:${NC}"
    echo "git clone --depth=1 -b android-11.0.0_r1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86"
    exit 1
fi

# 解压 (如果是tar.gz文件)
echo -e "${YELLOW}[3/5] 解压文件...${NC}"
if [ -f "/tmp/clang-${CLANG_VERSION}.tar.gz" ]; then
    tar -xzf "/tmp/clang-${CLANG_VERSION}.tar.gz" -C "${CLANG_DIR}"
    rm -f "/tmp/clang-${CLANG_VERSION}.tar.gz"
fi

# 验证安装
echo -e "${YELLOW}[4/5] 验证安装...${NC}"
if [ -f "${CLANG_DIR}/bin/clang" ]; then
    CLANG_VER=$("${CLANG_DIR}/bin/clang" --version 2>/dev/null | head -1 || echo "未知版本")
    echo -e "${GREEN}Clang 版本: ${CLANG_VER}${NC}"
else
    echo -e "${RED}错误: clang 二进制文件不存在${NC}"
    exit 1
fi

# 创建环境设置脚本
echo -e "${YELLOW}[5/5] 创建环境设置脚本...${NC}"
cat > "${CLANG_DIR}/env_setup.sh" << EOF
#!/bin/bash
# Clang ${CLANG_VERSION} 环境设置
# 适用于: 红米K40游戏增强版内核编译

export CLANG_PATH="${CLANG_DIR}"
export PATH="\${CLANG_PATH}/bin:\${PATH}"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-

# 验证
echo "Clang 路径: \${CLANG_PATH}"
clang --version | head -1
EOF

chmod +x "${CLANG_DIR}/env_setup.sh"

# 完成
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Clang ${CLANG_VERSION} 安装完成!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${BLUE}安装路径: ${CLANG_DIR}${NC}"
echo ""
echo -e "${YELLOW}使用方法:${NC}"
echo "  source ${CLANG_DIR}/env_setup.sh"
echo ""
echo -e "${YELLOW}编译红米K40游戏增强版内核示例:${NC}"
echo "  cd redmi_k40_gaming_kernel"
echo "  source ${CLANG_DIR}/env_setup.sh"
echo "  make ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- ares_defconfig"
echo "  make ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- -j\$(nproc)"
echo ""
