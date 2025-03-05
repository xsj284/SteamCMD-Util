# 游戏服务器管理工具

这是一个基于PowerShell的游戏服务器管理工具，用于自动化管理和更新基于Steam的游戏服务器。

## 功能特点

- 自动下载和安装SteamCMD
- 管理多个游戏服务器
- 支持服务器的批量更新
- 支持匿名和账号登录Steam
- 简单易用的交互式菜单

## 系统要求

- Windows操作系统
- PowerShell 5.0或更高版本
- 互联网连接

## 安装说明

1. 克隆或下载此仓库到本地
2. 确保有足够的磁盘空间用于安装游戏服务器
3. 运行`server_util.ps1`脚本，它会自动下载并安装所需的SteamCMD

## 配置文件

配置文件`server_info.json`用于存储服务器配置信息，结构如下：

```json
{
    "SteamCMD_Path": "SteamCMD",
    "ServerList": {
        "服务器名称": {
            "AppId": "Steam应用ID",
            "Description": "服务器描述",
            "ForceInstallDir": "安装目录",
            "Anonymous": true/false
        }
    }
}
```

### 配置项说明

- `SteamCMD_Path`: SteamCMD的安装路径（相对于脚本目录）
- `ServerList`: 服务器列表，包含多个服务器配置
  - `AppId`: Steam游戏的应用ID
  - `Description`: 服务器的描述信息
  - `ForceInstallDir`: 服务器安装目录（相对于脚本目录）
  - `Anonymous`: 是否使用匿名登录（true/false）

## 使用说明

### 启动工具

运行PowerShell，切换到脚本所在目录，执行：

```powershell
.\server_util.ps1
```

### 主要功能

1. **更新服务器**
   - 选择菜单选项"1"
   - 可以选择更新单个服务器或所有服务器
   - 支持匿名登录和账号登录

2. **添加新服务器**
   - 选择菜单选项"2"
   - 输入服务器名称、Steam AppID、描述和安装目录
   - 选择是否使用匿名登录

3. **修改服务器配置**
   - 选择菜单选项"3"
   - 选择要修改的服务器
   - 可以修改AppID、描述、安装目录和登录方式

4. **删除服务器**
   - 选择菜单选项"4"
   - 选择要删除的服务器
   - 系统会要求确认删除操作
   - 删除操作会同时移除配置信息和服务器文件
   - 注意：此操作不可逆，请确保已备份重要数据

### 使用示例

1. **添加Project Zomboid服务器**
   ```
   服务器名称: PZServer
   Steam AppID: 380870
   描述: Project Zomboid专用服务器
   安装目录: ./PZServer
   匿名登录: Y
   ```

2. **添加Valheim服务器**
   ```
   服务器名称: ValheimServer
   Steam AppID: 896660
   描述: Valheim专用服务器
   安装目录: ./ValheimServer
   匿名登录: Y
   ```

## 注意事项

1. 确保有足够的磁盘空间用于安装游戏服务器
2. 部分游戏服务器可能需要Steam账号登录
3. 首次运行时会自动下载并安装SteamCMD
4. 建议使用相对路径配置安装目录

## 常见问题

1. **SteamCMD下载失败**
   - 检查网络连接
   - 确保有足够的磁盘空间
   - 尝试手动下载并解压到SteamCMD目录

2. **服务器更新失败**
   - 检查Steam账号登录状态
   - 确认AppID是否正确
   - 检查磁盘空间是否充足

## 技术支持

如果遇到问题，请检查以下内容：

1. PowerShell版本是否满足要求
2. 配置文件格式是否正确
3. 网络连接是否正常
4. 磁盘空间是否充足
