# Service Application and DB names
$stateName = "State Service"
$stateDBName = "SP2013_Auto_SA_StateService"
$usageName = "Usage and Health Data Collection Service Application"
$usageDBName = "SP2013_Auto_SA_Usage"

<# Create State Service Application and Proxy, and add to default proxy group
        we need the state service for many things, like workflow and the like
        State isn't a "real" service application, note the lack of app pool etc
#>
Write-Host "Creating $stateName Application and Proxy..."
$stateDB = New-SPStateServiceDatabase -Name $stateDBName
$state = New-SPStateServiceApplication -Name $stateName -Database $stateDB
New-SPStateServiceApplicationProxy -Name "$stateName Proxy" -ServiceApplication $state -DefaultProxyGroup | out-null
Get-spdatabase | where-object {$_.type -eq "Microsoft.Office.Server.Administration.StateDatabase"} | initialize-spstateservicedatabase
Write-Host "Created $stateName Application and Proxy..."

<# Setup the Usage Service App
        configuring Search later will do this automatically but uses default names
        we cannot change the Proxy name
        Usage isn't a "real" service application, note the lack of app pool etc
#>
Write-Host "Creating $usageName Application and Proxy..."
$serviceInstance = Get-SPUsageService
New-SPUsageApplication -Name $usageName -DatabaseName $usageDBName -UsageService $serviceInstance | out-null
$proxy = Get-SPServiceApplicationProxy | where {$_.TypeName -eq "Usage and Health Data Collection Proxy"}
# Clean up the proxy name
$proxy.Name = $proxy.TypeName
$proxy.Update()
$proxy.Provision()
Write-Host "Created $usageName Application and Proxy..."

Write-Host "Enabling Heatlth Data Collection..."
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Diagnostics") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Administration")
$farm = [Microsoft.SharePoint.Administration.SPFarm]::Local
[Microsoft.SharePoint.Diagnostics.SPDiagnosticsProvider]::EnableAll($farm)