<#
.SYNOPSIS

A script used to disconnect all current P2S VPN connections.

.DESCRIPTION

A script used to disconnect all current P2S VPN connections.
The script will do all of the following:

Check if the PowerShell window is running as Administrator (when not running from Cloud Shell), otherwise the Azure PowerShell script will be exited.
Suppress breaking change warning messages.
Check Virtual Network Gateway parameter input. If the input is incorrect, the script will be exited.
Retrieve all current sessions and save them in a variable.
Disconnect all current sessions.

.NOTES

Filename:       Disconnect-all-current-P2S-VPN-connections.ps1
Created:        19/08/2022
Last modified:  19/08/2022
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v5.9.0) and Az.Network (v4.16.0)
Action:         Change variables were needed to fit your needs
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "<xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx>" (if not using the default tenant)
Set-AzContext -Subscription "<SubscriptionName>" (if not using the default subscription)
.\Disconnect-all-current-P2S-VPN-connections.ps1

.LINK


#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $gatewayName,
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $rgNameGateway
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$global:currenttime= Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime= Get-Date -UFormat "%A %m/%d/%Y %R"}
$foregroundColor1 = "Red"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Check if PowerShell runs as Administrator (when not running from Cloud Shell), otherwise exit the script

if ($PSVersionTable.Platform -eq "Unix") {
    Write-Host ($writeEmptyLine + "# Running in Cloud Shell" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine
    
    ## Start script execution    
    Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 1 minute to complete" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine 
} else {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        ## Check if running as Administrator, otherwise exit the script
        if ($isAdministrator -eq $false) {
        Write-Host ($writeEmptyLine + "# Please run PowerShell as Administrator" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1 $writeEmptyLine
        Start-Sleep -s 3
        exit
        }
        else {

        ## If running as Administrator, start script execution    
        Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 1 minute to complete" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1 $writeEmptyLine 
        }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Suppress breaking change warning messages

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Check Virtual Network Gateway parameter input. If the input is incorrect, the script will be exited

try {
    Get-AzVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $rgNameGateway -ErrorAction Stop | Out-Null 
} catch {
    Write-Host ($writeEmptyLine + "# VPN Gateway $gatewayName does not exist, please validate your input. The script will be exited" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine 
    Start-Sleep -s 3
    exit
}

Write-Host ($writeEmptyLine + "# Virtual Network Gateway with name $gatewayName exists in the current subscription. The script will continue" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Retrieve all current sessions and save them in a variable

$currentSessions = Get-AzVirtualNetworkGatewayVpnClientConnectionHealth -VirtualNetworkGatewayName $gatewayName -ResourceGroupName $rgNameGateway 

Write-Host ($writeEmptyLine + "# Current sessions variable created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Disconnect all current sessions

Foreach ($currentSession in $currentSessions) { 
    Disconnect-AzVirtualNetworkGatewayVpnConnection -VirtualNetworkGatewayName $gatewayName -ResourceGroupName $rgNameGateway `
    -VpnConnectionId $currentSession.VpnConnectionId | Out-Null
  
    Write-Host ($writeEmptyLine + "# Session with VpnConnectionID $($currentSession.VpnConnectionId) disconnected" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
  }
  
## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed. Wait at least 5 minutes to validate that all sessions are disconnected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
