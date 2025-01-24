# This script is used/can be called to add role membership to a user.
param(
    [bool]$wantToAddRoleMember = $true,
    [string]$RoleName = "Security Reader",
    [Parameter(Mandatory = $true)]
    [string]$RoleMemberEmailAddress
)

if(-not $wantToAddRoleMember){
    Write-Host "You have chosen not to add the RoleMember"
    Write-Host "So I will just run the get-command"
    Get-MsolRoleMember -RoleName $RoleName
} else {
    Write-Host "You have chosen to add the RoleMember"
    Write-Host "So I will run the add-command"
    Add-MsolRoleMember -RoleName $RoleName -RoleMemberEmailAddress $RoleMemberEmailAddress
}