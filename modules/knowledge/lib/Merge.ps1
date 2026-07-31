#requires -Version 7.0
# Merge knowledge fragments by provider priority; raise confidence on agreement.

function New-DsKnowledgeFragment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [hashtable]$Data = @{},

        [object[]]$Claims = @(),

        [object[]]$Entities = @(),

        [object[]]$Edges = @()
    )

    return [pscustomobject]@{
        Provider = $Provider.ToLowerInvariant()
        Data     = $Data
        Claims   = @($Claims)
        Entities = @($Entities)
        Edges    = @($Edges)
    }
}

function New-DsKnowledgeClaim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string[]]$Sources,

        [ValidateRange(0, 100)]
        [int]$Confidence = 50,

        [switch]$Unverified,

        [ValidateSet('fact', 'decision', 'pending', 'risk', 'discovery', 'context')]
        [string]$Kind = 'fact',

        [hashtable]$Meta = @{}
    )

    return [pscustomobject]@{
        Text       = $Text
        Sources    = @($Sources | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique)
        Confidence = $Confidence
        Unverified = [bool]$Unverified
        Kind       = $Kind
        Meta       = $Meta
    }
}

function Merge-DsKnowledgeFragments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Fragments,

        [hashtable]$ProviderPriority = @{}
    )

    $ordered = @($Fragments | Sort-Object {
            $name = $_.Provider
            if ($ProviderPriority.ContainsKey($name)) { [int]$ProviderPriority[$name] }
            else { 0 }
        } -Descending)

    $claimsByKey = [ordered]@{}
    $entitiesById = [ordered]@{}
    $edges = [System.Collections.Generic.List[object]]::new()
    $data = [ordered]@{}
    $providersUsed = [System.Collections.Generic.List[string]]::new()

    foreach ($frag in $ordered) {
        if (-not $frag) { continue }
        $pname = [string]$frag.Provider
        if ($pname -and -not $providersUsed.Contains($pname)) {
            $providersUsed.Add($pname) | Out-Null
        }

        if ($frag.Data) {
            $data[$pname] = $frag.Data
        }

        foreach ($c in @($frag.Claims)) {
            if (-not $c -or [string]::IsNullOrWhiteSpace($c.Text)) { continue }
            $key = ($c.Text.Trim().ToLowerInvariant() -replace '\s+', ' ')
            if ($claimsByKey.Contains($key)) {
                $existing = $claimsByKey[$key]
                $src = @($existing.Sources) + @($c.Sources) | Select-Object -Unique
                $bump = [Math]::Min(100, [int]$existing.Confidence + 8 + (2 * (@($c.Sources).Count)))
                $existing.Sources = @($src)
                $existing.Confidence = [Math]::Max([int]$existing.Confidence, [Math]::Max([int]$c.Confidence, $bump))
                if (-not $c.Unverified) { $existing.Unverified = $false }
                $claimsByKey[$key] = $existing
            }
            else {
                $claimsByKey[$key] = [pscustomobject]@{
                    Text       = [string]$c.Text
                    Sources    = @($c.Sources)
                    Confidence = [int]$c.Confidence
                    Unverified = [bool]$c.Unverified
                    Kind       = [string]$c.Kind
                    Meta       = $(if ($c.Meta) { $c.Meta } else { @{} })
                }
            }
        }

        foreach ($e in @($frag.Entities)) {
            if (-not $e -or [string]::IsNullOrWhiteSpace($e.Id)) { continue }
            $id = [string]$e.Id
            if ($entitiesById.Contains($id)) {
                $prev = $entitiesById[$id]
                $mergedProps = @{}
                if ($prev.Properties) {
                    foreach ($k in $prev.Properties.Keys) { $mergedProps[$k] = $prev.Properties[$k] }
                }
                elseif ($prev.PSObject.Properties['Properties']) {
                    foreach ($p in $prev.Properties.PSObject.Properties) { $mergedProps[$p.Name] = $p.Value }
                }
                if ($e.Properties -is [hashtable]) {
                    foreach ($k in $e.Properties.Keys) { $mergedProps[$k] = $e.Properties[$k] }
                }
                $entitiesById[$id] = [pscustomobject]@{
                    Id         = $id
                    Type       = $(if ($e.Type) { $e.Type } else { $prev.Type })
                    Label      = $(if ($e.Label) { $e.Label } else { $prev.Label })
                    Properties = $mergedProps
                    Sources    = @(@($prev.Sources) + @($e.Sources) | Select-Object -Unique)
                }
            }
            else {
                $entitiesById[$id] = [pscustomobject]@{
                    Id         = $id
                    Type       = [string]$e.Type
                    Label      = [string]$e.Label
                    Properties = $(if ($e.Properties) { $e.Properties } else { @{} })
                    Sources    = @($e.Sources)
                }
            }
        }

        foreach ($edge in @($frag.Edges)) {
            if (-not $edge -or -not $edge.From -or -not $edge.To -or -not $edge.Rel) { continue }
            $edges.Add([pscustomobject]@{
                    From    = [string]$edge.From
                    To      = [string]$edge.To
                    Rel     = [string]$edge.Rel
                    Sources = @($edge.Sources)
                }) | Out-Null
        }
    }

    $claims = @($claimsByKey.Values)
    $avgConf = if ($claims.Count -gt 0) {
        [int][Math]::Round(($claims | Measure-Object -Property Confidence -Average).Average)
    }
    else { 0 }

    return [pscustomobject]@{
        Providers  = @($providersUsed)
        Data       = $data
        Claims     = $claims
        Entities   = @($entitiesById.Values)
        Edges      = @($edges)
        Confidence = $avgConf
    }
}
