#requires -Version 7.0
# knowledge — Knowledge Engine: providers, journal, graph, agent-agnostic commands.

$script:DsKnowledgeProviders = [ordered]@{}

# Dot-source libraries first (providers register on load)
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'lib') -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

function Register-DsKnowledgeProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Collect,

        [string]$Description = '',

        [int]$Priority = 50,

        [scriptblock]$Detect,

        [scriptblock]$TestAuth,

        [scriptblock]$Authenticate,

        [switch]$Force
    )

    $key = $Name.ToLowerInvariant()
    if ($script:DsKnowledgeProviders.Contains($key) -and -not $Force) {
        Write-DsLog -Level Debug -Module knowledge -Message "Provider '$key' already registered"
        return
    }

    $script:DsKnowledgeProviders[$key] = [pscustomobject]@{
        Name         = $key
        Description  = $Description
        Priority     = $Priority
        Collect      = $Collect
        Detect       = $Detect
        TestAuth     = $TestAuth
        Authenticate = $Authenticate
    }
    Write-DsLog -Level Debug -Module knowledge -Message "Registered knowledge provider '$key' priority=$Priority"
}

function Get-DsKnowledgeProvider {
    [CmdletBinding()]
    param(
        [string]$Name
    )
    if ($Name) {
        $key = $Name.ToLowerInvariant()
        if ($script:DsKnowledgeProviders.Contains($key)) {
            return $script:DsKnowledgeProviders[$key]
        }
        return $null
    }
    return @($script:DsKnowledgeProviders.Values | Sort-Object Priority -Descending)
}

function Test-DsKnowledgeProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [ValidateSet('Detect', 'Auth')]
        [string]$Check = 'Detect'
    )

    $p = Get-DsKnowledgeProvider -Name $Name
    if (-not $p) { return $false }

    if ($Check -eq 'Detect') {
        if (-not $p.Detect) { return $true }
        try { return [bool](& $p.Detect) } catch { return $false }
    }

    if (-not $p.TestAuth) { return $true }
    try { return [bool](& $p.TestAuth) } catch { return $false }
}

function Get-DsKnowledgeProviderPriorityMap {
    [CmdletBinding()]
    param()
    $map = @{}
    foreach ($p in Get-DsKnowledgeProvider) {
        $map[$p.Name] = [int]$p.Priority
    }
    return $map
}

function Show-DsKnowledgeProviderStatus {
    [CmdletBinding()]
    param(
        [hashtable]$Status
    )
    Write-Host ''
    Write-Host 'Knowledge providers' -ForegroundColor Cyan
    Write-Host '  ✔ ok   ⚠ needs auth   – not configured   ❌ error' -ForegroundColor DarkGray
    foreach ($name in @($Status.Keys | Sort-Object)) {
        $st = $Status[$name]
        $mark = '❌'
        $color = 'DarkGray'
        $hint = ''
        switch ($st) {
            'ok' { $mark = '✔'; $color = 'Green' }
            'auth' { $mark = '⚠'; $color = 'Yellow'; $hint = '  (run auth in external terminal)' }
            'skip' { $mark = '–'; $color = 'DarkGray'; $hint = '  (not configured / N/A)' }
            default { $mark = '❌'; $color = 'Red' }
        }
        Write-Host ("  {0,-10} {1}{2}" -f $name, $mark, $hint) -ForegroundColor $color
    }
    Write-Host ''
}

function Invoke-DsReport {
    <#
    .SYNOPSIS
      Collect knowledge providers and write journal reports for a period.
    .EXAMPLE
      Invoke-DsReport today
      Invoke-DsReport -Period today -Project DemoApp
      Invoke-DsReport -Period today -ExcludeProject DevShell
      Invoke-DsReport -Period week -NonInteractive -Json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('today', 'week', 'month')]
        [string]$Period = 'today',

        [datetime]$Date = (Get-Date),

        [Alias('IncludeProject')]
        [string[]]$Project,

        [string[]]$ExcludeProject,

        [switch]$NonInteractive,

        [switch]$SkipAuth,

        [switch]$Json,

        [switch]$Path
    )

    $scope = New-DsKnowledgeScope -Project $Project -ExcludeProject $ExcludeProject
    $range = Get-DsKnowledgePeriodRange -Period $Period -Anchor $Date
    $range | Add-Member -NotePropertyName Scope -NotePropertyValue $scope -Force

    $journal = Initialize-DsKnowledgeStore -Date $range.Anchor

    if ($Path) {
        Write-Output $journal
        return $journal
    }

    if (-not $Json) {
        if ($scope.Active) {
            Write-Host ("knowledge scope: include=[{0}] exclude=[{1}]" -f `
                ($scope.IncludeProjects -join ', '), ($scope.ExcludeProjects -join ', ')) -ForegroundColor DarkGray
        }
        else {
            Write-Host 'knowledge scope: (all projects — tip: -Project DemoApp  or  -ExcludeProject DevShell)' -ForegroundColor DarkGray
        }
    }

    $providerStatus = [ordered]@{}
    $skippedAuth = [System.Collections.Generic.List[string]]::new()
    $fragments = [System.Collections.Generic.List[object]]::new()
    $displayStatus = [ordered]@{}

    foreach ($p in Get-DsKnowledgeProvider) {
        $available = $true
        if ($p.Detect) {
            try { $available = [bool](& $p.Detect) } catch { $available = $false }
        }

        if (-not $available) {
            # Not installed / not configured (e.g. Linear without API key) — not an error
            $providerStatus[$p.Name] = $false
            $displayStatus[$p.Name] = 'skip'
            continue
        }

        $authed = $true
        if ($p.TestAuth) {
            try { $authed = [bool](& $p.TestAuth) } catch { $authed = $false }
        }

        if (-not $authed) {
            $ok = Request-DsKnowledgeAuth -Provider $p.Name -Authenticate $p.Authenticate -NonInteractive:$NonInteractive -SkipAuth:$SkipAuth
            if (-not $ok) {
                $providerStatus[$p.Name] = $false
                $skippedAuth.Add($p.Name) | Out-Null
                $displayStatus[$p.Name] = 'auth'
                continue
            }
            try { $authed = [bool](& $p.TestAuth) } catch { $authed = $false }
            if (-not $authed) {
                $providerStatus[$p.Name] = $false
                $skippedAuth.Add($p.Name) | Out-Null
                $displayStatus[$p.Name] = 'auth'
                continue
            }
        }

        try {
            $frag = & $p.Collect -Range $range
            if ($frag) { $fragments.Add($frag) | Out-Null }
            $providerStatus[$p.Name] = $true
            $displayStatus[$p.Name] = 'ok'
        }
        catch {
            Write-DsLog -Level Warn -Module knowledge -Message "Collect $($p.Name) failed: $($_.Exception.Message)"
            $providerStatus[$p.Name] = $false
            $displayStatus[$p.Name] = 'no'
            $fragments.Add((New-DsKnowledgeFragment -Provider $p.Name -Claims @(
                        New-DsKnowledgeClaim -Text ("Provider {0} collect error: {1}" -f $p.Name, $_.Exception.Message) -Sources @($p.Name) -Confidence 30 -Kind context -Unverified
                    ))) | Out-Null
        }
    }

    if (-not $Json -and -not $NonInteractive) {
        Show-DsKnowledgeProviderStatus -Status $displayStatus
    }
    elseif (-not $Json) {
        Write-Host ("knowledge: providers ok=[{0}] skippedAuth=[{1}]" -f `
            (($providerStatus.Keys | Where-Object { $providerStatus[$_] }) -join ','), `
            ($skippedAuth -join ',')) -ForegroundColor DarkGray
    }

    $merged = Merge-DsKnowledgeFragments -Fragments @($fragments) -ProviderPriority (Get-DsKnowledgeProviderPriorityMap)
    $graphResult = Update-DsKnowledgeGraph -Entities $merged.Entities -Edges $merged.Edges

    $psHash = @{}
    foreach ($k in $providerStatus.Keys) { $psHash[[string]$k] = [bool]$providerStatus[$k] }

    $meta = New-DsKnowledgeMetadata -Merged $merged -Date $range.Anchor -Period $Period `
        -ProviderStatus $psHash -SkippedAuth @($skippedAuth) -GraphDelta @($graphResult.GraphDelta) -Scope $scope

    Write-DsKnowledgeJson -Path (Join-Path $journal 'context.json') -Object $merged
    Write-DsKnowledgeJson -Path (Join-Path $journal 'metadata.json') -Object $meta
    Write-DsKnowledgeExecutiveReport -Path (Join-Path $journal 'executive.md') -Merged $merged -Date $range.Anchor -Period $Period
    Write-DsKnowledgeTechnicalReport -Path (Join-Path $journal 'technical.md') -Merged $merged -Date $range.Anchor -Period $Period
    Write-DsKnowledgeKnowledgeReport -Path (Join-Path $journal 'knowledge.md') -Merged $merged -Date $range.Anchor
    Update-DsKnowledgeMetadataIndex -Metadata $meta

    $result = [pscustomobject]@{
        Journal     = $journal
        Period      = $Period
        Date        = $range.Anchor.ToString('yyyy-MM-dd')
        Scope       = $scope
        Providers   = $providerStatus
        SkippedAuth = @($skippedAuth)
        Confidence  = $merged.Confidence
        Claims      = $merged.Claims.Count
        GraphDelta  = @($graphResult.GraphDelta)
        Files       = @(
            (Join-Path $journal 'executive.md')
            (Join-Path $journal 'technical.md')
            (Join-Path $journal 'knowledge.md')
            (Join-Path $journal 'metadata.json')
        )
    }

    if ($Json) {
        return ($result | ConvertTo-Json -Depth 8)
    }

    Write-Host ("knowledge journal → {0}" -f $journal) -ForegroundColor DarkGray
    Write-Host ("  claims={0} confidence={1}% entitiesΔ={2}" -f $result.Claims, $result.Confidence, $result.GraphDelta.Count)
    return $result
}

function Read-DsKnowledgeNotePaste {
    <#
    .SYNOPSIS
      Read a multi-line note from the console without leaving the shell.
    #>
    [CmdletBinding()]
    param()

    Write-Host "Pegá la nota (multilínea). Terminá con una línea solo con '.' — no hace falta salir de la shell." -ForegroundColor Cyan
    $lines = [System.Collections.Generic.List[string]]::new()
    while ($true) {
        try {
            $line = Read-Host
        }
        catch {
            break
        }
        if ($null -eq $line) { break }
        if ($line -eq '.') { break }
        $lines.Add($line) | Out-Null
    }
    return ($lines -join "`n").Trim()
}

function Add-DsKnowledgeNote {
    <#
    .SYNOPSIS
      Append a manual knowledge note for today (feeds notes provider).
    .EXAMPLE
      Add-DsKnowledgeNote 'postponed depot change'
      Add-DsKnowledgeNote -Project DemoApp 'validated route endpoint'
      Add-DsKnowledgeNote -Project Acme -Paste
      Add-DsKnowledgeNote -Project Acme @'
      Relevamiento funcional...
      '@
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments, ParameterSetName = 'Text')]
        [string[]]$Text,

        [Parameter(ParameterSetName = 'File', Mandatory)]
        [string]$File,

        [Parameter(ParameterSetName = 'Paste')]
        [switch]$Paste,

        [string]$Project
    )

    $dir = Get-DsKnowledgeNotesDir
    $outFile = Join-Path $dir ('{0:yyyy-MM-dd}.md' -f (Get-Date))

    $body = ''
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        $path = $File
        if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
            $path = Expand-DsPath -Path $path
        }
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Note file not found: $path"
        }
        $body = (Get-Content -LiteralPath $path -Raw -Encoding utf8).Trim()
    }
    elseif ($Paste -or ($PSCmdlet.ParameterSetName -eq 'Text' -and -not $Text)) {
        # Prefer staying in-shell: paste mode / here-string empty → interactive capture
        if ([Console]::IsInputRedirected) {
            $body = [Console]::In.ReadToEnd().Trim()
        }
        else {
            $body = Read-DsKnowledgeNotePaste
        }
    }
    else {
        # Preserve newlines inside a single here-string argument; join multi-arg short notes with space
        if (@($Text).Count -eq 1) {
            $body = [string]$Text[0]
        }
        else {
            $body = ($Text -join ' ')
        }
        $body = $body.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($body)) {
        throw @"
Note text is empty.
Usá (sin salir de la shell):
  dev note -Project Acme -Paste
  dev note -Project Acme @'
  texto largo...
  '@
Opcional: -File solo si ya tenés un .md LOCAL (nunca en el repo público).
"@
    }

    if ($Project) {
        $tag = '[{0}]' -f $Project.Trim()
        if ($body -notmatch ('(?m)^\s*\[{0}\]' -f [regex]::Escape($Project.Trim()))) {
            # Keep tag on its own line for multi-line bodies so reports can scope-match
            if ($body -match "`n") {
                $body = "{0}`n{1}" -f $tag, $body
            }
            else {
                $body = "{0} {1}" -f $tag, $body
            }
        }
    }

    # Multi-line imports: one block with timestamp header
    $stamp = '- {0:HH:mm}' -f (Get-Date)
    if ($body -match "`n") {
        $indented = ($body -split "`r?`n" | ForEach-Object { "  $_" }) -join "`n"
        $block = "{0}`n{1}`n" -f $stamp, $indented
        Add-Content -LiteralPath $outFile -Value $block -Encoding utf8
    }
    else {
        Add-Content -LiteralPath $outFile -Value ("{0} {1}" -f $stamp, $body) -Encoding utf8
    }

    Write-Host "knowledge note → $outFile" -ForegroundColor DarkGray
    return $outFile
}

function Invoke-DsConnect {
    <#
    .SYNOPSIS
      Authenticate a knowledge provider (linear, github, azure).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('linear', 'github', 'azure')]
        [string]$Provider,

        [switch]$NonInteractive
    )

    $p = Get-DsKnowledgeProvider -Name $Provider
    if (-not $p) {
        Write-Error "Unknown knowledge provider: $Provider"
        return 1
    }

    if ($NonInteractive) {
        if (Test-DsKnowledgeProvider -Name $Provider -Check Auth) {
            Write-Output "already-authenticated:$Provider"
            return 0
        }
        Write-Error "Provider $Provider is not authenticated. Cannot prompt in -NonInteractive mode."
        return 2
    }

    if (-not $p.Authenticate) {
        Write-Host "Provider $Provider has no Authenticate hook." -ForegroundColor Yellow
        return 1
    }

    try {
        & $p.Authenticate
        Write-Host "Connected: $Provider" -ForegroundColor Green
        return 0
    }
    catch {
        Write-Error $_.Exception.Message
        return 1
    }
}

function Search-DsKnowledge {
    <#
    .SYNOPSIS
      Search knowledge graph, metadata index, then journal text. Prefers graph over git.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Query,

        [int]$Top = 20,

        [switch]$Json
    )

    $q = ($Query -join ' ').Trim()
    $hits = [System.Collections.Generic.List[object]]::new()

    foreach ($h in @(Search-DsKnowledgeGraph -Query $q -Top $Top)) {
        $hits.Add([pscustomobject]@{
                Source = 'graph'
                Score  = $h.Score
                Id     = $h.Id
                Label  = $h.Label
                Type   = $h.Type
                Detail = $h
            }) | Out-Null
    }

    $indexPath = Join-Path (Get-DsKnowledgeIndexDir) 'metadata-index.json'
    foreach ($m in @(Read-DsKnowledgeJson -Path $indexPath -Default @())) {
        $blob = ($m | ConvertTo-Json -Compress -Depth 6)
        if ($blob -and $blob.ToLowerInvariant() -like "*$($q.ToLowerInvariant())*") {
            $hits.Add([pscustomobject]@{
                    Source = 'metadata-index'
                    Score  = 70
                    Id     = "journal:$($m.date)"
                    Label  = "Journal $($m.date) (confidence $($m.confidence))"
                    Type   = 'journal'
                    Detail = $m
                }) | Out-Null
        }
    }

    $store = Get-DsKnowledgeStoreRoot
    $journalRoot = Join-Path $store 'journal'
    if (Test-Path -LiteralPath $journalRoot) {
        Get-ChildItem -LiteralPath $journalRoot -Recurse -Filter 'knowledge.md' -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content.ToLowerInvariant() -like "*$($q.ToLowerInvariant())*") {
                    $hits.Add([pscustomobject]@{
                            Source = 'knowledge.md'
                            Score  = 55
                            Id     = $_.Directory.Name
                            Label  = $_.FullName
                            Type   = 'document'
                            Detail = ($content -split "`n" | Where-Object { $_ -like "*$q*" } | Select-Object -First 5)
                        }) | Out-Null
                }
            }
    }

    $ranked = @($hits | Sort-Object Score -Descending | Select-Object -First $Top)

    if ($Json) {
        return ($ranked | ConvertTo-Json -Depth 8)
    }

    if ($ranked.Count -eq 0) {
        Write-Host "No knowledge hits for: $q" -ForegroundColor Yellow
    }
    else {
        foreach ($h in $ranked) {
            Write-Host ("[{0,3}] {1,-16} {2}" -f $h.Score, $h.Source, $h.Label)
        }
    }
    return $ranked
}

function Invoke-DsAsk {
    <#
    .SYNOPSIS
      Answer using Knowledge Engine retrieval, then any registered AI provider.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Question,

        [string]$Provider,

        [switch]$NonInteractive
    )

    $q = ($Question -join ' ').Trim()
    $hits = @(Search-DsKnowledge -Query $q -Top 12)
    $journalToday = Get-DsKnowledgeJournalPath -Date (Get-Date)
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in @(
            (Join-Path $journalToday 'knowledge.md'),
            (Join-Path $journalToday 'metadata.json'),
            (Join-Path (Get-DsKnowledgeIndexDir) 'metadata-index.json')
        )) {
        if (Test-Path -LiteralPath $candidate) { $paths.Add($candidate) | Out-Null }
    }

    $contextBlocks = [System.Text.StringBuilder]::new()
    [void]$contextBlocks.AppendLine('You must answer using ONLY the Knowledge Engine context below. Prefer graph/metadata hits over git. If unknown, say so explicitly. Never invent facts.')
    [void]$contextBlocks.AppendLine()
    [void]$contextBlocks.AppendLine('## Retrieval hits')
    if ($hits.Count -eq 0) {
        [void]$contextBlocks.AppendLine('(no hits)')
    }
    else {
        foreach ($h in $hits) {
            [void]$contextBlocks.AppendLine(("- [{0}] {1}: {2}" -f $h.Source, $h.Id, $h.Label))
        }
    }
    [void]$contextBlocks.AppendLine()
    [void]$contextBlocks.AppendLine('## Local knowledge files')
    foreach ($p in $paths) {
        [void]$contextBlocks.AppendLine("--- FILE: $p ---")
        $raw = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
        if ($raw -and $raw.Length -gt 8000) { $raw = $raw.Substring(0, 8000) + "`n...(truncated)" }
        [void]$contextBlocks.AppendLine($raw)
    }
    [void]$contextBlocks.AppendLine()
    [void]$contextBlocks.AppendLine("## Question")
    [void]$contextBlocks.AppendLine($q)

    $prompt = $contextBlocks.ToString()

    if (-not (Get-Command Invoke-DsAi -ErrorAction SilentlyContinue)) {
        Write-Host 'Invoke-DsAi not available; printing retrieval context only.' -ForegroundColor Yellow
        Write-Output $prompt
        return
    }

    $aiArgs = @{ Prompt = $prompt }
    if ($Provider) { $aiArgs['Provider'] = $Provider }
    Invoke-DsAi @aiArgs
}

function Export-DsKnowledge {
    <#
    .SYNOPSIS
      Export journal range as a markdown/json bundle directory (or zip if Compress).
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('today', 'week', 'month')]
        [string]$Period = 'today',

        [datetime]$Date = (Get-Date),

        [Parameter(Mandatory)]
        [string]$OutPath,

        [switch]$Compress
    )

    $range = Get-DsKnowledgePeriodRange -Period $Period -Anchor $Date
    if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
        $OutPath = Expand-DsPath -Path $OutPath
    }

    $bundle = Join-Path $OutPath ("devshell-knowledge-{0}-{1:yyyy-MM-dd}" -f $Period, $range.Anchor)
    if (-not (Test-Path -LiteralPath $bundle)) {
        New-Item -ItemType Directory -Path $bundle -Force | Out-Null
    }

    $cursor = $range.Start.Date
    $copied = 0
    while ($cursor -le $range.End.Date) {
        $src = Get-DsKnowledgeJournalPath -Date $cursor
        if (Test-Path -LiteralPath $src) {
            $dest = Join-Path $bundle $cursor.ToString('yyyy-MM-dd')
            Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
            $copied++
        }
        $cursor = $cursor.AddDays(1)
    }

    $graphDir = Get-DsKnowledgeGraphDir
    if (Test-Path -LiteralPath $graphDir) {
        Copy-Item -LiteralPath $graphDir -Destination (Join-Path $bundle 'graph') -Recurse -Force
    }
    $indexDir = Get-DsKnowledgeIndexDir
    if (Test-Path -LiteralPath $indexDir) {
        Copy-Item -LiteralPath $indexDir -Destination (Join-Path $bundle 'index') -Recurse -Force
    }

    Write-DsKnowledgeJson -Path (Join-Path $bundle 'export-meta.json') -Object @{
        period = $Period
        start  = $range.Start.ToString('o')
        end    = $range.End.ToString('o')
        days   = $copied
    }

    if ($Compress) {
        $zip = "$bundle.zip"
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
        Compress-Archive -Path $bundle -DestinationPath $zip -Force
        Write-Host "Exported → $zip" -ForegroundColor DarkGray
        return $zip
    }

    Write-Host "Exported → $bundle ($copied day(s))" -ForegroundColor DarkGray
    return $bundle
}

function Invoke-DsDev {
    <#
    .SYNOPSIS
      Unified DevShell knowledge CLI: report | search | ask | note | connect | export.
    .EXAMPLE
      dev report today
      dev ask 'what did we decide about Planner?'
      dev note 'postponed Company.depot change'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('report', 'search', 'ask', 'note', 'connect', 'export', 'help')]
        [string]$Command = 'help',

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$ArgsRest
    )

    switch ($Command) {
        'help' {
            Write-Host @'
dev report [today|week|month] [-Project X] [-ExcludeProject Y]
dev search <query>              Search graph + index + knowledge.md
dev ask <question>              Retrieve KE context → Invoke-DsAi
dev note [-Project X] <text> | -Paste | -File path.md
dev connect <linear|github|azure>
dev export [today|week|month] -OutPath <path>

Examples:
  dev report today -Project DemoApp
  dev report today -Project DemoApp,Acme
  dev report today -ExcludeProject DevShell
  # Texto corto:
  dev note -Project DemoApp 'Jornada DemoApp + Acme'
  # Texto largo SIN salir de la shell (recomendado):
  dev note -Project Acme -Paste
  # o here-string:
  dev note -Project Acme @'
  Resumen funcional...
  '@
  # -File solo para .md LOCAL fuera del repo (nunca datos de cliente en git público)
  # GitHub auth (external terminal only):
  gh auth login -h github.com -p https -w
  # Linear: only appears if you configure an API key (optional)
  # Never commit client/private notes to this public repo — use ~/.devshell/knowledge/notes
'@
            return
        }
        'report' {
            $period = 'today'
            $ni = $false
            $json = $false
            $projects = [System.Collections.Generic.List[string]]::new()
            $excludes = [System.Collections.Generic.List[string]]::new()
            $args = @($ArgsRest)
            for ($i = 0; $i -lt $args.Count; $i++) {
                $a = $args[$i]
                if ($a -in @('today', 'week', 'month')) { $period = $a }
                elseif ($a -eq '-NonInteractive') { $ni = $true }
                elseif ($a -eq '-Json') { $json = $true }
                elseif ($a -in @('-Project', '-IncludeProject') -and ($i + 1) -lt $args.Count) {
                    $projects.Add($args[++$i]) | Out-Null
                }
                elseif ($a -eq '-ExcludeProject' -and ($i + 1) -lt $args.Count) {
                    $excludes.Add($args[++$i]) | Out-Null
                }
            }
            $splat = @{
                Period          = $period
                NonInteractive  = $ni
                Json            = $json
            }
            if ($projects.Count -gt 0) { $splat['Project'] = @($projects) }
            if ($excludes.Count -gt 0) { $splat['ExcludeProject'] = @($excludes) }
            return Invoke-DsReport @splat
        }
        'search' {
            return Search-DsKnowledge -Query @($ArgsRest)
        }
        'ask' {
            return Invoke-DsAsk -Question @($ArgsRest)
        }
        'note' {
            $project = $null
            $file = $null
            $paste = $false
            $textParts = [System.Collections.Generic.List[string]]::new()
            $args = @($ArgsRest)
            for ($i = 0; $i -lt $args.Count; $i++) {
                $a = $args[$i]
                if ($a -eq '-Project' -and ($i + 1) -lt $args.Count) {
                    $project = $args[++$i]
                }
                elseif ($a -eq '-File' -and ($i + 1) -lt $args.Count) {
                    $file = $args[++$i]
                }
                elseif ($a -eq '-Paste') {
                    $paste = $true
                }
                else {
                    $textParts.Add([string]$a) | Out-Null
                }
            }
            if ($file) {
                if ($project) { return Add-DsKnowledgeNote -Project $project -File $file }
                return Add-DsKnowledgeNote -File $file
            }
            if ($paste -or $textParts.Count -eq 0) {
                # No text → stay in shell and paste (usability); -Paste is explicit
                if ($project) { return Add-DsKnowledgeNote -Project $project -Paste }
                return Add-DsKnowledgeNote -Paste
            }
            if ($project) {
                return Add-DsKnowledgeNote -Project $project -Text @($textParts)
            }
            return Add-DsKnowledgeNote -Text @($textParts)
        }
        'connect' {
            $prov = if ($ArgsRest -and $ArgsRest[0]) { $ArgsRest[0] } else { $null }
            if (-not $prov) {
                Write-Host 'Usage: dev connect linear|github|azure' -ForegroundColor Yellow
                return
            }
            return Invoke-DsConnect -Provider $prov
        }
        'export' {
            $period = 'today'
            $out = $null
            $compress = $false
            for ($i = 0; $i -lt @($ArgsRest).Count; $i++) {
                $a = $ArgsRest[$i]
                if ($a -in @('today', 'week', 'month')) { $period = $a }
                elseif ($a -eq '-OutPath' -and ($i + 1) -lt $ArgsRest.Count) { $out = $ArgsRest[++$i] }
                elseif ($a -eq '-Compress') { $compress = $true }
                elseif (-not $out -and $a -notlike '-*') { $out = $a }
            }
            if (-not $out) {
                Write-Host 'Usage: dev export [today|week|month] -OutPath <dir>' -ForegroundColor Yellow
                return
            }
            return Export-DsKnowledge -Period $period -OutPath $out -Compress:$compress
        }
    }
}

Set-Alias -Name dev -Value Invoke-DsDev -Scope Script -Force

function Register-DsKnowledgeOnLoad {
    Write-DsLog -Level Debug -Module knowledge -Message (
        'Knowledge providers: ' + ((Get-DsKnowledgeProvider | ForEach-Object Name) -join ', ')
    )
}

function Register-DsKnowledgeKeys {
    if (-not (Get-Command Register-DsKey -ErrorAction SilentlyContinue)) { return }
    $null = Register-DsKey -Chord 'Ctrl+Alt+K' -Module knowledge -Description 'Knowledge report today' -Action {
        Invoke-DsReport -Period today
    }
}

# Register providers (after Register-DsKnowledgeProvider exists)
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'providers') -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    'Register-DsKnowledgeProvider',
    'Get-DsKnowledgeProvider',
    'Test-DsKnowledgeProvider',
    'Get-DsKnowledgeRoot',
    'Get-DsKnowledgeJournalPath',
    'Invoke-DsReport',
    'Add-DsKnowledgeNote',
    'Invoke-DsConnect',
    'Search-DsKnowledge',
    'Invoke-DsAsk',
    'Export-DsKnowledge',
    'Invoke-DsDev',
    'Get-DsKnowledgeGraph',
    'Register-DsKnowledgeOnLoad',
    'Register-DsKnowledgeKeys'
) -Alias @(
    'dev'
)
