# Steam Game Server Management Tool

[简体中文](README_CN.md) | English

A tool for managing and updating Steam-based game servers, supporting both Windows (PowerShell) and Linux (Bash) environments.

## Features

* Automatic download and installation of SteamCMD
* Management of multiple game servers
* Batch server updates
* Support for anonymous and account-based Steam login
* User-friendly interactive menu
* Debug mode support
* Multi-language support (English, Simplified Chinese)

## System Requirements

### Windows Version

* Windows operating system
* PowerShell 5.0 or higher
* Internet connection

### Linux Version

* Linux operating system
* Bash shell
* `jq` command-line tool (for JSON processing)
* Internet connection

## Installation

1. Clone or download this repository to your local machine
2. Ensure you have sufficient disk space for game server installation
3. Run the appropriate script for your operating system:
    * Windows: `server_util.ps1`
    * Linux: `server_util.sh`

The script will automatically download and install the required SteamCMD.

## Configuration File

The configuration file `server_info.json` is used to store server configuration information with the following structure:

```json
{
    "SteamCMD_Path": "SteamCMD",
    "Language": "en-US",
    "ServerList": {
        "ServerName": {
            "AppId": "SteamAppID",
            "Description": "Server Description",
            "ForceInstallDir": "Installation Directory",
            "Anonymous": true/false
        }
    }
}
```

### Configuration Options

* `SteamCMD_Path`: SteamCMD installation path (relative to the script directory)
* `Language`: Interface language (en-US for English, zh-CN for Simplified Chinese)
* `ServerList`: List of servers, containing multiple server configurations
  * `AppId`: Steam game application ID
  * `Description`: Server description
  * `ForceInstallDir`: Server installation directory (relative to the script directory)
  * `Anonymous`: Whether to use anonymous login (true/false)

## Usage Instructions

### Starting the Tool

#### Windows

```powershell
.\server_util.ps1 [-debug]
```

#### Linux

```bash
./server_util.sh [-debug]
```

Use the `-debug` parameter to enable debug mode, which displays the full SteamCMD commands.

### Main Functions

1. **Update Server**
    * Select menu option "1"
    * Choose to update a single server or all servers
    * Supports anonymous and account logins
    * Debug mode shows the complete SteamCMD command

2. **Add New Server**
    * Select menu option "2"
    * Enter server name, Steam AppID, description, and installation directory
    * Choose whether to use anonymous login
    * Automatically checks for duplicate server names

3. **Modify Server Configuration**
    * Select menu option "3"
    * Choose the server to modify
    * You can modify:
        * Server name
        * AppID
        * Description
        * Installation directory
        * Login method
    * All fields can remain unchanged if desired
    * Automatically checks if the new server name conflicts with existing ones

4. **Delete Server**
    * Select menu option "4"
    * Select the server to delete
    * The system will ask you to confirm the deletion
    * Option to simultaneously delete server files
    * Note: This operation is irreversible, please ensure important data is backed up

5. **Language Settings**
    * Select menu option "5" (on the main menu)
    * Choose your preferred language
    * Currently supports English and Simplified Chinese
    * Settings are saved and applied immediately

### Usage Examples

1. **Adding a Project Zomboid Server**

    ```text
    Server Name: PZServer
    Steam AppID: 380870
    Description: Project Zomboid Dedicated Server
    Installation Directory: ./PZServer
    Anonymous Login: Y
    ```

2. **Adding a Valheim Server**

    ```text
    Server Name: ValheimServer
    Steam AppID: 896660
    Description: Valheim Dedicated Server
    Installation Directory: ./ValheimServer
    Anonymous Login: Y
    ```

## Debug Mode

Use the `-debug` parameter when starting the script to enable debug mode, which will:

* Display the complete SteamCMD command line
* Help troubleshoot update failures
* Verify command parameters are correct

Example:

```bash
./server_util.sh -debug
```

## Important Notes

1. Ensure you have sufficient disk space for game server installation
2. Some game servers may require a Steam account login
3. SteamCMD will be automatically downloaded and installed on first run
4. It is recommended to use relative paths for installation directories
5. The Linux version requires the `jq` tool to be installed
6. When modifying server names, the system automatically checks for duplicates

## Common Issues

1. **SteamCMD Download Failure**
    * Check your network connection
    * Ensure you have sufficient disk space
    * Try manually downloading and extracting to the SteamCMD directory

2. **Server Update Failure**
    * Use the `-debug` parameter to check the complete command
    * Check Steam account login status
    * Verify the AppID is correct
    * Check if disk space is sufficient

3. **Missing jq in Linux**
    * Debian/Ubuntu: `sudo apt-get install jq`
    * CentOS/RHEL: `sudo yum install jq`
    * Fedora: `sudo dnf install jq`
    * Arch Linux: `sudo pacman -S jq`

## Technical Support

If you encounter issues, please check the following:

1. Confirm system requirements are met
2. Check if the configuration file format is correct
3. Verify network connection is normal
4. Validate sufficient disk space
5. Use debug mode to check if commands are correct
