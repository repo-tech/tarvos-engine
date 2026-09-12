[CmdletBinding()]
param(
    [string]$Version = "v1.5.0",
    [string]$Repository = "repo-tech/tarvos-engine",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

$window = New-Object Windows.Window
$window.Title = "Tarvos Setup"
$window.Width = 560
$window.Height = 300
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"

$panel = New-Object Windows.Controls.StackPanel
$panel.Margin = New-Object Windows.Thickness(28)
$window.Content = $panel

$title = New-Object Windows.Controls.TextBlock
$title.Text = "Install Tarvos"
$title.FontSize = 26
$title.FontWeight = "SemiBold"
$panel.Children.Add($title) | Out-Null

$subtitle = New-Object Windows.Controls.TextBlock
$subtitle.Text = "A user-local, zero-administrator installation"
$subtitle.Margin = New-Object Windows.Thickness(0, 6, 0, 18)
$panel.Children.Add($subtitle) | Out-Null

$status = New-Object Windows.Controls.TextBlock
$status.Text = "Ready to install Tarvos $Version."
$status.TextWrapping = "Wrap"
$status.Margin = New-Object Windows.Thickness(0, 0, 0, 18)
$panel.Children.Add($status) | Out-Null

$progress = New-Object Windows.Controls.ProgressBar
$progress.Height = 16
$progress.IsIndeterminate = $true
$progress.Visibility = "Collapsed"
$panel.Children.Add($progress) | Out-Null

$button = New-Object Windows.Controls.Button
$button.Content = "Install Tarvos"
$button.Width = 150
$button.Height = 34
$button.HorizontalAlignment = "Right"
$button.Margin = New-Object Windows.Thickness(0, 20, 0, 0)
$panel.Children.Add($button) | Out-Null

$button.Add_Click({
    $button.IsEnabled = $false
    $progress.Visibility = "Visible"
    $status.Text = "Downloading and verifying Tarvos $Version..."
    try {
        $script = Join-Path $PSScriptRoot "install.ps1"
        & $script -Version $Version -Repository $Repository -Force:$Force
        $status.Text = "Tarvos installed successfully. Open a new terminal to use it."
        $button.Content = "Done"
    } catch {
        $status.Text = "Installation failed: $($_.Exception.Message)"
        $status.ToolTip = "The v1.5.0 release must be published to repo-tech/tarvos-engine before installation."
        $button.IsEnabled = $true
    } finally {
        $progress.Visibility = "Collapsed"
    }
})

$window.ShowDialog() | Out-Null
