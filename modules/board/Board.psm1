#requires -Version 7.0
# board — Taskbook-style pinboard (tasks + notes + boards). Keyboard-first.

$script:DsBoardCache = $null

function Get-DsBoardDataPath {
    [CmdletBinding()]
    param()
    $root = $null
    try {
        $cfg = Get-DsConfig -Path 'Board.DataPath'
        if ($cfg) { $root = [string]$cfg }
    }
    catch { }
    if (-not $root) {
        $root = Join-Path $env:USERPROFILE '.config\devshell\board'
    }
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Force -Path $root | Out-Null
    }
    Join-Path $root 'pinboard.json'
}

function Get-DsBoardDefaultData {
    [CmdletBinding()]
    param()
    $boards = [ordered]@{}
    foreach ($name in @('Today', 'Scratch', 'Waiting')) {
        $boards[$name] = [System.Collections.Generic.List[object]]::new()
    }
    [ordered]@{
        version = 1
        boards  = $boards
    }
}

function Read-DsBoardData {
    [CmdletBinding()]
    param()
    $path = Get-DsBoardDataPath
    if (-not (Test-Path -LiteralPath $path)) {
        $data = Get-DsBoardDefaultData
        # ensure mutable lists
        $boards = [ordered]@{}
        foreach ($k in $data.boards.Keys) {
            $boards[$k] = [System.Collections.Generic.List[object]]::new()
        }
        $data.boards = $boards
        Write-DsBoardData -Data $data
        return $data
    }
    $raw = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $boards = [ordered]@{}
    foreach ($prop in $raw.boards.PSObject.Properties) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($it in @($prop.Value)) {
            if ($null -eq $it) { continue }
            $items.Add([pscustomobject]@{
                Id       = [string]$it.id
                Type     = [string]$it.type
                Text     = [string]$it.text
                Done     = [bool]$it.done
                Star     = [bool]$it.star
                Priority = if ($null -ne $it.priority) { [int]$it.priority } else { 1 }
                Created  = [string]$it.created
            }) | Out-Null
        }
        $boards[$prop.Name] = $items
    }
    # ensure default boards exist
    foreach ($name in @('Today', 'Scratch', 'Waiting')) {
        if (-not $boards.Contains($name)) {
            $boards[$name] = [System.Collections.Generic.List[object]]::new()
        }
    }
    return [ordered]@{ version = 1; boards = $boards }
}

function Write-DsBoardData {
    [CmdletBinding()]
    param($Data)

    $path = Get-DsBoardDataPath
    $export = [ordered]@{
        version = 1
        boards  = [ordered]@{}
    }
    foreach ($name in $Data.boards.Keys) {
        $arr = @()
        foreach ($it in @($Data.boards[$name])) {
            $arr += [ordered]@{
                id       = $it.Id
                type     = $it.Type
                text     = $it.Text
                done     = [bool]$it.Done
                star     = [bool]$it.Star
                priority = [int]$it.Priority
                created  = $it.Created
            }
        }
        $export.boards[$name] = $arr
    }
    ($export | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $path -Encoding utf8
    $script:DsBoardCache = $null
}

function Get-DsBoardData {
    [CmdletBinding()]
    param([switch]$Refresh)
    if ($Refresh -or $null -eq $script:DsBoardCache) {
        $script:DsBoardCache = Read-DsBoardData
    }
    return $script:DsBoardCache
}

function New-DsBoardItemId {
    [CmdletBinding()]
    param()
    ([guid]::NewGuid().ToString('N').Substring(0, 8))
}

function Add-DsBoardTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [string]$Board = 'Today',

        [ValidateRange(1, 3)]
        [int]$Priority = 1
    )

    $data = Get-DsBoardData -Refresh
    if (-not $data.boards.Contains($Board)) {
        $data.boards[$Board] = [System.Collections.Generic.List[object]]::new()
    }
    $item = [pscustomobject]@{
        Id       = New-DsBoardItemId
        Type     = 'task'
        Text     = $Text
        Done     = $false
        Star     = ($Priority -ge 3)
        Priority = $Priority
        Created  = (Get-Date).ToString('o')
    }
    [void]$data.boards[$Board].Add($item)
    Write-DsBoardData -Data $data
    return $item
}

function Add-DsBoardNote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [string]$Board = 'Scratch'
    )

    $data = Get-DsBoardData -Refresh
    if (-not $data.boards.Contains($Board)) {
        $data.boards[$Board] = [System.Collections.Generic.List[object]]::new()
    }
    $item = [pscustomobject]@{
        Id       = New-DsBoardItemId
        Type     = 'note'
        Text     = $Text
        Done     = $false
        Star     = $false
        Priority = 1
        Created  = (Get-Date).ToString('o')
    }
    [void]$data.boards[$Board].Add($item)
    Write-DsBoardData -Data $data
    return $item
}

function Complete-DsBoardTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    $data = Get-DsBoardData -Refresh
    foreach ($b in $data.boards.Keys) {
        foreach ($it in @($data.boards[$b])) {
            if ($it.Id -eq $Id -and $it.Type -eq 'task') {
                $it.Done = -not $it.Done
                Write-DsBoardData -Data $data
                return $it
            }
        }
    }
    Write-DsLog -Level Warn -Module board -Message "Task not found: $Id"
}

function Show-DsBoard {
    <#
    .SYNOPSIS
      Pinboard view — boards, tasks, notes (Taskbook-inspired).
    #>
    [CmdletBinding()]
    param(
        [string]$Board
    )

    $data = Get-DsBoardData -Refresh
    $accent = 'Green'
    $muted = 'DarkGray'
    $fg = 'White'
    if (Get-Command Get-DsThemeColor -ErrorAction SilentlyContinue) {
        $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
        $muted = (Get-DsThemeColor -Role Muted).ConsoleColor
        $fg = (Get-DsThemeColor -Role Fg).ConsoleColor
    }

    $names = @($data.boards.Keys)
    if ($Board) {
        $names = @($names | Where-Object { $_ -eq $Board })
        if ($names.Count -eq 0) {
            Write-Host "Board not found: $Board" -ForegroundColor Yellow
            return
        }
    }

    Write-Host ''
    Write-Host '╭──────────────────────────────────────────╮' -ForegroundColor $muted
    Write-Host '│' -NoNewline -ForegroundColor $muted
    Write-Host '  PINBOARD' -NoNewline -ForegroundColor $accent
    Write-Host (' ' * 30) -NoNewline
    Write-Host '│' -ForegroundColor $muted
    Write-Host '│' -ForegroundColor $muted

    foreach ($name in $names) {
        Write-Host '│' -NoNewline -ForegroundColor $muted
        Write-Host "  $name" -ForegroundColor $accent
        Write-Host '│' -ForegroundColor $muted
        $items = @($data.boards[$name])
        if ($items.Count -eq 0) {
            Write-Host '│' -NoNewline -ForegroundColor $muted
            Write-Host '    (empty)' -ForegroundColor $muted
            Write-Host ''
        }
        else {
            foreach ($it in $items) {
                $mark = if ($it.Type -eq 'note') {
                    '•'
                }
                elseif ($it.Done) {
                    '■'
                }
                elseif ($it.Star -or $it.Priority -ge 3) {
                    '★'
                }
                else {
                    '□'
                }
                $color = if ($it.Done) { $muted } elseif ($it.Type -eq 'note') { $fg } else { $fg }
                Write-Host '│' -NoNewline -ForegroundColor $muted
                Write-Host ('  {0} {1}' -f $mark, $it.Text) -NoNewline -ForegroundColor $color
                Write-Host ("  [{0}]" -f $it.Id.Substring(0, [Math]::Min(4, $it.Id.Length))) -ForegroundColor $muted
            }
        }
        Write-Host '│' -ForegroundColor $muted
        Write-Host '│' -NoNewline -ForegroundColor $muted
        Write-Host '  ────────────────────────────────' -ForegroundColor $muted
        Write-Host ''
    }

    Write-Host '│' -NoNewline -ForegroundColor $muted
    Write-Host '  Quick Capture' -ForegroundColor $accent
    Write-Host ''
    Write-Host '│' -NoNewline -ForegroundColor $muted
    Write-Host ('  >  dstask "…" · dsbnote "…" · dsboard') -ForegroundColor $muted
    Write-Host ''
    Write-Host '╰──────────────────────────────────────────╯' -ForegroundColor $muted
    Write-Host ''
}

function Invoke-DsBoard {
    <#
    .SYNOPSIS
      Interactive pinboard: show, add task/note via gum when available.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Show')]
    param(
        [Parameter(ParameterSetName = 'Show')]
        [switch]$Show,

        [Parameter(ParameterSetName = 'Task', Mandatory)]
        [string]$Task,

        [Parameter(ParameterSetName = 'Note', Mandatory)]
        [string]$Note,

        [string]$Board,

        [Parameter(ParameterSetName = 'Check', Mandatory)]
        [string]$Check,

        [Parameter(ParameterSetName = 'Interactive')]
        [switch]$Interactive
    )

    if ($PSCmdlet.ParameterSetName -eq 'Task' -or $Task) {
        $b = if ($Board) { $Board } else { 'Today' }
        $null = Add-DsBoardTask -Text $Task -Board $b
        Show-DsBoard
        return
    }
    if ($PSCmdlet.ParameterSetName -eq 'Note' -or $Note) {
        $b = if ($Board) { $Board } else { 'Scratch' }
        $null = Add-DsBoardNote -Text $Note -Board $b
        Show-DsBoard
        return
    }
    if ($Check) {
        $null = Complete-DsBoardTask -Id $Check
        Show-DsBoard
        return
    }
    if ($Interactive) {
        $action = 'Show'
        if (Get-Command Invoke-DsGumChoose -ErrorAction SilentlyContinue) {
            $action = Invoke-DsGumChoose -Items @('Show', 'Add task', 'Add note', 'Toggle task') -Prompt 'Pinboard'
        }
        elseif (Get-Command Invoke-DsFuzzy -ErrorAction SilentlyContinue) {
            $action = Invoke-DsFuzzy -Items @('Show', 'Add task', 'Add note', 'Toggle task') -Prompt 'pinboard'
        }
        switch ($action) {
            'Add task' {
                $text = if (Get-Command Invoke-DsInput -ErrorAction SilentlyContinue) {
                    Invoke-DsInput -Prompt '>' -Placeholder 'task…'
                }
                else { Read-Host 'task' }
                if ($text) { $null = Add-DsBoardTask -Text $text }
            }
            'Add note' {
                $text = if (Get-Command Invoke-DsInput -ErrorAction SilentlyContinue) {
                    Invoke-DsInput -Prompt '>' -Placeholder 'note…'
                }
                else { Read-Host 'note' }
                if ($text) { $null = Add-DsBoardNote -Text $text }
            }
            'Toggle task' {
                $data = Get-DsBoardData -Refresh
                $choices = [System.Collections.Generic.List[string]]::new()
                foreach ($b in $data.boards.Keys) {
                    foreach ($it in @($data.boards[$b])) {
                        if ($it.Type -eq 'task') {
                            $choices.Add(('{0} | {1}' -f $it.Id, $it.Text)) | Out-Null
                        }
                    }
                }
                if ($choices.Count -eq 0) { Show-DsBoard; return }
                $pick = if (Get-Command Invoke-DsFuzzy -ErrorAction SilentlyContinue) {
                    Invoke-DsFuzzy -Items @($choices) -Prompt 'toggle'
                }
                else { $choices[0] }
                if ($pick -match '^(\S+)\s\|') {
                    $null = Complete-DsBoardTask -Id $Matches[1]
                }
            }
        }
        Show-DsBoard
        return
    }

    Show-DsBoard -Board $Board
}

function Invoke-DsTasks {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Text
    )
    if ($Text -and $Text.Count -gt 0) {
        Invoke-DsBoard -Task ($Text -join ' ')
    }
    else {
        Invoke-DsBoard -Interactive
    }
}

function Invoke-DsBoardNote {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Text,

        [string]$Board = 'Scratch'
    )
    if (-not $Text -or $Text.Count -eq 0) {
        $t = if (Get-Command Invoke-DsInput -ErrorAction SilentlyContinue) {
            Invoke-DsInput -Prompt '>' -Placeholder 'note…'
        }
        else { Read-Host 'note' }
        if (-not $t) { return }
        $null = Add-DsBoardNote -Text $t -Board $Board
    }
    else {
        $null = Add-DsBoardNote -Text ($Text -join ' ') -Board $Board
    }
    Show-DsBoard
}

function Register-DsBoardOnLoad {
    Write-DsLog -Level Debug -Module board -Message ("board ready ({0})" -f (Get-DsBoardDataPath))
}

function Register-DsBoardKeys {
    if (-not (Get-Command Register-DsKey -ErrorAction SilentlyContinue)) { return }
    $null = Register-DsKey -Chord 'Ctrl+Alt+B' -Module board -Description 'Pinboard (Invoke-DsBoard)' -Action {
        Invoke-DsBoard -Interactive
    }
}

Export-ModuleMember -Function @(
    'Show-DsBoard',
    'Invoke-DsBoard',
    'Invoke-DsTasks',
    'Add-DsBoardTask',
    'Add-DsBoardNote',
    'Invoke-DsBoardNote',
    'Complete-DsBoardTask',
    'Get-DsBoardData',
    'Get-DsBoardDataPath',
    'Register-DsBoardOnLoad',
    'Register-DsBoardKeys'
)
