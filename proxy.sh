#!/bin/bash

# Linux/macOS 终端代理管理脚本
# 使用方法: source proxy.sh 或将其添加到 ~/.zshrc 或 ~/.bashrc

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
                echo "代理已开启"
                proxy status
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
            echo "当前代理状态:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ]; then
                echo "✓ HTTP 代理: ${http_proxy:-$HTTP_PROXY}"
            else
                echo "✗ HTTP 代理: 未设置"
            fi

            if [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ]; then
                echo "✓ HTTPS 代理: ${https_proxy:-$HTTPS_PROXY}"
            else
                echo "✗ HTTPS 代理: 未设置"
            fi

            if [ -n "$socks_proxy" ] || [ -n "$SOCKS_PROXY" ]; then
                echo "✓ SOCKS5 代理: ${socks_proxy:-$SOCKS_PROXY}"
            else
                echo "✗ SOCKS5 代理: 未设置"
            fi

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "代理检测:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # 检测函数
            check_website() {
                local url="$1"
                local name="$2"
                local timeout=5
                
                if curl -s --max-time "$timeout" --head "$url" > /dev/null 2>&1; then
                    echo "✓ $name: 可达"
                else
                    echo "✗ $name: 不可达"
                fi
            }
            
            check_website "https://www.google.com" "Google"
            check_website "https://www.github.com" "GitHub"
            check_website "https://www.youtube.com" "YouTube"
            
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        *)
            echo "代理管理工具"
            echo ""
            echo "用法:"
            echo "  proxy on                    - 开启代理（从保存的配置恢复）"
            echo "  proxy off                   - 关闭代理"
            echo "  proxy set http <host> <port>    - 设置 HTTP 代理"
            echo "  proxy set https <host> <port>   - 设置 HTTPS 代理"
            echo "  proxy set socks5 <host> <port> - 设置 SOCKS5 代理"
            echo "  proxy set all <host> <port>     - 设置所有代理"
            echo "  proxy status                - 查看当前代理状态"
            echo ""
            echo "示例:"
            echo "  proxy set all 127.0.0.1 7890"
            echo "  proxy on"
            echo "  proxy off"
            echo "  proxy status"
            ;;
    esac
}
