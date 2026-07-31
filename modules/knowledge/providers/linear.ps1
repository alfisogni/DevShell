#requires -Version 7.0
# Knowledge provider: Linear GraphQL API (independent of Cursor MCP).

function Invoke-DsLinearGraphQl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [hashtable]$Variables = @{}
    )

    $cred = Get-DsKnowledgeCredential -Provider linear
    $token = $null
    if ($cred -and $cred.credential -and $cred.credential.apiKey) {
        $token = [string]$cred.credential.apiKey
    }
    if (-not $token) { $token = $env:LINEAR_API_KEY }
    if (-not $token) { throw 'Linear API key not configured' }

    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10
    $headers = @{
        Authorization = $token
        'Content-Type' = 'application/json'
    }
    $resp = Invoke-RestMethod -Uri 'https://api.linear.app/graphql' -Method Post -Headers $headers -Body $body
    if ($resp.errors) {
        throw ($resp.errors | ConvertTo-Json -Compress)
    }
    return $resp.data
}

Register-DsKnowledgeProvider -Name linear -Priority 55 -Description 'Linear issues via GraphQL API' -Force -Detect {
    $cred = Get-DsKnowledgeCredential -Provider linear
    if ($cred -and $cred.credential -and $cred.credential.apiKey) { return $true }
    if ($env:LINEAR_API_KEY) { return $true }
    return $false
} -TestAuth {
    try {
        $null = Invoke-DsLinearGraphQl -Query '{ viewer { id name } }'
        return $true
    }
    catch {
        return $false
    }
} -Authenticate {
    $key = $env:LINEAR_API_KEY
    if (-not $key) {
        $key = Read-Host 'Linear API key (https://linear.app/settings/api)'
    }
    if ([string]::IsNullOrWhiteSpace($key)) { throw 'No Linear API key provided' }
    Set-DsKnowledgeCredential -Provider linear -Credential @{ apiKey = $key.Trim() }
    $null = Invoke-DsLinearGraphQl -Query '{ viewer { id } }'
} -Collect {
    param($Range)

    $claims = [System.Collections.Generic.List[object]]::new()
    $entities = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $issueIds = [System.Collections.Generic.List[object]]::new()
    $journalId = 'journal:{0:yyyy-MM-dd}' -f $Range.Anchor

    try {
        $data = Invoke-DsLinearGraphQl -Query @'
query($after: String) {
  issues(first: 50, after: $after, orderBy: updatedAt) {
    nodes {
      id
      identifier
      title
      description
      url
      updatedAt
      createdAt
      completedAt
      state { name type }
      labels { nodes { name } }
      project { name }
    }
  }
}
'@
    }
    catch {
        $claims.Add((New-DsKnowledgeClaim -Text ("Linear collect failed: {0}" -f $_.Exception.Message) -Sources @('linear') -Confidence 40 -Kind context -Unverified)) | Out-Null
        return New-DsKnowledgeFragment -Provider linear -Data @{ available = $false } -Claims @($claims)
    }

    $nodes = @($data.issues.nodes)
    foreach ($issue in $nodes) {
        $updated = $null
        $created = $null
        $completed = $null
        try { $updated = [datetime]$issue.updatedAt } catch { }
        try { $created = [datetime]$issue.createdAt } catch { }
        try { if ($issue.completedAt) { $completed = [datetime]$issue.completedAt } } catch { }

        $inRange = $false
        foreach ($dt in @($updated, $created, $completed)) {
            if ($dt -and $dt -ge $Range.Start -and $dt -le $Range.End) { $inRange = $true; break }
        }
        if (-not $inRange) { continue }

        $issueIds.Add($issue.identifier) | Out-Null
        $ie = New-DsKnowledgeEntity -Type Issue -Key $issue.identifier -Label $issue.title -Sources @('linear') -Properties @{
            state   = $issue.state.name
            url     = $issue.url
            project = $(if ($issue.project) { $issue.project.name } else { $null })
        }
        $entities.Add($ie) | Out-Null
        $edges.Add((New-DsKnowledgeEdge -From $ie.Id -To $journalId -Rel mentioned_in -Sources @('linear'))) | Out-Null

        $stateType = if ($issue.state) { $issue.state.type } else { '' }
        $kind = 'fact'
        if ($stateType -eq 'completed') { $kind = 'fact' }
        $claims.Add((New-DsKnowledgeClaim -Text ("Linear {0} [{1}]: {2}" -f $issue.identifier, $issue.state.name, $issue.title) -Sources @('linear') -Confidence 90 -Kind $kind)) | Out-Null
    }

    if ($issueIds.Count -eq 0) {
        $claims.Add((New-DsKnowledgeClaim -Text 'No Linear issue updates in range' -Sources @('linear') -Confidence 70 -Kind context)) | Out-Null
    }

    return New-DsKnowledgeFragment -Provider linear -Data @{
        available = $true
        issues    = @($issueIds)
    } -Claims @($claims) -Entities @($entities) -Edges @($edges)
}
