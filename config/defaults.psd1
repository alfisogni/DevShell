@{
    DevShellVersion = '0.2.1'
    LogLevel        = 'Warn'   # silencioso al arrancar; Debug/Info si hace falta
    Theme           = 'default'
    ProjectRoots    = @(
        '~/projects'
        '~/source'
    )
    Startup = @{
        ShowBanner = $true
        ShowStatus = $false
        SidePanel  = 'memo'   # memo | weather | none
        Memo = @{
            Enabled = $true
        }
        Weather = @{
            Enabled    = $false  # opcional; el default útil es memo
            Location   = ''
            TimeoutSec = 2
            CacheSec   = 600
        }
    }
    Utilities = @{
        NotesDir = '~/Documents/DevShellNotes'
    }
    Knowledge = @{
        Root = '~/.devshell'
        DefaultPeriod = 'today'
        Report = @{
            # Optional defaults for journaling scope (override in user.psd1)
            IncludeProjects = @()
            ExcludeProjects = @()   # e.g. @('DevShell') to omit meta-work
        }
    }
    Ai = @{
        DefaultProvider = 'cursor'
        IdeCommand      = 'cursor'
        Providers       = @{
            cursor = @{}
        }
    }
    Aliases = @{
        Enabled = $true
        Force   = $false
    }
    Cursor = @{
        PreferCli   = $true
        IdeOnDemand = $true
    }
}
