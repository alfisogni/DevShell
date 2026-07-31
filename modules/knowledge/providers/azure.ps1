#requires -Version 7.0
# Knowledge provider: Azure DevOps via az CLI / REST when authenticated.

Register-DsKnowledgeProvider -Name azure -Priority 80 -Description 'Azure DevOps work items and PRs' -Force -Detect {
    if (Get-Command az -ErrorAction SilentlyContinue) { return $true }
    if ($env:AZURE_DEVOPS_EXT_PAT -or $env:ADO_PAT) { return $true }
    $cred = Get-DsKnowledgeCredential -Provider azure
    return [bool]($cred -and $cred.credential)
} -TestAuth {
    $cred = Get-DsKnowledgeCredential -Provider azure
    if ($cred -and $cred.credential -and $cred.credential.pat) { return $true }
    if ($env:AZURE_DEVOPS_EXT_PAT -or $env:ADO_PAT) { return $true }
    if (Get-Command az -ErrorAction SilentlyContinue) {
        $null = az account show 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    return $false
} -Authenticate {
    if (Get-Command az -ErrorAction SilentlyContinue) {
        az login
        if ($LASTEXITCODE -ne 0) { throw 'az login failed' }
        return
    }
    $org = Read-Host 'Azure DevOps org URL (e.g. https://dev.azure.com/myorg)'
    $pat = Read-Host 'Azure DevOps PAT'
    if ([string]::IsNullOrWhiteSpace($org) -or [string]::IsNullOrWhiteSpace($pat)) {
        throw 'org and PAT required'
    }
    Set-DsKnowledgeCredential -Provider azure -Credential @{ org = $org.Trim(); pat = $pat.Trim() }
} -Collect {
    param($Range)

    $claims = [System.Collections.Generic.List[object]]::new()
    $entities = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $workItems = [System.Collections.Generic.List[object]]::new()
    $prs = [System.Collections.Generic.List[object]]::new()
    $journalId = 'journal:{0:yyyy-MM-dd}' -f $Range.Anchor

    # Prefer az boards/devops if available
    if (Get-Command az -ErrorAction SilentlyContinue) {
        $wiJson = $null
        try {
            $wiJson = az boards query --wiql "Select [System.Id], [System.Title], [System.State] From WorkItems Where [System.ChangedDate] >= '$($Range.Start.ToString('yyyy-MM-dd'))' order by [System.ChangedDate] desc" -o json 2>$null
        }
        catch { }

        if ($wiJson) {
            try {
                $parsed = $wiJson | ConvertFrom-Json
                $items = @()
                if ($parsed.workItems) { $items = @($parsed.workItems) }
                elseif ($parsed -is [array]) { $items = @($parsed) }

                foreach ($wi in $items | Select-Object -First 25) {
                    $id = $wi.id
                    if (-not $id -and $wi.fields) { $id = $wi.id }
                    if (-not $id) { continue }
                    $title = if ($wi.fields.'System.Title') { $wi.fields.'System.Title' } elseif ($wi.fields -and $wi.fields.SystemTitle) { $wi.fields.SystemTitle } else { "Work Item $id" }
                    $state = if ($wi.fields.'System.State') { $wi.fields.'System.State' } else { '' }
                    $workItems.Add($id) | Out-Null
                    $ent = New-DsKnowledgeEntity -Type WorkItem -Key ("azure:$id") -Label $title -Sources @('azure') -Properties @{ state = $state }
                    $entities.Add($ent) | Out-Null
                    $edges.Add((New-DsKnowledgeEdge -From $ent.Id -To $journalId -Rel mentioned_in -Sources @('azure'))) | Out-Null
                    $claims.Add((New-DsKnowledgeClaim -Text ("ADO work item #{0} [{1}]: {2}" -f $id, $state, $title) -Sources @('azure') -Confidence 85 -Kind fact)) | Out-Null
                }
            }
            catch {
                $claims.Add((New-DsKnowledgeClaim -Text ("Azure boards parse failed: {0}" -f $_.Exception.Message) -Sources @('azure') -Confidence 40 -Kind context -Unverified)) | Out-Null
            }
        }

        $prJson = $null
        try {
            $prJson = az repos pr list --status all -o json 2>$null
        }
        catch { }
        if ($prJson) {
            try {
                foreach ($pr in @($prJson | ConvertFrom-Json) | Select-Object -First 20) {
                    $prs.Add($pr.pullRequestId) | Out-Null
                    $title = $pr.title
                    $ent = New-DsKnowledgeEntity -Type PR -Key ("azure:{0}" -f $pr.pullRequestId) -Label $title -Sources @('azure') -Properties @{
                        status = $pr.status
                    }
                    $entities.Add($ent) | Out-Null
                    $edges.Add((New-DsKnowledgeEdge -From $ent.Id -To $journalId -Rel mentioned_in -Sources @('azure'))) | Out-Null
                    $claims.Add((New-DsKnowledgeClaim -Text ("ADO PR #{0} [{1}]: {2}" -f $pr.pullRequestId, $pr.status, $title) -Sources @('azure') -Confidence 85 -Kind fact)) | Out-Null
                }
            }
            catch { }
        }
    }

    if ($workItems.Count -eq 0 -and $prs.Count -eq 0) {
        $claims.Add((New-DsKnowledgeClaim -Text 'Azure DevOps: no work items/PRs collected (check az devops defaults / auth)' -Sources @('azure') -Confidence 55 -Kind context -Unverified)) | Out-Null
    }

    return New-DsKnowledgeFragment -Provider azure -Data @{
        available    = $true
        workItems    = @($workItems)
        pullRequests = @($prs)
    } -Claims @($claims) -Entities @($entities) -Edges @($edges)
}
