#!/bin/bash

# 检查jq是否已安装
if ! command -v jq &>/dev/null; then
    echo "错误: 未找到jq命令，该脚本需要jq来处理JSON数据" >&2
    echo "请安装jq后再运行此脚本" >&2
fi

# 处理命令行参数
DEBUG_MODE=false
for arg in "$@"; do
    case $arg in
    -debug)
        DEBUG_MODE=true
        shift
        ;;
    esac
done

# 设置脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 读取配置文件
CONFIG_PATH="$SCRIPT_DIR/server_info.json"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "警告: 配置文件不存在，正在创建默认配置文件: $CONFIG_PATH" >&2
    # 创建默认配置文件
    cat >"$CONFIG_PATH" <<EOF
{
  "SteamCMD_Path": "./SteamCMD",
  "ServerList": {}
}
EOF
    echo "已创建默认配置文件"
fi

# 解析配置文件
STEAMCMD_PATH="$(jq -r '.SteamCMD_Path' "$CONFIG_PATH")"
STEAMCMD_PATH="$SCRIPT_DIR/$STEAMCMD_PATH"
STEAMCMD_EXE="$STEAMCMD_PATH/steamcmd.sh"

# 检查并安装 SteamCMD
if [ ! -f "$STEAMCMD_EXE" ]; then
    echo "SteamCMD 不存在，正在自动下载..."

    # 创建 SteamCMD 目录
    mkdir -p "$STEAMCMD_PATH"

    # 下载 SteamCMD
    STEAMCMD_TAR="$STEAMCMD_PATH/steamcmd_linux.tar.gz"
    DOWNLOAD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

    if ! wget -O "$STEAMCMD_TAR" "$DOWNLOAD_URL"; then
        echo "错误: 下载 SteamCMD 失败" >&2
        exit 1
    fi

    # 解压 SteamCMD
    echo "正在解压 SteamCMD..."
    if ! tar -xzf "$STEAMCMD_TAR" -C "$STEAMCMD_PATH"; then
        echo "错误: 解压 SteamCMD 失败" >&2
        exit 1
    fi

    # 清理下载的压缩包
    rm -f "$STEAMCMD_TAR"

    echo "SteamCMD 安装完成！"
fi

# 显示主菜单
show_main_menu() {
    clear
    echo "===== 游戏服务器管理工具 ====="
    echo "1. 更新服务器"
    echo "2. 添加新服务器"
    echo "3. 修改服务器"
    echo "4. 删除服务器"
    echo "Q. 退出"
    echo "============================="

    read -p "请选择操作: " choice

    case $choice in
    1) update_servers ;;
    2) add_new_server ;;
    3) modify_server ;;
    4) remove_server ;;
    [Qq]) exit 0 ;;
    *)
        echo "无效的选择，请重试"
        sleep 2
        show_main_menu
        ;;
    esac
}

# 添加新服务器功能
add_new_server() {
    clear
    echo "===== 添加新服务器 ====="

    read -p "请输入服务器名称 (例如: PZServer): " server_name

    # 检查服务器名称是否已存在
    if jq -e ".ServerList.\"$server_name\"" "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "错误: 服务器名称 '$server_name' 已存在!"
        read -p "按回车键返回主菜单"
        show_main_menu
        return
    fi

    read -p "请输入 Steam AppID: " app_id
    read -p "请输入服务器描述: " description
    read -p "请输入安装目录 (相对于脚本目录，例如: ./PZServer): " install_dir
    read -p "是否使用匿名登录? (Y/N): " anonymous_choice

    anonymous=false
    if [[ $anonymous_choice =~ ^[Yy]$ ]]; then
        anonymous=true
    fi

    # 创建新服务器配置
    new_server=$(
        cat <<EOF
    {
        "AppId": "$app_id",
        "Description": "$description",
        "ForceInstallDir": "$install_dir",
        "Anonymous": $anonymous
    }
EOF
    )

    # 更新配置文件
    jq ".ServerList += {\"$server_name\": $new_server}" "$CONFIG_PATH" >"${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

    echo "服务器 '$server_name' 已成功添加!"
    read -p "按回车键返回主菜单"
    show_main_menu
}

# 修改服务器功能
modify_server() {
    clear
    echo "可用的服务器列表:"

    # 获取服务器列表
    mapfile -t server_list < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")
    index=1

    for server_name in "${server_list[@]}"; do
        app_id=$(jq -r ".ServerList.\"$server_name\".AppId" "$CONFIG_PATH")
        description=$(jq -r ".ServerList.\"$server_name\".Description" "$CONFIG_PATH")
        echo "$index. $server_name (AppID: $app_id) - $description"
        ((index++))
    done

    echo "B. 返回主菜单"
    echo "Q. 退出程序"

    read -p "请输入要修改的服务器编号 (1-${#server_list[@]}, B 返回, Q 退出): " choice

    case $choice in
    [Bb])
        show_main_menu
        return
        ;;
    [Qq]) exit 0 ;;
    *)
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#server_list[@]} ]; then
            selected_server=${server_list[$choice - 1]}

            clear
            echo "===== 修改服务器: $selected_server ====="
            echo "当前配置:"
            jq ".ServerList.\"$selected_server\"" "$CONFIG_PATH"

            read -p "请输入新的服务器名称 (留空保持不变): " new_server_name
            read -p "请输入新的 Steam AppID (留空保持不变): " new_app_id
            read -p "请输入新的服务器描述 (留空保持不变): " new_description
            read -p "请输入新的安装目录 (留空保持不变): " new_install_dir
            read -p "是否修改登录方式? (Y/N): " change_login

            # 构建更新命令
            current_config=$(jq -c ".ServerList.\"$selected_server\"" "$CONFIG_PATH")

            if [ ! -z "$new_server_name" ]; then
                # 检查新名称是否已存在
                if [ "$new_server_name" != "$selected_server" ] && jq -e ".ServerList.\"$new_server_name\"" "$CONFIG_PATH" >/dev/null 2>&1; then
                    echo "错误: 服务器名称 '$new_server_name' 已存在!"
                    read -p "按回车键返回主菜单"
                    show_main_menu
                    return
                fi
                # 删除旧名称并添加新名称
                update_cmd="del(.ServerList.\"$selected_server\") | .ServerList.\"$new_server_name\" = $current_config"
                selected_server="$new_server_name"
            else
                update_cmd=".ServerList.\"$selected_server\" = $current_config"
            fi

            if [ ! -z "$new_app_id" ]; then
                update_cmd="$update_cmd | .ServerList.\"$selected_server\".AppId = \"$new_app_id\""
            fi

            if [ ! -z "$new_description" ]; then
                update_cmd="$update_cmd | .ServerList.\"$selected_server\".Description = \"$new_description\""
            fi

            if [ ! -z "$new_install_dir" ]; then
                update_cmd="$update_cmd | .ServerList.\"$selected_server\".ForceInstallDir = \"$new_install_dir\""
            fi

            if [[ $change_login =~ ^[Yy]$ ]]; then
                read -p "是否使用匿名登录? (Y/N): " anonymous_choice
                anonymous=false
                if [[ $anonymous_choice =~ ^[Yy]$ ]]; then
                    anonymous=true
                fi
                update_cmd="$update_cmd | .ServerList.\"$selected_server\".Anonymous = $anonymous"
            fi

            # 更新配置文件
            jq "$update_cmd" "$CONFIG_PATH" >"${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

            echo "服务器 '$selected_server' 已成功修改!"
            read -p "按回车键返回主菜单"
            show_main_menu
        else
            echo "无效的选择: $choice"
            sleep 2
            modify_server
        fi
        ;;
    esac
}

# 更新服务器功能
update_servers() {
    clear
    echo "可用的服务器列表:"

    # 获取服务器列表
    mapfile -t server_list < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")
    index=1

    for server_name in "${server_list[@]}"; do
        app_id=$(jq -r ".ServerList.\"$server_name\".AppId" "$CONFIG_PATH")
        description=$(jq -r ".ServerList.\"$server_name\".Description" "$CONFIG_PATH")
        echo "$index. $server_name (AppID: $app_id) - $description"
        ((index++))
    done

    echo "0. 更新所有服务器"
    echo "B. 返回主菜单"
    echo "Q. 退出程序"

    read -p "请输入要更新的服务器编号 (0-${#server_list[@]}, B 返回, Q 退出): " choice

    case $choice in
    [Bb])
        show_main_menu
        return
        ;;
    [Qq]) exit 0 ;;
    *)
        if [ "$choice" = "0" ]; then
            servers_to_update=("${server_list[@]}")
        elif [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#server_list[@]} ]; then
            servers_to_update=("${server_list[$choice - 1]}")
        else
            echo "无效的选择: $choice"
            sleep 2
            update_servers
            return
        fi

        # 处理选定的服务器
        for server_name in "${servers_to_update[@]}"; do
            echo "正在处理服务器: $server_name"

            # 获取服务器配置
            app_id=$(jq -r ".ServerList.\"$server_name\".AppId" "$CONFIG_PATH")
            install_dir=$(jq -r ".ServerList.\"$server_name\".ForceInstallDir" "$CONFIG_PATH")
            anonymous=$(jq -r ".ServerList.\"$server_name\".Anonymous" "$CONFIG_PATH")

            # 构建 SteamCMD 命令
            steamcmd_args=()
            steamcmd_args+=("force_install_dir \"$SCRIPT_DIR/$install_dir\"")

            if [ "$anonymous" = "true" ]; then
                steamcmd_args+=("login anonymous")
            else
                read -p "请输入 Steam 用户名: " username
                read -s -p "请输入 Steam 密码: " password
                echo
                steamcmd_args+=("login \"$username\" \"$password\"")
            fi

            steamcmd_args+=("app_update $app_id validate")
            steamcmd_args+=("quit")

            # 执行 SteamCMD
            echo "开始更新服务器..."
            steamcmd_full_cmd="\"$STEAMCMD_EXE\" $(printf "%s " "${steamcmd_args[@]}")"
            if [ "$DEBUG_MODE" = true ]; then
                echo "调试信息 - SteamCMD 完整命令:"
                echo "$steamcmd_full_cmd"
            fi
            if eval "$steamcmd_full_cmd"; then
                echo "服务器更新成功完成！"
                update_success=true
            else
                echo "服务器更新过程中出现错误"
                update_success=false
            fi
        done

        if [ ${#servers_to_update[@]} -eq 1 ]; then
            if [ "$update_success" = true ]; then
                echo "服务器 '${servers_to_update[0]}' 更新完成！"
            fi
        else
            if [ "$update_success" = true ]; then
                echo "所有选定的服务器更新完成！"
            fi
        fi

        read -p "按回车键返回主菜单"
        show_main_menu
        ;;
    esac
}

# 删除服务器功能
remove_server() {
    clear
    echo "可用的服务器列表:"

    # 获取服务器列表
    mapfile -t server_list < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")
    index=1

    if [ ${#server_list[@]} -eq 0 ]; then
        echo "当前没有配置任何服务器！"
        read -p "按回车键返回主菜单"
        show_main_menu
        return
    fi

    for server_name in "${server_list[@]}"; do
        app_id=$(jq -r ".ServerList.\"$server_name\".AppId" "$CONFIG_PATH")
        description=$(jq -r ".ServerList.\"$server_name\".Description" "$CONFIG_PATH")
        echo "$index. $server_name (AppID: $app_id) - $description"
        ((index++))
    done

    echo "B. 返回主菜单"
    echo "Q. 退出程序"

    read -p "请输入要删除的服务器编号 (1-${#server_list[@]}, B 返回, Q 退出): " choice

    case $choice in
    [Bb])
        show_main_menu
        return
        ;;
    [Qq]) exit 0 ;;
    *)
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#server_list[@]} ]; then
            selected_server=${server_list[$choice - 1]}

            clear
            echo "===== 删除服务器: $selected_server ====="
            echo "当前配置:"
            jq ".ServerList.\"$selected_server\"" "$CONFIG_PATH"

            # 获取安装目录
            install_dir=$(jq -r ".ServerList.\"$selected_server\".ForceInstallDir" "$CONFIG_PATH")
            full_install_dir="$SCRIPT_DIR/$install_dir"

            echo ""
            echo "警告: 此操作将从配置中删除服务器 '$selected_server'！"
            if [ -d "$full_install_dir" ]; then
                echo "警告: 服务器安装目录 '$full_install_dir' 存在！"
                read -p "是否同时删除服务器安装目录? (Y/N): " delete_files_choice
            fi

            read -p "确认删除服务器 '$selected_server'? (Y/N): " confirm_choice

            if [[ $confirm_choice =~ ^[Yy]$ ]]; then
                # 从配置文件中删除服务器
                jq "del(.ServerList.\"$selected_server\")" "$CONFIG_PATH" >"${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

                # 如果用户选择删除文件且目录存在
                if [[ $delete_files_choice =~ ^[Yy]$ ]] && [ -d "$full_install_dir" ]; then
                    echo "正在删除服务器文件..."
                    rm -rf "$full_install_dir"
                    echo "服务器文件已删除！"
                fi

                echo "服务器 '$selected_server' 已成功从配置中删除！"
            else
                echo "已取消删除操作！"
            fi

            read -p "按回车键返回主菜单"
            show_main_menu
        else
            echo "无效的选择: $choice"
            sleep 2
            remove_server
        fi
        ;;
    esac
}

# 启动主菜单
show_main_menu
