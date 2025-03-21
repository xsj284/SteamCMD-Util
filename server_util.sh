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

# 读取本地化文件
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOCALE_PATH="$SCRIPT_DIR/locale.json"
CONFIG_PATH="$SCRIPT_DIR/server_info.json"

# 初始化时首先创建配置文件（如果不存在）
init_config() {
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\e[33m配置文件不存在，正在创建默认配置文件: $CONFIG_PATH\e[0m"
        # 创建默认配置文件
        echo '{
            "SteamCMD_Path": "./SteamCMD",
            "Language": "zh-CN",
            "ServerList": {}
        }' | jq '.' >"$CONFIG_PATH"
        echo -e "\e[32m已创建默认配置文件\e[0m"
    fi

    # 初始设置语言
    CURRENT_LANGUAGE=$(jq -r '.Language // "zh-CN"' "$CONFIG_PATH")
}

# 检查依赖
check_dependencies() {
    # 检查jq是否安装
    if ! command -v jq &>/dev/null; then
        echo -e "\e[33m警告: 未找到jq工具，此工具用于处理JSON格式的配置文件\e[0m"
        echo -e "\e[33m您可以通过以下命令安装:\e[0m"
        echo -e "\e[33m  Debian/Ubuntu: sudo apt-get install jq\e[0m"
        echo -e "\e[33m  CentOS/RHEL: sudo yum install jq\e[0m"
        echo -e "\e[33m  Fedora: sudo dnf install jq\e[0m"
        echo -e "\e[33m  Arch Linux: sudo pacman -S jq\e[0m"
        read -r -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 获取本地化文本
get_localized_text() {
    local key=$1
    shift
    local params=("$@")

    # 获取语言列表
    local lang_list
    lang_list=$(jq -r '.LanguageList | @csv' "$LOCALE_PATH" | tr -d '"' | tr ',' ' ')
    local lang_array
    read -ra lang_array <<<"$lang_list"

    # 查找当前语言索引
    local lang_index=0
    for i in "${!lang_array[@]}"; do
        if [ "${lang_array[$i]}" = "$CURRENT_LANGUAGE" ]; then
            lang_index=$i
            break
        fi
    done

    # 获取对应的文本
    local text
    text=$(jq -r ".[\"$key\"][$lang_index]" "$LOCALE_PATH")

    # 替换参数（类似于格式化字符串）
    for i in "${!params[@]}"; do
        text=${text//\{$i\}/${params[$i]}}
    done

    echo "$text"
}

# 保存语言设置到配置文件
save_language_setting() {
    local language=$1
    jq --arg lang "$language" '.Language = $lang' "$CONFIG_PATH" >temp.json && mv temp.json "$CONFIG_PATH"
}

# 语言选择功能
select_language() {
    clear
    echo -e "\e[36m$(get_localized_text "LANGUAGE_SETTINGS")\e[0m"

    # 获取语言列表和名称
    local lang_list
    lang_list=$(jq -r '.LanguageList | @csv' "$LOCALE_PATH" | tr -d '"' | tr ',' ' ')
    local lang_array
    read -ra lang_array <<<"$lang_list"

    # 获取语言名称列表
    local lang_name_list
    lang_name_list=$(jq -r '.LanguageName | @csv' "$LOCALE_PATH" | tr -d '"' | tr ',' '\n')
    local lang_name_array
    readarray -t lang_name_array <<<"$lang_name_list"

    # 显示所有可用语言
    for i in "${!lang_array[@]}"; do
        echo -e "$((i + 1)). ${lang_name_array[$i]}"
    done

    read -r -p "$(get_localized_text "SELECT_LANGUAGE"): " CHOICE

    # 处理用户选择
    if [[ $CHOICE =~ ^[0-9]+$ ]]; then
        index=$((CHOICE - 1))
        if [ $index -ge 0 ] && [ $index -lt ${#lang_array[@]} ]; then
            CURRENT_LANGUAGE="${lang_array[$index]}"
            save_language_setting "${lang_array[$index]}"
        else
            # 默认使用第一个语言
            CURRENT_LANGUAGE="${lang_array[0]}"
            save_language_setting "${lang_array[0]}"
        fi
    else
        # 默认使用第一个语言
        CURRENT_LANGUAGE="${lang_array[0]}"
        save_language_setting "${lang_array[0]}"
    fi
}

# 读取配置文件
load_config() {
    # 检查配置文件是否存在，基于当前语言更新配置信息
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\e[33m$(get_localized_text "CONFIG_FILE_NOT_EXIST" "$CONFIG_PATH")\e[0m"
        # 创建默认配置文件
        jq -n --arg lang "$CURRENT_LANGUAGE" '{
            "SteamCMD_Path": "./SteamCMD",
            "Language": $lang,
            "ServerList": {}
        }' >"$CONFIG_PATH"
        echo -e "\e[32m$(get_localized_text "CONFIG_FILE_CREATED")\e[0m"
    fi
}

# 检查SteamCMD
check_steamcmd() {
    STEAMCMD_PATH="$SCRIPT_DIR/$(jq -r '.SteamCMD_Path' "$CONFIG_PATH")"
    STEAMCMD_SH="$STEAMCMD_PATH/steamcmd.sh"

    if [ ! -f "$STEAMCMD_SH" ]; then
        echo -e "\e[33m$(get_localized_text "STEAMCMD_NOT_EXIST")\e[0m"

        # 创建SteamCMD目录
        mkdir -p "$STEAMCMD_PATH"

        # 下载SteamCMD
        echo -e "\e[33m$(get_localized_text "DOWNLOADING_STEAMCMD")\e[0m"
        cd "$STEAMCMD_PATH" || exit 1

        if ! curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -; then
            echo -e "\e[31m$(get_localized_text "STEAMCMD_DOWNLOAD_ERROR")\e[0m"
            exit 1
        fi

        echo -e "\e[32m$(get_localized_text "STEAMCMD_INSTALL_COMPLETE")\e[0m"
    fi
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "\e[36m===== $(get_localized_text "GAME_SERVER_TOOL") =====\e[0m"
    echo -e "\e[37m1. $(get_localized_text "UPDATE_SERVER")\e[0m"
    echo -e "\e[37m2. $(get_localized_text "ADD_NEW_SERVER")\e[0m"
    echo -e "\e[37m3. $(get_localized_text "MODIFY_SERVER")\e[0m"
    echo -e "\e[37m4. $(get_localized_text "DELETE_SERVER")\e[0m"
    echo -e "\e[37m5. $(get_localized_text "LANGUAGE_SETTINGS")\e[0m"
    echo -e "\e[37mQ. $(get_localized_text "EXIT")\e[0m"
    echo -e "\e[36m=============================\e[0m"

    read -r -p "$(get_localized_text "SELECT_OPERATION"): " CHOICE
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
    "5")
        select_language
        show_main_menu
        ;;
    "Q" | "q")
        exit 0
        ;;
    *)
        echo -e "\e[31m$(get_localized_text "INVALID_CHOICE")\e[0m"
        sleep 2
        show_main_menu
        ;;
    esac
}

# 添加新服务器
add_new_server() {
    clear
    echo -e "\e[36m===== $(get_localized_text "ADD_NEW_SERVER") =====\e[0m"

    read -r -p "$(get_localized_text "ENTER_SERVER_NAME"): " SERVER_NAME

    # 检查服务器名称是否已存在
    if jq -e ".ServerList.\"$SERVER_NAME\"" "$CONFIG_PATH" >/dev/null 2>&1; then
        echo -e "\e[31m$(get_localized_text "SERVER_NAME_EXISTS" "$SERVER_NAME")\e[0m"
        read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
        show_main_menu
        return
    fi

    read -r -p "$(get_localized_text "ENTER_STEAM_APPID"): " APP_ID
    read -r -p "$(get_localized_text "ENTER_SERVER_DESCRIPTION"): " DESCRIPTION
    read -r -p "$(get_localized_text "ENTER_INSTALL_DIR"): " INSTALL_DIR

    ANONYMOUS=false
    read -r -p "$(get_localized_text "USE_ANONYMOUS_LOGIN"): " ANONYMOUS_CHOICE
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
        "$CONFIG_PATH" >temp.json && mv temp.json "$CONFIG_PATH"

    echo -e "\e[32m$(get_localized_text "SERVER_ADDED" "$SERVER_NAME")\e[0m"
    read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
    show_main_menu
}

# 删除服务器
remove_server() {
    clear
    # 显示服务器列表并让用户选择
    echo -e "\n\e[36m$(get_localized_text "AVAILABLE_SERVERS")\e[0m"
    INDEX=1
    SERVER_NAMES=()

    while read -r SERVER_NAME; do
        SERVER_NAMES+=("$SERVER_NAME")
        APP_ID=$(jq -r ".ServerList.\"$SERVER_NAME\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SERVER_NAME\".Description" "$CONFIG_PATH")
        echo -e "$INDEX. $SERVER_NAME (AppID: $APP_ID) - $DESCRIPTION"
        INDEX=$((INDEX + 1))
    done < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")

    if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
        echo -e "\n\e[33m$(get_localized_text "NO_SERVERS_CONFIGURED")\e[0m"
        read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
        show_main_menu
        return
    fi

    echo -e "\e[33mB. $(get_localized_text "RETURN_MAIN_MENU")\e[0m"
    echo -e "\e[33mQ. $(get_localized_text "EXIT_PROGRAM")\e[0m"
    read -r -p "$(get_localized_text "ENTER_SERVER_NUMBER" "删除" "${#SERVER_NAMES[@]}"): " CHOICE

    if [[ $CHOICE =~ ^[Bb]$ ]]; then
        show_main_menu
        return
    fi

    if [[ $CHOICE =~ ^[Qq]$ ]]; then
        exit 0
    fi

    # 处理用户选择
    if [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#SERVER_NAMES[@]} ]; then
        SELECTED_SERVER="${SERVER_NAMES[$CHOICE - 1]}"
        APP_ID=$(jq -r ".ServerList.\"$SELECTED_SERVER\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SELECTED_SERVER\".Description" "$CONFIG_PATH")
        INSTALL_DIR=$(jq -r ".ServerList.\"$SELECTED_SERVER\".ForceInstallDir" "$CONFIG_PATH")
        FULL_INSTALL_DIR="$SCRIPT_DIR/$INSTALL_DIR"

        clear
        echo -e "\e[36m===== $(get_localized_text "DELETE_SERVER"): $SELECTED_SERVER =====\e[0m"
        echo -e "\e[33m$(get_localized_text "CURRENT_CONFIG"):\e[0m"
        echo -e "AppID: $APP_ID"
        echo -e "$(get_localized_text "ENTER_SERVER_DESCRIPTION"): $DESCRIPTION"
        echo -e "$(get_localized_text "ENTER_INSTALL_DIR"): $INSTALL_DIR"
        echo -e "$(get_localized_text "ENTER_INSTALL_DIR"): $FULL_INSTALL_DIR"
        echo -e "\e[36m=============================\e[0m"

        # 显示风险警告
        echo -e "\n\e[41m$(get_localized_text "WARNING")\e[0m"
        echo -e "\e[31m$(get_localized_text "DELETE_SERVER_WARNING")\e[0m"
        echo -e "\e[31m$(get_localized_text "REMOVE_SERVER_INFO")\e[0m"
        echo -e "\e[31m$(get_localized_text "DELETE_SERVER_DIR")\e[0m"
        echo -e "\e[31m$(get_localized_text "OPERATION_IRREVERSIBLE")\e[0m"

        # 要求用户确认
        read -r -p "$(get_localized_text "ENTER_SERVER_NAME_CONFIRM" "$SELECTED_SERVER"): " CONFIRMATION

        if [ "$CONFIRMATION" = "$SELECTED_SERVER" ]; then
            # 删除安装目录
            if [ -d "$FULL_INSTALL_DIR" ]; then
                echo -e "\n\e[33m$(get_localized_text "DELETING_INSTALL_DIR" "$FULL_INSTALL_DIR")\e[0m"
                if rm -rf "$FULL_INSTALL_DIR"; then
                    echo -e "\e[32m$(get_localized_text "INSTALL_DIR_DELETED")\e[0m"
                else
                    echo -e "\e[31m$(get_localized_text "ERROR_DELETING_DIR")\e[0m"
                fi
            else
                echo -e "\n\e[33m$(get_localized_text "INSTALL_DIR_NOT_EXIST" "$FULL_INSTALL_DIR")\e[0m"
            fi

            # 从配置中移除服务器
            jq "del(.ServerList.\"$SELECTED_SERVER\")" "$CONFIG_PATH" >temp.json && mv temp.json "$CONFIG_PATH"

            echo -e "\n\e[32m$(get_localized_text "SERVER_DELETED" "$SELECTED_SERVER")\e[0m"
        else
            echo -e "\n\e[33m$(get_localized_text "DELETE_CANCELED")\e[0m"
        fi

        read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
        show_main_menu
    else
        echo -e "\e[31m$(get_localized_text "INVALID_CHOICE")\e[0m"
        sleep 2
        remove_server
        return
    fi
}

# 修改服务器
update_server() {
    clear
    # 显示服务器列表并让用户选择
    echo -e "\n\e[36m$(get_localized_text "AVAILABLE_SERVERS")\e[0m"
    INDEX=1
    SERVER_NAMES=()

    while read -r SERVER_NAME; do
        SERVER_NAMES+=("$SERVER_NAME")
        APP_ID=$(jq -r ".ServerList.\"$SERVER_NAME\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SERVER_NAME\".Description" "$CONFIG_PATH")
        echo -e "$INDEX. $SERVER_NAME (AppID: $APP_ID) - $DESCRIPTION"
        INDEX=$((INDEX + 1))
    done < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")

    if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
        echo -e "\n\e[33m$(get_localized_text "NO_SERVERS_CONFIGURED")\e[0m"
        read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
        show_main_menu
        return
    fi

    echo -e "\e[33mB. $(get_localized_text "RETURN_MAIN_MENU")\e[0m"
    echo -e "\e[33mQ. $(get_localized_text "EXIT_PROGRAM")\e[0m"
    read -r -p "$(get_localized_text "ENTER_SERVER_NUMBER" "修改" "${#SERVER_NAMES[@]}"): " CHOICE

    if [[ $CHOICE =~ ^[Bb]$ ]]; then
        show_main_menu
        return
    fi

    if [[ $CHOICE =~ ^[Qq]$ ]]; then
        exit 0
    fi

    # 处理用户选择
    if [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#SERVER_NAMES[@]} ]; then
        SELECTED_SERVER="${SERVER_NAMES[$CHOICE - 1]}"
        APP_ID=$(jq -r ".ServerList.\"$SELECTED_SERVER\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SELECTED_SERVER\".Description" "$CONFIG_PATH")
        INSTALL_DIR=$(jq -r ".ServerList.\"$SELECTED_SERVER\".ForceInstallDir" "$CONFIG_PATH")
        ANONYMOUS=$(jq -r ".ServerList.\"$SELECTED_SERVER\".Anonymous" "$CONFIG_PATH")

        clear
        echo -e "\e[36m===== $(get_localized_text "MODIFY_SERVER"): $SELECTED_SERVER =====\e[0m"
        echo -e "\e[33m$(get_localized_text "CURRENT_CONFIG"):\e[0m"
        echo -e "AppID: $APP_ID"
        echo -e "$(get_localized_text "ENTER_SERVER_DESCRIPTION"): $DESCRIPTION"
        echo -e "$(get_localized_text "ENTER_INSTALL_DIR"): $INSTALL_DIR"
        echo -e "$(get_localized_text "USE_ANONYMOUS_LOGIN"): $ANONYMOUS"
        echo -e "\e[36m=============================\e[0m"

        # 修改服务器名称
        read -r -p "$(get_localized_text "ENTER_NEW_SERVER_NAME"): " NEW_SERVER_NAME
        if [ -n "$NEW_SERVER_NAME" ] && [ "$NEW_SERVER_NAME" != "$SELECTED_SERVER" ]; then
            # 检查新名称是否已存在
            if jq -e ".ServerList.\"$NEW_SERVER_NAME\"" "$CONFIG_PATH" >/dev/null 2>&1; then
                echo -e "\e[31m$(get_localized_text "SERVER_NAME_EXISTS" "$NEW_SERVER_NAME")\e[0m"
                read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
                show_main_menu
                return
            fi
        else
            NEW_SERVER_NAME="$SELECTED_SERVER"
        fi

        # 修改其他配置
        read -r -p "$(get_localized_text "ENTER_NEW_APPID"): " NEW_APP_ID
        NEW_APP_ID=${NEW_APP_ID:-$APP_ID}

        read -r -p "$(get_localized_text "ENTER_NEW_DESCRIPTION"): " NEW_DESCRIPTION
        NEW_DESCRIPTION=${NEW_DESCRIPTION:-$DESCRIPTION}

        read -r -p "$(get_localized_text "ENTER_NEW_INSTALL_DIR"): " NEW_INSTALL_DIR
        NEW_INSTALL_DIR=${NEW_INSTALL_DIR:-$INSTALL_DIR}

        read -r -p "$(get_localized_text "CHANGE_LOGIN_METHOD") (Y/N): " CHANGE_LOGIN_METHOD
        if [[ $CHANGE_LOGIN_METHOD =~ ^[Yy]$ ]]; then
            if [ "$ANONYMOUS" = "true" ]; then
                NEW_ANONYMOUS=false
            else
                NEW_ANONYMOUS=true
            fi
        else
            NEW_ANONYMOUS=$ANONYMOUS
        fi

        # 从配置中移除旧服务器
        jq "del(.ServerList.\"$SELECTED_SERVER\")" "$CONFIG_PATH" >temp.json && mv temp.json "$CONFIG_PATH"

        # 添加新服务器配置
        jq --arg name "$NEW_SERVER_NAME" \
            --arg appid "$NEW_APP_ID" \
            --arg desc "$NEW_DESCRIPTION" \
            --arg dir "$NEW_INSTALL_DIR" \
            --argjson anon "$NEW_ANONYMOUS" \
            '.ServerList[$name] = {"AppId": $appid, "Description": $desc, "ForceInstallDir": $dir, "Anonymous": $anon}' \
            "$CONFIG_PATH" >temp.json && mv temp.json "$CONFIG_PATH"

        echo -e "\e[32m$(get_localized_text "SERVER_UPDATED" "$SELECTED_SERVER")\e[0m"
        read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
        show_main_menu
    else
        echo -e "\e[31m$(get_localized_text "INVALID_CHOICE"): $CHOICE\e[0m"
        sleep 2
        update_server
        return
    fi
}

# 更新服务器
update_servers() {
    clear
    # 显示服务器列表并让用户选择
    echo -e "\n\e[36m$(get_localized_text "AVAILABLE_SERVERS")\e[0m"
    INDEX=1
    SERVER_NAMES=()

    while read -r SERVER_NAME; do
        SERVER_NAMES+=("$SERVER_NAME")
        APP_ID=$(jq -r ".ServerList.\"$SERVER_NAME\".AppId" "$CONFIG_PATH")
        DESCRIPTION=$(jq -r ".ServerList.\"$SERVER_NAME\".Description" "$CONFIG_PATH")
        echo -e "$INDEX. $SERVER_NAME (AppID: $APP_ID) - $DESCRIPTION"
        INDEX=$((INDEX + 1))
    done < <(jq -r '.ServerList | keys[]' "$CONFIG_PATH")

    if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
        echo -e "\n\e[33m$(get_localized_text "NO_SERVERS_CONFIGURED")\e[0m"
        read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
        show_main_menu
        return
    fi

    echo -e "\e[33m0. $(get_localized_text "UPDATE_ALL_SERVERS")\e[0m"
    echo -e "\e[33mB. $(get_localized_text "RETURN_MAIN_MENU")\e[0m"
    echo -e "\e[33mQ. $(get_localized_text "EXIT_PROGRAM")\e[0m"
    read -r -p "$(get_localized_text "ENTER_SERVER_NUMBER" "更新" "${#SERVER_NAMES[@]}"): " CHOICE

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
        SERVERS_TO_UPDATE=("${SERVER_NAMES[$CHOICE - 1]}")
    else
        echo -e "\e[31m$(get_localized_text "INVALID_CHOICE"): $CHOICE\e[0m"
        sleep 2
        update_servers
        return
    fi

    # 处理选定的服务器
    for SERVER in "${SERVERS_TO_UPDATE[@]}"; do
        echo -e "\n\e[32m$(get_localized_text "PROCESSING_SERVER" "$SERVER")\e[0m"

        APP_ID=$(jq -r ".ServerList.\"$SERVER\".AppId" "$CONFIG_PATH")
        INSTALL_DIR=$(jq -r ".ServerList.\"$SERVER\".ForceInstallDir" "$CONFIG_PATH")
        FULL_INSTALL_DIR="$SCRIPT_DIR/$INSTALL_DIR"
        ANONYMOUS=$(jq -r ".ServerList.\"$SERVER\".Anonymous" "$CONFIG_PATH")

        # 构建SteamCMD脚本
        TEMP_SCRIPT="/tmp/steamcmd_script_$$.txt"
        echo "@ShutdownOnFailedCommand 1" >"$TEMP_SCRIPT"
        echo "@NoPromptForPassword 1" >>"$TEMP_SCRIPT"
        echo "force_install_dir \"$FULL_INSTALL_DIR\"" >>"$TEMP_SCRIPT"

        # 处理登录信息
        if [ "$ANONYMOUS" = "true" ]; then
            echo "login anonymous" >>"$TEMP_SCRIPT"
        else
            read -r -p "$(get_localized_text "ENTER_STEAM_USERNAME"): " USERNAME
            read -r -s -p "$(get_localized_text "ENTER_STEAM_PASSWORD"): " PASSWORD
            echo
            echo "login \"$USERNAME\" \"$PASSWORD\"" >>"$TEMP_SCRIPT"
        fi

        # 添加应用更新命令
        echo "app_update $APP_ID validate" >>"$TEMP_SCRIPT"
        echo "quit" >>"$TEMP_SCRIPT"

        # 执行SteamCMD
        echo -e "\e[33m$(get_localized_text "START_UPDATING_SERVER")\e[0m"
        if [ "$DEBUG_MODE" = true ]; then
            echo -e "\e[33m$(get_localized_text "DEBUG_STEAMCMD_COMMAND")\e[0m"
            cat "$TEMP_SCRIPT"
        fi

        cd "$STEAMCMD_PATH" || exit 1
        if [ "$DEBUG_MODE" = true ]; then
            echo -e "\e[33m$(get_localized_text "DEBUG_STEAMCMD_COMMAND")\e[0m"
            echo -e "\e[37m./steamcmd.sh +runscript $TEMP_SCRIPT\e[0m"
        fi

        if ./steamcmd.sh +runscript "$TEMP_SCRIPT"; then
            echo -e "\e[32m$(get_localized_text "SERVER_UPDATE_SUCCESS")\e[0m"
        else
            echo -e "\e[31m$(get_localized_text "SERVER_UPDATE_ERROR" "$?")\e[0m"
        fi

        # 清理临时脚本
        rm -f "$TEMP_SCRIPT"
    done

    if [ ${#SERVERS_TO_UPDATE[@]} -eq 1 ]; then
        echo -e "\n\e[32m$(get_localized_text "SERVER_UPDATED" "${SERVERS_TO_UPDATE[0]}")\e[0m"
    else
        echo -e "\n\e[32m$(get_localized_text "ALL_SERVERS_UPDATED")\e[0m"
    fi

    read -r -p "$(get_localized_text "PRESS_ENTER_RETURN")"
    show_main_menu
}

# 主程序
main() {
    check_dependencies
    init_config
    load_config
    check_steamcmd
    show_main_menu
}

# 执行主程序
main
