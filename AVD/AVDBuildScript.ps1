<#
.SYNOPSIS
Master Build Script for AVD
.DESCRIPTION
This script pulls multiple other scripts and processes for building of Azure Virtual Desktop
.EXAMPLE
.\AVDBuildScript.ps1 -WorkingFolder "C:\AzureWorkingFolder" -DomainShortName "DOMAIN"
.EXAMPLE
Or, just modify Variables and run!
Run the following before running the .\AVDBuildScript.ps1 file
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
#>

<# Defined Parameters
The Following Parameters are required:
  -DomainShortName
  -AVDOUdistinguishedName
#>
[cmdletbinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$WorkingFolder = "C:\AzureWorkingFolder",                           # Working folder for scripts
    [Parameter(Mandatory=$false)]
    [string]$CleanUpWhenDoneYN = "yes",                                         # Delete when done? "Yes,y,No,n"
    [Parameter(Mandatory=$false)]
    [string]$AVDProfileResourceGroupName = "P-AVD-EUS-RG",                      # AVD Resource Group for Profiles
    [Parameter(Mandatory=$false)]
    [string]$AzFilesVer = "v0.2.4",                                             # Version of Azure File Share Hybrid
    [Parameter(Mandatory=$true)]
    [string]$DomainShortName = "DOMAIN",                                        # Shortname for Domain
    [Parameter(Mandatory=$false)]
    [string]$AVDAdminGroupName = "AVDAdmins",                                   # Security Group for AVD Admins
    [Parameter(Mandatory=$false)]
    [string]$AVDUserGroupName = "AVDUsers",                                     # Security Group for AVD Users
    [Parameter(Mandatory=$true)]
    [string]$AVDOUdistinguishedName = "OU=AVDComputers,DC=domain,DC=com",       # OU for AVD Session Hosts
    [Parameter(Mandatory=$false)]
    [string]$AVDFileShareName = "profiles"
)
$BuildRepo = "https://skyterrastorage.blob.core.windows.net/public/newbuilds"

# Disable IE Enhanced Security for admins
Write-Host "Disabling IE Enhanced Security for admins"
$adminRegEntry = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}'
Set-ItemProperty -Path $AdminRegEntry -Name 'IsInstalled' -Value 0
Stop-Process -Name Explorer

# Create Working Folder
New-Item $WorkingFolder -ItemType Directory
Write-Host "$WorkingFolder Created Successfully"
Start-Sleep -s 2

########## Add something about continuing or ending if folder already exists.  State that contents will be cleared out.  GOTO End if no.

Set-Location -Path $WorkingFolder
Invoke-WebRequest -Uri "$BuildRepo/AVD/AzFilesADDSEnablement.ps1" -OutFile "$WorkingFolder\AzFilesADDSEnablement.ps1" -UseBasicParsing
.\AzFilesADDSEnablement.ps1 $AVDProfileResourceGroupName $WorkingFolder $AzFilesVer $DomainShortName $AVDAdminGroupName $AVDUserGroupName $AVDOUdistinguishedName $AVDFileShareName auto


if ($CleanUpWhenDoneYN -eq "yes" -OR $CleanUpWhenDoneYN -eq "y")
{
    Write-Host "Cleaning up scripts"
    Start-Sleep -s 2
    Remove-Item -LiteralPath $WorkingFolder -Force -Recurse
    Set-Location -Path $HOME
    Write-Host "Scripts $WorkingFolder directory has been cleared!"
    Start-Sleep -s 1
}elseif($CleanUpWhenDoneYN -eq "no" -OR $CleanUpWhenDoneYN -eq "n"){Write-Host "All files in $WorkingFolder directory will remain intact."}

Write-Host -NoNewLine "Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
