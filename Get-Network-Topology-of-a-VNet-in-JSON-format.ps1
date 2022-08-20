<#
.SYNOPSIS

An Azure PowerShell script used to get the network topology of a VNet in a JSON output.

.DESCRIPTION

An Azure PowerShell script used to get the network topology of a VNet in a JSON output.
This output will give you a network level view of all networking resources and their relationships from a specific resource group.
If resources from multiple regions reside in the resource group, only the resources in the same region as the Network Watcher will be included in the JSON output.

.NOTES

Filename:       Get-Network-Topology-of-a-VNet-in-JSON-format.ps1
Created:        07/08/2022
Last modified:  07/08/2022
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Cloud Shell
Requires:       PowerShell Az (v8.1.0) and Az.Network (v4.18.0)
Action:         Change variables were needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "<xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx>" (if not using the default tenant)
Set-AzContext -Subscription "<SubscriptionName>" (if not using the default subscription)
.\Get-Network-Topology-of-a-VNet-in-JSON-format.ps1 <your network watcher name here> <your networking resource group here>

-> .\Get-Network-Level-View-of-a-VNet.ps1 nw-hub-myh-we-01 rg-hub-myh-networking-01

.LINK

https://wmatthyssen.com/2022/08/09/azure-tip-use-azure-network-watcher-to-view-or-download-the-network-topology-of-a-vnet/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $networkWatcherName,
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $rgNameVNet
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$global:currenttime= Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime= Get-Date -UFormat "%A %m/%d/%Y %R"}
$foregroundColor1 = "Red"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Retrieve a VNet network level view

# Get the properties of the Network Watcher
$networkWatcher = Get-AzNetworkWatcher -Name $networkWatcherName -ResourceGroupName $networkWatcherResourceGroup

#Get network topology
Get-AzNetworkWatcherTopology -NetworkWatcher $networkWatcher -TargetResourceGroupName $rgNameVNet

Write-Host ($writeEmptyLine + "# VNet network level view created " + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------