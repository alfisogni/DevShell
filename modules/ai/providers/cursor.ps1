# Provider: Cursor Agent CLI (optional — one backend among many)

function Resolve-DsCursorAgentPath {
    [CmdletBinding()]
    param()

    $configured = $null
    try { $configured = Get-DsConfig -Path 'Ai.Providers.cursor.CliPath' } catch { }
    if (-not $configured) {
        try { $configured = Get-DsConfig -Path 'Cursor.CliPath' } catch { }
    }
    if ($configured -and (Test-Path -LiteralPath "$configured")) {
        return [string]$configured
    }

    foreach ($name in @('agent', 'cursor-agent')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
    }

    $local = [string]$env:LOCALAPPDATA
    if ($local) {
        foreach ($rel in @(
            'cursor-agent\agent.ps1',
            'cursor-agent\cursor-agent.ps1',
            'cursor-agent\agent.cmd',
            'cursor-agent\agent.exe'
        )) {
            $candidate = Join-Path $local $rel
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $null
}

# Ensure helper is available in module scope when this file is dot-sourced from OnLoad
Register-DsAiProvider -Name cursor -Description 'Cursor Agent CLI' -Force -Detect {
    [bool](Resolve-DsCursorAgentPath)
} -Invoke {
    param(
        [string]$Prompt,
        [hashtable]$Arguments
    )

    $cli = Resolve-DsCursorAgentPath
    if (-not $cli) {
        throw 'Cursor Agent CLI not found (agent / cursor-agent).'
    }

    $chat = $Arguments -and $Arguments.ContainsKey('Chat') -and $Arguments.Chat
    if ($chat) {
        Write-Host "ai:cursor → $cli (interactive Agent TTY)" -ForegroundColor DarkGray
        & $cli
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-DsLog -Level Warn -Module ai -Message "cursor provider exit $LASTEXITCODE"
        }
        return
    }

    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-p') | Out-Null
    if ($Arguments -and $Arguments.ContainsKey('Mode') -and $Arguments.Mode) {
        $argList.Add('--mode') | Out-Null
        $argList.Add([string]$Arguments.Mode) | Out-Null
    }

    try {
        $cfgArgs = Get-DsConfig -Path 'Ai.Providers.cursor.Args'
        if ($cfgArgs) {
            foreach ($a in @($cfgArgs)) { $argList.Add([string]$a) | Out-Null }
        }
    }
    catch { }

    $argList.Add($Prompt) | Out-Null

    Write-Host "ai:cursor → $cli -p ..." -ForegroundColor DarkGray
    & $cli @($argList)
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-DsLog -Level Warn -Module ai -Message "cursor provider exit $LASTEXITCODE"
    }
}
