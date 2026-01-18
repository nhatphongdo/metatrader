<#
.SYNOPSIS
    Setup git hooks for this project
.DESCRIPTION
    Configures git to use .githooks directory for hooks
#>

Write-Host "Setting up git hooks..."
git config core.hooksPath .githooks
Write-Host "Done! Git hooks are now active."
