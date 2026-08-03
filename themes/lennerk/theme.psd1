@{
    Name   = 'lennerk'
    Author = 'Lennerk'
    Colors = @{
        Bg          = '#1e1e2e'
        Fg          = '#cdd6f4'
        Accent      = '#a6e3a1'
        Interactive = '#89dceb'
        Knowledge   = '#cba6f7'
        Muted       = '#6c7086'
        Success     = '#a6e3a1'
        Warning     = '#f9e2af'
        Error       = '#f38ba8'
    }
    Symbols = @{
        Prompt = '>'
        Git    = ''
        Sep    = ' '
    }
    Banner = @{
        Enabled   = $true
        ArtFile   = 'banner.txt'
        SidePanel = 'dashboard'
        Memo      = @{ Enabled = $true }
        Weather   = @{ Enabled = $false }
        Dashboard = @{ Enabled = $true }
    }
    Terminal = @{
        FontSuggestion = 'JetBrainsMono Nerd Font'
        Background     = '#1e1e2e'
        Foreground     = '#cdd6f4'
        Accent         = '#a6e3a1'
    }
}
