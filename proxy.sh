#!/bin/bash

# Linux/macOS 终端代理管理脚本
# 使用方法: source proxy.sh 或将其添加到 ~/.zshrc 或 ~/.bashrc

# 版本号
PROXY_VERSION="1.1.0"
PROXY_REPO="MorvenCat/Proxyctl"
PROXY_SCRIPT_URL="https://raw.githubusercontent.com/${PROXY_REPO}/main/proxy.sh"

proxy() {
    local command="$1"
    local proxy_type="$2"
    local host="$3"
    local port="$4"

    case "$command" in
        on)
            # 从保存的配置中恢复代理设置
            if [ -f ~/.proxy_config ]; then
                source ~/.proxy_config
                # 保存代理开启状态，以便下次打开终端时自动开启
                echo "on" > ~/.proxy_state
                echo "代理已开启"
            else
                echo "错误: 未找到保存的代理配置"
                echo ""
                echo "请先使用以下命令设置代理："
                echo "  proxy set all <host> <port>"
                echo ""
                echo "示例："
                echo "  proxy set all 127.0.0.1 7890"
                return 1
            fi
            ;;

        off)
            # 清除所有代理环境变量
            unset http_proxy
            unset HTTP_PROXY
            unset https_proxy
            unset HTTPS_PROXY
            unset all_proxy
            unset ALL_PROXY
            unset socks_proxy
            unset SOCKS_PROXY
            # 保存代理关闭状态，下次打开终端时不自动开启
            echo "off" > ~/.proxy_state
            echo "代理已关闭"
            ;;

        set)
            if [ -z "$proxy_type" ] || [ -z "$host" ] || [ -z "$port" ]; then
                echo "用法: proxy set <http|https|socks5|all> <host> <port>"
                return 1
            fi

            case "$proxy_type" in
                http)
                    export http_proxy="http://${host}:${port}"
                    export HTTP_PROXY="http://${host}:${port}"
                    echo "HTTP 代理已设置为: http://${host}:${port}"
                    ;;

                https)
                    export https_proxy="http://${host}:${port}"
                    export HTTPS_PROXY="http://${host}:${port}"
                    echo "HTTPS 代理已设置为: http://${host}:${port}"
                    ;;

                socks5)
                    export socks_proxy="socks5://${host}:${port}"
                    export SOCKS_PROXY="socks5://${host}:${port}"
                    echo "SOCKS5 代理已设置为: socks5://${host}:${port}"
                    ;;

                all)
                    export http_proxy="http://${host}:${port}"
                    export HTTP_PROXY="http://${host}:${port}"
                    export https_proxy="http://${host}:${port}"
                    export HTTPS_PROXY="http://${host}:${port}"
                    export all_proxy="http://${host}:${port}"
                    export ALL_PROXY="http://${host}:${port}"
                    export socks_proxy="socks5://${host}:${port}"
                    export SOCKS_PROXY="socks5://${host}:${port}"
                    echo "所有代理已设置为: http://${host}:${port}"
                    ;;

                *)
                    echo "错误: 不支持的代理类型 '$proxy_type'"
                    echo "支持的代理类型: http, https, socks5, all"
                    return 1
                    ;;
            esac

            # 保存配置到文件
            {
                echo "# 代理配置 - 自动生成，请勿手动编辑"
                echo "export http_proxy=\"${http_proxy}\""
                echo "export HTTP_PROXY=\"${HTTP_PROXY}\""
                echo "export https_proxy=\"${https_proxy}\""
                echo "export HTTPS_PROXY=\"${HTTPS_PROXY}\""
                echo "export all_proxy=\"${all_proxy}\""
                echo "export ALL_PROXY=\"${ALL_PROXY}\""
                [ -n "$socks_proxy" ] && echo "export socks_proxy=\"${socks_proxy}\""
                [ -n "$SOCKS_PROXY" ] && echo "export SOCKS_PROXY=\"${SOCKS_PROXY}\""
            } > ~/.proxy_config
            ;;

        status)
            # 从配置文件中读取代理地址（如果环境变量未设置）
            local config_http_proxy=""
            local config_https_proxy=""
            local config_socks_proxy=""
            
            if [ -f ~/.proxy_config ]; then
                # 在子 shell 中 source 配置文件并提取变量值
                config_http_proxy=$(bash -c "source ~/.proxy_config 2>/dev/null; echo \"\${http_proxy:-}\"")
                config_https_proxy=$(bash -c "source ~/.proxy_config 2>/dev/null; echo \"\${https_proxy:-}\"")
                config_socks_proxy=$(bash -c "source ~/.proxy_config 2>/dev/null; echo \"\${socks_proxy:-}\"")
            fi
            
            # 显示标题
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📊 代理状态"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            # 显示代理开启状态（放在最前面）
            local proxy_enabled=false
            if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$socks_proxy" ] || [ -n "$SOCKS_PROXY" ]; then
                echo "🟢 代理状态: 已开启"
                proxy_enabled=true
            else
                echo "🔴 代理状态: 未开启"
            fi
            
            echo ""
            
            # 显示代理配置状态
            echo "📋 代理配置:"
            if [ -n "$config_http_proxy" ]; then
                echo "   ✓ HTTP    $config_http_proxy"
            else
                echo "   ✗ HTTP    未设置"
            fi

            if [ -n "$config_https_proxy" ]; then
                echo "   ✓ HTTPS   $config_https_proxy"
            else
                echo "   ✗ HTTPS   未设置"
            fi

            if [ -n "$config_socks_proxy" ]; then
                echo "   ✓ SOCKS5  $config_socks_proxy"
            else
                echo "   ✗ SOCKS5  未设置"
            fi

            # 只在代理开启时进行连通性检测
            if [ "$proxy_enabled" = true ]; then
                echo ""
                echo "🌐 连通性检测:"
                
                # 检测函数
                check_website() {
                    local url="$1"
                    local name="$2"
                    local timeout=5
                    
                    if curl -s --max-time "$timeout" --head "$url" > /dev/null 2>&1; then
                        echo "   ✓ $name"
                    else
                        echo "   ✗ $name"
                    fi
                }
                
                check_website "https://www.google.com" "Google"
                check_website "https://www.github.com" "GitHub"
                check_website "https://www.youtube.com" "YouTube"
            fi
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📦 proxyctl v${PROXY_VERSION}"
            echo "👤 Author: MorvenCat"
            echo "🔗 https://github.com/${PROXY_REPO}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        update)
            echo "正在检查更新..."
            
            # 获取脚本安装路径
            local script_path=""
            # 优先检查标准安装路径
            if [ -f "$HOME/.local/bin/proxy.sh" ]; then
                script_path="$HOME/.local/bin/proxy.sh"
            else
                # 尝试从当前脚本位置获取
                local current_script="${BASH_SOURCE[0]}"
                if [ -L "$current_script" ]; then
                    # 如果是符号链接，尝试解析
                    if command -v readlink >/dev/null 2>&1; then
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            # macOS 使用 readlink 不带 -f
                            current_script="$(readlink "$current_script")"
                        else
                            # Linux 使用 readlink -f
                            current_script="$(readlink -f "$current_script")"
                        fi
                    fi
                fi
                script_path="$(cd "$(dirname "$current_script")" && pwd)/proxy.sh"
                if [ ! -f "$script_path" ]; then
                    echo "错误: 无法找到脚本安装路径"
                    echo "请手动指定脚本路径或重新安装"
                    return 1
                fi
            fi
            
            # 创建临时文件
            local temp_file=$(mktemp)
            local download_success=0
            
            # 下载最新版本
            if command -v curl >/dev/null 2>&1; then
                if curl -fsSL "$PROXY_SCRIPT_URL" -o "$temp_file" 2>/dev/null; then
                    download_success=1
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q "$PROXY_SCRIPT_URL" -O "$temp_file" 2>/dev/null; then
                    download_success=1
                fi
            else
                echo "错误: 未找到 curl 或 wget，无法下载更新"
                rm -f "$temp_file"
                return 1
            fi
            
            if [ $download_success -eq 0 ] || [ ! -f "$temp_file" ]; then
                echo "错误: 下载失败，请检查网络连接"
                rm -f "$temp_file"
                return 1
            fi
            
            # 验证下载的文件是否为有效脚本
            if ! head -n 1 "$temp_file" | grep -q "^#!/bin/bash" 2>/dev/null; then
                echo "错误: 下载的文件不是有效的脚本文件"
                rm -f "$temp_file"
                return 1
            fi
            
            # 获取最新版本号（从脚本中提取）
            local latest_version=$(grep -E '^PROXY_VERSION=' "$temp_file" 2>/dev/null | head -n1 | sed -E 's/^PROXY_VERSION="([^"]*)".*/\1/')
            
            if [ -z "$latest_version" ]; then
                latest_version="未知"
            fi
            
            # 比较版本
            if [ "$latest_version" != "未知" ] && [ "$PROXY_VERSION" = "$latest_version" ]; then
                echo "✓ 已是最新版本 (v${PROXY_VERSION})"
                rm -f "$temp_file"
                return 0
            fi
            
            # 备份当前脚本
            local backup_file="${script_path}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$script_path" "$backup_file" 2>/dev/null
            
            # 更新脚本
            if cp "$temp_file" "$script_path" 2>/dev/null && chmod +x "$script_path" 2>/dev/null; then
                echo "✓ 更新成功！"
                if [ "$latest_version" != "未知" ]; then
                    echo "  当前版本: v${PROXY_VERSION} -> v${latest_version}"
                fi
                echo "  备份文件: $backup_file"
                echo ""
                
                # 检测用户的配置文件
                local config_file=""
                if [ -n "${ZSH_VERSION:-}" ]; then
                    if [ -f "$HOME/.zshrc" ]; then
                        config_file="$HOME/.zshrc"
                    elif [ -f "$HOME/.zprofile" ]; then
                        config_file="$HOME/.zprofile"
                    fi
                elif [ -n "${BASH_VERSION:-}" ]; then
                    if [ -f "$HOME/.bashrc" ]; then
                        config_file="$HOME/.bashrc"
                    elif [ -f "$HOME/.bash_profile" ]; then
                        config_file="$HOME/.bash_profile"
                    elif [ -f "$HOME/.profile" ]; then
                        config_file="$HOME/.profile"
                    fi
                fi
                
                if [ -n "$config_file" ]; then
                    echo "执行以下命令重新加载配置："
                    echo "  source $config_file"
                else
                    echo "执行以下命令重新加载配置："
                    echo "  source $script_path"
                fi
                echo "或者直接重新打开终端。"
                rm -f "$temp_file"
            else
                echo "错误: 更新失败，请检查文件权限"
                # 尝试恢复备份
                if [ -f "$backup_file" ]; then
                    cp "$backup_file" "$script_path" 2>/dev/null
                    echo "已恢复备份文件"
                fi
                rm -f "$temp_file"
                return 1
            fi
            ;;

        *)
            echo "代理管理工具"
            echo ""
            echo "用法:"
            echo "  proxy on                    - 开启代理"
            echo "  proxy off                   - 关闭代理"
            echo "  proxy set http <host> <port>    - 设置 HTTP 代理"
            echo "  proxy set https <host> <port>   - 设置 HTTPS 代理"
            echo "  proxy set socks5 <host> <port> - 设置 SOCKS5 代理"
            echo "  proxy set all <host> <port>     - 设置所有代理"
            echo "  proxy status                - 查看当前代理状态"
            echo "  proxy update                - 更新到最新版本"
            echo ""
            echo "示例:"
            echo "  proxy set all 127.0.0.1 7890"
            echo "  proxy on"
            echo "  proxy off"
            echo "  proxy status"
            ;;
    esac
}

# 自动恢复代理状态（如果上次是开启状态）
# 只在非交互模式下静默加载，避免每次打开终端都显示输出
if [ -f ~/.proxy_state ] && [ "$(cat ~/.proxy_state 2>/dev/null)" = "on" ]; then
    if [ -f ~/.proxy_config ]; then
        # 静默加载代理配置（不显示输出）
        source ~/.proxy_config >/dev/null 2>&1
    fi
fi
