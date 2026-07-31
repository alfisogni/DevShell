#requires -Version 7.0
# Knowledge provider: manual developer notes.

Register-DsKnowledgeProvider -Name notes -Priority 10 -Description 'Manual developer notes' -Force -Detect {
    $true
} -TestAuth {
    $true
} -Authenticate {
} -Collect {
    param($Range)

    $notesDir = Get-DsKnowledgeNotesDir
    $legacyDir = $null
    try { $legacyDir = Get-DsConfig -Path 'Utilities.NotesDir' } catch { }
    if (-not $legacyDir) { $legacyDir = Join-Path $HOME 'Documents/DevShellNotes' }
    if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
        $legacyDir = Expand-DsPath -Path $legacyDir
    }
    elseif ($legacyDir -like '~*') {
        $legacyDir = $legacyDir -replace '^~', $HOME
    }

    $days = [System.Collections.Generic.List[datetime]]::new()
    $cursor = $Range.Start.Date
    while ($cursor -le $Range.End.Date) {
        $days.Add($cursor) | Out-Null
        $cursor = $cursor.AddDays(1)
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($day in $days) {
        $name = '{0:yyyy-MM-dd}.md' -f $day
        foreach ($dir in @($notesDir, $legacyDir)) {
            if (-not $dir) { continue }
            $path = Join-Path $dir $name
            if (Test-Path -LiteralPath $path) {
                Get-Content -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_ -and $_.Trim()) { $lines.Add($_.Trim()) | Out-Null }
                }
            }
        }
    }

    $scope = if ($Range.Scope) { $Range.Scope } else { New-DsKnowledgeScope }

    $claims = [System.Collections.Generic.List[object]]::new()
    $entities = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $journalId = 'journal:{0:yyyy-MM-dd}' -f $Range.Anchor
    $kept = 0
    $skipped = 0

    # Reassemble multi-line note blocks (timestamp header + following lines until next stamp).
    # Lines are Trim()'d when read, so we must NOT require leading indent for continuations.
    $blocks = [System.Collections.Generic.List[string]]::new()
    $current = $null
    foreach ($line in $lines) {
        if ($line -match '^-\s+\d{1,2}:\d{2}\b') {
            if ($current) { $blocks.Add($current) | Out-Null }
            $current = ($line -replace '^-\s*', '')
        }
        elseif ($null -ne $current) {
            $current = $current + "`n" + $line.Trim()
        }
        else {
            if ($line -and $line.Trim()) { $blocks.Add(($line -replace '^-\s*', '')) | Out-Null }
        }
    }
    if ($current) { $blocks.Add($current) | Out-Null }

    foreach ($text in $blocks) {
        if (-not (Test-DsKnowledgeTextInScope -Text $text -Scope $scope)) {
            $skipped++
            continue
        }
        $kept++
        $kind = 'context'
        if ($text -match '(?i)\b(decid|postpone|posterg|elegimos|acordamos)\b') { $kind = 'decision' }
        elseif ($text -match '(?i)\b(pendiente|todo|falta|blocker|caja negra)\b') { $kind = 'pending' }
        elseif ($text -match '(?i)\b(riesgo|risk|cuidado)\b') { $kind = 'risk' }
        elseif ($text -match '(?i)\b(descubr|aprend|root cause|encontramos|relevamiento)\b') { $kind = 'discovery' }

        $projectMeta = @{}
        if ($text -match '\[([^\]]+)\]') { $projectMeta['project'] = $Matches[1] }

        # Keep claims readable: first ~500 chars for huge imports
        $claimText = $text
        if ($claimText.Length -gt 500) {
            $claimText = $claimText.Substring(0, 500).Trim() + '…'
        }

        $claims.Add((New-DsKnowledgeClaim -Text $claimText -Sources @('notes') -Confidence 75 -Kind $kind -Meta $projectMeta)) | Out-Null

        if ($kind -eq 'decision' -or $kind -eq 'discovery') {
            $key = ($text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
            if ($key.Length -gt 48) { $key = $key.Substring(0, 48) }
            $ent = New-DsKnowledgeEntity -Type Decision -Key $key -Label $claimText -Sources @('notes')
            $entities.Add($ent) | Out-Null
            $edges.Add((New-DsKnowledgeEdge -From $ent.Id -To $journalId -Rel recorded_in -Sources @('notes'))) | Out-Null
        }
    }

    if ($kept -eq 0) {
        $msg = if ($lines.Count -eq 0) {
            'No manual notes found for this period'
        }
        else {
            "No notes matched report scope (kept=0 skipped=$skipped). Tip: dev note -Project <Name> @' ... '@  o  dev note -Project <Name> (pegar texto)"
        }
        $claims.Add((New-DsKnowledgeClaim -Text $msg -Sources @('notes') -Confidence 60 -Kind context)) | Out-Null
    }

    return New-DsKnowledgeFragment -Provider notes -Data @{
        available = $true
        count     = $kept
        skipped   = $skipped
        lines     = @($lines)
        scope     = $scope
    } -Claims @($claims) -Entities @($entities) -Edges @($edges)
}
