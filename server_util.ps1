# 处理命令行参数
$DebugMode = $false
foreach ($arg in $args) {
    switch ($arg) {
        "-debug" { $DebugMode = $true }
    }
}

# 读取配置文件
$configPath = Join-Path $PSScriptRoot "server_info.json"
if (-not (Test-Path $configPath)) {
    Write-Warning "配置文件不存在，正在创建默认配置文件: $configPath"
    # 创建默认配置文件
    $defaultConfig = @{
        SteamCMD_Path = "./SteamCMD"
        Language      = "zh-CN"
        ServerList    = @{}
    }
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
    Write-Host "已创建默认配置文件" -ForegroundColor Green
}

$config = Get-Content $configPath | ConvertFrom-Json

# 读取并解析本地化文件
$localeFilePath = Join-Path $PSScriptRoot "locale.json"
$localeData = Get-Content $localeFilePath -Raw | ConvertFrom-Json
# 从配置中读取语言设置
$CurrentLanguage = if ($config.Language) { $config.Language } else { "zh-CN" }

# 获取本地化文本
function Get-LocalizedText {
    param (
        [string]$Key,
        [string[]]$Params = @()
    )

    # 获取语言列表并找出当前语言的索引
    $langList = $localeData.LanguageList
    $langIndex = $langList.IndexOf($CurrentLanguage)

    # 如果找不到当前语言，默认使用第一个语言
    if ($langIndex -eq -1) {
        $langIndex = 0
    }

    # 获取对应的文本数组并返回对应索引的文本
    $textArray = $localeData.$Key
    $text = $textArray[$langIndex]

    # 替换参数
    for ($i = 0; $i -lt $Params.Length; $i++) {
        $text = $text -replace "\{$i\}", $Params[$i]
    }
    return $text
}

# 保存语言设置到配置文件
function Save-LanguageSetting {
    param (
        [string]$Language
    )

    $config.Language = $Language
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
}

# 语言选择功能
function Select-Language {
    Clear-Host
    Write-Host (Get-LocalizedText "LANGUAGE_SETTINGS") -ForegroundColor Cyan

    # 获取语言列表
    $langList = $localeData.LanguageList
    $langNameList = $localeData.LanguageName

    # 显示所有可用语言
    for ($i = 0; $i -lt $langList.Count; $i++) {
        Write-Host "$($i+1). $($langNameList[$i])"
    }

    $choice = Read-Host (Get-LocalizedText "SELECT_LANGUAGE")

    # 处理用户选择
    if ([int]::TryParse($choice, [ref]$null)) {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $langList.Count) {
            $script:CurrentLanguage = $langList[$index]
            Save-LanguageSetting -Language $langList[$index]
        }
        else {
            # 默认使用第一个语言
            $script:CurrentLanguage = $langList[0]
            Save-LanguageSetting -Language $langList[0]
        }
    }
    else {
        # 默认使用第一个语言
        $script:CurrentLanguage = $langList[0]
        Save-LanguageSetting -Language $langList[0]
    }
}

# 检查 SteamCMD 路径
$steamCmdPath = Join-Path $PSScriptRoot $config.SteamCMD_Path
$steamCmdExe = Join-Path $steamCmdPath "steamcmd.exe"

if (-not (Test-Path $steamCmdExe)) {
    Write-Host (Get-LocalizedText "STEAMCMD_NOT_EXIST") -ForegroundColor Yellow

    # 创建 SteamCMD 目录
    New-Item -ItemType Directory -Force -Path $steamCmdPath | Out-Null

    # 下载 SteamCMD
    $steamCmdZip = Join-Path $steamCmdPath "steamcmd.zip"
    $downloadUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $steamCmdZip

        # 解压 SteamCMD
        Write-Host (Get-LocalizedText "DOWNLOADING_STEAMCMD") -ForegroundColor Yellow
        Expand-Archive -Path $steamCmdZip -DestinationPath $steamCmdPath -Force

        # 清理下载的压缩包
        Remove-Item $steamCmdZip -Force

        Write-Host (Get-LocalizedText "STEAMCMD_INSTALL_COMPLETE") -ForegroundColor Green
    }
    catch {
        Write-Error (Get-LocalizedText "STEAMCMD_DOWNLOAD_ERROR")
        exit 1
    }
}

# 显示主菜单
function Show-MainMenu {
    Clear-Host
    Write-Host "===== $(Get-LocalizedText "GAME_SERVER_TOOL") =====" -ForegroundColor Cyan
    Write-Host "1. $(Get-LocalizedText "UPDATE_SERVER")" -ForegroundColor White
    Write-Host "2. $(Get-LocalizedText "ADD_NEW_SERVER")" -ForegroundColor White
    Write-Host "3. $(Get-LocalizedText "MODIFY_SERVER")" -ForegroundColor White
    Write-Host "4. $(Get-LocalizedText "DELETE_SERVER")" -ForegroundColor White
    Write-Host "5. $(Get-LocalizedText "LANGUAGE_SETTINGS")" -ForegroundColor White
    Write-Host "Q. $(Get-LocalizedText "EXIT")" -ForegroundColor White
    Write-Host "=============================" -ForegroundColor Cyan

    $choice = Read-Host (Get-LocalizedText "SELECT_OPERATION")

    switch ($choice) {
        "1" { Update-Servers }
        "2" { Add-NewServer }
        "3" { Update-Server }
        "4" { Remove-Server }
        "5" { Select-Language; Show-MainMenu }
        "Q" { exit }
        "q" { exit }
        default {
            Write-Host (Get-LocalizedText "INVALID_CHOICE") -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}

# 添加新服务器功能
function Add-NewServer {
    Clear-Host
    Write-Host "===== $(Get-LocalizedText "ADD_NEW_SERVER") =====" -ForegroundColor Cyan

    $serverName = Read-Host (Get-LocalizedText "ENTER_SERVER_NAME")

    # 检查服务器名称是否已存在
    if ($config.ServerList.PSObject.Properties.Name -contains $serverName) {
        Write-Host (Get-LocalizedText "SERVER_NAME_EXISTS" -Params @($serverName)) -ForegroundColor Red
        Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
        Show-MainMenu
        return
    }

    $appId = Read-Host (Get-LocalizedText "ENTER_STEAM_APPID")
    $description = Read-Host (Get-LocalizedText "ENTER_SERVER_DESCRIPTION")
    $installDir = Read-Host (Get-LocalizedText "ENTER_INSTALL_DIR")

    $anonymous = $false
    $anonymousChoice = Read-Host (Get-LocalizedText "USE_ANONYMOUS_LOGIN")
    if ($anonymousChoice -eq "Y" -or $anonymousChoice -eq "y") {
        $anonymous = $true
    }

    # 创建新服务器配置
    $newServer = @{
        AppId           = $appId
        Description     = $description
        ForceInstallDir = $installDir
        Anonymous       = $anonymous
    }

    # 添加到配置
    if (-not $config.ServerList.PSObject.Properties) {
        # 如果 ServerList 为空，创建一个新的
        $config.ServerList = New-Object PSObject
    }

    # 添加新服务器
    $config.ServerList | Add-Member -MemberType NoteProperty -Name $serverName -Value $newServer

    # 保存配置
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath

    Write-Host (Get-LocalizedText "SERVER_ADDED" -Params @($serverName)) -ForegroundColor Green
    Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
    Show-MainMenu
}

# 删除服务器功能
function Remove-Server {
    Clear-Host
    # 显示服务器列表并让用户选择
    $serverList = @()
    $index = 1
    Write-Host "`n$(Get-LocalizedText "AVAILABLE_SERVERS")" -ForegroundColor Cyan
    foreach ($server in $config.ServerList.PSObject.Properties) {
        $serverName = $server.Name
        $serverConfig = $server.Value
        $serverList += [PSCustomObject]@{
            Index  = $index
            Name   = $serverName
            Config = $serverConfig
        }
        $description = if ($serverConfig.Description) { " - $($serverConfig.Description)" } else { "" }
        Write-Host "$index. $serverName (AppID: $($serverConfig.AppId))$description" -ForegroundColor White
        $index++
    }

    if ($serverList.Count -eq 0) {
        Write-Host "`n$(Get-LocalizedText "NO_SERVERS_CONFIGURED")" -ForegroundColor Yellow
        Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
        Show-MainMenu
        return
    }

    Write-Host "B. $(Get-LocalizedText "RETURN_MAIN_MENU")" -ForegroundColor Yellow
    Write-Host "Q. $(Get-LocalizedText "EXIT_PROGRAM")" -ForegroundColor Yellow
    $choice = Read-Host "`n$(Get-LocalizedText "ENTER_SERVER_NUMBER" -Params @("删除", $serverList.Count))"

    if ($choice -eq "B" -or $choice -eq "b") {
        Show-MainMenu
        return
    }

    if ($choice -eq "Q" -or $choice -eq "q") {
        exit
    }

    # 处理用户选择
    if ([int]$choice -ge 1 -and [int]$choice -le $serverList.Count) {
        $selectedServer = $serverList[[int]$choice - 1]
        $serverName = $selectedServer.Name
        $serverConfig = $selectedServer.Config
        $installDir = Join-Path $PSScriptRoot $serverConfig.ForceInstallDir

        Clear-Host
        Write-Host "===== $(Get-LocalizedText "DELETE_SERVER"): $serverName =====" -ForegroundColor Cyan
        Write-Host "$(Get-LocalizedText "CURRENT_CONFIG"):" -ForegroundColor Yellow
        Write-Host "AppID: $($serverConfig.AppId)" -ForegroundColor White
        Write-Host "$(Get-LocalizedText "ENTER_SERVER_DESCRIPTION"): $($serverConfig.Description)" -ForegroundColor White
        Write-Host "$(Get-LocalizedText "ENTER_INSTALL_DIR"): $($serverConfig.ForceInstallDir)" -ForegroundColor White
        Write-Host "$(Get-LocalizedText "ENTER_INSTALL_DIR"): $installDir" -ForegroundColor White
        Write-Host "=============================" -ForegroundColor Cyan

        # 显示风险警告
        Write-Host "`n$(Get-LocalizedText "WARNING")" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "$(Get-LocalizedText "DELETE_SERVER_WARNING")" -ForegroundColor Red
        Write-Host "$(Get-LocalizedText "REMOVE_SERVER_INFO")" -ForegroundColor Red
        Write-Host "$(Get-LocalizedText "DELETE_SERVER_DIR")" -ForegroundColor Red
        Write-Host "$(Get-LocalizedText "OPERATION_IRREVERSIBLE")" -ForegroundColor Red

        # 要求用户确认
        $confirmation = Read-Host "`n$(Get-LocalizedText "ENTER_SERVER_NAME_CONFIRM" -Params @($serverName))"

        if ($confirmation -eq $serverName) {
            # 删除安装目录
            if (Test-Path $installDir) {
                Write-Host "`n$(Get-LocalizedText "DELETING_INSTALL_DIR" -Params @($installDir))" -ForegroundColor Yellow
                try {
                    Remove-Item -Path $installDir -Recurse -Force
                    Write-Host "$(Get-LocalizedText "INSTALL_DIR_DELETED")" -ForegroundColor Green
                }
                catch {
                    Write-Host "$(Get-LocalizedText "ERROR_DELETING_DIR")" -ForegroundColor Red
                }
            }
            else {
                Write-Host "`n$(Get-LocalizedText "INSTALL_DIR_NOT_EXIST" -Params @($installDir))" -ForegroundColor Yellow
            }

            # 从配置中移除服务器
            $config.PSObject.Properties.Remove($serverName)
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath

            Write-Host "`n$(Get-LocalizedText "SERVER_DELETED" -Params @($serverName))" -ForegroundColor Green
        }
        else {
            Write-Host "`n$(Get-LocalizedText "DELETE_CANCELED")" -ForegroundColor Yellow
        }

        Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
        Show-MainMenu
    }
    else {
        Write-Host (Get-LocalizedText "INVALID_CHOICE") -ForegroundColor Red
        Start-Sleep -Seconds 2
        Remove-Server
        return
    }
}

# 修改服务器功能
function Update-Server {
    Clear-Host
    # 显示服务器列表并让用户选择
    $serverList = @()
    $index = 1
    Write-Host "`n$(Get-LocalizedText "AVAILABLE_SERVERS")" -ForegroundColor Cyan
    foreach ($server in $config.ServerList.PSObject.Properties) {
        $serverName = $server.Name
        $serverConfig = $server.Value
        $serverList += [PSCustomObject]@{
            Index  = $index
            Name   = $serverName
            Config = $serverConfig
        }
        $description = if ($serverConfig.Description) { " - $($serverConfig.Description)" } else { "" }
        Write-Host "$index. $serverName (AppID: $($serverConfig.AppId))$description" -ForegroundColor White
        $index++
    }

    if ($serverList.Count -eq 0) {
        Write-Host "`n$(Get-LocalizedText "NO_SERVERS_CONFIGURED")" -ForegroundColor Yellow
        Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
        Show-MainMenu
        return
    }

    Write-Host "B. $(Get-LocalizedText "RETURN_MAIN_MENU")" -ForegroundColor Yellow
    Write-Host "Q. $(Get-LocalizedText "EXIT_PROGRAM")" -ForegroundColor Yellow
    $choice = Read-Host "`n$(Get-LocalizedText "ENTER_SERVER_NUMBER" -Params @("修改", $serverList.Count))"

    if ($choice -eq "B" -or $choice -eq "b") {
        Show-MainMenu
        return
    }

    if ($choice -eq "Q" -or $choice -eq "q") {
        exit
    }

    # 处理用户选择
    if ([int]$choice -ge 1 -and [int]$choice -le $serverList.Count) {
        $selectedServer = $serverList[[int]$choice - 1]
        $serverName = $selectedServer.Name
        $serverConfig = $selectedServer.Config

        Clear-Host
        Write-Host "===== $(Get-LocalizedText "MODIFY_SERVER"): $serverName =====" -ForegroundColor Cyan
        Write-Host "$(Get-LocalizedText "CURRENT_CONFIG"):" -ForegroundColor Yellow
        Write-Host "AppID: $($serverConfig.AppId)" -ForegroundColor White
        Write-Host "$(Get-LocalizedText "ENTER_SERVER_DESCRIPTION"): $($serverConfig.Description)" -ForegroundColor White
        Write-Host "$(Get-LocalizedText "ENTER_INSTALL_DIR"): $($serverConfig.ForceInstallDir)" -ForegroundColor White
        Write-Host "$(Get-LocalizedText "USE_ANONYMOUS_LOGIN"): $($serverConfig.Anonymous)" -ForegroundColor White
        Write-Host "=============================" -ForegroundColor Cyan

        # 修改服务器名称
        $newServerName = Read-Host (Get-LocalizedText "ENTER_NEW_SERVER_NAME")
        if (-not [string]::IsNullOrWhiteSpace($newServerName)) {
            # 检查新名称是否已存在
            if ($newServerName -ne $serverName -and $config.ServerList.PSObject.Properties.Name -contains $newServerName) {
                Write-Host (Get-LocalizedText "SERVER_NAME_EXISTS" -Params @($newServerName)) -ForegroundColor Red
                Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
                Show-MainMenu
                return
            }
        }

        # 修改其他配置
        $newAppId = Read-Host (Get-LocalizedText "ENTER_NEW_APPID")
        $newDescription = Read-Host (Get-LocalizedText "ENTER_NEW_DESCRIPTION")
        $newInstallDir = Read-Host (Get-LocalizedText "ENTER_NEW_INSTALL_DIR")
        $changeLoginMethod = Read-Host (Get-LocalizedText "CHANGE_LOGIN_METHOD")

        # 创建新的配置对象
        $updatedServer = @{
            AppId           = if (-not [string]::IsNullOrWhiteSpace($newAppId)) { $newAppId } else { $serverConfig.AppId }
            Description     = if (-not [string]::IsNullOrWhiteSpace($newDescription)) { $newDescription } else { $serverConfig.Description }
            ForceInstallDir = if (-not [string]::IsNullOrWhiteSpace($newInstallDir)) { $newInstallDir } else { $serverConfig.ForceInstallDir }
            Anonymous       = $serverConfig.Anonymous
        }

        # 处理登录方式变更
        if ($changeLoginMethod -eq "Y" -or $changeLoginMethod -eq "y") {
            $updatedServer.Anonymous = -not $serverConfig.Anonymous
        }

        # 保存修改后的配置
        if ([string]::IsNullOrWhiteSpace($newServerName) -or $newServerName -eq $serverName) {
            # 更新现有服务器
            $config.ServerList.PSObject.Properties.Remove($serverName)
            $config.ServerList | Add-Member -MemberType NoteProperty -Name $serverName -Value $updatedServer
        }
        else {
            # 创建新服务器并删除旧的
            $config.ServerList.PSObject.Properties.Remove($serverName)
            $config.ServerList | Add-Member -MemberType NoteProperty -Name $newServerName -Value $updatedServer
        }

        # 保存到配置文件
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath

        Write-Host (Get-LocalizedText "SERVER_UPDATED" -Params @($serverName)) -ForegroundColor Green
        Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
        Show-MainMenu
    }
    else {
        Write-Host (Get-LocalizedText "INVALID_CHOICE") -ForegroundColor Red
        Start-Sleep -Seconds 2
        Update-Server
        return
    }
}

# 更新服务器功能
function Update-Servers {
    Clear-Host
    # 显示服务器列表并让用户选择
    $serverList = @()
    $index = 1
    Write-Host "`n$(Get-LocalizedText "AVAILABLE_SERVERS")" -ForegroundColor Cyan
    foreach ($server in $config.ServerList.PSObject.Properties) {
        $serverName = $server.Name
        $serverConfig = $server.Value
        $serverList += [PSCustomObject]@{
            Index  = $index
            Name   = $serverName
            Config = $serverConfig
        }
        $description = if ($serverConfig.Description) { " - $($serverConfig.Description)" } else { "" }
        Write-Host "$index. $serverName (AppID: $($serverConfig.AppId))$description" -ForegroundColor White
        $index++
    }

    if ($serverList.Count -eq 0) {
        Write-Host "`n$(Get-LocalizedText "NO_SERVERS_CONFIGURED")" -ForegroundColor Yellow
        Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
        Show-MainMenu
        return
    }

    Write-Host "0. $(Get-LocalizedText "UPDATE_ALL_SERVERS")" -ForegroundColor Yellow
    Write-Host "B. $(Get-LocalizedText "RETURN_MAIN_MENU")" -ForegroundColor Yellow
    Write-Host "Q. $(Get-LocalizedText "EXIT_PROGRAM")" -ForegroundColor Yellow
    $choice = Read-Host "`n$(Get-LocalizedText "ENTER_SERVER_NUMBER" -Params @("更新", $serverList.Count))"

    if ($choice -eq "B" -or $choice -eq "b") {
        Show-MainMenu
        return
    }

    if ($choice -eq "Q" -or $choice -eq "q") {
        exit
    }

    # 处理用户选择
    $serversToUpdate = @()
    if ($choice -eq "0") {
        $serversToUpdate = $serverList
    }
    elseif ([int]$choice -ge 1 -and [int]$choice -le $serverList.Count) {
        $serversToUpdate = @($serverList[[int]$choice - 1])
    }
    else {
        Write-Host (Get-LocalizedText "INVALID_CHOICE") -ForegroundColor Red
        Start-Sleep -Seconds 2
        Update-Servers
        return
    }

    # 处理选定的服务器
    foreach ($server in $serversToUpdate) {
        $serverName = $server.Name
        $serverConfig = $server.Config

        Write-Host "`n$(Get-LocalizedText "PROCESSING_SERVER" -Params @($serverName))" -ForegroundColor Green

        # 构建 SteamCMD 参数
        $steamCmdArgs = @("+force_install_dir `"$(Join-Path $PSScriptRoot $serverConfig.ForceInstallDir)`"")

        # 处理登录信息
        if ($serverConfig.Anonymous) {
            $steamCmdArgs += "+login anonymous"
        }
        else {
            if ([string]::IsNullOrEmpty($serverConfig.Username)) {
                $username = Read-Host (Get-LocalizedText "ENTER_STEAM_USERNAME")
                $password = Read-Host (Get-LocalizedText "ENTER_STEAM_PASSWORD") -AsSecureString
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
                $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                $steamCmdArgs += "+login `"$username`" `"$plainPassword`""
            }
            else {
                $steamCmdArgs += "+login `"$($serverConfig.Username)`""
            }
        }

        # 添加应用更新命令
        $steamCmdArgs += "+app_update $($serverConfig.AppId) validate"
        $steamCmdArgs += "+quit"

        # 执行 SteamCMD
        Write-Host (Get-LocalizedText "START_UPDATING_SERVER") -ForegroundColor Yellow
        try {
            $steamCmdArgs = $steamCmdArgs -join " "
            if ($DebugMode) {
                Write-Host (Get-LocalizedText "DEBUG_STEAMCMD_COMMAND") -ForegroundColor Yellow
                Write-Host "$steamCmdExe $steamCmdArgs" -ForegroundColor Gray
            }
            $process = Start-Process -FilePath $steamCmdExe -ArgumentList $steamCmdArgs -NoNewWindow -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Write-Host (Get-LocalizedText "SERVER_UPDATE_SUCCESS") -ForegroundColor Green
            }
            else {
                Write-Host (Get-LocalizedText "SERVER_UPDATE_ERROR" -Params @($process.ExitCode)) -ForegroundColor Red
            }
        }
        catch {
            Write-Error "执行 SteamCMD 时发生错误: $_"
        }
    }

    if ($serversToUpdate.Count -eq 1) {
        Write-Host "`n$(Get-LocalizedText "SERVER_UPDATED" -Params @($serversToUpdate[0].Name))" -ForegroundColor Green
    }
    else {
        Write-Host "`n$(Get-LocalizedText "ALL_SERVERS_UPDATED")" -ForegroundColor Green
    }

    Read-Host (Get-LocalizedText "PRESS_ENTER_RETURN")
    Show-MainMenu
}

# 启动主菜单
Show-MainMenu
