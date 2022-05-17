<#
.SYNOPSIS
Enable Active Directory authentication for Azure Files
.DESCRIPTION
This script will enable Active Directory authentication for the Azure File Share
This script requires that an existing storage account and file share has already been created
This must be ran from a domain joined machine as a Domain Admin user
.EXAMPLE
.\AzFilesADDSEnablement.ps1 -DomainShortName "MyDomain" -AVDOUdistinguishedName = "OU=AVD,OU=Computers,DC=domain,DC=local"
.EXAMPLE
.\AzFilesADDSEnablement.ps1 -DomainShortName "Company" -AVDOUdistinguishedName = "OU=AVD,DC=company,DC=int" -FileShareName = "FSLogix"
.EXAMPLE
Or, just modify Variables and run!
#>

# Change the execution policy to unblock importing AzFilesHybrid.psm1 module
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# Define Variables
[cmdletbinding()]
param(
    [Parameter(Mandatory=$false,Position=0)]
    [string]$AVDProfileResourceGroupName = "P-AVD-EUS-RG",                       # Resource Group where Storage Account exists
    [Parameter(Mandatory=$false,Position=1)]
    [string]$AzFileHybridFolderName = "C:\AzFilesHybrid",                        # Folder to save AzFilesHybrid script
    [Parameter(Mandatory=$false,Position=2)]
    [string]$AzFilesVer = "v0.2.4",                                              # Current version from website
    [Parameter(Mandatory=$false,Position=3)]
    [string]$DomainShortName = "DOMAIN",                                         # Shortname of Domain used for DOMAIN\USER
    [Parameter(Mandatory=$false,Position=4)]
    [string]$AVDAdminGroupName = "AVDAdmins",                                    # AD Group for AVD Administrators
    [Parameter(Mandatory=$false,Position=5)]
    [string]$AVDUserGroupName = "AVDUsers",                                      # AD Group for AVD Users
    [Parameter(Mandatory=$false,Position=6)]
    [string]$AVDOUdistinguishedName = "OU=AVDComputers,DC=domain,DC=com",        # Distinguished Name for OU where AVD Session Hosts are located
    [Parameter(Mandatory=$false,Position=7)]
    [string]$AVDFileShareName = "profiles",                                      # Name of File Share in Storage Account
    [Parameter(Mandatory=$false,Position=8)]
    [ValidateSet("yes","no","y","n","auto")]
    [string]$AVDAzFileCleanupYN = "yes"                                          # Clean up after task [yes,y,no,n]. "auto" variable used when called by another script
    
)

# Check for $AzFileHybridFolderName.  Create if doesn't exist.
Write-Host "Checking for existing $AzFileHybridFolderName directory."
if (Test-Path $AzFileHybridFolderName) {
   
    Write-Host "Folder Exists"
    Start-Sleep -s 2
}else{
    New-Item $AzFileHybridFolderName -ItemType Directory
    Write-Host "Folder Created Successfully"
    Start-Sleep -s 2
}

# Download and Extract AzFilesHybrid
Write-Host "Downloading AZFilesHybrid Script"
Start-Sleep -s 2
Invoke-WebRequest -Uri "https://github.com/Azure-Samples/azure-files-samples/releases/download/$AzFilesVer/AzFilesHybrid.zip" -OutFile "$AzFileHybridFolderName\AzFilesHybrid.zip" -UseBasicParsing
Set-Location -Path $AzFileHybridFolderName
Expand-Archive -path AzFilesHybrid.zip -DestinationPath .\
.\CopyToPSPath.ps1 

# Join storage account to Active Directory
Write-Host "Joining Storage account to domain"
Start-Sleep -s 2
Import-Module -Name AzFilesHybrid
Connect-AzAccount
<# Command not used
$SubscriptionId = (Get-AzContext).Subscription.Id
#>
$StorageAccountName = (Get-AzStorageAccount -ResourceGroupName $AVDProfileResourceGroupName)[0].StorageAccountName
Join-AzStorageAccountForAuth `
  -ResourceGroupName $AVDProfileResourceGroupName `
  -StorageAccountName $StorageAccountName `
  -DomainAccountType 'ComputerAccount' `
  -OrganizationalUnitDistinguishedName $AVDOUdistinguishedName

# Verify AD Auth is enabled for storage account.
<# 
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $AVDProfileResourceGroupName -Name $StorageAccountName
$StorageAccount.AzureFilesIdentityBasedAuth.ActiveDirectoryProperties
$StorageAccount.AzureFilesIdentityBasedAuth.DirectoryServiceOptions
#>

# Retrieve key for storage account
Write-Host "Retrieving storage account key and mounting profile share"
Start-Sleep -s 2
<#  Commands not necessary
$storageAccount = (Get-AzStorageAccount -ResourceGroupName $AVDProfileResourceGroupName)[0]
#$storageAccountName = $storageAccount.StorageAccountName
#>
$StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $AVDProfileResourceGroupName -Name $StorageAccountName).Value[0]
net use Z: "\\$StorageAccountName.file.core.windows.net\$AVDFileShareName" /u:AZURE\$StorageAccountName $StorageAccountKey

# Update folder permissions using icacls
Write-Host "Updating Permissions on profile share"
Start-Sleep -s 2
$permissions = "$DomainShortName\$AVDAdminGroupName"+':(F)'
cmd /c icacls Z: /grant $permissions
$permissions = "$DomainShortName\$AVDUserGroupName"+':(M)'
cmd /c icacls Z: /grant $permissions
$permissions = 'Creator Owner'+':(OI)(CI)(IO)(M)'
cmd /c icacls Z: /grant $permissions
icacls Z: /remove 'Authenticated Users'
icacls Z: /remove 'Builtin\Users'

# Unmount profile storage
Write-Host "Unmounting profile share"
Start-Sleep -s 2
net use Z: /delete /y

Write-Host "Active Directory enablement of profile share has been completed."
Start-Sleep -s 1
Write-Host 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

if ($AVDAzFileCleanupYN -eq "yes" -OR $AVDAzFileCleanupYN -eq "y")
{
    Write-Host "Cleaning up scripts"
    Start-Sleep -s 2
    Remove-Item -LiteralPath $AzFileHybridFolderName -Force -Recurse
    Set-Location -Path $HOME
    Write-Host "Scripts $AzFileHybridFolderName directory has been cleared!"
    Start-Sleep -s 1
}elseif($AVDAzFileCleanupYN -eq "no" -OR $AVDAzFileCleanupYN -eq "n"){Write-Host "All files in $AzFileHybridFolderName directory will remain intact."
}elseif($AVDAzFileCleanupYN -eq "auto"){Write-Host "AzFilesADDSEnablement.ps1 script has been completed."}

Write-Host 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
