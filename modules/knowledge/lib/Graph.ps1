#requires -Version 7.0
# Knowledge Graph — entities + edges as plain JSON.

function New-DsKnowledgeEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Key,

        [string]$Label,

        [hashtable]$Properties = @{},

        [string[]]$Sources = @()
    )

    $id = '{0}:{1}' -f $Type.ToLowerInvariant(), $Key
    return [pscustomobject]@{
        Id         = $id
        Type       = $Type
        Label      = $(if ($Label) { $Label } else { $Key })
        Properties = $Properties
        Sources    = @($Sources)
    }
}

function New-DsKnowledgeEdge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To,

        [Parameter(Mandatory)]
        [string]$Rel,

        [string[]]$Sources = @()
    )

    return [pscustomobject]@{
        From    = $From
        To      = $To
        Rel     = $Rel
        Sources = @($Sources)
    }
}

function Get-DsKnowledgeGraph {
    [CmdletBinding()]
    param()

    $dir = Get-DsKnowledgeGraphDir
    $entitiesPath = Join-Path $dir 'entities.json'
    $edgesPath = Join-Path $dir 'edges.json'

    return [pscustomobject]@{
        Entities = @(Read-DsKnowledgeJson -Path $entitiesPath -Default @())
        Edges    = @(Read-DsKnowledgeJson -Path $edgesPath -Default @())
    }
}

function Update-DsKnowledgeGraph {
    [CmdletBinding()]
    param(
        [object[]]$Entities = @(),
        [object[]]$Edges = @()
    )

    Initialize-DsKnowledgeStore | Out-Null
    $dir = Get-DsKnowledgeGraphDir
    $entitiesPath = Join-Path $dir 'entities.json'
    $edgesPath = Join-Path $dir 'edges.json'

    $byId = [ordered]@{}
    foreach ($e in @(Read-DsKnowledgeJson -Path $entitiesPath -Default @())) {
        if ($e -and $e.Id) { $byId[[string]$e.Id] = $e }
    }

    $deltaIds = [System.Collections.Generic.List[string]]::new()
    foreach ($e in @($Entities)) {
        if (-not $e -or -not $e.Id) { continue }
        $id = [string]$e.Id
        $byId[$id] = $e
        if (-not $deltaIds.Contains($id)) { $deltaIds.Add($id) | Out-Null }
    }

    $edgeKey = {
        param($x)
        '{0}|{1}|{2}' -f $x.From, $x.Rel, $x.To
    }
    $edgeMap = [ordered]@{}
    foreach ($edge in @(Read-DsKnowledgeJson -Path $edgesPath -Default @())) {
        if (-not $edge) { continue }
        $edgeMap[(& $edgeKey $edge)] = $edge
    }
    foreach ($edge in @($Edges)) {
        if (-not $edge -or -not $edge.From -or -not $edge.To) { continue }
        $k = & $edgeKey $edge
        $edgeMap[$k] = $edge
    }

    Write-DsKnowledgeJson -Path $entitiesPath -Object @($byId.Values)
    Write-DsKnowledgeJson -Path $edgesPath -Object @($edgeMap.Values)

    return [pscustomobject]@{
        EntityCount = $byId.Count
        EdgeCount   = $edgeMap.Count
        GraphDelta  = @($deltaIds)
    }
}

function Search-DsKnowledgeGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [int]$Top = 20
    )

    $q = $Query.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($q)) { return @() }

    $graph = Get-DsKnowledgeGraph
    $hits = [System.Collections.Generic.List[object]]::new()

    foreach ($e in @($graph.Entities)) {
        $blob = (@($e.Id, $e.Type, $e.Label, ($e.Properties | ConvertTo-Json -Compress -ErrorAction SilentlyContinue)) -join ' ').ToLowerInvariant()
        if ($blob -like "*$q*") {
            $related = @($graph.Edges | Where-Object { $_.From -eq $e.Id -or $_.To -eq $e.Id })
            $hits.Add([pscustomobject]@{
                    Kind     = 'entity'
                    Score    = $(if ($e.Label -and $e.Label.ToLowerInvariant() -eq $q) { 100 } elseif ($e.Id.ToLowerInvariant() -like "*$q*") { 90 } else { 60 })
                    Id       = $e.Id
                    Label    = $e.Label
                    Type     = $e.Type
                    Related  = $related
                    Entity   = $e
                }) | Out-Null
        }
    }

    foreach ($edge in @($graph.Edges)) {
        $blob = ('{0} {1} {2}' -f $edge.From, $edge.Rel, $edge.To).ToLowerInvariant()
        if ($blob -like "*$q*") {
            $hits.Add([pscustomobject]@{
                    Kind  = 'edge'
                    Score = 50
                    Id    = $blob
                    Label = "$($edge.From) --$($edge.Rel)--> $($edge.To)"
                    Type  = 'edge'
                    Edge  = $edge
                }) | Out-Null
        }
    }

    return @($hits | Sort-Object Score -Descending | Select-Object -First $Top)
}
