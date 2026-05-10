param(
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [string]$Site,

    [string]$Env = "prod",
    [string]$Account = "default",
    [string]$Browser = "chromium",

    [string]$Url,
    [string]$CheckSelector,
    [int]$TimeoutMs = 60000,
    [switch]$Headed
)

$ErrorActionPreference = "Stop"

function Get-RegistryScriptPath {
    return Join-Path $PSScriptRoot "session_registry.ps1"
}

function Get-VerifyPythonPath {
    return Join-Path $PSScriptRoot "verify_session.py"
}

function Invoke-RegistryJson {
    param(
        [string]$RegistryScript,
        [hashtable]$Parameters
    )

    $invokeParams = @{
        Command = "get"
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

$registryScript = Get-RegistryScriptPath
$verifyScript = Get-VerifyPythonPath
$session = Invoke-RegistryJson -RegistryScript $registryScript -Parameters @{
    Root = $Root
    Site = $Site
    Env = $Env
    Account = $Account
    Browser = $Browser
}

$targetUrl = if ($Url) { $Url } elseif ($session.checkUrl) { $session.checkUrl } else { $session.baseUrl }
if ([string]::IsNullOrWhiteSpace($targetUrl)) {
    throw "Missing target URL. Set -Url, or ensure the session has checkUrl/baseUrl."
}

$resolvedSelector = if ($CheckSelector) { $CheckSelector } else { $session.checkSelector }

$pythonArgs = @(
    (Get-VerifyPythonPath),
    "--state-path", $session.statePath,
    "--url", $targetUrl,
    "--browser", $session.browser,
    "--timeout-ms", [string]$TimeoutMs,
    "--headless", ($(if ($Headed) { "false" } else { "true" }))
)

if (-not [string]::IsNullOrWhiteSpace($resolvedSelector)) {
    $pythonArgs += @("--check-selector", $resolvedSelector)
}

& python @pythonArgs
if ($LASTEXITCODE -ne 0) {
    throw "Session verification failed."
}
