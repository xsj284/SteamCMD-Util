#!/bin/bash

# 处理命令行参数
DEBUG_MODE=false
for arg in "$@"; do
    case $arg in
        "-debug")
            DEBUG_MODE=true
            ;;
    esac
done

# 检查依赖
check_dependencies() {
    # 检查jq是否安装
    if ! command -v jq &> /dev/null; then
        echo -e "\e[33m警告: 未找到jq工具，此工具用于处理JSON格式的配置文件\e[0m"
        echo -e "\e[33m您可以通过以下命令安装:\e[0m"
        echo -e "\e[33m  Debian/Ubuntu: sudo apt-get install jq\e[0m"
        echo -e "\e[33m  CentOS/RHEL: sudo yum install jq\e[0m"
        echo -e "\e[33m  Fedora: sudo dnf install jq\e[0m"
        echo -e "\e[33m  Arch Linux: sudo pacman -S jq\e[0m"
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 读取配置文件
load_config() {
    CONFIG_PATH="$(dirname "$(readlink -f "$0")")/server_info.json"
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\e[33m配置文件不存在，正在创建默认配置文件: $CONFIG_PATH\e[0m"
        # 创建默认配置文件
        echo '{
            "SteamCMD_Path": "./SteamCMD",
            "ServerList": {}
        }' | jq '.' > "$CONFIG_PATH"
        echo -e "\e[32m已创建默认配置文件\e[0m"
    fi
}

# 检查SteamCMD
check_steamcmd() {
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    STEAMCMD_PATH="$SCRIPT_DIR/$(jq -r '.SteamCMD_Path' "$CONFIG_PATH")"
    STEAMCMD_SH="$STEAMCMD_PATH/steamcmd.sh"

    if [ ! -f "$STEAMCMD_SH" ]; then
        echo -e "\e[33mSteamCMD不存在，正在自动下载...\e[0m"

        # 创建SteamCMD目录
        mkdir -p "$STEAMCMD_PATH"

        # 下载SteamCMD
        echo -e "\e[33m下载SteamCMD...\e[0m"
        cd "$STEAMCMD_PATH" || exit 1

        if ! curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -; then
            echo -e "\e[31m下载或解压SteamCMD时发生错误\e[0m"
            exit 1
        fi

        echo -e "\e[32mSteamCMD安装完成！\e[0m"
    fi
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "\e[36m===== 游戏服务器管理工具 =====\e[0m"
    echo -e "\e[37m1. 更新服务器\e[0m"
    echo -e "\e[37m2. 添加新服务器\e[0m"
    echo -e "\e[37m3. 修改服务器\e[0m"
    echo -e "\e[37m4. 删除服务器\e[0m"
    echo -e "\e[37mQ. 退出\e[0m"
    echo -e "\e[36m=============================\e[0m"

    read -p "请选择操作: " CHOICE
    case $CHOICE in
        "1")
            update_servers
            ;;
        "2")
            add_new_server
            ;;
        "3")
            update_server
            ;;
        "4")
            remove_server
            ;;
        "Q"|"q")
            exit 0
            ;;
        *)
            echo -e "\e[31m无效的选择，请重试\e[0m"
            sleep 2
            show_main_menu
            ;;
    esac
}

# 添加新服务器
add_new_server() {
    clear
    echo -e "\e[36m===== 添加新服务器 =====\e[0m"

    read -p "请输入服务器名称 (例如: PZServer): " SERVER_NAME

    # 检查服务器名称是否已存在
    if jq -e ".ServerList.\"$SERVER_NAME\"" "$CONFIG_PATH" > /dev/null 2>&1; then
        echo -e "\e[31m错误: 服务器名称 '$SERVER_NAME' 已存在!\e[0m"
        read -p "按Enter键返回主菜单"
        show_main_menu
        return
    fi

    read -p "请输入Steam AppID: " APP_ID
    read -p "请输入服务器描述: " DESCRIPTION
    read -p "请输入安装目录 (相对于脚本目录，例如: ./PZServer): " INSTALL_DIR

    ANONYMOUS=false
    read -p "是否使用匿名登录? (Y/N): " ANONYMOUS_CHOICE
    if [[ $ANONYMOUS_CHOICE =~ ^[Yy]$ ]]; then
        ANONYMOUS=true
    fi

    # 更新配置
    jq --arg name "$SERVER_NAME" \
       --arg appid "$APP_ID" \
       --arg desc "$DESCRIPTION" \
       --arg dir "$INSTALL_DIR" \
       --argjson anon "$ANONYMOUS" \
       '.ServerList[$name] = {"AppId": $appid, "Description": $desc, "ForceInstallDir": $dir, "Anonymous": $anon}' \
       "$CONFIG_PATH" > temp.json && mv temp.json "$CONFIG_PATH"

    echo -e "\e[32m服务器 '$SERVER_NAME' 已成功添加!\e[0m"
    read -p "按Enter键返回主菜单"
    show_main_menu
}

# 删除服务器
remove_server() {
    clear
    # 显示服务器列表并让用户选择
    echo -e "\n\e[36m可用的服务器列表:\e[0m"
    INDEX=1
    SERVER_LIST=()
    SERVER_NAMES=()

    while read -r SERVER_NAME; do
        SERVER_NAMES+=("$SERVER_NAME")
        APP_ID=$(jq -r ".ServerList.\"$SERVER_NAME\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SERVER_NAME\".Description" "$CONFIG_PATH")
        echo -e "$INDEX. $SERVER_NAME (AppID: $APP_ID) - $DESCRIPTION"
        INDEX=$((INDEX+1))
    done < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")

    if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
        echo -e "\n\e[33m当前没有配置任何服务器\e[0m"
        read -p "按Enter键返回主菜单"
        show_main_menu
        return
    fi

    echo -e "\e[33mB. 返回主菜单\e[0m"
    echo -e "\e[33mQ. 退出程序\e[0m"
    read -p "请输入要删除的服务器编号 (1-${#SERVER_NAMES[@]}, B 返回, Q 退出): " CHOICE

    if [[ $CHOICE =~ ^[Bb]$ ]]; then
        show_main_menu
        return
    fi

    if [[ $CHOICE =~ ^[Qq]$ ]]; then
        exit 0
    fi

    # 处理用户选择
    if [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#SERVER_NAMES[@]} ]; then
        SELECTED_SERVER="${SERVER_NAMES[$CHOICE-1]}"
        APP_ID=$(jq -r ".ServerList.\"$SELECTED_SERVER\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SELECTED_SERVER\".Description" "$CONFIG_PATH")
        INSTALL_DIR=$(jq -r ".ServerList.\"$SELECTED_SERVER\".ForceInstallDir" "$CONFIG_PATH")
        FULL_INSTALL_DIR="$SCRIPT_DIR/$INSTALL_DIR"

        clear
        echo -e "\e[36m===== 删除服务器: $SELECTED_SERVER =====\e[0m"
        echo -e "\e[33m当前配置:\e[0m"
        echo -e "AppID: $APP_ID"
        echo -e "描述: $DESCRIPTION"
        echo -e "安装目录: $INSTALL_DIR"
        echo -e "安装路径: $FULL_INSTALL_DIR"
        echo -e "\e[36m=============================\e[0m"

        # 显示风险警告
        echo -e "\n\e[41m警告!\e[0m"
        echo -e "\e[31m删除服务器将会:\e[0m"
        echo -e "\e[31m1. 从配置文件中移除服务器信息\e[0m"
        echo -e "\e[31m2. 永久删除服务器安装目录及其中的所有文件\e[0m"
        echo -e "\e[31m此操作不可逆，请确保您已备份重要数据!\e[0m"

        # 要求用户确认
        read -p "请输入服务器名称 '$SELECTED_SERVER' 以确认删除，或输入任意其他内容取消: " CONFIRMATION

        if [ "$CONFIRMATION" = "$SELECTED_SERVER" ]; then
            # 删除安装目录
            if [ -d "$FULL_INSTALL_DIR" ]; then
                echo -e "\n\e[33m正在删除安装目录: $FULL_INSTALL_DIR\e[0m"
                if rm -rf "$FULL_INSTALL_DIR"; then
                    echo -e "\e[32m安装目录已成功删除\e[0m"
                else
                    echo -e "\e[31m删除安装目录时出错\e[0m"
                fi
            else
                echo -e "\n\e[33m安装目录不存在: $FULL_INSTALL_DIR\e[0m"
            fi

            # 从配置中移除服务器
            jq "del(.ServerList.\"$SELECTED_SERVER\")" "$CONFIG_PATH" > temp.json && mv temp.json "$CONFIG_PATH"

            echo -e "\n\e[32m服务器 '$SELECTED_SERVER' 已成功删除!\e[0m"
        else
            echo -e "\n\e[33m删除操作已取消\e[0m"
        fi

        read -p "按Enter键返回主菜单"
        show_main_menu
    else
        echo -e "\e[31m无效的选择: $CHOICE\e[0m"
        sleep 2
        remove_server
        return
    fi
}

# 修改服务器
update_server() {
    clear
    # 显示服务器列表并让用户选择
    echo -e "\n\e[36m可用的服务器列表:\e[0m"
    INDEX=1
    SERVER_LIST=()
    SERVER_NAMES=()

    while read -r SERVER_NAME; do
        SERVER_NAMES+=("$SERVER_NAME")
        APP_ID=$(jq -r ".ServerList.\"$SERVER_NAME\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SERVER_NAME\".Description" "$CONFIG_PATH")
        echo -e "$INDEX. $SERVER_NAME (AppID: $APP_ID) - $DESCRIPTION"
        INDEX=$((INDEX+1))
    done < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")

    if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
        echo -e "\n\e[33m当前没有配置任何服务器\e[0m"
        read -p "按Enter键返回主菜单"
        show_main_menu
        return
    fi

    echo -e "\e[33mB. 返回主菜单\e[0m"
    echo -e "\e[33mQ. 退出程序\e[0m"
    read -p "请输入要修改的服务器编号 (1-${#SERVER_NAMES[@]}, B 返回, Q 退出): " CHOICE

    if [[ $CHOICE =~ ^[Bb]$ ]]; then
        show_main_menu
        return
    fi

    if [[ $CHOICE =~ ^[Qq]$ ]]; then
        exit 0
    fi

    # 处理用户选择
    if [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#SERVER_NAMES[@]} ]; then
        SELECTED_SERVER="${SERVER_NAMES[$CHOICE-1]}"
        APP_ID=$(jq -r ".ServerList.\"$SELECTED_SERVER\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SELECTED_SERVER\".Description" "$CONFIG_PATH")
        INSTALL_DIR=$(jq -r ".ServerList.\"$SELECTED_SERVER\".ForceInstallDir" "$CONFIG_PATH")
        ANONYMOUS=$(jq -r ".ServerList.\"$SELECTED_SERVER\".Anonymous" "$CONFIG_PATH")

        clear
        echo -e "\e[36m===== 修改服务器: $SELECTED_SERVER =====\e[0m"
        echo -e "\e[33m当前配置:\e[0m"
        echo -e "AppID: $APP_ID"
        echo -e "描述: $DESCRIPTION"
        echo -e "安装目录: $INSTALL_DIR"
        echo -e "匿名登录: $ANONYMOUS"
        echo -e "\e[36m=============================\e[0m"

        # 修改服务器名称
        read -p "请输入新的服务器名称 (留空保持不变): " NEW_SERVER_NAME
        if [ ! -z "$NEW_SERVER_NAME" ] && [ "$NEW_SERVER_NAME" != "$SELECTED_SERVER" ]; then
            # 检查新名称是否已存在
            if jq -e ".ServerList.\"$NEW_SERVER_NAME\"" "$CONFIG_PATH" > /dev/null 2>&1; then
                echo -e "\e[31m错误: 服务器名称 '$NEW_SERVER_NAME' 已存在!\e[0m"
                read -p "按Enter键返回主菜单"
                show_main_menu
                return
            fi
        fi

        # 修改其他配置
        read -p "请输入新的Steam AppID (留空保持不变): " NEW_APP_ID
        read -p "请输入新的服务器描述 (留空保持不变): " NEW_DESCRIPTION
        read -p "请输入新的安装目录 (留空保持不变): " NEW_INSTALL_DIR
        read -p "是否修改登录方式? (Y/N): " CHANGE_LOGIN_METHOD

        # 更新配置
        if [ -z "$NEW_APP_ID" ]; then NEW_APP_ID="$APP_ID"; fi
        if [ -z "$NEW_DESCRIPTION" ]; then NEW_DESCRIPTION="$DESCRIPTION"; fi
        if [ -z "$NEW_INSTALL_DIR" ]; then NEW_INSTALL_DIR="$INSTALL_DIR"; fi

        NEW_ANONYMOUS=$ANONYMOUS
        if [[ $CHANGE_LOGIN_METHOD =~ ^[Yy]$ ]]; then
            read -p "是否使用匿名登录? (Y/N): " ANONYMOUS_CHOICE
            if [[ $ANONYMOUS_CHOICE =~ ^[Yy]$ ]]; then
                NEW_ANONYMOUS=true
            else
                NEW_ANONYMOUS=false
            fi
        fi

        # 更新配置
        if [ ! -z "$NEW_SERVER_NAME" ] && [ "$NEW_SERVER_NAME" != "$SELECTED_SERVER" ]; then
            # 如果服务器名称改变，删除旧配置并添加新配置
            jq --arg oldname "$SELECTED_SERVER" \
               --arg newname "$NEW_SERVER_NAME" \
               --arg appid "$NEW_APP_ID" \
               --arg desc "$NEW_DESCRIPTION" \
               --arg dir "$NEW_INSTALL_DIR" \
               --argjson anon "$NEW_ANONYMOUS" \
               'del(.ServerList[$oldname]) | .ServerList[$newname] = {"AppId": $appid, "Description": $desc, "ForceInstallDir": $dir, "Anonymous": $anon}' \
               "$CONFIG_PATH" > temp.json && mv temp.json "$CONFIG_PATH"
        else
            # 如果服务器名称未改变，直接更新配置
            jq --arg name "$SELECTED_SERVER" \
               --arg appid "$NEW_APP_ID" \
               --arg desc "$NEW_DESCRIPTION" \
               --arg dir "$NEW_INSTALL_DIR" \
               --argjson anon "$NEW_ANONYMOUS" \
               '.ServerList[$name] = {"AppId": $appid, "Description": $desc, "ForceInstallDir": $dir, "Anonymous": $anon}' \
               "$CONFIG_PATH" > temp.json && mv temp.json "$CONFIG_PATH"
        fi

        echo -e "\e[32m服务器配置已成功修改!\e[0m"
        read -p "按Enter键返回主菜单"
        show_main_menu
    else
        echo -e "\e[31m无效的选择: $CHOICE\e[0m"
        sleep 2
        update_server
        return
    fi
}

# 更新服务器功能
update_servers() {
    clear
    # 显示服务器列表并让用户选择
    echo -e "\n\e[36m可用的服务器列表:\e[0m"
    INDEX=1
    SERVER_LIST=()
    SERVER_NAMES=()

    while read -r SERVER_NAME; do
        SERVER_NAMES+=("$SERVER_NAME")
        APP_ID=$(jq -r ".ServerList.\"$SERVER_NAME\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SERVER_NAME\".Description" "$CONFIG_PATH")
        echo -e "$INDEX. $SERVER_NAME (AppID: $APP_ID) - $DESCRIPTION"
        INDEX=$((INDEX+1))
    done < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")

    if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
        echo -e "\n\e[33m当前没有配置任何服务器\e[0m"
        read -p "按Enter键返回主菜单"
        show_main_menu
        return
    fi

    echo -e "\e[33m0. 更新所有服务器\e[0m"
    echo -e "\e[33mB. 返回主菜单\e[0m"
    echo -e "\e[33mQ. 退出程序\e[0m"
    read -p "请输入要更新的服务器编号 (0-${#SERVER_NAMES[@]}, B 返回, Q 退出): " CHOICE

    if [[ $CHOICE =~ ^[Bb]$ ]]; then
        show_main_menu
        return
    fi

    if [[ $CHOICE =~ ^[Qq]$ ]]; then
        exit 0
    fi

    # 处理用户选择
    SERVERS_TO_UPDATE=()
    if [ "$CHOICE" = "0" ]; then
        SERVERS_TO_UPDATE=("${SERVER_NAMES[@]}")
    elif [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#SERVER_NAMES[@]} ]; then
        SERVERS_TO_UPDATE=("${SERVER_NAMES[$CHOICE-1]}")
    else
        echo -e "\e[31m无效的选择: $CHOICE\e[0m"
        sleep 2
        update_servers
        return
    fi

    # 处理选定的服务器
    for SERVER in "${SERVERS_TO_UPDATE[@]}"; do
        echo -e "\n\e[32m正在处理服务器: $SERVER\e[0m"

        APP_ID=$(jq -r ".ServerList.\"$SERVER\".AppId" "$CONFIG_PATH")
        INSTALL_DIR=$(jq -r ".ServerList.\"$SERVER\".ForceInstallDir" "$CONFIG_PATH")
        FULL_INSTALL_DIR="$SCRIPT_DIR/$INSTALL_DIR"
        ANONYMOUS=$(jq -r ".ServerList.\"$SERVER\".Anonymous" "$CONFIG_PATH")

        # 构建SteamCMD脚本
        TEMP_SCRIPT="/tmp/steamcmd_script_$$.txt"
        echo "@ShutdownOnFailedCommand 1" > "$TEMP_SCRIPT"
        echo "@NoPromptForPassword 1" >> "$TEMP_SCRIPT"
        echo "force_install_dir \"$FULL_INSTALL_DIR\"" >> "$TEMP_SCRIPT"

        # 处理登录信息
        if [ "$ANONYMOUS" = "true" ]; then
            echo "login anonymous" >> "$TEMP_SCRIPT"
        else
            read -p "请输入Steam用户名: " USERNAME
            read -sp "请输入Steam密码: " PASSWORD
            echo
            echo "login \"$USERNAME\" \"$PASSWORD\"" >> "$TEMP_SCRIPT"
        fi

        # 添加应用更新命令
        echo "app_update $APP_ID validate" >> "$TEMP_SCRIPT"
        echo "quit" >> "$TEMP_SCRIPT"

        # 执行SteamCMD
        echo -e "\e[33m开始更新服务器...\e[0m"
        if [ "$DEBUG_MODE" = true ]; then
            echo -e "\e[33m调试信息 - SteamCMD脚本内容:\e[0m"
            cat "$TEMP_SCRIPT"
        fi

        cd "$STEAMCMD_PATH" || exit 1
        if [ "$DEBUG_MODE" = true ]; then
            echo -e "\e[33m调试信息 - SteamCMD完整命令:\e[0m"
            echo -e "\e[37m./steamcmd.sh +runscript $TEMP_SCRIPT\e[0m"
        fi

        if ./steamcmd.sh +runscript "$TEMP_SCRIPT"; then
            echo -e "\e[32m服务器更新成功完成！\e[0m"
        else
            echo -e "\e[31m服务器更新过程中出现错误，退出代码: $?\e[0m"
        fi

        # 清理临时脚本
        rm -f "$TEMP_SCRIPT"
    done

    if [ ${#SERVERS_TO_UPDATE[@]} -eq 1 ]; then
        echo -e "\n\e[32m服务器 '${SERVERS_TO_UPDATE[0]}' 更新完成！\e[0m"
    else
        echo -e "\n\e[32m所有选定的服务器更新完成！\e[0m"
    fi

    read -p "按Enter键返回主菜单"
    show_main_menu
}

# 主程序
main() {
    check_dependencies
    load_config
    check_steamcmd
    show_main_menu
}

# 执行主程序
main
