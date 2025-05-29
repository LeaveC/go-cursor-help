# 设置输出编码为 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 颜色定义
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$NC = "`e[0m"

# 配置文件路径
$STORAGE_FILE = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
$BACKUP_DIR = "$env:APPDATA\Cursor\User\globalStorage\backups"

# 检查管理员权限
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "$RED[错误]$NC 请以管理员身份运行此脚本"
    Write-Host "请右键点击脚本，选择'以管理员身份运行'"
    exit 1
}

# 显示 Logo
Clear-Host
Write-Host @"

    ██████╗██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗ 
   ██╔════╝██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗
   ██║     ██║   ██║██████╔╝███████╗██║   ██║██████╔╝
   ██║     ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗
   ╚██████╗╚██████╔╝██║  ██║███████║╚██████╔╝██║  ██║
    ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝

"@
Write-Host "$BLUE================================$NC"
Write-Host "$GREEN   Cursor 设备ID 修改工具 (全自动版)    $NC"
Write-Host "$BLUE================================$NC"
Write-Host ""

# 获取并显示 Cursor 版本
function Get-CursorVersion {
    try {
        # 主要检测路径
        $packagePath = "$env:LOCALAPPDATA\Programs\cursor\resources\app\package.json"
        
        if (Test-Path $packagePath) {
            $packageJson = Get-Content $packagePath -Raw | ConvertFrom-Json
            if ($packageJson.version) {
                Write-Host "$GREEN[信息]$NC 当前安装的 Cursor 版本: v$($packageJson.version)"
                return $packageJson.version
            }
        }

        # 备用路径检测
        $altPath = "$env:LOCALAPPDATA\cursor\resources\app\package.json"
        if (Test-Path $altPath) {
            $packageJson = Get-Content $altPath -Raw | ConvertFrom-Json
            if ($packageJson.version) {
                Write-Host "$GREEN[信息]$NC 当前安装的 Cursor 版本: v$($packageJson.version)"
                return $packageJson.version
            }
        }

        Write-Host "$YELLOW[警告]$NC 无法检测到 Cursor 版本"
        Write-Host "$YELLOW[提示]$NC 请确保 Cursor 已正确安装"
        return $null
    }
    catch {
        Write-Host "$RED[错误]$NC 获取 Cursor 版本失败: $_"
        return $null
    }
}

# 获取并显示版本信息
$cursorVersion = Get-CursorVersion
Write-Host ""

# 检查并关闭 Cursor 进程
Write-Host "$GREEN[信息]$NC 检查并关闭 Cursor 进程..."

# 定义最大重试次数和等待时间
$MAX_RETRIES = 3
$WAIT_TIME = 1

# 处理进程关闭
function Close-CursorProcess {
    param($processName)
    
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "$YELLOW[警告]$NC 发现 $processName 正在运行，正在关闭..."
        try {
            Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
            
            $retryCount = 0
            while ($retryCount -lt $MAX_RETRIES) {
                Start-Sleep -Seconds $WAIT_TIME
                $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if (-not $process) { 
                    Write-Host "$GREEN[信息]$NC $processName 已成功关闭"
                    break 
                }
                
                $retryCount++
                if ($retryCount -ge $MAX_RETRIES) {
                    Write-Host "$RED[错误]$NC 无法关闭 $processName 进程，请手动关闭后重新运行此脚本"
                    exit 1
                }
                Write-Host "$YELLOW[警告]$NC 等待进程关闭，尝试 $retryCount/$MAX_RETRIES..."
            }
        }
        catch {
            Write-Host "$YELLOW[警告]$NC 关闭进程时出现问题，但将继续执行..."
        }
    }
}

# 关闭所有 Cursor 进程
Close-CursorProcess "Cursor"
Close-CursorProcess "cursor"

# 创建备份目录
if (-not (Test-Path $BACKUP_DIR)) {
    try {
        New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
        Write-Host "$GREEN[信息]$NC 创建备份目录成功"
    }
    catch {
        Write-Host "$YELLOW[警告]$NC 创建备份目录失败，但将继续执行..."
    }
}

# 备份现有配置
if (Test-Path $STORAGE_FILE) {
    try {
        Write-Host "$GREEN[信息]$NC 正在备份配置文件..."
        $backupName = "storage.json.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $STORAGE_FILE "$BACKUP_DIR\$backupName" -Force
        Write-Host "$GREEN[信息]$NC 配置文件备份完成"
    }
    catch {
        Write-Host "$YELLOW[警告]$NC 备份配置文件失败，但将继续执行..."
    }
}

# 生成新的 ID
Write-Host "$GREEN[信息]$NC 正在生成新的设备ID..."

# 生成随机十六进制函数
function Get-RandomHex {
    param([int]$length)
    $bytes = New-Object byte[] $length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $hexString = [System.BitConverter]::ToString($bytes) -replace '-',''
    $rng.Dispose()
    return $hexString
}

# 生成标准机器ID函数
function New-StandardMachineId {
    $template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    $result = $template -replace '[xy]', {
        param($match)
        $r = [Random]::new().Next(16)
        $v = if ($match.Value -eq "x") { $r } else { ($r -band 0x3) -bor 0x8 }
        return $v.ToString("x")
    }
    return $result
}

# 生成新的ID
$MAC_MACHINE_ID = New-StandardMachineId
$UUID = [System.Guid]::NewGuid().ToString()
$prefixBytes = [System.Text.Encoding]::UTF8.GetBytes("auth0|user_")
$prefixHex = -join ($prefixBytes | ForEach-Object { '{0:x2}' -f $_ })
$randomPart = Get-RandomHex -length 32
$MACHINE_ID = "$prefixHex$randomPart"
$SQM_ID = "{$([System.Guid]::NewGuid().ToString().ToUpper())}"

# 更新注册表机器GUID函数
function Update-MachineGuid {
    try {
        Write-Host "$GREEN[信息]$NC 正在更新系统机器GUID..."
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Cryptography"
        
        # 检查并创建注册表路径
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        # 备份当前值
        $originalGuid = ""
        try {
            $currentGuid = Get-ItemProperty -Path $registryPath -Name MachineGuid -ErrorAction SilentlyContinue
            if ($currentGuid) {
                $originalGuid = $currentGuid.MachineGuid
            }
        } catch {
            # 忽略读取错误
        }

        # 生成并设置新GUID
        $newGuid = [System.Guid]::NewGuid().ToString()
        Set-ItemProperty -Path $registryPath -Name MachineGuid -Value $newGuid -Force
        
        # 验证更新
        $verifyGuid = (Get-ItemProperty -Path $registryPath -Name MachineGuid).MachineGuid
        if ($verifyGuid -eq $newGuid) {
            Write-Host "$GREEN[信息]$NC 系统机器GUID更新成功"
            return $true
        } else {
            Write-Host "$YELLOW[警告]$NC 系统机器GUID验证失败，但将继续执行..."
            return $false
        }
    }
    catch {
        Write-Host "$YELLOW[警告]$NC 更新系统机器GUID失败: $($_.Exception.Message)，但将继续执行..."
        return $false
    }
}

# 更新配置文件
Write-Host "$GREEN[信息]$NC 正在更新Cursor配置文件..."

try {
    # 检查配置文件是否存在
    if (-not (Test-Path $STORAGE_FILE)) {
        Write-Host "$RED[错误]$NC 未找到配置文件: $STORAGE_FILE"
        Write-Host "$RED[错误]$NC 请先安装并运行一次 Cursor 后再使用此脚本"
        exit 1
    }

    # 读取和更新配置文件
    $originalContent = Get-Content $STORAGE_FILE -Raw -Encoding UTF8
    $config = $originalContent | ConvertFrom-Json 

    # 更新设备ID
    $config.'telemetry.machineId' = $MACHINE_ID
    $config.'telemetry.macMachineId' = $MAC_MACHINE_ID
    $config.'telemetry.devDeviceId' = $UUID
    $config.'telemetry.sqmId' = $SQM_ID

    # 保存更新后的配置
    $updatedJson = $config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($STORAGE_FILE), $updatedJson, [System.Text.Encoding]::UTF8)
    
    Write-Host "$GREEN[信息]$NC 配置文件更新成功"
} catch {
    Write-Host "$RED[错误]$NC 更新配置文件失败: $($_.Exception.Message)"
    exit 1
}

# 更新系统机器GUID
Update-MachineGuid

# 默认禁用自动更新（完全自动化）
Write-Host "$GREEN[信息]$NC 正在禁用Cursor自动更新功能..."
$updaterPath = "$env:LOCALAPPDATA\cursor-updater"

try {
    # 如果存在更新器目录，删除它
    if (Test-Path $updaterPath) {
        if ((Get-Item $updaterPath).PSIsContainer) {
            Remove-Item -Path $updaterPath -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "$GREEN[信息]$NC 已删除现有cursor-updater目录"
        } elseif ((Get-Item $updaterPath) -is [System.IO.FileInfo]) {
            Write-Host "$GREEN[信息]$NC cursor-updater阻止文件已存在"
        }
    }

    # 创建阻止更新的文件
    if (-not (Test-Path $updaterPath) -or (Test-Path $updaterPath -PathType Container)) {
        New-Item -Path $updaterPath -ItemType File -Force | Out-Null
        
        # 设置只读权限
        Set-ItemProperty -Path $updaterPath -Name IsReadOnly -Value $true -ErrorAction SilentlyContinue
        
        # 使用icacls设置更严格的权限
        $icaclsResult = Start-Process "icacls.exe" -ArgumentList "`"$updaterPath`" /inheritance:r /grant:r `"$($env:USERNAME):(R)`"" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        
        Write-Host "$GREEN[信息]$NC 成功创建自动更新阻止文件"
    }
    
    Write-Host "$GREEN[信息]$NC 自动更新已成功禁用"
} catch {
    Write-Host "$YELLOW[警告]$NC 禁用自动更新时出现问题: $($_.Exception.Message)，但主要功能已完成"
}

# 显示完成信息
Write-Host ""
Write-Host "$GREEN[信息]$NC ================================="
Write-Host "$GREEN[信息]$NC 操作完成！新的设备ID已生成："
Write-Host "$BLUE[详情]$NC machineId: $MACHINE_ID"
Write-Host "$BLUE[详情]$NC macMachineId: $MAC_MACHINE_ID"
Write-Host "$BLUE[详情]$NC devDeviceId: $UUID"
Write-Host "$BLUE[详情]$NC sqmId: $SQM_ID"
Write-Host "$GREEN[信息]$NC ================================="
Write-Host ""
Write-Host "$GREEN[信息]$NC 请重启 Cursor 以应用新的配置"
Write-Host "$GREEN[信息]$NC 自动更新功能已被禁用"

# 输出成功标记（用于脚本调用检测）
Write-Output "ExecutionSuccessMarker"
Write-Host "$GREEN[成功]$NC 成功禁用自动更新" -ForegroundColor Green

Write-Host ""
Write-Host "$GREEN[信息]$NC 脚本执行完成，正在退出..."
exit 0

# 在文件写入部分修改
function Write-ConfigFile {
    param($config, $filePath)
    
    try {
        # 使用 UTF8 无 BOM 编码
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $jsonContent = $config | ConvertTo-Json -Depth 10
        
        # 统一使用 LF 换行符
        $jsonContent = $jsonContent.Replace("`r`n", "`n")
        
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::GetFullPath($filePath),
            $jsonContent,
            $utf8NoBom
        )
        
        Write-Host "$GREEN[信息]$NC 成功写入配置文件(UTF8 无 BOM)"
    }
    catch {
        throw "写入配置文件失败: $_"
    }
}

# 获取并显示版本信息
$cursorVersion = Get-CursorVersion
Write-Host ""
if ($cursorVersion) {
    Write-Host "$GREEN[信息]$NC 检测到 Cursor 版本: $cursorVersion，继续执行..."
} else {
    Write-Host "$YELLOW[警告]$NC 无法检测版本，将继续执行..."
} 
