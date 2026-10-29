[CmdletBinding()]
param(
    [string]$SourceDirectory = $PSScriptRoot,
    [string]$Destination,
    [switch]$VerifyOnly,
    [switch]$ChooseDestination
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-LocalPath([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "$Label 不能为空。" }
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^[A-Za-z]:\\' -or $full.StartsWith('\\')) {
        throw "$Label 必须使用普通本地磁盘路径：$Path"
    }
    $drive = New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($full))
    if ($drive.DriveType -eq [System.IO.DriveType]::Network) {
        throw "$Label 不支持映射网络盘：$Path"
    }
    $current = $full
    while (-not [string]::IsNullOrEmpty($current)) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "$Label 的路径包含链接或重解析目录，请选择普通本地目录：$current"
            }
        }
        $parent = [System.IO.Directory]::GetParent($current)
        if ($null -eq $parent) { break }
        $current = $parent.FullName
    }
    if ($full -ieq [System.IO.Path]::GetPathRoot($full)) { return $full }
    return $full.TrimEnd('\')
}

function Get-MemberPath([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or
        $Name -ne [System.IO.Path]::GetFileName($Name) -or
        $Name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Name -eq '.' -or $Name -eq '..') {
        throw "校验清单中的文件名无效：$Name"
    }
    $path = Join-Path $script:source $Name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -or
            ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "需要普通文件，不能是目录或链接：$Name"
        }
    }
    return $path
}

function Get-DeclaredSha256([string]$Path) {
    $stream = $null
    $algorithm = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        $bytes = $algorithm.ComputeHash($stream)
        return [System.BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
    }
    finally {
        if ($null -ne $algorithm) { $algorithm.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Test-DeclaredFile($Record, [string]$Kind) {
    $name = [string]$Record.name
    $path = Get-MemberPath $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "缺少$Kind：$name。请补下载，保持原文件名，放到脚本所在目录。"
    }
    if ([string]$Record.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        throw "校验清单中的 SHA256 无效：$name"
    }
    $expected = [long]$Record.bytes
    if ($expected -le 0) { throw "校验清单中的文件大小无效：$name" }
    $actual = (Get-Item -LiteralPath $path).Length
    if ($actual -ne $expected) {
        throw "文件大小不符：$name；应为 $expected 字节，实际 $actual 字节。请重新下载该文件。"
    }
    Write-Host ("正在校验 {0} ..." -f $name)
    $hash = Get-DeclaredSha256 $path
    if ($hash -ine [string]$Record.sha256) {
        throw "SHA256 不符：$name。请重新下载该文件；其它已经通过的分卷无需重下。"
    }
    return $path
}

try {
    $script:source = Get-LocalPath $SourceDirectory '下载目录'
    if (-not (Test-Path -LiteralPath $script:source -PathType Container)) {
        throw "下载目录不存在：$script:source"
    }
    $manifestPath = Get-MemberPath 'transfer-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw '缺少 transfer-manifest.json。请从同一个 Release 补下载。'
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.format -ne 'clear-offline-transfer-v1') {
        throw '不支持的清单版本，请使用同一个 Release 提供的脚本和清单。'
    }
    $volumes = @($manifest.volumes)
    if ($volumes.Count -eq 0) { throw '校验清单没有分卷记录。' }
    $seen = @{}
    for ($i = 0; $i -lt $volumes.Count; $i++) {
        $name = [string]$volumes[$i].name
        $null = Get-MemberPath $name
        if ($seen.ContainsKey($name)) { throw "清单包含重复分卷：$name" }
        $seen[$name] = $true
        if ($name -notmatch '^Clear-offline-win-x64\.7z\.(\d{3,})$' -or
            [int]$Matches[1] -ne ($i + 1)) {
            throw "清单分卷编号不连续或顺序不正确：$name"
        }
    }
    if ([string]$manifest.archive_first_volume -ne [string]$volumes[0].name) {
        throw '清单的首卷与分卷列表不一致。'
    }
    Write-Host ("共 {0} 卷。校验会完整读取所有下载文件，可能需要几分钟。" -f $volumes.Count)
    $missing = @($volumes | Where-Object {
        -not (Test-Path -LiteralPath (Get-MemberPath ([string]$_.name)) -PathType Leaf)
    } | ForEach-Object { [string]$_.name })
    if ($missing.Count -gt 0) {
        throw ("缺少 {0} 个分卷，请补下载：`n{1}" -f $missing.Count, ($missing -join "`n"))
    }
    foreach ($volume in $volumes) {
        $null = Test-DeclaredFile $volume '分卷'
    }
    if ([string]$manifest.extractor.name -notin @('7za.exe', '7zz.exe', '7z.exe')) {
        throw '清单的解压工具名称不受支持。'
    }
    $extractor = Test-DeclaredFile $manifest.extractor '解压工具'
    $dependencies = @()
    if ($null -ne $manifest.extractor.PSObject.Properties['dependencies']) {
        $dependencies = @($manifest.extractor.dependencies)
    }
    $dependencyNames = @{}
    foreach ($dependency in $dependencies) {
        $dependencyName = [string]$dependency.name
        if ($seen.ContainsKey($dependencyName) -or
            $dependencyName -ieq [string]$manifest.extractor.name -or
            $dependencyNames.ContainsKey($dependencyName)) {
            throw "清单包含重复或冲突的工具依赖：$dependencyName"
        }
        $dependencyNames[$dependencyName] = $true
        $null = Test-DeclaredFile $dependency '解压工具依赖'
    }
    if ([string]$manifest.extractor.name -ieq '7z.exe' -and -not $dependencyNames.ContainsKey('7z.dll')) {
        throw '使用 7z.exe 时，清单必须同时声明并校验 7z.dll。'
    }
    Write-Host '全部分卷及解压工具的 SHA256 校验通过。' -ForegroundColor Green
    if ($VerifyOnly) { exit 0 }

    if ([string]::IsNullOrWhiteSpace($Destination)) {
        if ($ChooseDestination) {
            $Destination = Read-Host '请输入解压目录（直接回车使用当前目录下的 Clear-extracted）'
        }
        if ([string]::IsNullOrWhiteSpace($Destination)) {
            $Destination = Join-Path $script:source 'Clear-extracted'
        }
    }
    $target = Get-LocalPath $Destination '解压目录'
    if ($target -ieq $script:source -or
        $script:source.StartsWith($target.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw '解压目录不能是下载目录或它的上级目录。请选择新的空目录。'
    }
    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            throw "解压目标已存在且不是目录：$target"
        }
        if (@(Get-ChildItem -LiteralPath $target -Force | Select-Object -First 1).Count -gt 0) {
            throw "解压目录不是空目录，不会覆盖现有文件：$target。请选择新的空目录。"
        }
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    # 临时文件跟随用户选择的本地解压目录，不回落到系统默认临时目录。
    $localTemp = Join-Path $target '.clear-extraction-temp'
    New-Item -ItemType Directory -Force -Path $localTemp | Out-Null
    $oldTemp = @{}
    foreach ($key in @('TEMP', 'TMP', 'TMPDIR')) {
        $oldTemp[$key] = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        [System.Environment]::SetEnvironmentVariable($key, $localTemp, 'Process')
    }
    try {
        Write-Host ("正在解压到：{0}" -f $target)
        $firstVolume = Get-MemberPath ([string]$manifest.archive_first_volume)
        & $extractor x $firstVolume ("-o{0}" -f $target) -y -bd -bsp0
        $extractExit = $LASTEXITCODE
        if ($extractExit -ne 0) {
            throw "解压失败，7-Zip 返回码：$extractExit。下载文件保留不变；请换一个新的空目录后重试。"
        }
    }
    finally {
        foreach ($key in @('TEMP', 'TMP', 'TMPDIR')) {
            [System.Environment]::SetEnvironmentVariable($key, $oldTemp[$key], 'Process')
        }
        if (Test-Path -LiteralPath $localTemp -PathType Container) {
            if (@(Get-ChildItem -LiteralPath $localTemp -Force | Select-Object -First 1).Count -eq 0) {
                Remove-Item -LiteralPath $localTemp -Force
            }
        }
    }
    Write-Host ("校验与解压完成：{0}" -f $target) -ForegroundColor Green
    Write-Host '接下来打开解压目录中的 README，按说明初始化目标机器；此操作没有启动或安装服务。'
    exit 0
}
catch {
    Write-Host ("操作未完成：{0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
