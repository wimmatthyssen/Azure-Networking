<#
.SYNOPSIS

A script used to configure NSG FLog logs for all NSG's used in an Azure Subscription.

.DESCRIPTION

A script used to configure NSG FLog logs for all NSG's used in an Azure Subscription.
The script will do all of the following:

Check if the PowerShell window is running as Administrator (when not running from Cloud Shell), otherwise the Azure PowerShell script will be exited.
Suppress breaking change warning messages.
Store the specified set of tags in a hash table.
Register Insights provider (Microsoft.Insights) in order for flow logging to work, if not already registered. Registration may take up to 10 minutes.
Create a resource group for the Storage account which will store the flow logs, if it not already exists
Create a general purpose v2 storage account for storing the flow logs with specific configuration settings, if it not already exists. Also apply the necessary tags to this storage account.
Enable NSG Flow logs and Traffic Analytics for all NSG's.

.NOTES

Filename:       Configure-NSG-Flow-Logs-for-all-NSGs-in-an-Azure-Subscription.ps1
Created:        18/08/2022
Last modified:  18/08/2022
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
.\Configure-NSG-Flow-Logs-for-all-NSGs-in-an-Azure-Subscription.ps1

.LINK

#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$abbraviationLog = "log"
$inventoryNumbering = 1
$region = "westeurope"

$rgNameStorage = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + "storage" + "-" + $inventoryNumbering.ToString("D2")
$rgNameNetworkWatcher = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + "networkwatcher" + "-" + $inventoryNumbering.ToString("D2")

$networkWatcherName = #<your Network Watcher name here> The name of the Network Watcher. Example: "nw-prd-myh-we-01"
$logAnalyticsWorkspaceName = #<your Log Analytics workspace name here> The name of your existing Log Analytics workspace. Example: "law-hub-myh-01"

$StorageAccountName = #<your Storage Account name here> The name of the storage account used to store your flow logs. Example: "stprdmyhlog01"
$storageAccountSkuName = "Standard_LRS"
$storageAccountType = "StorageV2"
$storageMinimumTlsVersion = "TLS1_2"

$nsgFlowLogsRetention = "90"
$trafficAnalyticsInterval = "60"

$tagSpokeName = #<your environment tag name here> The environment tag name you want to use. Example: "Env"
$tagSpokeValue = "$($spoke[0].ToString().ToUpper())$($spoke.SubString(1))"
$tagCostCenterName = #<your costCenter tag name here> The costCenter tag name you want to use. Example: "CostCenter"
$tagCostCenterValue = #<your costCenter tag value here> The costCenter tag value you want to use. Example: "23"
$tagCriticalityName = #<your businessCriticality tag name here> The businessCriticality tag name you want to use. Example: "Criticality"
$tagCriticalityValue = #<your businessCriticality tag value here> The businessCriticality tag value you want to use. Example:"High"
$tagPurposeName = #<your purpose tag name here> The purpose tag name you want to use. Example: "Purpose"
$tagPurposeValue = (Get-Culture).TextInfo.ToTitleCase($abbraviationLog.ToLower())
$tagSkuName = #<your SKU tag name here> The SKU tag name you want to use. Example: "Sku"
$tagSkuValue = $storageAccountSkuName

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

## Save Log Analytics workspace from the managment subscription in a variable

# ! Delete this part if the Log Analytics is in the same subscription as the current one, or change the -like search parameter if it is stored in another subscription !

$subNameCurrent = (Get-AzContext).Subscription
$subNameManagement = Get-Azsubscription | Where-Object {$_.Name -like "*management*"}

Set-AzContext -subscriptionId $subNameManagement.subscriptionId | Out-Null 

$workSpace = Get-AzOperationalInsightsWorkspace | Where-Object Name -Match $logAnalyticsWorkspaceName 

Set-AzContext -subscriptionId $subNameCurrent | Out-Null

Write-Host ($writeEmptyLine + "# Log Analytics workspace variable created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register Insights provider in order for flow logging to work, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.Insights resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.Insights  | Out-Null

Write-Host ($writeEmptyLine + "# Microsoft.Insights resource provider currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for the Storage account which will store the flow logs, if it not already exists

try {
    Get-AzResourceGroup -Name $rgNameStorage -ErrorAction Stop | Out-Null 
} catch {
    New-AzResourceGroup -Name $rgNameStorage -Location $region -Force | Out-Null 
}

# Save variable tags in a new variable to add tags
$tagsResourceGroup = $tags

# Add Purpose tag to tagsResourceGroup
$tagsResourceGroup += @{$tagPurposeName = "Storage"}

# Set tags rg storage
Set-AzResourceGroup -Name $rgNameStorage -Tag $tagsResourceGroup | Out-Null

Write-Host ($writeEmptyLine + "# Resource group $rgNameStorage available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a general purpose v2 storage account for storing the flow logs with specific configuration settings, if it not already exists. Also apply the necessary tags to this storage account.

try {
    Get-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $StorageAccountName -ErrorAction Stop | Out-Null 
} catch {
    New-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $StorageAccountName -SkuName $storageAccountSkuName -Location $region -Kind $storageAccountType `
    -AllowBlobPublicAccess $false -MinimumTlsVersion $storageMinimumTlsVersion | Out-Null 
}

# Save variable tags in a new variable to add tags
$tagsStorageAccount = $tags

# Add Purpose tag to tagsStorageAccount
$tagsStorageAccount += @{$tagPurposeName = $tagPurposeValue}

# Add Sku tag to tagsStorageAccount
$tagsStorageAccount += @{$tagSkuName = $tagSkuValue}

# Set tags storage account
Set-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $StorageAccountName -Tag $tagsStorageAccount | Out-Null

Write-Host ($writeEmptyLine + "# Storage account $StorageAccountName created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Enable NSG Flow logs and Traffic Analytics for all NSG's

$networkWatcher = Get-AzNetworkWatcher -Name $networkWatcherName -ResourceGroupName $rgNameNetworkWatcher
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName
$nsgs = Get-AzNetworkSecurityGroup

Foreach ($nsg in $nsgs) { 
  # Configure Flow log and Traffic Analytics
  Set-AzNetworkWatcherFlowLog -Name ($nsg.Name + "-flow-log") -NetworkWatcher $networkWatcher -TargetResourceId $nsg.Id -StorageId $storageAccount.Id -Enabled $true -FormatType Json `
  -FormatVersion 2 -EnableTrafficAnalytics -TrafficAnalyticsWorkspaceId ($workSpace.ResourceId) -TrafficAnalyticsInterval $trafficAnalyticsInterval -EnableRetention $true `
  -RetentionPolicyDays $nsgFlowLogsRetention -Tag $tags -Force | Out-Null

  Write-Host ($writeEmptyLine + "# NSG FLow logs and Traffic Analytics for $($nsg.Name) enabled" + $writeSeperatorSpaces + $currentTime) -foregroundcolor $foregroundColor2 $writeEmptyLine
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Query Flow Log Status

# Get-AzNetworkWatcherFlowLogStatus -NetworkWatcher $networkWatcher -TargetResourceId $nsg1.Id | Out-Null

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

