param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$RecordsRoot,

    [string]$Date,

    [string]$SummaryFile,

    [Parameter(ValueFromPipeline = $true)]
    [string[]]$InputObject
)

$ErrorActionPreference = "Stop"

function Convert-ToSafeFileName {
    param([string]$Text)

    $safe = $Text.Trim()
    $safe = $safe -replace '[\\/:*?"<>|]', '-'
    $safe = $safe -replace '\s+', '-'
    $safe = $safe -replace '-{2,}', '-'
    $safe = $safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "untitled"
    }
    if ($safe.Length -gt 60) {
        return $safe.Substring(0, 60).Trim('-')
    }
    return $safe
}

if ([string]::IsNullOrWhiteSpace($RecordsRoot)) {
    $RecordsRoot = Join-Path (Join-Path (Get-Location) "AI工作记录") "records"
}

if ([string]::IsNullOrWhiteSpace($Date)) {
    $recordDate = Get-Date
} else {
    $recordDate = [datetime]::Parse($Date)
}

if (-not [string]::IsNullOrWhiteSpace($SummaryFile)) {
    $summary = Get-Content -LiteralPath $SummaryFile -Raw -Encoding UTF8
} else {
    $pipelineItems = @($InputObject)
    if ($pipelineItems.Count -gt 0) {
        $summary = $pipelineItems -join [Environment]::NewLine
    } else {
        $summary = [Console]::In.ReadToEnd()
    }
}

if ([string]::IsNullOrWhiteSpace($summary)) {
    throw "摘要内容为空。请通过管道传入 Markdown 摘要，或使用 -SummaryFile 指定摘要文件。"
}

$year = $recordDate.ToString("yyyy")
$month = $recordDate.ToString("MM")
$day = $recordDate.ToString("yyyy-MM-dd")
$targetDir = Join-Path (Join-Path $RecordsRoot $year) $month
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

$slug = Convert-ToSafeFileName -Text $Title
$targetPath = Join-Path $targetDir "$day-$slug.md"

$counter = 2
while (Test-Path -LiteralPath $targetPath) {
    $targetPath = Join-Path $targetDir "$day-$slug-$counter.md"
    $counter += 1
}

$content = @"
# $Title

- 日期：$day
- 来源：AI 对话摘要
- 类型：记录
- 相关目录：
- 相关 skill：
- 标签：

$summary
"@

Set-Content -LiteralPath $targetPath -Value $content -Encoding UTF8
Write-Output $targetPath

