# 读取配置文件
$configPath = Join-Path $PSScriptRoot "server_info.json"
if (-not (Test-Path $configPath)) {
    Write-Warning "配置文件不存在，正在创建默认配置文件: $configPath"
    # 创建默认配置文件
    $defaultConfig = @{
        SteamCMD_Path = "./SteamCMD"
        ServerList    = @{}
    }
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
    Write-Host "已创建默认配置文件" -ForegroundColor Green
}

$config = Get-Content $configPath | ConvertFrom-Json

# 检查 SteamCMD 路径
$steamCmdPath = Join-Path $PSScriptRoot $config.SteamCMD_Path
$steamCmdExe = Join-Path $steamCmdPath "steamcmd.exe"

if (-not (Test-Path $steamCmdExe)) {
    Write-Host "SteamCMD 不存在，正在自动下载..." -ForegroundColor Yellow

    # 创建 SteamCMD 目录
    New-Item -ItemType Directory -Force -Path $steamCmdPath | Out-Null

    # 下载 SteamCMD
    $steamCmdZip = Join-Path $steamCmdPath "steamcmd.zip"
    $downloadUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $steamCmdZip

        # 解压 SteamCMD
        Write-Host "正在解压 SteamCMD..." -ForegroundColor Yellow
        Expand-Archive -Path $steamCmdZip -DestinationPath $steamCmdPath -Force

        # 清理下载的压缩包
        Remove-Item $steamCmdZip -Force

        Write-Host "SteamCMD 安装完成！" -ForegroundColor Green
    }
    catch {
        Write-Error "下载或解压 SteamCMD 时发生错误: $_"
        exit 1
    }
}

# 显示主菜单
function Show-MainMenu {
    Clear-Host
    Write-Host "===== 游戏服务器管理工具 =====" -ForegroundColor Cyan
    Write-Host "1. 更新服务器" -ForegroundColor White
    Write-Host "2. 添加新服务器" -ForegroundColor White
    Write-Host "3. 修改服务器" -ForegroundColor White
    Write-Host "4. 删除服务器" -ForegroundColor White
    Write-Host "Q. 退出" -ForegroundColor White
    Write-Host "=============================" -ForegroundColor Cyan

    $choice = Read-Host "请选择操作"

    switch ($choice) {
        "1" { Update-Servers }
        "2" { Add-NewServer }
        "3" { Update-Server }
        "4" { Remove-Server }
        "Q" { exit }
        "q" { exit }
        default {
            Write-Host "无效的选择，请重试" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}

# 添加新服务器功能
function Add-NewServer {
    Clear-Host
    Write-Host "===== 添加新服务器 =====" -ForegroundColor Cyan

    $serverName = Read-Host "请输入服务器名称 (例如: PZServer)"

    # 检查服务器名称是否已存在
    if ($config.ServerList.PSObject.Properties.Name -contains $serverName) {
        Write-Host "错误: 服务器名称 '$serverName' 已存在!" -ForegroundColor Red
        Read-Host "按任意键返回主菜单"
        Show-MainMenu
        return
    }

    $appId = Read-Host "请输入 Steam AppID"
    $description = Read-Host "请输入服务器描述"
    $installDir = Read-Host "请输入安装目录 (相对于脚本目录，例如: ./PZServer)"

    $anonymous = $false
    $anonymousChoice = Read-Host "是否使用匿名登录? (Y/N)"
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

    Write-Host "服务器 '$serverName' 已成功添加!" -ForegroundColor Green
    Read-Host "按任意键返回主菜单"
    Show-MainMenu
}

# 删除服务器功能
function Remove-Server {
    Clear-Host
    # 显示服务器列表并让用户选择
    $serverList = @()
    $index = 1
    Write-Host "`n可用的服务器列表:" -ForegroundColor Cyan
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
        Write-Host "`n当前没有配置任何服务器" -ForegroundColor Yellow
        Read-Host "按任意键返回主菜单"
        Show-MainMenu
        return
    }

    Write-Host "B. 返回主菜单" -ForegroundColor Yellow
    Write-Host "Q. 退出程序" -ForegroundColor Yellow
    $choice = Read-Host "`n请输入要删除的服务器编号 (1-$($serverList.Count), B 返回, Q 退出)"

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
        Write-Host "===== 删除服务器: $serverName =====" -ForegroundColor Cyan
        Write-Host "当前配置:" -ForegroundColor Yellow
        Write-Host "AppID: $($serverConfig.AppId)" -ForegroundColor White
        Write-Host "描述: $($serverConfig.Description)" -ForegroundColor White
        Write-Host "安装目录: $($serverConfig.ForceInstallDir)" -ForegroundColor White
        Write-Host "安装路径: $installDir" -ForegroundColor White
        Write-Host "=============================" -ForegroundColor Cyan

        # 显示风险警告
        Write-Host "`n警告!" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "删除服务器将会:" -ForegroundColor Red
        Write-Host "1. 从配置文件中移除服务器信息" -ForegroundColor Red
        Write-Host "2. 永久删除服务器安装目录及其中的所有文件" -ForegroundColor Red
        Write-Host "此操作不可逆，请确保您已备份重要数据!" -ForegroundColor Red

        # 要求用户确认
        $confirmation = Read-Host "`n请输入服务器名称 '$serverName' 以确认删除，或输入任意其他内容取消"

        if ($confirmation -eq $serverName) {
            # 删除安装目录
            if (Test-Path $installDir) {
                Write-Host "`n正在删除安装目录: $installDir" -ForegroundColor Yellow
                try {
                    Remove-Item -Path $installDir -Recurse -Force -ErrorAction Stop
                    Write-Host "安装目录已成功删除" -ForegroundColor Green
                }
                catch {
                    Write-Host "删除安装目录时出错: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "`n安装目录不存在: $installDir" -ForegroundColor Yellow
            }

            # 从配置中移除服务器
            $newServerList = New-Object PSObject
            foreach ($server in $config.ServerList.PSObject.Properties) {
                if ($server.Name -ne $serverName) {
                    $newServerList | Add-Member -MemberType NoteProperty -Name $server.Name -Value $server.Value
                }
            }
            $config.ServerList = $newServerList

            # 保存配置
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath

            Write-Host "`n服务器 '$serverName' 已成功删除!" -ForegroundColor Green
        }
        else {
            Write-Host "`n删除操作已取消" -ForegroundColor Yellow
        }

        Read-Host "按任意键返回主菜单"
        Show-MainMenu
    }
    else {
        Write-Error "无效的选择: $choice"
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
    Write-Host "`n可用的服务器列表:" -ForegroundColor Cyan
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

    Write-Host "B. 返回主菜单" -ForegroundColor Yellow
    Write-Host "Q. 退出程序" -ForegroundColor Yellow
    $choice = Read-Host "`n请输入要修改的服务器编号 (1-$($serverList.Count), B 返回, Q 退出)"

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
        Write-Host "===== 修改服务器: $serverName =====" -ForegroundColor Cyan
        Write-Host "当前配置:" -ForegroundColor Yellow
        Write-Host "AppID: $($serverConfig.AppId)" -ForegroundColor White
        Write-Host "描述: $($serverConfig.Description)" -ForegroundColor White
        Write-Host "安装目录: $($serverConfig.ForceInstallDir)" -ForegroundColor White
        Write-Host "匿名登录: $($serverConfig.Anonymous)" -ForegroundColor White
        Write-Host "=============================" -ForegroundColor Cyan

        # 修改 AppID
        $newAppId = Read-Host "请输入新的 Steam AppID (留空保持不变)"
        if (-not [string]::IsNullOrWhiteSpace($newAppId)) {
            $serverConfig.AppId = $newAppId
        }

        # 修改描述
        $newDescription = Read-Host "请输入新的服务器描述 (留空保持不变)"
        if (-not [string]::IsNullOrWhiteSpace($newDescription)) {
            $serverConfig.Description = $newDescription
        }

        # 修改安装目录
        $newInstallDir = Read-Host "请输入新的安装目录 (留空保持不变)"
        if (-not [string]::IsNullOrWhiteSpace($newInstallDir)) {
            $serverConfig.ForceInstallDir = $newInstallDir
        }

        # 修改登录方式
        $changeLoginMethod = Read-Host "是否修改登录方式? (Y/N)"
        if ($changeLoginMethod -eq "Y" -or $changeLoginMethod -eq "y") {
            $anonymousChoice = Read-Host "是否使用匿名登录? (Y/N)"
            $serverConfig.Anonymous = ($anonymousChoice -eq "Y" -or $anonymousChoice -eq "y")
        }

        # 保存配置
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath

        Write-Host "服务器 '$serverName' 已成功修改!" -ForegroundColor Green
        Read-Host "按任意键返回主菜单"
        Show-MainMenu
    }
    else {
        Write-Error "无效的选择: $choice"
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
    Write-Host "`n可用的服务器列表:" -ForegroundColor Cyan
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

    Write-Host "0. 更新所有服务器" -ForegroundColor Yellow
    Write-Host "B. 返回主菜单" -ForegroundColor Yellow
    Write-Host "Q. 退出程序" -ForegroundColor Yellow
    $choice = Read-Host "`n请输入要更新的服务器编号 (0-$($serverList.Count), B 返回, Q 退出)"

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
        Write-Error "无效的选择: $choice"
        Start-Sleep -Seconds 2
        Update-Servers
        return
    }

    # 处理选定的服务器
    foreach ($server in $serversToUpdate) {
        $serverName = $server.Name
        $serverConfig = $server.Config

        Write-Host "`n正在处理服务器: $serverName" -ForegroundColor Green

        # 构建 SteamCMD 参数
        $steamCmdArgs = @("+force_install_dir `"$(Join-Path $PSScriptRoot $serverConfig.ForceInstallDir)`"")

        # 处理登录信息
        if ($serverConfig.Anonymous) {
            $steamCmdArgs += "+login anonymous"
        }
        else {
            if ([string]::IsNullOrEmpty($serverConfig.Username)) {
                $username = Read-Host "请输入 Steam 用户名"
                $password = Read-Host "请输入 Steam 密码" -AsSecureString
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
        Write-Host "开始更新服务器..." -ForegroundColor Yellow
        try {
            $process = Start-Process -FilePath $steamCmdExe -ArgumentList $steamCmdArgs -NoNewWindow -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Write-Host "服务器更新成功完成！" -ForegroundColor Green
            }
            else {
                Write-Host "服务器更新过程中出现错误，退出代码: $($process.ExitCode)" -ForegroundColor Red
            }
        }
        catch {
            Write-Error "执行 SteamCMD 时发生错误: $_"
        }
    }

    if ($serversToUpdate.Count -eq 1) {
        Write-Host "`n服务器 '$($serversToUpdate[0].Name)' 更新完成！" -ForegroundColor Green
    }
    else {
        Write-Host "`n所有选定的服务器更新完成！" -ForegroundColor Green
    }

    Read-Host "按任意键返回主菜单"
    Show-MainMenu
}

# 启动主菜单
Show-MainMenu
