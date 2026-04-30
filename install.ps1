param(
    [string]$RepoUrl = "https://github.com/Randolph87cb/rethink.git",
    [string]$SkillDir,
    [string]$GlobalAgentsPath,
    [switch]$SkipGlobalAgents
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SkillDir)) {
    $SkillDir = Join-Path $env:USERPROFILE ".codex\skills\record-and-reflect-review"
}

if ([string]::IsNullOrWhiteSpace($GlobalAgentsPath)) {
    $GlobalAgentsPath = Join-Path $env:USERPROFILE ".codex\AGENTS.md"
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

function Install-Skill {
    $skillsRoot = Split-Path -Parent $SkillDir
    New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null

    if (Test-Path -LiteralPath $SkillDir) {
        $gitDir = Join-Path $SkillDir ".git"
        if (-not (Test-Path -LiteralPath $gitDir)) {
            throw "目标目录已存在但不是 Git 仓库：$SkillDir。请先手动处理该目录，避免覆盖已有文件。"
        }

        Write-Output "已检测到 skill，开始更新：$SkillDir"
        Invoke-Git -WorkingDirectory $SkillDir -Arguments @("pull", "--ff-only")
        return
    }

    Write-Output "开始安装 skill：$SkillDir"
    Invoke-Git -Arguments @("clone", $RepoUrl, $SkillDir)
}

function Install-GlobalAgentsRules {
    if ($SkipGlobalAgents) {
        Write-Output "已跳过全局 AGENTS.md 规则安装。"
        return
    }

    $templatePath = Join-Path $SkillDir "references\global-agents-rules.md"
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

Install-Skill
Install-GlobalAgentsRules

Write-Output "安装完成。请重启 Codex，让新 skill 和全局规则生效。"

