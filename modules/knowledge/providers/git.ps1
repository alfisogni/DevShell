#requires -Version 7.0
# Knowledge provider: local Git (commits, branches, files, tags) — scope-aware.

function Collect-DsKnowledgeGitRepo {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Range,
        [string]$ProjectName
    )

    $since = $Range.Start.ToString('yyyy-MM-dd')
    $until = $Range.End.AddDays(1).ToString('yyyy-MM-dd')
    $repoName = if ($ProjectName) { $ProjectName } else { Split-Path -Leaf $Root }

    Push-Location -LiteralPath $Root
    try {
        $branch = git branch --show-current 2>$null
        if ($branch) { $branch = $branch.Trim() }

        $logLines = @(git log --since=$since --until=$until --pretty=format:'%H|%h|%s|%an|%aI' 2>$null)
        $commits = [System.Collections.Generic.List[object]]::new()
        $commitIds = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $logLines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 5
            if ($parts.Count -lt 5) { continue }
            $commits.Add([pscustomobject]@{
                    Hash      = $parts[0]
                    Short     = $parts[1]
                    Subject   = $parts[2]
                    Author    = $parts[3]
                    Timestamp = $parts[4]
                }) | Out-Null
            $commitIds.Add($parts[1]) | Out-Null
        }

        $files = @()
        if ($commitIds.Count -gt 0) {
            $files = @(git log --since=$since --until=$until --name-only --pretty=format: 2>$null |
                    Where-Object { $_ -and $_.Trim() } |
                    Sort-Object -Unique)
        }
        else {
            $files = @(git status --porcelain 2>$null | ForEach-Object {
                    if ($_ -match '^\?\?\s+(.+)$') { $Matches[1] }
                    elseif ($_.Length -gt 3) { $_.Substring(3).Trim() }
                } | Where-Object { $_ } | Sort-Object -Unique)
        }

        $tags = @(git tag --list --sort=-creatordate 2>$null | Select-Object -First 20)
        $merges = @($commits | Where-Object { $_.Subject -match '^Merge\b' })

        $claims = [System.Collections.Generic.List[object]]::new()
        $entities = [System.Collections.Generic.List[object]]::new()
        $edges = [System.Collections.Generic.List[object]]::new()

        $repoEntity = New-DsKnowledgeEntity -Type Repository -Key $repoName -Label $repoName -Sources @('git') -Properties @{
            path    = $Root
            branch  = $branch
            project = $repoName
        }
        $entities.Add($repoEntity) | Out-Null

        $journalId = 'journal:{0:yyyy-MM-dd}' -f $Range.Anchor
        $entities.Add((New-DsKnowledgeEntity -Type Journal -Key $Range.Anchor.ToString('yyyy-MM-dd') -Label $Range.Anchor.ToString('yyyy-MM-dd') -Sources @('git'))) | Out-Null
        $projectEntity = New-DsKnowledgeEntity -Type Project -Key $repoName -Label $repoName -Sources @('git')
        $entities.Add($projectEntity) | Out-Null
        $edges.Add((New-DsKnowledgeEdge -From $repoEntity.Id -To $projectEntity.Id -Rel belongs_to -Sources @('git'))) | Out-Null

        if ($branch) {
            $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] Active branch: {1}" -f $repoName, $branch) -Sources @('git') -Confidence 95 -Kind context -Meta @{ project = $repoName })) | Out-Null
        }

        if ($commits.Count -gt 0) {
            $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] Recorded {1} commit(s) during period" -f $repoName, $commits.Count) -Sources @('git') -Confidence 95 -Kind fact -Meta @{ project = $repoName })) | Out-Null
            foreach ($c in $commits | Select-Object -First 15) {
                $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] Commit {1}: {2}" -f $repoName, $c.Short, $c.Subject) -Sources @('git') -Confidence 90 -Kind fact -Meta @{ hash = $c.Hash; project = $repoName })) | Out-Null
                $ce = New-DsKnowledgeEntity -Type Commit -Key ("{0}:{1}" -f $repoName, $c.Short) -Label $c.Subject -Sources @('git') -Properties @{
                    hash      = $c.Hash
                    author    = $c.Author
                    timestamp = $c.Timestamp
                    project   = $repoName
                }
                $entities.Add($ce) | Out-Null
                $edges.Add((New-DsKnowledgeEdge -From $ce.Id -To $repoEntity.Id -Rel belongs_to -Sources @('git'))) | Out-Null
                $edges.Add((New-DsKnowledgeEdge -From $ce.Id -To $journalId -Rel recorded_in -Sources @('git'))) | Out-Null
            }
        }
        elseif ($files.Count -gt 0) {
            $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] Working tree has {1} changed file(s) (no commits in range yet)" -f $repoName, $files.Count) -Sources @('git') -Confidence 80 -Kind fact -Meta @{ project = $repoName })) | Out-Null
        }
        else {
            $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] No git commits or file changes in range" -f $repoName) -Sources @('git') -Confidence 70 -Kind context -Meta @{ project = $repoName })) | Out-Null
        }

        if ($merges.Count -gt 0) {
            $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] {1} merge commit(s) in period" -f $repoName, $merges.Count) -Sources @('git') -Confidence 90 -Kind fact -Meta @{ project = $repoName })) | Out-Null
        }

        if ($files.Count -gt 0) {
            $claims.Add((New-DsKnowledgeClaim -Text ("[{0}] Modified files include: {1}" -f $repoName, (($files | Select-Object -First 8) -join ', ')) -Sources @('git') -Confidence 85 -Kind fact -Meta @{ project = $repoName })) | Out-Null
        }

        return New-DsKnowledgeFragment -Provider git -Data @{
            available     = $true
            repository    = $repoName
            project       = $repoName
            root          = $Root
            branch        = $branch
            commits       = @($commitIds)
            commitDetails = @($commits)
            files         = @($files)
            tags          = @($tags)
            merges        = @($merges | ForEach-Object Short)
        } -Claims @($claims) -Entities @($entities) -Edges @($edges)
    }
    finally {
        Pop-Location
    }
}

Register-DsKnowledgeProvider -Name git -Priority 100 -Description 'Local git history' -Force -Detect {
    [bool](Get-Command git -ErrorAction SilentlyContinue)
} -TestAuth {
    $true
} -Authenticate {
} -Collect {
    param($Range)

    $scope = if ($Range.Scope) { $Range.Scope } else { New-DsKnowledgeScope }
    $targets = @(Get-DsKnowledgeScopedProjects -Scope $scope)

    if ($targets.Count -eq 0) {
        # No include filter + not in a repo → honest empty
        $current = $null
        if (Get-Command Get-DsGitRoot -ErrorAction SilentlyContinue) {
            $current = Get-DsGitRoot
        }
        if ($current -and (Test-DsKnowledgeNameInScope -Name (Split-Path -Leaf $current) -Scope $scope)) {
            $targets = @([pscustomobject]@{ Name = (Split-Path -Leaf $current); Path = $current })
        }
    }

    if ($targets.Count -eq 0) {
        $hint = if ($scope.IncludeProjects.Count -gt 0) {
            "No git repos matched scope Include=[{0}]. Check ProjectRoots / -Project name." -f ($scope.IncludeProjects -join ', ')
        }
        else {
            'No git repository in scope (cd into a repo or pass -Project Name)'
        }
        return New-DsKnowledgeFragment -Provider git -Data @{ available = $false; scope = $scope } -Claims @(
            New-DsKnowledgeClaim -Text $hint -Sources @('git') -Confidence 60 -Kind context
        )
    }

    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($t in $targets) {
        $frag = Collect-DsKnowledgeGitRepo -Root $t.Path -Range $Range -ProjectName $t.Name
        if ($frag) { $all.Add($frag) | Out-Null }
    }

    if ($all.Count -eq 1) { return $all[0] }

    $claims = [System.Collections.Generic.List[object]]::new()
    $entities = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $repos = [System.Collections.Generic.List[string]]::new()
    $projects = [System.Collections.Generic.List[string]]::new()
    $commitIds = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($frag in $all) {
        foreach ($c in @($frag.Claims)) { $claims.Add($c) | Out-Null }
        foreach ($e in @($frag.Entities)) { $entities.Add($e) | Out-Null }
        foreach ($e in @($frag.Edges)) { $edges.Add($e) | Out-Null }
        if ($frag.Data.repository) { $repos.Add([string]$frag.Data.repository) | Out-Null }
        if ($frag.Data.project) { $projects.Add([string]$frag.Data.project) | Out-Null }
        foreach ($c in @($frag.Data.commits)) { if ($c) { $commitIds.Add([string]$c) | Out-Null } }
        foreach ($f in @($frag.Data.files)) { if ($f) { $files.Add([string]$f) | Out-Null } }
    }

    return New-DsKnowledgeFragment -Provider git -Data @{
        available  = $true
        repository = ($repos | Select-Object -Unique) -join ', '
        project    = ($projects | Select-Object -Unique) -join ', '
        commits    = @($commitIds | Select-Object -Unique)
        files      = @($files | Select-Object -Unique)
        multi      = $true
    } -Claims @($claims) -Entities @($entities) -Edges @($edges)
}
