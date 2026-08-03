@{
    Name   = 'tokyo-night'
    Author = 'Lennerk'
    Colors = @{
        Bg          = '#1a1b26'
        Fg          = '#c0caf5'
        Accent      = '#9ece6a'
        Interactive = '#7dcfff'
        Knowledge   = '#bb9af7'
        Muted       = '#565f89'
        Success     = '#9ece6a'
        Warning     = '#e0af68'
        Error       = '#f7768e'
    }
    Symbols = @{
        Prompt = '>'
        Git    = ''
        Sep    = ' '
    }
    Banner = @{
        Enabled   = $true
        ArtFile   = 'banner.txt'
        SidePanel = 'memo'
        Memo      = @{ Enabled = $true }
        Weather   = @{ Enabled = $false }
        Dashboard = @{ Enabled = $true }
    }
    Terminal = @{
        FontSuggestion = 'JetBrainsMono Nerd Font'
        Background     = '#1a1b26'
        Foreground     = '#c0caf5'
        Accent         = '#9ece6a'
    }
}
