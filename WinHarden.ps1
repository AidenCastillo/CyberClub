# Search for users that do not have passwords
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$PrincipalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine')

Get-LocalUser | Where-Object Enabled -eq $true | ForEach-Object {
    $myUsername = $_.Name
    $myPasswordIsBlank = $PrincipalContext.ValidateCredentials($myUserName, $null)
    If ($myPasswordIsBlank) {
        # Do whatever you want here to output or alert the fact that you found a blank password.
            Write-Output "User does not have password:"
            Write-Output $myUsername
    }
}



# Password Policy
net accounts /uniquepw:10
net accounts /maxpwage:90
net accounts /minpwage:30
net accounts /minpwlen:8

# Registry Keys
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "PasswordComplexity" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\currentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -Value 1

gpupdate /force

# Account Lockout Policy
net accounts /lockoutthreshold:10
net accounts /lockoutduration:30
net accounts /lockoutwindow:30

# Firewall
Write-Output "Enabling Windows Firewall..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Windows Defender Antivirus
Write-Output "Enabling Windows Defender Antivirus..."
Set-MpPreference -DisableRealtimeMonitoring $false

# Enable Automaitc Updates
Write-Output "Setting Windows updates to automatically check for updates..."
$wuKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
New-Item -Path $wuKeyPath -Force | Out-Null
Set-ItemProperty -Path $wuKeyPath -Name "AUOptions" -Value 4 # 4 means auto install

# Event Log Service
Write-Output "Event Log service status..."
$eventLogService = Get-Service -Name "EventLog"
if ($eventLogService.Status -ne "Running") {
    Write-Output "Starting Event Log Service..."
    Start-Service -Name "EventLog"
} else {
    Write-Output "Event log service already running"
}

# Disable and stop FTP service if running
Write-Output "Checking FTP service status..."
$ftpService = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue
if ($ftpService -and $ftpService.Status -eq "Running") {
    Write-Output "Disabling and stopping microsoft ftp service"
    Stop-Service -Name "FTPSVC" -Force
    Set-Service -Name "FTPSVC" -StartupType Disabled
} else {
    Write-Output "Microsoft ftp service is not found or already stopped"
}

# uninstalll programs
$appsToUninstall = @("Wireshark", "BitTorrent", "Adaware Web Companion")

foreach ($app in $appsToUninstall) {
    Write-Output "Checking for $app..."
    $appUninstall = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = '$app'" -ErrorAction SilentlyContinue
    if ($appUninstall) {
        Write-Output "Uninstalling $app..."
        $appUninstall.Uninstall() | Out-Null
        Write-Output "$app as been uninstalled."
    } else {
        Write-Output "$app is not installed."
    }
}


Write-Output "System hardening tasks completed."
