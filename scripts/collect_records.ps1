param(
    [string]$RecordsRoot,
    [int]$Days = 30,
    [switch]$IncludeExcerpt,
    [int]$ExcerptLines = 40
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RecordsRoot)) {
    $RecordsRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "records"
}

if (-not (Test-Path -LiteralPath $RecordsRoot)) {
    Write-Output "No records directory found: $RecordsRoot"
    exit 0
}

$since = (Get-Date).AddDays(-1 * $Days)
$files = Get-ChildItem -LiteralPath $RecordsRoot -Filter "*.md" -Recurse |
    Where-Object { $_.LastWriteTime -ge $since } |
    Sort-Object LastWriteTime -Descending

foreach ($file in $files) {
    Write-Output "## $($file.FullName)"
    Write-Output "- LastWriteTime: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    if ($IncludeExcerpt) {
        Get-Content -LiteralPath $file.FullName -Encoding UTF8 | Select-Object -First $ExcerptLines
    }
    Write-Output ""
}
