<#
.SYNOPSIS
Configuration of AVD Session Host
.DESCRIPTION
This script Configures basics of a session host
.EXAMPLE
.\AVDSessionHostSetup.ps1 -OOBE generatize
.EXAMPLE
.\AVDSessionHostSetup.ps1 -AVDHostDir "C:\MyDirectory"
.EXAMPLE
Or, just modify Variables and run!
Run the following before running the .\AVDSessionHostSetup.ps1 file
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
#>

#### Define Parameters that can be called
[cmdletbinding()]
param(
    [Parameter(Mandatory=$false,Position=0)]
    [string]$AVDHostDir = "C:\AVDWorkingDir",           # Working Directory for files
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateSet("generalize","standard")]
    [string]$OOBE = "standard"                          # Out of Box Experience [generalize=run sysprep;standard=don't run sysprep]
)

#### Disable Windows Updates
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
#### Disable Storage Sense
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 0 /f
#### Configure Time Zone Redirection
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fEnableTimeZoneRedirection /t REG_DWORD /d 1 /f
#### Disable feedback hub collection of telemetry data
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f

#### Configure Teams for AVD
reg add "HKLM\Software\Microsoft\Teams" /v IsWVDEnvironment /t REG_DWORD /d 1 /f
## Download and install Visual C++ Redis 64bit
Set-Location -Path $AVDHostDir
Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vc_redist.x64.exe" -UseBasicParsing -OutFile "$AVDHostDir\vc_redist.x64.exe"
.\vc_redist.x64.exe /install /passive /norestart /log $AVDHostDir\vc_redist.log
## Check if Teams Machine-Wide Installer is installed.  Install if Installer is not installed.
$TeamsCheck = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Contains "Teams Machine-Wide Installer"
if (-Not $TeamsCheck)
{
    Invoke-WebRequest -Uri "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true" -UseBasicParsing -OutFile "$AVDHostDir\Teams_windows_x64.msi"
    msiexec /i $AVDHostDir\Teams_windows_x64.msi /l*v $AVDHostDir\Teams.log ALLUSER=1
}else{Write-Host "Teams Machine-Wide Installer detected.  Skipping Installation"; Start-Sleep -s 2}

#### Install MS Edge
Start-BitsTransfer -Source "https://aka.ms/edge-msi" -Destination "$AVDHostDir\MicrosoftEdgeEnterpriseX64.msi"
Start-Process -Wait -Filepath msiexec.exe -Argumentlist "/i $AVDHostDir\MicrosoftEdgeEnterpriseX64.msi /q"

#### Run Disk Cleanup Utility ###### INTERACTIVE - Wait to complete
## FYI - As of 5/2022, Disk cleanup may be depecated in the near future
cleanmgr /d C: /verylowdisk
Write-Host "Please wait for Disk Cleanup to finish.";
Write-Host "Press any key when complete...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

#### Run sysprem if "generalize" parameter is defined.  This will generalize the VM to be converted to an image
if ($OOBE -eq "generalize")
{
    Write-Host "Running SysPrep to Generalize Image"
    Start-Sleep -s 2
    C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown
}elseif($OOBE -eq "standard")
{
    Write-Host "Image is ready."
    Start-Sleep -s 1
    Write-Host "Press any key to continue...";
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}    
