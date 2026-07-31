#requires -Version 7.0
# completions — tab-completion para comandos DevShell frecuentes.

function Register-DsCompletions {
    [CmdletBinding()]
    param()

    $moduleNames = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $root = $null
        try { $root = Join-Path (Get-DsHome) 'modules' } catch { return }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '_*' -and $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
            }
    }

    $themeNames = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $root = $null
        try { $root = Join-Path (Get-DsHome) 'themes' } catch { return }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
            }
    }

    $aiProviders = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        if (-not (Get-Command Get-DsAiProvider -ErrorAction SilentlyContinue)) { return }
        Get-DsAiProvider |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Description)
            }
    }

    $toolNames = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        if (-not (Get-Command Get-DsTool -ErrorAction SilentlyContinue)) { return }
        Get-DsTool |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Description)
            }
    }

    Register-ArgumentCompleter -CommandName Set-DsTheme -ParameterName Name -ScriptBlock $themeNames
    Register-ArgumentCompleter -CommandName Invoke-DsAi -ParameterName Provider -ScriptBlock $aiProviders
    Register-ArgumentCompleter -CommandName Test-DsAiProvider -ParameterName Name -ScriptBlock $aiProviders
    Register-ArgumentCompleter -CommandName Get-DsTool -ParameterName Name -ScriptBlock $toolNames
    Register-ArgumentCompleter -CommandName Test-DsTool -ParameterName Name -ScriptBlock $toolNames
    Register-ArgumentCompleter -CommandName Use-DsTool -ParameterName Name -ScriptBlock $toolNames

    Write-DsLog -Level Debug -Module completions -Message 'argument completers registered'
}

function Register-DsCompletionsOnLoad {
    Register-DsCompletions
}

Export-ModuleMember -Function Register-DsCompletions, Register-DsCompletionsOnLoad
