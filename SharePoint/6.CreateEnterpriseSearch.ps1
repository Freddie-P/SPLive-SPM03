$databaseServer = "SPSQL"
$databaseName = "SP2013_Auto_SA_Search"
$ServiceAppPool = "SharePoint Web Services Default"
$IndexLocation = "C:\Indexes\SP2013_Search"
$SearchServiceApplicationName = "Search Service Application"

$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$currentHostName = $objIPProperties.HostName

$searchServer = $currentHostName

$searchServiceAccount = "splive360\svcspservices"
$searchServiceAccountPassword = (ConvertTo-SecureString "Devise!!!" -AsPlainText -force)
$searchContentAccessAccount = "splive360\svcspcontentacc"
$searchContentAccessAccountPassword = (ConvertTo-SecureString "Devise!!!" -AsPlainText -force)
 
Write-Host -ForegroundColor Green "Setting up Search..."

Write-Host -ForegroundColor Yellow "Verifying Index Location..."
if (Test-Path $IndexLocation) {
    Write-Host -ForegroundColor Red "   Index location exists. Clearing it out..."
    Remove-Item -Recurse -Force -LiteralPath $IndexLocation -ErrorAction SilentlyContinue 
} 

Write-Host -ForegroundColor Green "   Index location created..."
New-Item -Path $IndexLocation -type Directory

Write-Host -ForegroundColor Yellow "Starting services on $searchServer" 
Start-SPEnterpriseSearchServiceInstance $searchServer
Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $searchServer
 
Write-Host -ForegroundColor Yellow "Creating service application..."
$searchApp = New-SPEnterpriseSearchServiceApplication -Name $SearchServiceApplicationName -ApplicationPool $ServiceAppPool -DatabaseServer $databaseServer -DatabaseName $databaseName -ErrorAction SilentlyContinue -ErrorVariable err

if ($err) {
    Write-Host -ForegroundColor Red "We errored, but keep calm and continue on!"
}

$searchInstance = Get-SPEnterpriseSearchServiceInstance $searchServer
 
$ssa = Get-SPEnterpriseSearchServiceApplication
 
Write-Host -ForegroundColor Yellow "Creating cloned topology..."
$original = $ssa.ActiveTopology
$clone = $ssa.ActiveTopology.Clone()
 
New-SPEnterpriseSearchAdminComponent –SearchTopology $clone -SearchServiceInstance $searchInstance
New-SPEnterpriseSearchContentProcessingComponent –SearchTopology $clone -SearchServiceInstance $searchInstance
New-SPEnterpriseSearchAnalyticsProcessingComponent –SearchTopology $clone -SearchServiceInstance $searchInstance
New-SPEnterpriseSearchCrawlComponent –SearchTopology $clone -SearchServiceInstance $searchInstance
New-SPEnterpriseSearchQueryProcessingComponent –SearchTopology $clone -SearchServiceInstance $searchInstance
  
Set-SPEnterpriseSearchAdministrationComponent -SearchApplication $ssa -SearchServiceInstance  $searchInstance

New-SPEnterpriseSearchIndexComponent –SearchTopology $clone -SearchServiceInstance $searchInstance -RootDirectory $IndexLocation -IndexPartition 0
 
Write-Host -ForegroundColor Yellow "   Activating topology..."
$clone.Activate()
Write-Host -ForegroundColor Green "Cloned topology activated..."

Write-Host -ForegroundColor Red "Next call will provoke an error but after that the old topology can be deleted - just ignore it!"
$original.Synchronize()

Write-Host -ForegroundColor Yellow "Deleting old topology..."
Remove-SPEnterpriseSearchTopology -Identity $original -Confirm:$false
Write-Host -ForegroundColor Green "Old topology deleted"
 
Write-Host -ForegroundColor Yellow "Creating Service Application Proxy..."
$searchAppProxy = New-SPEnterpriseSearchServiceApplicationProxy -Name "$SearchServiceApplicationName Proxy" -SearchApplication $SearchServiceApplicationName > $null

Write-Host -ForegroundColor Yellow "Setting Search Service Account..."
Set-SPEnterpriseSearchService -Identity $SearchServiceApplicationName –ServiceAccount $searchServiceAccount –ServicePassword $searchServiceAccountPassword

Write-Host -ForegroundColor Yellow "Setting Default Content Access Account..."
Set-SPEnterpriseSearchServiceApplication -Identity $SearchServiceApplicationName -DefaultContentAccessAccountName $searchContentAccessAccount -DefaultContentAccessAccountPassword $searchContentAccessAccountPassword

Write-Host -ForegroundColor Green "Done!"