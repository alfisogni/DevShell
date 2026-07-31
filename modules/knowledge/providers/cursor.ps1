#requires -Version 7.0
# Knowledge provider: optional Cursor product signals (IDE/CLI). Never invents transcripts.

Register-DsKnowledgeProvider -Name cursor -Priority 90 -Description 'Optional Cursor IDE/CLI signals' -Force -Detect {
    # Available if Cursor agent CLI or typical Cursor project dirs exist — soft signal only
    if (Get-Command agent -ErrorAction SilentlyContinue) { return $true }
    if (Get-Command cursor-agent -ErrorAction SilentlyContinue) { return $true }
    if ($env:LOCALAPPDATA -and (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'cursor-agent'))) { return $true }
    if (Test-Path -LiteralPath (Join-Path (Get-Location).Path '.cursor')) { return $true }
    return $false
} -TestAuth {
    $true
} -Authenticate {
} -Collect {
    param($Range)

    $claims = [System.Collections.Generic.List[object]]::new()
    $entities = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $signals = [System.Collections.Generic.List[string]]::new()

    $hasCli = [bool](Get-Command agent -ErrorAction SilentlyContinue) -or [bool](Get-Command cursor-agent -ErrorAction SilentlyContinue)
    if ($hasCli) {
        $signals.Add('agent-cli') | Out-Null
        $claims.Add((New-DsKnowledgeClaim -Text 'Cursor Agent CLI is available in this environment' -Sources @('cursor') -Confidence 80 -Kind context)) | Out-Null
    }

    $cursorDir = Join-Path (Get-Location).Path '.cursor'
    if (Test-Path -LiteralPath $cursorDir) {
        $signals.Add('project-.cursor') | Out-Null
        $claims.Add((New-DsKnowledgeClaim -Text 'Project contains a .cursor directory (rules/skills may apply)' -Sources @('cursor') -Confidence 75 -Kind context)) | Out-Null

        $rules = Get-ChildItem -LiteralPath $cursorDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.md', '.mdc' } |
            Select-Object -First 10
        foreach ($r in $rules) {
            $ent = New-DsKnowledgeEntity -Type Document -Key ("cursor-rule:{0}" -f $r.Name) -Label $r.Name -Sources @('cursor') -Properties @{
                path = $r.FullName
            }
            $entities.Add($ent) | Out-Null
        }
    }

    # Honest: we do not scrape private chat transcripts unless a known export path exists
    $exportHint = Join-Path (Get-DsKnowledgeStoreRoot) 'imports/cursor'
    if (Test-Path -LiteralPath $exportHint) {
        $imports = Get-ChildItem -LiteralPath $exportHint -File -Filter '*.md' -ErrorAction SilentlyContinue
        foreach ($f in @($imports)) {
            $mtime = $f.LastWriteTime
            if ($mtime -lt $Range.Start -or $mtime -gt $Range.End) { continue }
            $signals.Add("import:$($f.Name)") | Out-Null
            Get-Content -LiteralPath $f.FullName -TotalCount 20 -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -and $_.Trim()) {
                    $claims.Add((New-DsKnowledgeClaim -Text $_.Trim() -Sources @('cursor') -Confidence 70 -Kind discovery)) | Out-Null
                }
            }
        }
    }
    else {
        $claims.Add((New-DsKnowledgeClaim -Text 'No Cursor transcript export found under knowledge/imports/cursor — chat decisions not collected' -Sources @('cursor') -Confidence 60 -Kind context -Unverified)) | Out-Null
    }

    return New-DsKnowledgeFragment -Provider cursor -Data @{
        available = $true
        signals   = @($signals)
    } -Claims @($claims) -Entities @($entities) -Edges @($edges)
}
