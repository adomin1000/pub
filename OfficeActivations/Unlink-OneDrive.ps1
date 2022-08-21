Function Remove-OneDriveBusinessLink {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Alias("UserPrincipalName")]
        [Alias("UserEmail")]
        [Alias("EmailAddress")]
        [MailAddress]$Account
    )

    $accountsRegKeyPath = 'HKCU:\Software\Microsoft\OneDrive\Accounts'

    # Get subkeys matching "Business" (may be more than 1)
    $businessSubKeys = (Get-Item $accountsRegKeyPath).GetSubKeyNames() -match '^Business'

    # Loop through subkeys and find the one with the specified Account matching the value of
    # the UserEmail property
    foreach ($subkey in $businessSubKeys) {

        $oneDriveAccountKeyPath = Join-Path -Path $accountsRegKeyPath -ChildPath $subkey

        if ((Get-ItemProperty -Path $oneDriveAccountKeyPath -Name UserEmail).UserEmail -match "^$Account$") {

            Write-Output "Found $Account in $oneDriveAccountKeyPath"

            # Get the DisplayName. This is the only way to reference another registry key that
            # needs to be deleted
            $displayName = (Get-ItemProperty -Path $oneDriveAccountKeyPath -Name DisplayName).DisplayName
            $oneDriveName = "OneDrive - $displayName"

            # Get all subkeys in below regkey location. The subkey containing (Default) value matching
            # DisplayName will be deleted
            $desktopPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace'
            $desktopSubKeys = (Get-Item $desktopPath).GetSubKeyNames()

            foreach ($subKey in $desktopSubKeys) {

                $subKeyFullPath = Join-Path -Path $desktopPath -ChildPath $subKey

                if ((Get-ItemProperty -Path $subKeyFullPath).'(Default)' -eq $oneDriveName) {

                    if ($PSCmdlet.ShouldProcess("Delete OneDrive registry keys for $Account")) {

                        # Found (Default) value matching DisplayName
                        # Safe to delete all relative keys

                        Write-Output "Name is ""$oneDriveName"""

                        Remove-Item -Path $subKeyFullPath -Recurse

                        Write-Output "Deleted (Default) in $subKeyFullPath containing ""$oneDriveName"""

                        # Delete the account key path
                        Remove-Item -Path $oneDriveAccountKeyPath -Recurse
                        Write-Output "Removed $oneDriveAccountKeyPath"

                        Stop-Process -Name OneDrive
                        Write-Output "OneDrive process stopped"
                    }
                }
            }
        }
    }
}
Remove-OneDriveBusinessLink