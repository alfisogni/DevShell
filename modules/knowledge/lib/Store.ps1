#requires -Version 7.0
# Knowledge store paths and IO (plain files under ~/.devshell/knowledge).

function Get-DsKnowledgeRoot {
    [CmdletBinding()]
    param()

    if ($env:DEVSHELL_KNOWLEDGE_ROOT) {
        $root = $env:DEVSHELL_KNOWLEDGE_ROOT
        if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
            return [string](Expand-DsPath -Path $root)
        }
        if ($root -like '~*') { return [string]($root -replace '^~', $HOME) }
        return [string]$root
    }

    $root = $null
    try { $root = Get-DsConfig -Path 'Knowledge.Root' } catch { }
    if (-not $root) {
        try { $root = Get-DsConfig -Path 'KnowledgeRoot' } catch { }
    }
    if (-not $root) { $root = Join-Path $HOME '.devshell' }

    if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
        $root = Expand-DsPath -Path $root
    }
    elseif ($root -like '~*' ) {
        $root = $root -replace '^~', $HOME
    }

    return [string]$root
}

function Get-DsKnowledgeStoreRoot {
    [CmdletBinding()]
    param()
    return Join-Path (Get-DsKnowledgeRoot) 'knowledge'
}

function Get-DsKnowledgeJournalPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [datetime]$Date
    )

    $store = Get-DsKnowledgeStoreRoot
    $y = $Date.ToString('yyyy')
    $m = $Date.ToString('MM')
    $d = $Date.ToString('yyyy-MM-dd')
    return Join-Path $store "journal/$y/$m/$d"
}

function Get-DsKnowledgeGraphDir {
    [CmdletBinding()]
    param()
    return Join-Path (Get-DsKnowledgeStoreRoot) 'graph'
}

function Get-DsKnowledgeIndexDir {
    [CmdletBinding()]
    param()
    return Join-Path (Get-DsKnowledgeStoreRoot) 'index'
}

function Get-DsKnowledgeCredentialsDir {
    [CmdletBinding()]
    param()
    return Join-Path (Get-DsKnowledgeRoot) 'credentials'
}

function Initialize-DsKnowledgeStore {
    [CmdletBinding()]
    param(
        [datetime]$Date = (Get-Date)
    )

    $journal = Get-DsKnowledgeJournalPath -Date $Date
    $graph = Get-DsKnowledgeGraphDir
    $index = Get-DsKnowledgeIndexDir
    $creds = Get-DsKnowledgeCredentialsDir

    foreach ($dir in @($journal, $graph, $index, $creds)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    foreach ($pair in @(
            @{ Path = (Join-Path $graph 'entities.json'); Value = '[]' },
            @{ Path = (Join-Path $graph 'edges.json'); Value = '[]' },
            @{ Path = (Join-Path $index 'metadata-index.json'); Value = '[]' }
        )) {
        if (-not (Test-Path -LiteralPath $pair.Path)) {
            Set-Content -LiteralPath $pair.Path -Value $pair.Value -Encoding utf8
        }
    }

    return $journal
}

function Get-DsKnowledgeNotesDir {
    [CmdletBinding()]
    param()

    $dir = Join-Path (Get-DsKnowledgeStoreRoot) 'notes'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-DsKnowledgePeriodRange {
    [CmdletBinding()]
    param(
        [ValidateSet('today', 'week', 'month')]
        [string]$Period = 'today',

        [datetime]$Anchor = (Get-Date)
    )

    $end = Get-Date -Date $Anchor.Date -Hour 23 -Minute 59 -Second 59
    switch ($Period) {
        'today' {
            $start = $Anchor.Date
        }
        'week' {
            # Monday-start week containing Anchor
            $dow = [int]$Anchor.DayOfWeek
            if ($dow -eq 0) { $dow = 7 }
            $start = $Anchor.Date.AddDays(1 - $dow)
        }
        'month' {
            $start = Get-Date -Year $Anchor.Year -Month $Anchor.Month -Day 1
        }
    }

    return [pscustomobject]@{
        Period = $Period
        Start  = $start
        End    = $end
        Anchor = $Anchor.Date
    }
}

function Write-DsKnowledgeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Object
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = $Object | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

function Read-DsKnowledgeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        $Default = $null
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $Default }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    try {
        return $raw | ConvertFrom-Json -Depth 20
    }
    catch {
        Write-DsLog -Level Warn -Module knowledge -Message "JSON parse failed: $Path — $($_.Exception.Message)"
        return $Default
    }
}
