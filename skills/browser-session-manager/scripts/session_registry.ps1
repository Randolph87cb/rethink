param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("init", "upsert", "get", "list", "remove", "mark-verified")]
    [string]$Command,

    [string]$Root,
    [string]$Site,
    [string]$Env = "prod",
    [string]$Account = "default",
    [string]$Browser = "chromium",

    [ValidateSet("storageState", "profile", "hybrid")]
    [string]$Mode = "storageState",

    [string]$StatePath,
    [string]$ProfilePath,
    [string]$BaseUrl,
    [string]$CheckUrl,
    [string]$CheckSelector,
    [string[]]$Tags,
    [string]$Notes,
    [string]$VerifiedAt
)

$ErrorActionPreference = "Stop"

function Get-StoreRoot {
    param([string]$ProvidedRoot)

    if (-not [string]::IsNullOrWhiteSpace($ProvidedRoot)) {
        return [System.IO.Path]::GetFullPath($ProvidedRoot)
    }

    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    return Join-Path $localAppData "Codex\browser-sessions"
}

function Convert-ToSafeName {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "default"
    }

    $safe = $Text.Trim().ToLowerInvariant()
    $safe = $safe -replace '[\\/:*?"<>|]', '-'
    $safe = $safe -replace '\s+', '-'
    $safe = $safe -replace '[^a-z0-9._-]', '-'
    $safe = $safe -replace '-{2,}', '-'
    return $safe.Trim('-')
}

function Get-SessionKey {
    param(
        [string]$Site,
        [string]$Env,
        [string]$Account,
        [string]$Browser
    )

    return "{0}|{1}|{2}|{3}" -f $Site, $Env, $Account, $Browser
}

function Get-SafeFileStem {
    param(
        [string]$Site,
        [string]$Env,
        [string]$Account,
        [string]$Browser
    )

    return "{0}--{1}--{2}--{3}" -f (Convert-ToSafeName $Site), (Convert-ToSafeName $Env), (Convert-ToSafeName $Account), (Convert-ToSafeName $Browser)
}

function Ensure-Store {
    param([string]$StoreRoot)

    $statesDir = Join-Path $StoreRoot "states"
    $profilesDir = Join-Path $StoreRoot "profiles"
    foreach ($dir in @($StoreRoot, $statesDir, $profilesDir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $registryPath = Join-Path $StoreRoot "registry.json"
    if (-not (Test-Path -LiteralPath $registryPath)) {
        $initial = [ordered]@{
            version = 1
            updatedAt = (Get-Date).ToString("o")
            sessions = @()
        }
        $initial | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $registryPath -Encoding UTF8
    }

    return [ordered]@{
        root = $StoreRoot
        statesDir = $statesDir
        profilesDir = $profilesDir
        registryPath = $registryPath
    }
}

function Load-Registry {
    param([string]$RegistryPath)

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        return [pscustomobject]@{
            version = 1
            updatedAt = (Get-Date).ToString("o")
            sessions = @()
        }
    }

    $raw = Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{
            version = 1
            updatedAt = (Get-Date).ToString("o")
            sessions = @()
        }
    }

    $registry = $raw | ConvertFrom-Json
    if ($null -eq $registry.sessions) {
        $registry | Add-Member -NotePropertyName sessions -NotePropertyValue @()
    }
    return $registry
}

function Save-Registry {
    param(
        [psobject]$Registry,
        [string]$RegistryPath
    )

    $Registry.updatedAt = (Get-Date).ToString("o")
    $Registry | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $RegistryPath -Encoding UTF8
}

function Resolve-ManagedPath {
    param(
        [string]$StoreRoot,
        [string]$RelativeFolder,
        [string]$PathValue,
        [string]$DefaultName
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return [System.IO.Path]::GetFullPath((Join-Path (Join-Path $StoreRoot $RelativeFolder) $DefaultName))
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $StoreRoot $PathValue))
}

function Require-SessionIdentity {
    if ([string]::IsNullOrWhiteSpace($Site)) {
        throw "缺少必填参数：-Site"
    }
}

function Normalize-Tags {
    param([string[]]$RawTags)

    $normalized = @()
    foreach ($tag in @($RawTags)) {
        if ([string]::IsNullOrWhiteSpace($tag)) {
            continue
        }

        foreach ($part in ($tag -split ",")) {
            $trimmed = $part.Trim().Trim("'`"")
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $normalized += $trimmed
            }
        }
    }

    return @($normalized | Select-Object -Unique)
}

function To-SessionOutput {
    param([psobject]$Session)

    if ($null -eq $Session) {
        return $null
    }

    return [ordered]@{
        key = $Session.key
        site = $Session.site
        env = $Session.env
        account = $Session.account
        browser = $Session.browser
        mode = $Session.mode
        statePath = $Session.statePath
        stateExists = if ($Session.statePath) { Test-Path -LiteralPath $Session.statePath } else { $false }
        profilePath = $Session.profilePath
        profileExists = if ($Session.profilePath) { Test-Path -LiteralPath $Session.profilePath } else { $false }
        baseUrl = $Session.baseUrl
        checkUrl = $Session.checkUrl
        checkSelector = $Session.checkSelector
        tags = @($Session.tags)
        notes = $Session.notes
        createdAt = $Session.createdAt
        updatedAt = $Session.updatedAt
        lastVerifiedAt = $Session.lastVerifiedAt
    }
}

$store = Ensure-Store -StoreRoot (Get-StoreRoot -ProvidedRoot $Root)
$registry = Load-Registry -RegistryPath $store.registryPath

switch ($Command) {
    "init" {
        $store | ConvertTo-Json -Depth 5
        break
    }
    "list" {
        $sessions = @($registry.sessions)

        if (-not [string]::IsNullOrWhiteSpace($Site)) {
            $sessions = @($sessions | Where-Object { $_.site -eq $Site })
        }
        if ($PSBoundParameters.ContainsKey("Env")) {
            $sessions = @($sessions | Where-Object { $_.env -eq $Env })
        }
        if ($PSBoundParameters.ContainsKey("Account")) {
            $sessions = @($sessions | Where-Object { $_.account -eq $Account })
        }
        if ($PSBoundParameters.ContainsKey("Browser")) {
            $sessions = @($sessions | Where-Object { $_.browser -eq $Browser })
        }

        @($sessions | ForEach-Object { To-SessionOutput $_ }) | ConvertTo-Json -Depth 10
        break
    }
    "get" {
        Require-SessionIdentity
        $key = Get-SessionKey -Site $Site -Env $Env -Account $Account -Browser $Browser
        $session = @($registry.sessions | Where-Object { $_.key -eq $key } | Select-Object -First 1)[0]
        if ($null -eq $session) {
            throw "未找到会话：$key"
        }

        To-SessionOutput $session | ConvertTo-Json -Depth 10
        break
    }
    "upsert" {
        Require-SessionIdentity
        $key = Get-SessionKey -Site $Site -Env $Env -Account $Account -Browser $Browser
        $safeStem = Get-SafeFileStem -Site $Site -Env $Env -Account $Account -Browser $Browser
        $defaultStatePath = "$safeStem.json"
        $defaultProfilePath = $safeStem

        $existing = @($registry.sessions | Where-Object { $_.key -eq $key } | Select-Object -First 1)[0]
        $isNew = $null -eq $existing

        if ($isNew) {
            $existing = [pscustomobject]@{
                key = $key
                site = $Site
                env = $Env
                account = $Account
                browser = $Browser
                mode = $Mode
                statePath = $null
                profilePath = $null
                baseUrl = $null
                checkUrl = $null
                checkSelector = $null
                tags = @()
                notes = $null
                createdAt = (Get-Date).ToString("o")
                updatedAt = (Get-Date).ToString("o")
                lastVerifiedAt = $null
            }
            $registry.sessions += $existing
        }

        $existing.site = $Site
        $existing.env = $Env
        $existing.account = $Account
        $existing.browser = $Browser
        $existing.mode = $Mode

        switch ($Mode) {
            "storageState" {
                $existing.statePath = Resolve-ManagedPath -StoreRoot $store.root -RelativeFolder "states" -PathValue $StatePath -DefaultName $defaultStatePath
                $existing.profilePath = if ($PSBoundParameters.ContainsKey("ProfilePath")) { Resolve-ManagedPath -StoreRoot $store.root -RelativeFolder "profiles" -PathValue $ProfilePath -DefaultName $defaultProfilePath } else { $null }
            }
            "profile" {
                $existing.profilePath = Resolve-ManagedPath -StoreRoot $store.root -RelativeFolder "profiles" -PathValue $ProfilePath -DefaultName $defaultProfilePath
                $existing.statePath = if ($PSBoundParameters.ContainsKey("StatePath")) { Resolve-ManagedPath -StoreRoot $store.root -RelativeFolder "states" -PathValue $StatePath -DefaultName $defaultStatePath } else { $null }
            }
            "hybrid" {
                $existing.statePath = Resolve-ManagedPath -StoreRoot $store.root -RelativeFolder "states" -PathValue $StatePath -DefaultName $defaultStatePath
                $existing.profilePath = Resolve-ManagedPath -StoreRoot $store.root -RelativeFolder "profiles" -PathValue $ProfilePath -DefaultName $defaultProfilePath
            }
        }

        foreach ($field in @("BaseUrl", "CheckUrl", "CheckSelector", "Notes")) {
            if ($PSBoundParameters.ContainsKey($field)) {
                $propertyName = $field.Substring(0, 1).ToLowerInvariant() + $field.Substring(1)
                $existing.$propertyName = $PSBoundParameters[$field]
            }
        }

        if ($PSBoundParameters.ContainsKey("Tags")) {
            $existing.tags = @(Normalize-Tags -RawTags $Tags)
        }

        $existing.updatedAt = (Get-Date).ToString("o")
        Save-Registry -Registry $registry -RegistryPath $store.registryPath
        To-SessionOutput $existing | ConvertTo-Json -Depth 10
        break
    }
    "mark-verified" {
        Require-SessionIdentity
        $key = Get-SessionKey -Site $Site -Env $Env -Account $Account -Browser $Browser
        $session = @($registry.sessions | Where-Object { $_.key -eq $key } | Select-Object -First 1)[0]
        if ($null -eq $session) {
            throw "未找到会话：$key"
        }

        $session.lastVerifiedAt = if ([string]::IsNullOrWhiteSpace($VerifiedAt)) { (Get-Date).ToString("o") } else { [datetime]::Parse($VerifiedAt).ToString("o") }
        $session.updatedAt = (Get-Date).ToString("o")
        Save-Registry -Registry $registry -RegistryPath $store.registryPath
        To-SessionOutput $session | ConvertTo-Json -Depth 10
        break
    }
    "remove" {
        Require-SessionIdentity
        $key = Get-SessionKey -Site $Site -Env $Env -Account $Account -Browser $Browser
        $remaining = @($registry.sessions | Where-Object { $_.key -ne $key })
        if ($remaining.Count -eq @($registry.sessions).Count) {
            throw "未找到会话：$key"
        }

        $registry.sessions = $remaining
        Save-Registry -Registry $registry -RegistryPath $store.registryPath
        ([ordered]@{
            removed = $true
            key = $key
        } | ConvertTo-Json -Depth 5)
        break
    }
}
