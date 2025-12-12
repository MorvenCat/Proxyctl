#!/bin/bash

# proxyctl 卸载脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/MorvenCat/proxyctl/main/uninstall.sh | bash

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}正在卸载 proxyctl...${NC}"

# 检测 shell 类型
detect_shell() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "zsh"
        return
    elif [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
        return
    fi
    
    if [ -n "${SHELL:-}" ]; then
        local current_shell="${SHELL##*/}"
        case "$current_shell" in
            zsh)
                echo "zsh"
                return
                ;;
            bash)
                echo "bash"
                return
                ;;
        esac
    fi
    
    if [ -f "$HOME/.zshrc" ]; then
        echo "zsh"
    elif [ -f "$HOME/.bashrc" ]; then
        echo "bash"
    else
        echo "bash"
    fi
}

# 获取配置文件路径
get_config_file() {
    local shell_type="$1"
    case "$shell_type" in
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                echo "$HOME/.zshrc"
            elif [ -f "$HOME/.zprofile" ]; then
                echo "$HOME/.zprofile"
            else
                echo "$HOME/.zshrc"
            fi
            ;;
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            elif [ -f "$HOME/.profile" ]; then
                echo "$HOME/.profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        *)
            echo "$HOME/.bashrc"
            ;;
    esac
}

SHELL_TYPE=$(detect_shell)
CONFIG_FILE=$(get_config_file "$SHELL_TYPE")

echo -e "${YELLOW}检测到 shell: $SHELL_TYPE${NC}"
echo -e "${YELLOW}配置文件: $CONFIG_FILE${NC}"

# 1. 从配置文件中移除 proxyctl 相关配置
if [ -f "$CONFIG_FILE" ]; then
    # 创建临时文件
    temp_file=$(mktemp)
    
    # 移除包含 proxyctl 的行
    grep -v "proxyctl" "$CONFIG_FILE" | grep -v "proxy.sh" > "$temp_file" || true
    
    # 如果文件有变化，替换原文件
    if ! diff -q "$CONFIG_FILE" "$temp_file" >/dev/null 2>&1; then
        mv "$temp_file" "$CONFIG_FILE"
        echo -e "${GREEN}✓ 已从 $CONFIG_FILE 中移除配置${NC}"
    else
        rm -f "$temp_file"
        echo -e "${YELLOW}⚠ $CONFIG_FILE 中未找到 proxyctl 配置${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 配置文件不存在: $CONFIG_FILE${NC}"
fi

# 2. 删除脚本文件
INSTALL_DIR="$HOME/.local/bin"
if [ -f "$INSTALL_DIR/proxy.sh" ]; then
    rm -f "$INSTALL_DIR/proxy.sh"
    echo -e "${GREEN}✓ 已删除 $INSTALL_DIR/proxy.sh${NC}"
else
    echo -e "${YELLOW}⚠ 脚本文件不存在: $INSTALL_DIR/proxy.sh${NC}"
fi

# 3. 删除配置文件
if [ -f "$HOME/.proxy_config" ]; then
    rm -f "$HOME/.proxy_config"
    echo -e "${GREEN}✓ 已删除 $HOME/.proxy_config${NC}"
else
    echo -e "${YELLOW}⚠ 配置文件不存在: $HOME/.proxy_config${NC}"
fi

# 4. 清除当前 shell 中的环境变量（提示用户）
echo ""
echo -e "${GREEN}卸载完成！${NC}"
echo ""
echo -e "${YELLOW}注意: 当前终端会话中的代理环境变量仍然存在${NC}"
echo -e "${YELLOW}请运行以下命令清除，或重新打开终端：${NC}"
echo -e "  ${GREEN}unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY socks_proxy SOCKS_PROXY${NC}"
echo ""


