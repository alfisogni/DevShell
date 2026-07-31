#requires -Version 7.0
# Knowledge provider: GitHub via gh CLI (PRs, issues, reviews, labels).

Register-DsKnowledgeProvider -Name github -Priority 70 -Description 'GitHub PRs/issues via gh' -Force -Detect {
    [bool](Get-Command gh -ErrorAction SilentlyContinue)
} -TestAuth {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false }
    $null = gh auth status 2>$null
    return ($LASTEXITCODE -eq 0)
} -Authenticate {
    # gh auth login is interactive and fails when embedded (Cursor chat, nested pwsh, no TTY).
    Write-Host ''
    Write-Host 'GitHub auth cannot run embedded here (same issue in Cursor chat/agent).' -ForegroundColor Yellow
    Write-Host 'Open a normal Windows Terminal / pwsh window and run:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  gh auth login -h github.com -p https -w' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Then retry:  dev report today   or   dev connect github' -ForegroundColor DarkGray
    Write-Host ''
    throw 'Complete: gh auth login -h github.com -p https -w  (external terminal)'
} -Collect {
    param($Range)

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        return New-DsKnowledgeFragment -Provider github -Data @{ available = $false }
    }

    $scope = if ($Range.Scope) { $Range.Scope } else { New-DsKnowledgeScope }
    $targets = @(Get-DsKnowledgeScopedProjects -Scope $scope)

    $claims = [System.Collections.Generic.List[object]]::new()
    $entities = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $prNumbers = [System.Collections.Generic.List[object]]::new()
    $labels = [System.Collections.Generic.List[string]]::new()
    $reposSeen = [System.Collections.Generic.List[string]]::new()
    $journalId = 'journal:{0:yyyy-MM-dd}' -f $Range.Anchor

    $reposToScan = [System.Collections.Generic.List[string]]::new()
    if ($targets.Count -gt 0) {
        foreach ($t in $targets) { $reposToScan.Add($t.Path) | Out-Null }
    }
    else {
        $reposToScan.Add((Get-Location).Path) | Out-Null
    }

    foreach ($repoPath in $reposToScan) {
        if (-not (Test-Path -LiteralPath $repoPath)) { continue }
        Push-Location -LiteralPath $repoPath
        try {
            $repo = $null
            try {
                $repo = (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null)
                if ($LASTEXITCODE -ne 0) { $repo = $null }
            }
            catch { $repo = $null }

            if (-not $repo) { continue }
            $shortName = ($repo -split '/')[-1]
            if (-not (Test-DsKnowledgeNameInScope -Name $shortName -Scope $scope)) { continue }
            $reposSeen.Add($repo) | Out-Null

            $prJson = $null
            try {
                $prJson = gh pr list --state all --limit 30 --json number,title,state,labels,mergedAt,createdAt,author,commits 2>$null
            }
            catch { }
            $prs = @()
            if ($prJson) {
                try { $prs = @($prJson | ConvertFrom-Json) } catch { $prs = @() }
            }

            foreach ($pr in $prs) {
                $created = $null
                $merged = $null
                try { if ($pr.createdAt) { $created = [datetime]$pr.createdAt } } catch { }
                try { if ($pr.mergedAt) { $merged = [datetime]$pr.mergedAt } } catch { }
                $inRange = $false
                if ($created -and $created -ge $Range.Start -and $created -le $Range.End) { $inRange = $true }
                if ($merged -and $merged -ge $Range.Start -and $merged -le $Range.End) { $inRange = $true }
                if (-not $inRange) { continue }

                $prNumbers.Add($pr.number) | Out-Null
                $prEntity = New-DsKnowledgeEntity -Type PR -Key ("github:{0}:{1}" -f $shortName, $pr.number) -Label $pr.title -Sources @('github') -Properties @{
                    state   = $pr.state
                    repo    = $repo
                    number  = $pr.number
                    project = $shortName
                }
                $entities.Add($prEntity) | Out-Null
                $edges.Add((New-DsKnowledgeEdge -From $prEntity.Id -To $journalId -Rel mentioned_in -Sources @('github'))) | Out-Null
                $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] PR #{1} ({2}): {3}" -f $shortName, $pr.number, $pr.state, $pr.title) -Sources @('github') -Confidence 90 -Kind fact -Meta @{ project = $shortName })) | Out-Null

                foreach ($lab in @($pr.labels)) {
                    $name = if ($lab.name) { $lab.name } else { [string]$lab }
                    if ($name) { $labels.Add($name) | Out-Null }
                }

                foreach ($c in @($pr.commits)) {
                    $oid = if ($c.oid) { $c.oid } elseif ($c.Hash) { $c.Hash } else { $null }
                    if (-not $oid) { continue }
                    $short = if ($oid.Length -ge 7) { $oid.Substring(0, 7) } else { $oid }
                    $ce = New-DsKnowledgeEntity -Type Commit -Key ("{0}:{1}" -f $shortName, $short) -Label $short -Sources @('github')
                    $entities.Add($ce) | Out-Null
                    $edges.Add((New-DsKnowledgeEdge -From $prEntity.Id -To $ce.Id -Rel includes -Sources @('github'))) | Out-Null
                }
            }

            $issueJson = $null
            try {
                $issueJson = gh issue list --state all --limit 30 --json number,title,state,labels,createdAt,closedAt 2>$null
            }
            catch { }
            $issues = @()
            if ($issueJson) {
                try { $issues = @($issueJson | ConvertFrom-Json) } catch { $issues = @() }
            }

            foreach ($issue in $issues) {
                $created = $null
                $closed = $null
                try { if ($issue.createdAt) { $created = [datetime]$issue.createdAt } } catch { }
                try { if ($issue.closedAt) { $closed = [datetime]$issue.closedAt } } catch { }
                $inRange = $false
                if ($created -and $created -ge $Range.Start -and $created -le $Range.End) { $inRange = $true }
                if ($closed -and $closed -ge $Range.Start -and $closed -le $Range.End) { $inRange = $true }
                if (-not $inRange) { continue }

                $ie = New-DsKnowledgeEntity -Type Issue -Key ("github:{0}:{1}" -f $shortName, $issue.number) -Label $issue.title -Sources @('github') -Properties @{
                    state   = $issue.state
                    number  = $issue.number
                    project = $shortName
                }
                $entities.Add($ie) | Out-Null
                $edges.Add((New-DsKnowledgeEdge -From $ie.Id -To $journalId -Rel mentioned_in -Sources @('github'))) | Out-Null
                $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] Issue #{1} ({2}): {3}" -f $shortName, $issue.number, $issue.state, $issue.title) -Sources @('github') -Confidence 88 -Kind fact -Meta @{ project = $shortName })) | Out-Null
            }
        }
        finally {
            Pop-Location
        }
    }

    if ($reposSeen.Count -eq 0) {
        $claims.Add((New-DsKnowledgeClaim -Text 'GitHub CLI present but no in-scope GitHub repository context' -Sources @('github') -Confidence 50 -Kind context -Unverified)) | Out-Null
    }
    elseif ($prNumbers.Count -eq 0 -and @($entities | Where-Object Type -EQ 'Issue').Count -eq 0) {
        $claims.Add((New-DsKnowledgeClaim -Text ("No GitHub PRs/issues activity in range for: {0}" -f ($reposSeen -join ', ')) -Sources @('github') -Confidence 70 -Kind context)) | Out-Null
    }

    return New-DsKnowledgeFragment -Provider github -Data @{
        available    = $true
        repository   = ($reposSeen -join ', ')
        pullRequests = @($prNumbers)
        labels       = @($labels | Select-Object -Unique)
        scope        = $scope
    } -Claims @($claims) -Entities @($entities) -Edges @($edges)
}
