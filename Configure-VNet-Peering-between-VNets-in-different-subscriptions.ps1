<#
.SYNOPSIS

A script used to configure VNet peering between Hub and spoke VNets in different Azure Subscriptions.

.DESCRIPTION

A script used to configure VNet peering between Hub and spoke VNets in different Azure Subscriptions.

.NOTES

Filename:       Configure-VNet-Peering-between-VNets-in-different-subscriptions.ps1
Created:        20/04/2021
Last modified:  25/04/2022
Author:         Wim Matthyssen
PowerShell:     Azure PowerShell or Azure Cloud Shell
Version:        Install latest Azure PowerShell modules (at least Az version 7.2.0 and Az.Network version 4.16.0 is required)
Action:         Change variables were needed to fit your needs
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
.\Configure-VNet-Peering-between-VNets-in-different-subscriptions.ps1

.LINK

https://wmatthyssen.com/2022/04/25/azure-networking-configure-vnet-peering-with-an-azure-powershell-script-between-vnets-in-different-subscriptions/
#>

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$hub = "hub"
$spoke1 = "prd"
$spoke2 = "dev"
$spoke3 = "tst"

$subNameManagement = Get-AzSubscription | Where-Object {$_.Name -like "*management*"} #if needed, adjust to your subscription naming
$subNameIdentity = Get-AzSubscription | Where-Object {$_.Name -like "*identity*"} #if needed, adjust to your subscription naming
$subNamePrd = Get-AzSubscription | Where-Object {$_.Name -like "*$spoke1*corp*"} #if needed, adjust to your subscription naming
$subNameDev = Get-AzSubscription | Where-Object {$_.Name -like "*$spoke2*corp*"} #if needed, adjust to your subscription naming
$subNameTst = Get-AzSubscription | Where-Object {$_.Name -like "*$spoke3*"} #if needed, adjust to your subscription naming

$tenant = Get-AzTenant | Where-Object {$_.Name -like "*$companyShortName*"}

$rgNetworkingManagementHub = #<your Management Hub VNet rg here> The Azure resource group in which your existing Management Hub VNet is deployed. Example: "rg-hub-myh-networking-01" 
$rgNetworkingIdentityHub = #<your Identity Hub VNet rg here> The Azure resource group in which your existing Identity Hub VNet is deployed. Example: "rg-hub-myh-networking-02"
$rgNetworkingSpoke1 = #<your Spoke 1 VNet rg here> The Azure resource group in which your existing Spoke 1 VNet is deployed. Example: "rg-prd-myh-networking-01"
$rgNetworkingSpoke2 = #<your Spoke 2 VNet rg here> The Azure resource group in which your existing Spoke 2 VNet is deployed. Example: "rg-dev-myh-networking-01"  
$rgNetworkingSpoke3 = #<your Spoke 3 VNet rg here> The Azure resource group in which your existing Spoke 3 VNet is deployed. Example: "rg-tst-myh-networking-01"

$vnetNameManagementHub = #<your Management Hub VNet name here> The existing VNet in the Management Hub. Example: "vnet-hub-myh-weu-01" 
$vnetNameIdenitityHub = #<your Identity Hub VNet name here> The existing VNet in the Management Hub. Example: "vnet-hub-myh-weu-02"
$vnetNameSpoke1 = #<your Spoke 1 VNet VNet name here> The existing VNet in Spoke 1. Example: "vnet-prd-myh-weu-01"
$vnetNameSpoke2 = #<your Spoke 2 VNet VNet name here> The existing VNet in Spoke 2. Example: "vnet-dev-myh-weu-01"
$vnetNameSpoke3 = #<your Spoke 3 VNet VNet VNet name here> The existing VNet in Spoke 3. Example: "vnet-tst-myh-weu-01"

$subShort = "/subscriptions/"
$rgShort = "/resourceGroups/"
$providersShort = "/providers/Microsoft.Network/virtualNetworks/"

$remoteManagementHubVirtualNetworkId = $subShort + $subNameManagement.SubscriptionId + $rgShort + $rgNetworkingManagementHub + $providersShort + $vnetNameManagementHub
$remoteIdentityHubVirtualNetworkId = $subShort + $subNameIdentity.SubscriptionId + $rgShort + $rgNetworkingIdentityHub + $providersShort + $vnetNameIdenitityHub
$remoteSpoke1VirtualNetworkId = $subShort + $subNamePrd.SubscriptionId + $rgShort + $rgNetworkingSpoke1 + $providersShort + $vnetNameSpoke1
$remoteSpoke2VirtualNetworkId = $subShort + $subNameDev.SubscriptionId + $rgShort + $rgNetworkingSpoke2 + $providersShort + $vnetNameSpoke2
$remoteSpoke3VirtualNetworkId = $subShort + $subNameTst.SubscriptionId + $rgShort + $rgNetworkingSpoke3 + $providersShort + $vnetNameSpoke3

$peeringNameHub1 = #<your peering name Hub VNet 2 Hub Identity VNet> The peering name for the peering between the Hub VNet and Hub Identity VNet. Example: "peer-hub-2-hub-ide"
$peeringNameHub2 = #<your peering name Hub VNet 2 Spoke 1 VNet> The peering name for the peering between the Hub VNet and Spoke 1 VNet. Example: "peer-hub-2-hub-prd"
$peeringNameHub3 = #<your peering name Hub VNet 2 Spoke 2 VNet> The peering name for the peering between the Hub VNet and Spoke 2 VNet. Example: "peer-hub-2-hub-dev"
$peeringNameHub4 = #<your peering name Hub VNet 2 Spoke 3 VNet> The peering name for the peering between the Hub VNet and Spoke 3 VNet. Example: "peer-hub-2-hub-tst"
$peeringNameIde1 = #<your peering name Hub Identity VNet 2 Hub VNet> The peering name for the peering between the Hub Identity VNet and Hub VNet. Example: "peer-hub-ide-2-hub"
$peeringNamePrd1 = #<your peering name Spoke 1 VNet 2 Hub VNet> The peering name for the peering between the Spoke 1 VNet and Hub VNet. Example: "peer-prd-2-hub"
$peeringNameDev1 = #<your peering name Spoke 2 VNet 2 Hub VNet> The peering name for the peering between the Spoke 2 VNet and Hub VNet. Example: "peer-dev-2-hub"
$peeringNameTst1 = #<your peering name Spoke 3 VNet 2 Hub VNet> The peering name for the peering between the Spoke 3 VNet and Hub VNet. Example: "peer-tst-2-hub"

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
    Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 12 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
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
        Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 12 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1 $writeEmptyLine 
        }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Suppress breaking change warning messages

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create peerings from Management Hub VNet to all spokes VNets (peering with use of Virtual network gateway or Route Server set), if they don't exist

# Change the current context to use the Management subscription
Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNameManagement.SubscriptionId | Out-Null

$vnetManagementHub = Get-AzVirtualNetwork -Name $vnetNameManagementHub -ResourceGroupName $rgNetworkingManagementHub

# Create $peeringNameHub1, if it doesn't exist (peering with use of Virtual network gateway or Route Server set)
try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetManagementHub.Name -ResourceGroupName $rgNetworkingManagementHub -Name $peeringNameHub1 -ErrorAction Stop | Out-Null 
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameHub1 -VirtualNetwork $vnetManagementHub -RemoteVirtualNetworkId $remoteIdentityHubVirtualNetworkId -AllowGatewayTransit | Out-Null   
}

# Create $peeringNameHub2, if it doesn't exist (peering with use of Virtual network gateway or Route Server set)
try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetManagementHub.Name -ResourceGroupName $rgNetworkingManagementHub -Name $peeringNameHub2 -ErrorAction Stop | Out-Null
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameHub2 -VirtualNetwork $vnetManagementHub -RemoteVirtualNetworkId $remoteSpoke1VirtualNetworkId -AllowGatewayTransit | Out-Null  
}

# Create $peeringNameHub3, if it doesn't exist (peering with use of Virtual network gateway or Route Server set)
try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetManagementHub.Name -ResourceGroupName $rgNetworkingManagementHub -Name $peeringNameHub3 -ErrorAction Stop | Out-Null 
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameHub3 -VirtualNetwork $vnetManagementHub -RemoteVirtualNetworkId $remoteSpoke2VirtualNetworkId -AllowGatewayTransit | Out-Null  
}

# Create $peeringNameHub4, if it doesn't exist (peering with use of Virtual network gateway or Route Server set)
try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetManagementHub.Name -ResourceGroupName $rgNetworkingManagementHub -Name $peeringNameHub4 -ErrorAction Stop | Out-Null 
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameHub4 -VirtualNetwork $vnetManagementHub -RemoteVirtualNetworkId $remoteSpoke3VirtualNetworkId -AllowGatewayTransit | Out-Null   
}

Write-Host ($writeEmptyLine + "# VNet peering Management Hub configured" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create peering Identity Hub VNet - Management Hub VNet (peering with different subscriptions and use of remote gateway), if it doesn't exist

# Change the current context to use the Identity subscription
Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNameIdentity.SubscriptionId | Out-Null

$vnetIdentityHub = Get-AzVirtualNetwork -Name $vnetNameIdenitityHub -ResourceGroupName $rgNetworkingIdentityHub

try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetIdentityHub.Name -ResourceGroupName $rgNetworkingIdentityHub -Name $peeringNameIde1 -ErrorAction Stop | Out-Null 
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameIde1 -VirtualNetwork $vnetIdentityHub -RemoteVirtualNetworkId $remoteManagementHubVirtualNetworkId -UseRemoteGateways | Out-Null    
}

Write-Host ($writeEmptyLine + "# VNet peering Identity Hub configured" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create peering Spoke 1 (e.g. Production) VNet - Management Hub VNet (peering with different subscriptions and use of remote gateway), if it doesn't exist

# Change the current context to use the Corp Production subscription
Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNamePrd.SubscriptionId | Out-Null 

$vnetSpoke1 = Get-AzVirtualNetwork -Name $vnetNameSpoke1 -ResourceGroupName $rgNetworkingSpoke1

try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetSpoke1.Name -ResourceGroupName $rgNetworkingSpoke1 -Name $peeringNamePrd1 -ErrorAction Stop | Out-Null 
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNamePrd1 -VirtualNetwork $vnetSpoke1 -RemoteVirtualNetworkId $remoteManagementHubVirtualNetworkId -UseRemoteGateways | Out-Null    
}

Write-Host ($writeEmptyLine + "# VNet peering Prd configured" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create peering Spoke 2 (e.g. Development) VNet - Management Hub VNet (peering with different subscriptions and use of remote gateway), if it doesn't exist

# Change the current context to use the Corp Development subscription
Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNameDev.SubscriptionId | Out-Null 

$vnetSpoke2 = Get-AzVirtualNetwork -Name $vnetNameSpoke2 -ResourceGroupName $rgNetworkingSpoke2

try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetSpoke2.Name -ResourceGroupName $rgNetworkingSpoke2 -Name $peeringNameDev1 -ErrorAction Stop | Out-Null  
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameDev1 -VirtualNetwork $vnetSpoke2 -RemoteVirtualNetworkId $remoteManagementHubVirtualNetworkId -UseRemoteGateways | Out-Null 
}

Write-Host ($writeEmptyLine + "# VNet peering Dev configured" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create peering Spoke 3 (e.g. Test) VNet - Management Hub VNet (peering with different subscriptions and use of remote gateway), if it doesn't exist

# Change the current context to use the Test subscription
Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNameTst.SubscriptionId | Out-Null 

$vnetSpoke3 = Get-AzVirtualNetwork -Name $vnetNameSpoke3 -ResourceGroupName $rgNetworkingSpoke3

try {
    Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetSpoke3.Name -ResourceGroupName $rgNetworkingSpoke3 -Name $peeringNameTst1 -ErrorAction Stop | Out-Null 
} catch {
    Add-AzVirtualNetworkPeering -Name $peeringNameTst1 -VirtualNetwork $vnetSpoke3 -RemoteVirtualNetworkId $remoteManagementHubVirtualNetworkId -UseRemoteGateways | Out-Null  
}

Write-Host ($writeEmptyLine + "# VNet peering Tst configured" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
