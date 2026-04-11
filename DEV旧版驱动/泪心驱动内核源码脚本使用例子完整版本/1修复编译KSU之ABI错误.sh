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
# 修复 GKI ABI 符号列表错误
# 解决 "abi_symbollist.raw whitelist file not found" 问题

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR/kernel"

cd "$KERNEL_DIR"

echo -e "${BLUE}=========================================="
echo "  修复 GKI ABI 错误"
echo -e "==========================================${NC}\n"

echo -e "${YELLOW}问题: abi_symbollist.raw whitelist file not found${NC}"
echo -e "${YELLOW}原因: GKI ABI 检查需要符号列表文件，但环境中不存在${NC}\n"

echo -e "${GREEN}>>> 应用修复...${NC}\n"

# 检查是否有 .config 文件
if [ ! -f ".config" ]; then
    echo -e "${RED}错误: 未找到 .config 文件${NC}"
    echo -e "${YELLOW}请先运行编译脚本生成配置文件${NC}"
    exit 1
fi

# 方法1: 禁用内核配置中的相关选项
echo -e "${BLUE}[1/2] 修改内核配置...${NC}"

if [ -f "scripts/config" ]; then
    ./scripts/config --disable UNUSED_KSYMS_WHITELIST
    ./scripts/config --set-val TRIM_UNUSED_KSYMS n
    echo -e "${GREEN}✓ 已禁用 UNUSED_KSYMS_WHITELIST${NC}"
else
    # 手动修改配置文件
    sed -i 's/CONFIG_UNUSED_KSYMS_WHITELIST=y/# CONFIG_UNUSED_KSYMS_WHITELIST is not set/g' .config
    sed -i 's/CONFIG_TRIM_UNUSED_KSYMS=y/# CONFIG_TRIM_UNUSED_KSYMS is not set/g' .config
    echo -e "${GREEN}✓ 已手动修改配置文件${NC}"
fi

# 方法2: 创建环境变量导出脚本
echo -e "\n${BLUE}[2/2] 创建环境变量脚本...${NC}"

cat > "$KERNEL_DIR/disable_abi_check.sh" << 'EOF'
#!/bin/bash
# 禁用 GKI ABI 检查的环境变量
# 使用方法: source disable_abi_check.sh

export TRIM_NONLISTED_KMI=0
export KMI_SYMBOL_LIST_STRICT_MODE=0
export KBUILD_MIXED_TREE=
unset ABI_DEFINITION
unset KMI_SYMBOL_LIST
unset ADDITIONAL_KMI_SYMBOL_LISTS
unset KMI_ENFORCED

echo "✓ GKI ABI 检查已禁用"
EOF

chmod +x "$KERNEL_DIR/disable_abi_check.sh"
echo -e "${GREEN}✓ 已创建 disable_abi_check.sh${NC}"

# 更新配置
echo -e "\n${BLUE}更新配置...${NC}"
yes "" | make oldconfig 2>/dev/null || true

echo -e "\n${GREEN}=========================================="
echo "  ✅ 修复完成！"
echo -e "==========================================${NC}\n"

echo -e "${YELLOW}现在可以重新编译:${NC}"
echo ""
echo "方法1: 使用修复后的编译脚本"
echo -e "  ${BLUE}./编译小米13内核.sh${NC}"
echo ""
echo "方法2: 手动编译（先加载环境变量）"
echo -e "  ${BLUE}source disable_abi_check.sh${NC}"
echo -e "  ${BLUE}make modules -j\$(nproc)${NC}"
echo ""

echo -e "${GREEN}提示: 编译脚本已自动更新，包含此修复${NC}"

