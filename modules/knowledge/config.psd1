@{
    Root = '~/.devshell'
    DefaultPeriod = 'today'
    Providers = @{
        git    = @{ Enabled = $true }
        cursor = @{ Enabled = $true }
        azure  = @{ Enabled = $true }
        github = @{ Enabled = $true }
        linear = @{ Enabled = $true }
        notes  = @{ Enabled = $true }
    }
}
