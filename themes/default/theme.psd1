@{
    Name   = 'default'
    Author = 'DevShell'
    Colors = @{
        Bg      = '#0A0A0A'
        Fg      = '#FFFFFF'
        Accent  = '#00C853'
        Muted   = '#A0A0A0'
        Success = '#00C853'
        Warning = '#E6B84D'
        Error   = '#E5484D'
    }
    Symbols = @{
        Prompt = '>'
        Git    = ''
        Sep    = ' '
    }
    Banner = @{
        Enabled   = $true
        ArtFile   = 'banner.txt'
        SidePanel = 'memo'   # memo | weather | none
        Memo      = @{ Enabled = $true }
        Weather   = @{ Enabled = $false }
    }
    Terminal = @{
        FontSuggestion = 'Cascadia Code / Inter / JetBrains Mono'
        Background     = '#0A0A0A'
        Foreground     = '#FFFFFF'
        Accent         = '#00C853'
    }
}
