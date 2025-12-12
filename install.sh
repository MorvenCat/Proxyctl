#!/bin/bash

# proxyctl 一键安装脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/MorvenCat/proxyctl/main/install.sh | bash

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检测 shell 类型
detect_shell() {
    # 方法1: 从当前运行的 shell 判断（最准确）
    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "zsh"
        return
    elif [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
        return
    fi
    
    # 方法2: 从 $SHELL 环境变量判断
    if [ -n "$SHELL" ]; then
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
    
    # 方法3: 检查配置文件存在情况（macOS 默认 zsh，Linux 默认 bash）
    if [ -f "$HOME/.zshrc" ]; then
        echo "zsh"
        return
    elif [ -f "$HOME/.bashrc" ]; then
        echo "bash"
        return
    elif [ -f "$HOME/.bash_profile" ]; then
        echo "bash"
        return
    fi
    
    # 方法4: 根据操作系统判断（macOS 默认 zsh，Linux 默认 bash）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "zsh"  # macOS 默认使用 zsh
    else
        echo "bash"  # Linux 默认使用 bash
    fi
}

# 获取配置文件路径（尝试多个可能的配置文件）
get_config_file() {
    local shell_type="$1"
    local config_file=""
    
    case "$shell_type" in
        zsh)
            # zsh 配置文件优先级：.zshrc > .zprofile
            if [ -f "$HOME/.zshrc" ]; then
                config_file="$HOME/.zshrc"
            elif [ -f "$HOME/.zprofile" ]; then
                config_file="$HOME/.zprofile"
            else
                # 都不存在则创建 .zshrc
                config_file="$HOME/.zshrc"
                touch "$config_file"
            fi
            ;;
        bash)
            # bash 配置文件优先级：.bashrc > .bash_profile > .profile
            if [ -f "$HOME/.bashrc" ]; then
                config_file="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                config_file="$HOME/.bash_profile"
            elif [ -f "$HOME/.profile" ]; then
                config_file="$HOME/.profile"
            else
                # 都不存在则创建 .bashrc
                config_file="$HOME/.bashrc"
                touch "$config_file"
            fi
            ;;
        *)
            # 未知 shell，尝试所有可能的配置文件
            for file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
                if [ -f "$file" ]; then
                    config_file="$file"
                    break
                fi
            done
            # 如果都不存在，默认创建 .bashrc
            [ -z "$config_file" ] && config_file="$HOME/.bashrc" && touch "$config_file"
            ;;
    esac
    
    echo "$config_file"
}

# 主安装函数
main() {
    echo -e "${GREEN}正在安装 proxyctl...${NC}"
    
    # 检测 shell
    SHELL_TYPE=$(detect_shell)
    CONFIG_FILE=$(get_config_file "$SHELL_TYPE")
    
    echo -e "${YELLOW}检测到 shell: $SHELL_TYPE${NC}"
    echo -e "${YELLOW}配置文件: $CONFIG_FILE${NC}"
    
    # 创建安装目录
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    
    # 下载脚本（如果是从 GitHub 安装）
    if [ -f "proxy.sh" ]; then
        # 本地安装
        cp proxy.sh "$INSTALL_DIR/proxy.sh"
        echo -e "${GREEN}✓ 脚本已复制到 $INSTALL_DIR/proxy.sh${NC}"
    else
        # 从 GitHub 下载
        echo -e "${YELLOW}正在从 GitHub 下载脚本...${NC}"
        
        local download_success=0
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL "https://raw.githubusercontent.com/MorvenCat/proxyctl/main/proxy.sh" -o "$INSTALL_DIR/proxy.sh" 2>/dev/null; then
                download_success=1
            else
                echo -e "${RED}错误: curl 下载失败 (HTTP 404 或其他错误)${NC}"
                echo -e "${YELLOW}请检查仓库是否存在: https://github.com/MorvenCat/proxyctl${NC}"
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "https://raw.githubusercontent.com/MorvenCat/proxyctl/main/proxy.sh" -O "$INSTALL_DIR/proxy.sh" 2>/dev/null; then
                download_success=1
            else
                echo -e "${RED}错误: wget 下载失败 (HTTP 404 或其他错误)${NC}"
                echo -e "${YELLOW}请检查仓库是否存在: https://github.com/MorvenCat/proxyctl${NC}"
            fi
        else
            echo -e "${RED}错误: 未找到 curl 或 wget，请手动下载脚本${NC}"
            exit 1
        fi
        
        # 验证下载是否成功
        if [ $download_success -eq 0 ] || [ ! -f "$INSTALL_DIR/proxy.sh" ]; then
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}安装失败: 无法下载脚本文件${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            exit 1
        fi
        
        # 验证文件内容（检查是否下载了错误页面）
        if ! head -n 1 "$INSTALL_DIR/proxy.sh" | grep -q "^#!/bin/bash" 2>/dev/null; then
            echo -e "${RED}错误: 下载的文件不是有效的脚本文件${NC}"
            rm -f "$INSTALL_DIR/proxy.sh"
            exit 1
        fi
        
        echo -e "${GREEN}✓ 脚本已下载到 $INSTALL_DIR/proxy.sh${NC}"
    fi
    
    # 验证文件存在并添加执行权限
    if [ ! -f "$INSTALL_DIR/proxy.sh" ]; then
        echo -e "${RED}错误: 脚本文件不存在: $INSTALL_DIR/proxy.sh${NC}"
        exit 1
    fi
    
    chmod +x "$INSTALL_DIR/proxy.sh"
    echo -e "${GREEN}✓ 已添加执行权限${NC}"
    
    # 检查是否已经安装（更精确的匹配）
    local proxy_marker="# proxyctl - 代理管理工具"
    local source_line="source $INSTALL_DIR/proxy.sh"
    
    # 检查是否已有标记
    if grep -q "$proxy_marker" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ 检测到已安装 proxyctl${NC}"
        # 检查 source 行是否存在且正确
        if ! grep -qF "$source_line" "$CONFIG_FILE" 2>/dev/null; then
            # 检查是否有旧的 source 行需要更新
            if grep -q "source.*proxy.sh" "$CONFIG_FILE" 2>/dev/null; then
                echo -e "${YELLOW}⚠ 发现旧的配置，正在更新...${NC}"
                # 在 macOS 和 Linux 上使用不同的 sed 命令
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "s|source.*proxy.sh|$source_line|g" "$CONFIG_FILE"
                else
                    sed -i "s|source.*proxy.sh|$source_line|g" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✓ 已更新配置${NC}"
            else
                # 添加缺失的 source 行
                echo "$source_line" >> "$CONFIG_FILE"
                echo -e "${GREEN}✓ 已添加 source 行到 $CONFIG_FILE${NC}"
            fi
        else
            echo -e "${GREEN}✓ 配置已存在且正确${NC}"
        fi
    else
        # 全新安装：添加到配置文件
        {
            echo ""
            echo "$proxy_marker"
            echo "$source_line"
        } >> "$CONFIG_FILE"
        echo -e "${GREEN}✓ 已添加到 $CONFIG_FILE${NC}"
    fi
    
    # 检查 PATH（更精确的检查）
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        # 检查配置文件中是否已有 PATH 设置
        if ! grep -q "$path_line" "$CONFIG_FILE" 2>/dev/null; then
            echo -e "${YELLOW}⚠ $INSTALL_DIR 不在 PATH 中，正在添加...${NC}"
            echo "" >> "$CONFIG_FILE"
            echo "# 添加 ~/.local/bin 到 PATH" >> "$CONFIG_FILE"
            echo "$path_line" >> "$CONFIG_FILE"
            echo -e "${GREEN}✓ 已添加 $INSTALL_DIR 到 PATH${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}安装完成！${NC}"
    echo ""
    
    # 验证安装
    if [ -f "$INSTALL_DIR/proxy.sh" ] && grep -q "$proxy_marker" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ 安装验证成功${NC}"
    else
        echo -e "${RED}⚠ 安装可能不完整，请检查${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}请运行以下命令使配置生效：${NC}"
    echo -e "  ${GREEN}source $CONFIG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}或者重新打开终端后，使用以下命令：${NC}"
    echo -e "  ${GREEN}proxy set all 127.0.0.1 7890${NC}"
    echo -e "  ${GREEN}proxy on${NC}"
    echo -e "  ${GREEN}proxy status${NC}"
    echo ""
}

main

