param(
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [string]$Site,

    [string]$Env = "prod",
    [string]$Account = "default",
    [string]$Browser = "chromium",

    [ValidateSet("storageState", "profile", "hybrid")]
    [string]$Mode = "storageState",

    [string]$Url,
    [string]$BaseUrl,
    [string]$CheckUrl,
    [string]$CheckSelector,
    [string[]]$Tags,
    [string]$Notes,

    [switch]$CreateIfMissing,
    [switch]$ForceUpsert,
    [switch]$SkipMarkVerified,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Invoke-RegistryJson {
    param(
        [string]$RegistryScript,
        [string]$CommandName,
        [hashtable]$Parameters
    )

    $invokeParams = @{
        Command = $CommandName
    }
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        if ($null -eq $value) {
            continue
        }

        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        $invokeParams[$key] = $value
    }

    $raw = & $RegistryScript @invokeParams
    return $raw | ConvertFrom-Json
}

function Get-RegistryScriptPath {
    return Join-Path $PSScriptRoot "session_registry.ps1"
}

function Get-CommonSessionParams {
    return @{
        Root = $Root
        Site = $Site
        Env = $Env
        Account = $Account
        Browser = $Browser
    }
}

function Get-PlaywrightBrowserName {
    param([string]$BrowserName)

    switch ($BrowserName.ToLowerInvariant()) {
        "cr" { return "chromium" }
        "chromium" { return "chromium" }
        "chrome" { return "chromium" }
        "ff" { return "firefox" }
        "firefox" { return "firefox" }
        "wk" { return "webkit" }
        "webkit" { return "webkit" }
        default { return $BrowserName }
    }
}

function Ensure-ParentDirectory {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return
    }

    $parent = Split-Path -Parent $PathValue
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

$registryScript = Get-RegistryScriptPath
$commonParams = Get-CommonSessionParams
$session = $null
$sessionExists = $true

try {
    $session = Invoke-RegistryJson -RegistryScript $registryScript -CommandName "get" -Parameters $commonParams
} catch {
    $sessionExists = $false
}

if (-not $sessionExists) {
    if (-not $BaseUrl -and -not $Url -and -not $CheckUrl) {
        throw "Session does not exist. For first-time use, provide -Url or -BaseUrl so the session can be created automatically."
    }

    if ($BaseUrl) {
        $resolvedBaseUrl = $BaseUrl
    } else {
        $resolvedBaseUrl = $Url
    }
    if ($CheckUrl) {
        $resolvedCheckUrl = $CheckUrl
    } else {
        $resolvedCheckUrl = $Url
    }

    $upsertParams = @{
        Root = $Root
        Site = $Site
        Env = $Env
        Account = $Account
        Browser = $Browser
        Mode = $Mode
        BaseUrl = $resolvedBaseUrl
        CheckUrl = $resolvedCheckUrl
        CheckSelector = $CheckSelector
        Tags = $Tags
        Notes = $Notes
    }

    $session = Invoke-RegistryJson -RegistryScript $registryScript -CommandName "upsert" -Parameters $upsertParams
} elseif ($ForceUpsert -or $PSBoundParameters.ContainsKey("BaseUrl") -or $PSBoundParameters.ContainsKey("CheckUrl") -or $PSBoundParameters.ContainsKey("CheckSelector") -or $PSBoundParameters.ContainsKey("Tags") -or $PSBoundParameters.ContainsKey("Notes")) {
    if ($PSBoundParameters.ContainsKey("BaseUrl")) {
        $resolvedBaseUrl = $BaseUrl
    } else {
        $resolvedBaseUrl = $session.baseUrl
    }
    if ($PSBoundParameters.ContainsKey("CheckUrl")) {
        $resolvedCheckUrl = $CheckUrl
    } else {
        $resolvedCheckUrl = $session.checkUrl
    }
    if ($PSBoundParameters.ContainsKey("CheckSelector")) {
        $resolvedCheckSelector = $CheckSelector
    } else {
        $resolvedCheckSelector = $session.checkSelector
    }
    if ($PSBoundParameters.ContainsKey("Tags")) {
        $resolvedTags = $Tags
    } else {
        $resolvedTags = $session.tags
    }
    if ($PSBoundParameters.ContainsKey("Notes")) {
        $resolvedNotes = $Notes
    } else {
        $resolvedNotes = $session.notes
    }

    $upsertParams = @{
        Root = $Root
        Site = $Site
        Env = $Env
        Account = $Account
        Browser = $Browser
        Mode = $Mode
        BaseUrl = $resolvedBaseUrl
        CheckUrl = $resolvedCheckUrl
        CheckSelector = $resolvedCheckSelector
        Tags = $resolvedTags
        Notes = $resolvedNotes
    }

    $session = Invoke-RegistryJson -RegistryScript $registryScript -CommandName "upsert" -Parameters $upsertParams
}

if ($Url) {
    $targetUrl = $Url
} elseif ($session.checkUrl) {
    $targetUrl = $session.checkUrl
} else {
    $targetUrl = $session.baseUrl
}
if ([string]::IsNullOrWhiteSpace($targetUrl)) {
    throw "Missing target URL. Pass -Url, or set -BaseUrl / -CheckUrl on the session first."
}

$playwrightBrowser = Get-PlaywrightBrowserName -BrowserName $session.browser

Ensure-ParentDirectory -PathValue $session.statePath
if ($session.profilePath) {
    New-Item -ItemType Directory -Path $session.profilePath -Force | Out-Null
}

$playwrightArgs = @("playwright", "open", "--browser", $playwrightBrowser)
if ($session.mode -eq "profile" -or $session.mode -eq "hybrid") {
    if (-not [string]::IsNullOrWhiteSpace($session.profilePath)) {
        $playwrightArgs += @("--user-data-dir", $session.profilePath)
    }
}

if ($session.stateExists) {
    $playwrightArgs += @("--load-storage", $session.statePath)
}

if (-not [string]::IsNullOrWhiteSpace($session.statePath)) {
    $playwrightArgs += @("--save-storage", $session.statePath)
}

$playwrightArgs += $targetUrl

Write-Host "Opening browser. Finish login in the browser, then close the window to save session state." -ForegroundColor Cyan
if (-not $sessionExists) {
    Write-Host "Session was missing, so it was created automatically before launch." -ForegroundColor DarkGray
}
Write-Host ("Command: npx " + ($playwrightArgs -join " ")) -ForegroundColor DarkGray

if ($DryRun) {
    [ordered]@{
        session = $session
        targetUrl = $targetUrl
        command = @("npx") + $playwrightArgs
    } | ConvertTo-Json -Depth 10
    exit 0
}

& npx @playwrightArgs
if ($LASTEXITCODE -ne 0) {
    throw "Playwright failed to open the browser."
}

$stateSaved = -not [string]::IsNullOrWhiteSpace($session.statePath) -and (Test-Path -LiteralPath $session.statePath)
if ($stateSaved -and -not $SkipMarkVerified) {
    $session = Invoke-RegistryJson -RegistryScript $registryScript -CommandName "mark-verified" -Parameters $commonParams
}

[ordered]@{
    site = $Site
    env = $Env
    account = $Account
    browser = $Browser
    mode = $session.mode
    statePath = $session.statePath
    stateSaved = $stateSaved
    profilePath = $session.profilePath
    lastVerifiedAt = $session.lastVerifiedAt
    targetUrl = $targetUrl
} | ConvertTo-Json -Depth 10
