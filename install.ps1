param(
    [string]$RepoUrl = "https://github.com/Randolph87cb/rethink.git",
    [string[]]$SkillNames = @("record-and-reflect-review"),
    [string]$SkillDir,
    [string]$GlobalAgentsPath,
    [string]$SourceRepoDir,
    [switch]$SkipGlobalAgents
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GlobalAgentsPath)) {
    $GlobalAgentsPath = Join-Path $env:USERPROFILE ".codex\AGENTS.md"
}

if ([string]::IsNullOrWhiteSpace($SourceRepoDir)) {
    $SourceRepoDir = Join-Path $env:USERPROFILE ".codex\skills\.rethink-source"
}

$SkillDefinitions = @{
    "record-and-reflect-review" = @{
        DefaultSkillDir = Join-Path $env:USERPROFILE ".codex\skills\record-and-reflect-review"
        SourceSubpath = "."
        InstallMode = "repo"
        SupportsGlobalAgents = $true
    }
    "task-retrospective" = @{
        DefaultSkillDir = Join-Path $env:USERPROFILE ".codex\skills\task-retrospective"
        SourceSubpath = "skills\task-retrospective"
        InstallMode = "export"
        SupportsGlobalAgents = $false
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        & git @Arguments
    } else {
        & git -C $WorkingDirectory @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Git 命令执行失败：git $($Arguments -join ' ')"
    }
}

function Get-SkillDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillName
    )

    if (-not $SkillDefinitions.ContainsKey($SkillName)) {
        $validNames = ($SkillDefinitions.Keys | Sort-Object) -join ", "
        throw "不支持的 skill：$SkillName。可选值：$validNames"
    }

    return $SkillDefinitions[$SkillName]
}

function Resolve-SkillNames {
    $resolved = @()
    foreach ($skillName in $SkillNames) {
        if ([string]::IsNullOrWhiteSpace($skillName)) {
            continue
        }

        foreach ($part in ($skillName -split ",")) {
            if ([string]::IsNullOrWhiteSpace($part)) {
                continue
            }

            $trimmed = $part.Trim()
            if ($resolved -notcontains $trimmed) {
                $null = Get-SkillDefinition -SkillName $trimmed
                $resolved += $trimmed
            }
        }
    }

    if ($resolved.Count -eq 0) {
        throw "至少需要提供一个 skill 名称。"
    }

    if (-not [string]::IsNullOrWhiteSpace($SkillDir) -and $resolved.Count -ne 1) {
        throw "当同时安装多个 skill 时，不支持通过 -SkillDir 只提供一个目标目录。"
    }

    return $resolved
}

function Get-TargetSkillDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillName
    )

    if (-not [string]::IsNullOrWhiteSpace($SkillDir)) {
        return $SkillDir
    }

    $definition = Get-SkillDefinition -SkillName $SkillName
    return $definition.DefaultSkillDir
}

function Ensure-SourceRepo {
    $parentDir = Split-Path -Parent $SourceRepoDir
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null

    if (Test-Path -LiteralPath $SourceRepoDir) {
        $gitDir = Join-Path $SourceRepoDir ".git"
        if (-not (Test-Path -LiteralPath $gitDir)) {
            throw "源码缓存目录已存在但不是 Git 仓库：$SourceRepoDir"
        }

        Write-Output "已检测到源码缓存，开始更新：$SourceRepoDir"
        Invoke-Git -WorkingDirectory $SourceRepoDir -Arguments @("pull", "--ff-only")
        return
    }

    Write-Output "开始拉取源码缓存：$SourceRepoDir"
    Invoke-Git -Arguments @("clone", $RepoUrl, $SourceRepoDir)
}

function Remove-ManagedTargetItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDir
    )

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

    foreach ($itemName in @("SKILL.md", "agents", "scripts", "references", "assets")) {
        $targetPath = Join-Path $TargetDir $itemName
        if (Test-Path -LiteralPath $targetPath) {
            Remove-Item -LiteralPath $targetPath -Recurse -Force
        }
    }
}

function Install-RepoSkill {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDir
    )

    $skillsRoot = Split-Path -Parent $TargetDir
    New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null

    if (Test-Path -LiteralPath $TargetDir) {
        $gitDir = Join-Path $TargetDir ".git"
        if (-not (Test-Path -LiteralPath $gitDir)) {
            throw "目标目录已存在但不是 Git 仓库：$TargetDir。请先手动处理该目录，避免覆盖已有文件。"
        }

        Write-Output "已检测到 skill，开始更新：$TargetDir"
        Invoke-Git -WorkingDirectory $TargetDir -Arguments @("pull", "--ff-only")
        return
    }

    Write-Output "开始安装 skill：$TargetDir"
    Invoke-Git -Arguments @("clone", $RepoUrl, $TargetDir)
}

function Install-ExportedSkill {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillName,
        [Parameter(Mandatory = $true)]
        [string]$TargetDir
    )

    Ensure-SourceRepo

    $definition = Get-SkillDefinition -SkillName $SkillName
    $sourcePath = Join-Path $SourceRepoDir $definition.SourceSubpath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "未找到 skill 源目录：$sourcePath"
    }

    Remove-ManagedTargetItems -TargetDir $TargetDir

    foreach ($itemName in @("SKILL.md", "agents", "scripts", "references", "assets")) {
        $sourceItem = Join-Path $sourcePath $itemName
        if (Test-Path -LiteralPath $sourceItem) {
            Copy-Item -LiteralPath $sourceItem -Destination (Join-Path $TargetDir $itemName) -Recurse -Force
        }
    }

    Write-Output "已导出 skill：$SkillName -> $TargetDir"
}

function Install-GlobalAgentsRules {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstalledRecordSkillDir
    )

    if ($SkipGlobalAgents) {
        Write-Output "已跳过全局 AGENTS.md 规则安装。"
        return
    }

    $templatePath = Join-Path $InstalledRecordSkillDir "references\global-agents-rules.md"
    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "未找到全局规则模板：$templatePath"
    }

    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $match = [regex]::Match($template, '(?s)```markdown\s*(.*?)\s*```')
    if (-not $match.Success) {
        throw "全局规则模板格式不正确，未找到 markdown 代码块。"
    }

    $rules = $match.Groups[1].Value.Trim()
    $beginMarker = "<!-- BEGIN: record-and-reflect-review global rules -->"
    $endMarker = "<!-- END: record-and-reflect-review global rules -->"
    $managedBlock = ($rules -replace '(?s)^\s*# 全局协作规则\s*', '').Trim()
    $agentsDir = Split-Path -Parent $GlobalAgentsPath
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

    if (-not (Test-Path -LiteralPath $GlobalAgentsPath)) {
        Set-Content -LiteralPath $GlobalAgentsPath -Value $rules -Encoding UTF8
        Write-Output "已创建全局 AGENTS.md：$GlobalAgentsPath"
        return
    }

    $current = Get-Content -LiteralPath $GlobalAgentsPath -Raw -Encoding UTF8
    $managedPattern = "(?s)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))"
    if ([regex]::IsMatch($current, $managedPattern)) {
        $updated = [regex]::Replace($current, $managedPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $managedBlock })
        Set-Content -LiteralPath $GlobalAgentsPath -Value $updated -Encoding UTF8
        Write-Output "已更新全局 AGENTS.md 受管规则块：$GlobalAgentsPath"
        return
    }

    $legacyPattern = '(?ms)^## 记录以及反思回顾\s*.*?(?=^## |\z)'
    if ([regex]::IsMatch($current, $legacyPattern)) {
        $updated = [regex]::Replace($current, $legacyPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $managedBlock })
        Set-Content -LiteralPath $GlobalAgentsPath -Value $updated -Encoding UTF8
        Write-Output "已替换全局 AGENTS.md 旧版记录规则：$GlobalAgentsPath"
        return
    }

    if ($current -like "*# 全局协作规则*") {
        Add-Content -LiteralPath $GlobalAgentsPath -Value "`r`n$managedBlock" -Encoding UTF8
        Write-Output "已追加全局 AGENTS.md 受管规则块：$GlobalAgentsPath"
        return
    }

    Add-Content -LiteralPath $GlobalAgentsPath -Value "`r`n$rules" -Encoding UTF8
    Write-Output "已写入全局 AGENTS.md：$GlobalAgentsPath"
}

$resolvedSkillNames = Resolve-SkillNames
$installedRecordSkillDir = $null

foreach ($skillName in $resolvedSkillNames) {
    $definition = Get-SkillDefinition -SkillName $skillName
    $targetDir = Get-TargetSkillDir -SkillName $skillName

    if ($definition.InstallMode -eq "repo") {
        Install-RepoSkill -TargetDir $targetDir
    } elseif ($definition.InstallMode -eq "export") {
        Install-ExportedSkill -SkillName $skillName -TargetDir $targetDir
    } else {
        throw "未知的安装模式：$($definition.InstallMode)"
    }

    if ($definition.SupportsGlobalAgents) {
        $installedRecordSkillDir = $targetDir
    }
}

if (-not [string]::IsNullOrWhiteSpace($installedRecordSkillDir)) {
    Install-GlobalAgentsRules -InstalledRecordSkillDir $installedRecordSkillDir
}

Write-Output "安装完成。请重启 Codex，让新 skill 和全局规则生效。"
