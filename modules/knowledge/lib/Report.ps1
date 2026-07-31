#requires -Version 7.0
# Report writers — executive / technical / knowledge.md from merged context only.

function Get-DsKnowledgeClaimsByKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Merged,

        [string[]]$Kinds
    )
    return @($Merged.Claims | Where-Object { $Kinds -contains $_.Kind })
}

function Write-DsKnowledgeExecutiveReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Merged,

        [Parameter(Mandatory)]
        [datetime]$Date,

        [string]$Period = 'today'
    )

    $context = @(Get-DsKnowledgeClaimsByKind -Merged $Merged -Kinds @('context'))
    $facts = @(Get-DsKnowledgeClaimsByKind -Merged $Merged -Kinds @('fact', 'discovery'))
    $decisions = @(Get-DsKnowledgeClaimsByKind -Merged $Merged -Kinds @('decision'))
    $pending = @(Get-DsKnowledgeClaimsByKind -Merged $Merged -Kinds @('pending'))

    # Strip implementation jargon for executive tone — filter claims that look file/class heavy
    $isImpl = {
        param($t)
        $t -match '\.(cs|ts|tsx|js|ps1|py)\b' -or $t -match '\b(class|function|method|namespace)\b'
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Executive Summary")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(("Date: {0:yyyy-MM-dd} | Period: {1} | Confidence: {2}%" -f $Date, $Period, $Merged.Confidence))
    [void]$sb.AppendLine(("Sources: {0}" -f (($Merged.Providers) -join ', ')))
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Contexto")
    if ($context.Count -eq 0) {
        [void]$sb.AppendLine("- (sin contexto verificado de las fuentes disponibles)")
    }
    else {
        foreach ($c in $context) {
            if (& $isImpl $c.Text) { continue }
            [void]$sb.AppendLine("- $($c.Text)")
        }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Qué ocurrió")
    $happened = @($facts | Where-Object { -not (& $isImpl $_.Text) })
    if ($happened.Count -eq 0) {
        [void]$sb.AppendLine("- (sin hechos verificados para este período)")
    }
    else {
        foreach ($c in $happened) { [void]$sb.AppendLine("- $($c.Text)") }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Qué hicimos")
    $did = @($decisions + $facts | Where-Object { $_.Kind -eq 'decision' -or ($_.Text -match '\b(implement|fix|merge|ship|entreg|resolv)') })
    $did = @($did | Where-Object { -not (& $isImpl $_.Text) } | Select-Object -Unique -Property Text)
    if ($did.Count -eq 0) {
        [void]$sb.AppendLine("- (sin acciones verificadas)")
    }
    else {
        foreach ($c in $did) { [void]$sb.AppendLine("- $($c.Text)") }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Qué descubrimos")
    $disc = @(Get-DsKnowledgeClaimsByKind -Merged $Merged -Kinds @('discovery') | Where-Object { -not (& $isImpl $_.Text) })
    if ($disc.Count -eq 0) {
        [void]$sb.AppendLine("- (sin descubrimientos verificados)")
    }
    else {
        foreach ($c in $disc) { [void]$sb.AppendLine("- $($c.Text)") }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Qué quedó resuelto")
    $resolved = @($facts | Where-Object { $_.Text -match '\b(resolv|fix|cerrad|complet|done|merged)\b' -and -not (& $isImpl $_.Text) })
    if ($resolved.Count -eq 0) {
        [void]$sb.AppendLine("- (sin ítems resueltos verificados)")
    }
    else {
        foreach ($c in $resolved) { [void]$sb.AppendLine("- $($c.Text)") }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Qué falta")
    if ($pending.Count -eq 0) {
        [void]$sb.AppendLine("- (sin pendientes registrados)")
    }
    else {
        foreach ($c in $pending) {
            if (& $isImpl $c.Text) { continue }
            [void]$sb.AppendLine("- $($c.Text)")
        }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Próximos pasos")
    if ($pending.Count -eq 0) {
        [void]$sb.AppendLine("- Continuar según prioridades del equipo.")
    }
    else {
        foreach ($c in $pending | Select-Object -First 5) {
            if (& $isImpl $c.Text) { continue }
            [void]$sb.AppendLine("- $($c.Text)")
        }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## Cierre")
    [void]$sb.AppendLine(("Resumen generado solo a partir de fuentes: {0}. Nada fue inventado." -f (($Merged.Providers) -join ', ')))
    [void]$sb.AppendLine()

    Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding utf8
}

function Write-DsKnowledgeTechnicalReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Merged,

        [Parameter(Mandatory)]
        [datetime]$Date,

        [string]$Period = 'today'
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Technical Summary")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(("Date: {0:yyyy-MM-dd} | Period: {1} | Confidence: {2}%" -f $Date, $Period, $Merged.Confidence))
    [void]$sb.AppendLine()

    $section = {
        param($title, $kinds, $fallback)
        [void]$sb.AppendLine("## $title")
        $items = @(Get-DsKnowledgeClaimsByKind -Merged $Merged -Kinds $kinds)
        if ($items.Count -eq 0) {
            [void]$sb.AppendLine("- $fallback")
        }
        else {
            foreach ($c in $items) {
                $mark = if ($c.Unverified) { ' *(unverified)*' } else { '' }
                $src = ($c.Sources -join '+')
                [void]$sb.AppendLine("- $($c.Text)$mark  _[$src · $($c.Confidence)%]_")
            }
        }
        [void]$sb.AppendLine()
    }

    & $section 'Problema' @('context', 'fact') '(sin problema declarado en fuentes)'
    & $section 'Root Cause' @('discovery') '(sin root cause verificado)'
    & $section 'Decisiones técnicas' @('decision') '(sin decisiones registradas)'
    & $section 'Arquitectura' @('decision', 'discovery') '(sin notas de arquitectura)'
    & $section 'Cambios implementados' @('fact') '(sin cambios listados)'
    & $section 'Riesgos' @('risk') '(sin riesgos registrados)'
    & $section 'Pendientes' @('pending') '(sin pendientes)'

    [void]$sb.AppendLine('## Archivos')
    $files = @()
    if ($Merged.Data.git -and $Merged.Data.git.files) {
        $files = @($Merged.Data.git.files)
    }
    if ($files.Count -eq 0) {
        [void]$sb.AppendLine('- (sin archivos reportados por git)')
    }
    else {
        foreach ($f in $files | Select-Object -First 40) {
            [void]$sb.AppendLine("- $f")
        }
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Componentes')
    $comps = @($Merged.Entities | Where-Object { $_.Type -eq 'Component' })
    if ($comps.Count -eq 0) {
        [void]$sb.AppendLine('- (sin componentes en el grafo para este período)')
    }
    else {
        foreach ($c in $comps) { [void]$sb.AppendLine(("- {0} ({1})" -f $c.Label, $c.Id)) }
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Testing')
    $tests = @($Merged.Claims | Where-Object { $_.Text -match '\b(test|pester|spec|qa)\b' })
    if ($tests.Count -eq 0) {
        [void]$sb.AppendLine('- (sin evidencias de testing en fuentes)')
    }
    else {
        foreach ($c in $tests) { [void]$sb.AppendLine("- $($c.Text)") }
    }
    [void]$sb.AppendLine()

    Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding utf8
}

function Write-DsKnowledgeKnowledgeReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Merged,

        [Parameter(Mandatory)]
        [datetime]$Date
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Knowledge Generated')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(("Date: {0:yyyy-MM-dd}" -f $Date))
    [void]$sb.AppendLine()

    $verified = @($Merged.Claims | Where-Object { -not $_.Unverified } | Sort-Object Confidence -Descending)
    $unverified = @($Merged.Claims | Where-Object { $_.Unverified })

    if ($verified.Count -eq 0 -and $unverified.Count -eq 0) {
        [void]$sb.AppendLine('- (no knowledge claims for this period)')
    }

    foreach ($c in $verified) {
        [void]$sb.AppendLine(("• {0}  _[{1} · {2}%]_" -f $c.Text, ($c.Sources -join '+'), $c.Confidence))
    }

    if ($unverified.Count -gt 0) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Unverified')
        foreach ($c in $unverified) {
            [void]$sb.AppendLine(("• {0}  _[{1}]_" -f $c.Text, ($c.Sources -join '+')))
        }
    }

    [void]$sb.AppendLine()
    Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding utf8
}

function New-DsKnowledgeMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Merged,

        [Parameter(Mandatory)]
        [datetime]$Date,

        [string]$Period = 'today',

        [hashtable]$ProviderStatus = @{},

        [string[]]$SkippedAuth = @(),

        [string[]]$GraphDelta = @(),

        $Scope = $null
    )

    $projects = [System.Collections.Generic.List[string]]::new()
    $repos = [System.Collections.Generic.List[string]]::new()
    $commits = [System.Collections.Generic.List[string]]::new()
    $prs = [System.Collections.Generic.List[object]]::new()
    $workItems = [System.Collections.Generic.List[object]]::new()
    $tags = [System.Collections.Generic.List[string]]::new()

    if ($Merged.Data.git) {
        $g = $Merged.Data.git
        if ($g.repository) { $repos.Add([string]$g.repository) | Out-Null }
        if ($g.project) { $projects.Add([string]$g.project) | Out-Null }
        foreach ($c in @($g.commits)) { if ($c) { $commits.Add([string]$c) | Out-Null } }
        foreach ($t in @($g.tags)) { if ($t) { $tags.Add([string]$t) | Out-Null } }
    }
    if ($Merged.Data.github) {
        foreach ($p in @($Merged.Data.github.pullRequests)) { if ($null -ne $p) { $prs.Add($p) | Out-Null } }
        foreach ($t in @($Merged.Data.github.labels)) { if ($t) { $tags.Add([string]$t) | Out-Null } }
    }
    if ($Merged.Data.azure) {
        foreach ($w in @($Merged.Data.azure.workItems)) { if ($null -ne $w) { $workItems.Add($w) | Out-Null } }
        foreach ($p in @($Merged.Data.azure.pullRequests)) { if ($null -ne $p) { $prs.Add($p) | Out-Null } }
    }
    if ($Merged.Data.linear) {
        foreach ($w in @($Merged.Data.linear.issues)) { if ($null -ne $w) { $workItems.Add($w) | Out-Null } }
    }

    foreach ($c in @($Merged.Claims)) {
        if ($c.Kind) { $tags.Add([string]$c.Kind) | Out-Null }
        if ($c.Meta -and $c.Meta.project) { $projects.Add([string]$c.Meta.project) | Out-Null }
    }
    foreach ($e in @($Merged.Entities)) {
        if ($e.Type -eq 'Project' -and $e.Label) { $projects.Add([string]$e.Label) | Out-Null }
        if ($e.Type -eq 'Repository' -and $e.Label) { $repos.Add([string]$e.Label) | Out-Null }
    }

    $scopeBlock = $null
    if ($Scope) {
        $scopeBlock = @{
            include = @($Scope.IncludeProjects)
            exclude = @($Scope.ExcludeProjects)
            active  = [bool]$Scope.Active
        }
    }

    return [ordered]@{
        date         = $Date.ToString('yyyy-MM-dd')
        period       = $Period
        scope        = $scopeBlock
        projects     = @($projects | Select-Object -Unique)
        repositories = @($repos | Select-Object -Unique)
        providers    = $ProviderStatus
        skippedAuth  = @($SkippedAuth)
        commits      = @($commits | Select-Object -Unique)
        pullRequests = @($prs | Select-Object -Unique)
        workItems    = @($workItems | Select-Object -Unique)
        tags         = @($tags | Select-Object -Unique)
        confidence   = [int]$Merged.Confidence
        graphDelta   = @($GraphDelta)
    }
}

function Update-DsKnowledgeMetadataIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Metadata
    )

    $indexPath = Join-Path (Get-DsKnowledgeIndexDir) 'metadata-index.json'
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @(Read-DsKnowledgeJson -Path $indexPath -Default @())) {
        if ($item -and $item.date -ne $Metadata.date) {
            $list.Add($item) | Out-Null
        }
    }
    $list.Add($Metadata) | Out-Null
    $sorted = @($list | Sort-Object { $_.date } -Descending)
    Write-DsKnowledgeJson -Path $indexPath -Object $sorted
}
