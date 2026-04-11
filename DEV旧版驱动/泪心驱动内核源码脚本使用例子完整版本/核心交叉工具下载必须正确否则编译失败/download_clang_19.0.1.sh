#!/bin/bash
#
# 下载 Android Clang 19.0.1 (clang-r536225) 交叉编译工具链
#
# GKI 6.12 内核需要使用 clang 19.0.1 版本编译
# 工具链版本: clang-r536225 (对应 clang 19.0.1)
#
# 下载源: Android AOSP prebuilts
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
TOOLCHAIN_DIR="$HOME/toolchain"
CLANG_VERSION="clang-r536225"
CLANG_DIR="$TOOLCHAIN_DIR/$CLANG_VERSION"

# Google 官方 tar.gz 下载地址 (gitiles archive)
DOWNLOAD_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/${CLANG_VERSION}.tar.gz"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "=========================================="
echo "  下载 Android Clang 19.0.1 工具链"
echo "  版本: $CLANG_VERSION"
echo "=========================================="
echo ""

# 创建目录
print_info "创建工具链目录: $TOOLCHAIN_DIR"
mkdir -p "$TOOLCHAIN_DIR"
cd "$TOOLCHAIN_DIR"

# 检查是否已存在
if [ -d "$CLANG_DIR" ]; then
    print_warning "工具链目录已存在: $CLANG_DIR"
    read -p "是否删除并重新下载? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        rm -rf "$CLANG_DIR"
    else
        print_info "跳过下载"
        exit 0
    fi
fi

# 创建目标目录
mkdir -p "$CLANG_DIR"

# 下载工具链
download_toolchain() {
    print_info "开始下载 Clang 19.0.1 工具链..."
    
    # 方法1: 从 Google gitiles 下载 tar.gz
    print_info "尝试从 Google 官方源下载..."
    print_info "URL: $DOWNLOAD_URL"
    
    if curl -L -o "${CLANG_VERSION}.tar.gz" "$DOWNLOAD_URL" --progress-bar 2>&1; then
        # 检查文件是否有效
        if [ -s "${CLANG_VERSION}.tar.gz" ] && file "${CLANG_VERSION}.tar.gz" | grep -q "gzip"; then
            print_success "下载成功 (Google 官方源)"
            return 0
        fi
        rm -f "${CLANG_VERSION}.tar.gz"
    fi
    
    print_warning "Google 官方源下载失败，尝试备用方案..."
    
    # 方法2: 使用 repo sync 单独下载 clang
    print_info "尝试使用 repo 下载..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # 创建 repo manifest
    mkdir -p .repo
    cat > .repo/manifest.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="aosp" fetch="https://android.googlesource.com/" />
  <default revision="main" remote="aosp" sync-j="4" />
  <project path="prebuilts/clang/host/linux-x86" name="platform/prebuilts/clang/host/linux-x86" clone-depth="1" />
</manifest>
EOF
    
    if command -v repo &> /dev/null; then
        repo init -u https://android.googlesource.com/platform/manifest -b main --depth=1 2>/dev/null || true
        repo sync prebuilts/clang/host/linux-x86 --current-branch --no-tags -j4 2>/dev/null && {
            if [ -d "prebuilts/clang/host/linux-x86/$CLANG_VERSION" ]; then
                cp -r "prebuilts/clang/host/linux-x86/$CLANG_VERSION"/* "$CLANG_DIR/"
                cd "$TOOLCHAIN_DIR"
                rm -rf "$TEMP_DIR"
                print_success "下载成功 (repo sync)"
                return 0
            fi
        }
    fi
    
    cd "$TOOLCHAIN_DIR"
    rm -rf "$TEMP_DIR"
    
    # 方法3: 使用 git sparse-checkout
    print_info "尝试使用 git sparse-checkout..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone --depth=1 --filter=blob:none --sparse \
        https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
        clang-repo 2>/dev/null && {
        cd clang-repo
        git sparse-checkout set "$CLANG_VERSION"
        
        if [ -d "$CLANG_VERSION" ]; then
            cp -r "$CLANG_VERSION"/* "$CLANG_DIR/"
            cd "$TOOLCHAIN_DIR"
            rm -rf "$TEMP_DIR"
            print_success "下载成功 (git sparse-checkout)"
            return 0
        fi
    }
    
    cd "$TOOLCHAIN_DIR"
    rm -rf "$TEMP_DIR"
    
    # 方法4: 从第三方镜像下载
    print_info "尝试从第三方镜像下载..."
    
    # ZY Clang 或其他社区维护的镜像
    MIRRORS=(
        "https://gitlab.com/AntMan-opensource/AntMan-opensource.gitlab.io/-/raw/main/clang/${CLANG_VERSION}.tar.gz"
        "https://github.com/AntMan-opensource/AntMan-opensource.github.io/releases/download/${CLANG_VERSION}/${CLANG_VERSION}.tar.gz"
    )
    
    for mirror in "${MIRRORS[@]}"; do
        print_info "尝试: $mirror"
        if curl -L -o "${CLANG_VERSION}.tar.gz" "$mirror" --progress-bar 2>&1; then
            if [ -s "${CLANG_VERSION}.tar.gz" ]; then
                print_success "下载成功 (第三方镜像)"
                return 0
            fi
        fi
        rm -f "${CLANG_VERSION}.tar.gz"
    done
    
    print_error "所有下载方式都失败了!"
    print_info ""
    print_info "请手动下载工具链:"
    print_info "1. 访问: https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/main"
    print_info "2. 找到 $CLANG_VERSION 目录"
    print_info "3. 点击 'tgz' 下载"
    print_info "4. 解压到: $CLANG_DIR"
    return 1
}

download_toolchain

# 解压 (如果是 tar.gz)
cd "$TOOLCHAIN_DIR"
if [ -f "${CLANG_VERSION}.tar.gz" ]; then
    print_info "解压工具链..."
    tar -xzf "${CLANG_VERSION}.tar.gz" -C "$CLANG_DIR"
    rm -f "${CLANG_VERSION}.tar.gz"
fi

# 验证安装
print_info "验证工具链安装..."

if [ -f "$CLANG_DIR/bin/clang" ]; then
    CLANG_VER=$("$CLANG_DIR/bin/clang" --version | head -n1)
    print_success "Clang 安装成功!"
    print_info "版本: $CLANG_VER"
else
    print_error "Clang 安装验证失败"
    print_info "请检查 $CLANG_DIR/bin/clang 是否存在"
    exit 1
fi

# 显示版本信息
if [ -f "$CLANG_DIR/AndroidVersion.txt" ]; then
    print_info "Android 版本信息:"
    cat "$CLANG_DIR/AndroidVersion.txt"
fi

# 创建符号链接 (可选)
print_info "创建符号链接..."
ln -sf "$CLANG_DIR" "$TOOLCHAIN_DIR/clang-19.0.1"

echo ""
echo "=========================================="
print_success "Clang 19.0.1 工具链安装完成!"
echo "=========================================="
echo ""
echo "安装路径: $CLANG_DIR"
echo "符号链接: $TOOLCHAIN_DIR/clang-19.0.1"
echo ""
echo "使用方法:"
echo "  export PATH=\"$CLANG_DIR/bin:\$PATH\""
echo ""
echo "更新编译脚本:"
echo "  将 TOOLCHAIN_DIR 改为: $CLANG_DIR"
echo ""
