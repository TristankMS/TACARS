[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('AllRequests','ActiveCertsBasic','IssuedCertsBasic',"Everything","EverythingCurrent")]
    [string]$CollectionTarget,
    [Parameter()]
    [string]$TableName = $CollectionTarget, # might want to use CA depending on data
    [Parameter()]
    [string]$ProxyServerURL,  # eg http://10.1.1.254:3128
    [Parameter()]
    [string]
    $WorkspaceID,
    [Parameter()]
    [string]
    $WorkspaceKey,
    [Parameter(Mandatory=$false)]
    [string]
    $ExportBackupPath,
    [Switch]
    $NoUpload
)

$ScriptName = "ExportCertificateData.ps1"
# IF the upload has completed, run a new log dump

Write-host -ForegroundColor Green "$ScriptName - Export certs since last run..."
# Get certs since last run
& .\LargeLogger.cmd "$CollectionTarget.log" $CollectionTarget

Write-host -ForegroundColor Green "$ScriptName - Convert exported certs to CSV with Process-Certutil-D"
# convert to CSV
if(!$ExportBackupPath){
    .\process-certutil-d.ps1 -InputFile ".\$CollectionTarget.log" -ExportFile ".\$CollectionTarget.csv" -CAName "$($env:Computername)"
} else{
    .\process-certutil-d.ps1 -InputFile ".\$CollectionTarget.log" -ExportFile ".\$CollectionTarget.csv" -CAName "$($env:Computername)" -ExportBackupPath $ExportBackupPath
}

if($NoUpload -eq $false){
    Write-host -ForegroundColor Green "$ScriptName - Upload exported records to Log Analytics with Upload-LogAnalyticsData.ps1"
    .\Upload-LogAnalyticsData.ps1 -CSVFile ".\$CollectionTarget.csv" -TableName $TableName -ProxyServerUrl $ProxyServerURL -WorkspaceID $WorkspaceID -WorkspaceKey $WorkspaceKey
    Write-host -ForegroundColor Green "$ScriptName - Script complete for $CollectionTarget to $TableName"
} else{
    Write-host -ForegroundColor Green "$ScriptName - Skipping log upload due to -NoUpload being set"
}

#Done

