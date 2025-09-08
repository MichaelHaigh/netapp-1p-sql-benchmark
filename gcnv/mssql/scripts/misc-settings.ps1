# Disable Windows updates (for 35 days)
$pause = (Get-Date).AddDays(35)
$pause = $pause.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ssZ" )
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -Value $pause

# Adjust for "best performance"
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Value 2

# Disable server manager startup
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
