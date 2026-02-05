#!/bin/bash

# Linux/macOS 终端代理管理脚本
# 使用方法: source proxy.sh 或将其添加到 ~/.zshrc 或 ~/.bashrc

# 版本号
PROXY_VERSION="1.4.4"
PROXY_REPO="MorvenCat/Proxyctl"
PROXY_SCRIPT_URL="https://raw.githubusercontent.com/${PROXY_REPO}/main/proxy.sh"

# API 配置（中转 URL / API Key profiles）
PROXY_API_DIR="$HOME/.proxy_api.d"
PROXY_API_STATE="$HOME/.proxy_api_state"

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

        api)
            # API profiles: 按厂商保存多组中转 URL / API Key，并按厂商标准变量导出
            local sub="$2"
            local provider_raw="$3"
            local profile_raw="$4"
            local base_url="$5"
            local api_key="$6"

            # name 规范化为安全文件名
            sanitize_name() {
                printf '%s' "${1:-}" \
                    | tr '[:upper:]' '[:lower:]' \
                    | tr -cs 'a-z0-9._-' '_' \
                    | sed 's/^_\\+//; s/_\\+$//'
            }

            has_cmd() { command -v "$1" >/dev/null 2>&1; }

            is_utf8() {
                local cm
                cm="$(locale charmap 2>/dev/null || true)"
                echo "$cm" | grep -qi "utf-8"
            }

            # 终端不支持 UTF-8 时，交互提示降级为纯 ASCII，避免乱码
            local UI_UTF8=false
            if is_utf8; then
                UI_UTF8=true
            fi

            choose_item() {
                # choose_item "Prompt" item1 item2 ...
                local prompt="$1"
                shift || true
                local items=("$@")

                if [ "${#items[@]}" -eq 0 ]; then
                    return 1
                fi

                if has_cmd fzf; then
                    # fzf 交互选择（如果用户已安装）
                    printf '%s\n' "${items[@]}" | fzf --prompt="${prompt}> " --height=12 --reverse
                    return $?
                fi

                # select 兜底（bash 内置）
                # 注意：select 会把菜单/提示输出到 stdout；这里把它们全部重定向到 stderr，
                # 只把最终选择写回 stdout，避免被命令替换 $(...) 捕获导致 action 变量混入提示文本。
                if [ "$UI_UTF8" = true ]; then
                    echo "$prompt" >&2
                else
                    echo "$prompt" >&2
                fi

                local PS3
                if [ "$UI_UTF8" = true ]; then
                    PS3="请输入编号: "
                else
                    PS3="Select number: "
                fi

                local opt=""
                exec 3>&1
                {
                    select opt in "${items[@]}"; do
                        if [ -n "${opt:-}" ]; then
                            printf '%s' "$opt" >&3
                            break
                        fi
                        if [ "$UI_UTF8" = true ]; then
                            echo "无效选择，请重试。" >&2
                        else
                            echo "Invalid selection, try again." >&2
                        fi
                    done
                } 1>&2
                exec 3>&-

                [ -n "${opt:-}" ]
            }

            prompt_with_default() {
                # prompt_with_default "Label" "default"
                local label="$1"
                local def="$2"
                local val=""
                read -r -p "${label} (默认: ${def}): " val
                if [ -z "$val" ]; then
                    val="$def"
                fi
                printf '%s' "$val"
            }

            prompt_required() {
                # prompt_required "Label"
                local label="$1"
                local val=""
                while true; do
                    read -r -p "${label}: " val
                    if [ -n "$val" ]; then
                        printf '%s' "$val"
                        return 0
                    fi
                    echo "不能为空，请重试。"
                done
            }

            prompt_secret_required() {
                # prompt_secret_required "Label"
                local label="$1"
                local val=""
                while true; do
                    read -r -s -p "${label}: " val
                    echo ""
                    if [ -n "$val" ]; then
                        printf '%s' "$val"
                        return 0
                    fi
                    echo "不能为空，请重试。"
                done
            }

            list_providers() {
                mkdir -p "$PROXY_API_DIR" 2>/dev/null || true
                local d
                for d in "$PROXY_API_DIR"/*; do
                    [ -d "$d" ] || continue
                    basename "$d"
                done
            }

            list_profiles() {
                local p="$1"
                local f
                for f in "$PROXY_API_DIR/$p"/*.sh; do
                    [ -e "$f" ] || continue
                    basename "$f" .sh
                done
            }

            local provider profile
            provider="$(sanitize_name "$provider_raw")"
            profile="$(sanitize_name "$profile_raw")"

            case "$sub" in
                ""|menu)
                    # 交互菜单：提升体验（无依赖；若安装 fzf 则自动使用）
                    while true; do
                        local action
                        if [ "$UI_UTF8" = true ]; then
                            action="$(choose_item "选择操作" "set" "use" "status" "list" "on" "off" "rm" "exit")" || return 1
                        else
                            action="$(choose_item "Choose action" "set" "use" "status" "list" "on" "off" "rm" "exit")" || return 1
                        fi

                        case "$action" in
                            set*)
                                proxy api set
                                ;;
                            use*)
                                proxy api use
                                ;;
                            status*)
                                proxy api status
                                ;;
                            list*)
                                proxy api list
                                ;;
                            on*)
                                proxy api on
                                ;;
                            off*)
                                proxy api off
                                ;;
                            rm*)
                                proxy api rm
                                ;;
                            exit*)
                                return 0
                                ;;
                        esac
                        echo ""
                    done
                    ;;

                set)
                    # 参数不全则进入交互向导
                    if [ -z "$provider" ] || [ -z "$profile" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; then
                        local picked_provider picked_profile picked_base picked_key
                        if [ "$UI_UTF8" = true ]; then
                            picked_provider="$(choose_item "选择 provider" "openai" "anthropic")" || return 1
                            picked_profile="$(prompt_with_default "Profile 名称" "default")"
                        else
                            picked_provider="$(choose_item "Choose provider" "openai" "anthropic")" || return 1
                            picked_profile="$(prompt_with_default "Profile name" "default")"
                        fi
                        picked_profile="$(sanitize_name "$picked_profile")"

                        if [ "$picked_provider" = "openai" ]; then
                            if [ "$UI_UTF8" = true ]; then
                                picked_base="$(prompt_with_default "Base URL（中转/官方）" "https://api.openai.com/v1")"
                            else
                                picked_base="$(prompt_with_default "Base URL" "https://api.openai.com/v1")"
                            fi
                        else
                            if [ "$UI_UTF8" = true ]; then
                                picked_base="$(prompt_with_default "Base URL（中转/官方）" "https://api.anthropic.com")"
                            else
                                picked_base="$(prompt_with_default "Base URL" "https://api.anthropic.com")"
                            fi
                        fi
                        if [ "$UI_UTF8" = true ]; then
                            picked_key="$(prompt_secret_required "API Key（不会回显）")"
                        else
                            picked_key="$(prompt_secret_required "API key (hidden)")"
                        fi

                        provider="$(sanitize_name "$picked_provider")"
                        profile="$picked_profile"
                        base_url="$picked_base"
                        api_key="$picked_key"
                    fi

                    if [ -z "$provider" ] || [ -z "$profile" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; then
                        echo "用法: proxy api set <openai|anthropic> <profile> <base_url> <api_key>"
                        echo "或直接运行: proxy api set  进入交互配置"
                        return 1
                    fi

                    mkdir -p "$PROXY_API_DIR/$provider"
                    chmod 700 "$PROXY_API_DIR" "$PROXY_API_DIR/$provider" 2>/dev/null || true

                    local profile_file="$PROXY_API_DIR/$provider/${profile}.sh"
                    cat > "$profile_file" <<EOF
# proxyctl api profile - 自动生成，请勿手动编辑
export PROXY_API_PROVIDER="${provider}"
export PROXY_API_PROFILE="${profile}"
export PROXY_API_BASE_URL="${base_url}"
export PROXY_API_KEY="${api_key}"
EOF

                    # 厂商标准变量（优先 OpenAI / Anthropic）
                    if [ "$provider" = "openai" ]; then
                        cat >> "$profile_file" <<EOF
export OPENAI_API_KEY="${api_key}"
export OPENAI_BASE_URL="${base_url}"
export OPENAI_API_BASE="${base_url}"
EOF
                    elif [ "$provider" = "anthropic" ]; then
                        cat >> "$profile_file" <<EOF
export ANTHROPIC_API_KEY="${api_key}"
export ANTHROPIC_BASE_URL="${base_url}"
export ANTHROPIC_API_URL="${base_url}"
EOF
                    fi

                    chmod 600 "$profile_file" 2>/dev/null || true
                    echo "✓ 已保存 API 配置: ${provider}/${profile}"
                    echo "  文件: $profile_file"
                    ;;

                use)
                    # 参数不全则进入交互选择
                    if [ -z "$provider" ] || [ -z "$profile" ]; then
                        local providers profiles picked_p picked_pf
                        mapfile -t providers < <(list_providers)
                        if [ "${#providers[@]}" -eq 0 ]; then
                            echo "错误: 未找到任何 API 配置，请先运行: proxy api set"
                            return 1
                        fi

                        if [ "$UI_UTF8" = true ]; then
                            picked_p="$(choose_item "选择 provider" "${providers[@]}")" || return 1
                        else
                            picked_p="$(choose_item "Choose provider" "${providers[@]}")" || return 1
                        fi
                        mapfile -t profiles < <(list_profiles "$picked_p")
                        if [ "${#profiles[@]}" -eq 0 ]; then
                            echo "错误: provider '$picked_p' 下没有 profile，请先运行: proxy api set $picked_p <profile> <base_url> <api_key>"
                            return 1
                        fi
                        if [ "$UI_UTF8" = true ]; then
                            picked_pf="$(choose_item "选择 profile" "${profiles[@]}")" || return 1
                        else
                            picked_pf="$(choose_item "Choose profile" "${profiles[@]}")" || return 1
                        fi

                        provider="$(sanitize_name "$picked_p")"
                        profile="$(sanitize_name "$picked_pf")"
                    fi

                    if [ -z "$provider" ] || [ -z "$profile" ]; then
                        echo "用法: proxy api use <provider> <profile>"
                        echo "或直接运行: proxy api use  进入交互选择"
                        return 1
                    fi

                    local profile_file="$PROXY_API_DIR/$provider/${profile}.sh"
                    if [ ! -f "$profile_file" ]; then
                        echo "错误: 未找到 API 配置: ${provider}/${profile}"
                        echo "可用列表: proxy api list ${provider}"
                        return 1
                    fi

                    # shellcheck disable=SC1090
                    source "$profile_file"
                    printf '%s %s\n' "$provider" "$profile" > "$PROXY_API_STATE"
                    chmod 600 "$PROXY_API_STATE" 2>/dev/null || true

                    echo "✓ 已启用 API 配置: ${provider}/${profile}"
                    echo "  BASE_URL: ${PROXY_API_BASE_URL}"
                    ;;

                on)
                    if [ ! -f "$PROXY_API_STATE" ]; then
                        echo "错误: 未找到上次使用的 API 配置（$PROXY_API_STATE 不存在）"
                        echo "请先使用: proxy api use <provider> <profile>"
                        return 1
                    fi

                    local last_provider last_profile
                    last_provider="$(awk '{print $1}' "$PROXY_API_STATE" 2>/dev/null)"
                    last_profile="$(awk '{print $2}' "$PROXY_API_STATE" 2>/dev/null)"
                    if [ -z "$last_provider" ] || [ -z "$last_profile" ]; then
                        echo "错误: 状态文件内容异常: $PROXY_API_STATE"
                        return 1
                    fi

                    provider="$(sanitize_name "$last_provider")"
                    profile="$(sanitize_name "$last_profile")"
                    local profile_file="$PROXY_API_DIR/$provider/${profile}.sh"
                    if [ ! -f "$profile_file" ]; then
                        echo "错误: 未找到上次使用的 API 配置文件: ${provider}/${profile}"
                        echo "可用列表: proxy api list ${provider}"
                        return 1
                    fi

                    # shellcheck disable=SC1090
                    source "$profile_file"
                    echo "✓ 已启用上次 API 配置: ${provider}/${profile}"
                    echo "  BASE_URL: ${PROXY_API_BASE_URL}"
                    ;;

                off)
                    local off_provider off_profile
                    if [ -n "${PROXY_API_PROVIDER:-}" ] && [ -n "${PROXY_API_PROFILE:-}" ]; then
                        off_provider="$(sanitize_name "$PROXY_API_PROVIDER")"
                        off_profile="$(sanitize_name "$PROXY_API_PROFILE")"
                    elif [ -f "$PROXY_API_STATE" ]; then
                        off_provider="$(awk '{print $1}' "$PROXY_API_STATE" 2>/dev/null)"
                        off_profile="$(awk '{print $2}' "$PROXY_API_STATE" 2>/dev/null)"
                        off_provider="$(sanitize_name "$off_provider")"
                        off_profile="$(sanitize_name "$off_profile")"
                    fi

                    if [ -z "$off_provider" ] || [ -z "$off_profile" ]; then
                        echo "⚠ 当前未启用任何 API 配置"
                        return 0
                    fi

                    local profile_file="$PROXY_API_DIR/$off_provider/${off_profile}.sh"
                    if [ -f "$profile_file" ]; then
                        local vars
                        vars="$(grep -E '^export [A-Za-z_][A-Za-z0-9_]*=' "$profile_file" 2>/dev/null \
                            | sed -E 's/^export ([A-Za-z_][A-Za-z0-9_]*)=.*/\1/')"
                        for v in $vars; do
                            unset "$v"
                        done
                    else
                        # 兜底：至少清理通用/常见变量
                        unset PROXY_API_PROVIDER PROXY_API_PROFILE PROXY_API_BASE_URL PROXY_API_KEY
                        unset OPENAI_API_KEY OPENAI_BASE_URL OPENAI_API_BASE
                        unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_API_URL
                    fi

                    echo "✓ 已关闭 API 配置: ${off_provider}/${off_profile}"
                    ;;

                status)
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "🔑 API 配置状态"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    if [ -n "${PROXY_API_PROVIDER:-}" ] && [ -n "${PROXY_API_PROFILE:-}" ]; then
                        echo "✓ 当前启用: ${PROXY_API_PROVIDER}/${PROXY_API_PROFILE}"
                        echo "✓ BASE_URL : ${PROXY_API_BASE_URL:-未设置}"
                        if [ -n "${PROXY_API_KEY:-}" ]; then
                            echo "✓ API_KEY  : 已设置"
                        else
                            echo "✗ API_KEY  : 未设置"
                        fi
                    else
                        echo "✗ 当前未启用任何 API 配置"
                        if [ -f "$PROXY_API_STATE" ]; then
                            echo "  上次使用: $(cat "$PROXY_API_STATE" 2>/dev/null)"
                        fi
                    fi
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    ;;

                list)
                    if [ -z "$provider" ]; then
                        mkdir -p "$PROXY_API_DIR" 2>/dev/null || true
                        echo "已保存的 API providers/profiles:"
                        local any_provider=false
                        for d in "$PROXY_API_DIR"/*; do
                            [ -d "$d" ] || continue
                            any_provider=true
                            local p
                            p="$(basename "$d")"
                            echo "- $p:"
                            local any_profile=false
                            for f in "$d"/*.sh; do
                                [ -e "$f" ] || continue
                                any_profile=true
                                echo "  - $(basename "$f" .sh)"
                            done
                            if [ "$any_profile" = false ]; then
                                echo "  - (空)"
                            fi
                        done
                        if [ "$any_provider" = false ]; then
                            echo "- (空)"
                        fi
                    else
                        local provider_dir="$PROXY_API_DIR/$provider"
                        echo "已保存的 profiles (${provider}):"
                        local found=false
                        for f in "$provider_dir"/*.sh; do
                            [ -e "$f" ] || continue
                            found=true
                            echo " - $(basename "$f" .sh)"
                        done
                        if [ "$found" = false ]; then
                            echo " - (空)"
                        fi
                    fi
                    ;;

                rm)
                    # 参数不全则进入交互选择 + 确认
                    if [ -z "$provider" ] || [ -z "$profile" ]; then
                        local providers profiles picked_p picked_pf confirm
                        mapfile -t providers < <(list_providers)
                        if [ "${#providers[@]}" -eq 0 ]; then
                            echo "错误: 未找到任何 API 配置"
                            return 1
                        fi
                        if [ "$UI_UTF8" = true ]; then
                            picked_p="$(choose_item "选择 provider" "${providers[@]}")" || return 1
                        else
                            picked_p="$(choose_item "Choose provider" "${providers[@]}")" || return 1
                        fi
                        mapfile -t profiles < <(list_profiles "$picked_p")
                        if [ "${#profiles[@]}" -eq 0 ]; then
                            echo "错误: provider '$picked_p' 下没有 profile"
                            return 1
                        fi
                        if [ "$UI_UTF8" = true ]; then
                            picked_pf="$(choose_item "选择 profile" "${profiles[@]}")" || return 1
                            confirm="$(choose_item "确认删除 ${picked_p}/${picked_pf} ?" "no" "yes")" || return 1
                        else
                            picked_pf="$(choose_item "Choose profile" "${profiles[@]}")" || return 1
                            confirm="$(choose_item "Confirm delete ${picked_p}/${picked_pf} ?" "no" "yes")" || return 1
                        fi
                        if [ "$confirm" != "yes" ]; then
                            echo "已取消。"
                            return 0
                        fi
                        provider="$(sanitize_name "$picked_p")"
                        profile="$(sanitize_name "$picked_pf")"
                    fi

                    if [ -z "$provider" ] || [ -z "$profile" ]; then
                        echo "用法: proxy api rm <provider> <profile>"
                        echo "或直接运行: proxy api rm  进入交互选择"
                        return 1
                    fi

                    local profile_file="$PROXY_API_DIR/$provider/${profile}.sh"
                    if [ -f "$profile_file" ]; then
                        rm -f "$profile_file"
                        echo "✓ 已删除 API 配置: ${provider}/${profile}"
                        if [ -f "$PROXY_API_STATE" ] && [ "$(cat "$PROXY_API_STATE" 2>/dev/null)" = "${provider} ${profile}" ]; then
                            rm -f "$PROXY_API_STATE"
                        fi
                    else
                        echo "⚠ 未找到 API 配置: ${provider}/${profile}"
                    fi
                    ;;

                *)
                    echo "API 配置管理（中转 URL / API Key profiles）"
                    echo ""
                    echo "用法:"
                    echo "  proxy api                                            - 进入交互式菜单"
                    echo "  proxy api set <provider> <profile> <base_url> <api_key>  - 保存/覆盖一个 profile"
                    echo "  proxy api use <provider> <profile>                       - 启用某个 profile（导出厂商标准变量）"
                    echo "  proxy api on                                             - 启用上次使用的 profile"
                    echo "  proxy api off                                            - 关闭当前/上次 profile（unset 导出变量）"
                    echo "  proxy api status                                         - 查看当前 API 配置状态"
                    echo "  proxy api list [provider]                                - 列出 profiles"
                    echo "  proxy api rm <provider> <profile>                        - 删除 profile"
                    echo ""
                    echo "示例:"
                    echo "  proxy api set openai default https://relay.example.com/v1 sk-xxx"
                    echo "  proxy api use openai default"
                    echo "  proxy api status"
                    ;;
            esac
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

            # 尝试通过 GitHub API 获取 main 最新 commit SHA，以绕开 raw 的缓存
            local download_url="$PROXY_SCRIPT_URL"
            # GitHub API 也可能被缓存，这里加 ts 参数强制取最新
            local api_url="https://api.github.com/repos/${PROXY_REPO}/commits/main?ts=$(date +%s)"
            local latest_sha=""
            if command -v curl >/dev/null 2>&1; then
                latest_sha="$(curl -fsSL "$api_url" 2>/dev/null | grep -m1 '\"sha\"' | sed -E 's/.*\"sha\": \"([0-9a-f]+)\".*/\\1/')"
            elif command -v wget >/dev/null 2>&1; then
                latest_sha="$(wget -qO- "$api_url" 2>/dev/null | grep -m1 '\"sha\"' | sed -E 's/.*\"sha\": \"([0-9a-f]+)\".*/\\1/')"
            fi
            if [ -n "$latest_sha" ]; then
                download_url="https://raw.githubusercontent.com/${PROXY_REPO}/${latest_sha}/proxy.sh"
            fi
            
            # 下载最新版本
            if command -v curl >/dev/null 2>&1; then
                if curl -fsSL "$download_url" -o "$temp_file" 2>/dev/null; then
                    download_success=1
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q "$download_url" -O "$temp_file" 2>/dev/null; then
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
            echo "  proxy api ...               - 管理 API 中转 URL 和 API Key profiles"
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
