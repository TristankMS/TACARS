[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $WorkspaceID,
    [Parameter()]
    [string]
    $WorkspaceKey,
    [Parameter()]
    [string]
    $ProxyServerURL="",
    [Parameter()]
    [string]
    $CSVFile = ".\current.csv",
    [Parameter()]
    [string]
    $TableName = "CAMonitor"
)

Function Get-PostSignature
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $WorkspaceID,
        [Parameter()]
        [string]
        $WorkspaceKey,
        [Parameter()]
        [string]
        $Date,
        [Parameter()]
        [string]
        $ContentLength,
        [Parameter()]
        [string]
        $Method,
        [Parameter()]
        [string]
        $ContentType,
        [Parameter()]
        [string]
        $Resource
    )
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($WorkspaceKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $WorkspaceID,$encodedHash
    return $authorization
}

Function Send-LogAnalyticsData
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $WorkspaceID,
        [Parameter()]
        [string]
        $WorkspaceKey,
        [Parameter()]
        [byte[]]
        $Body,
        [Parameter()]
        [string]
        $LogType,
        [Parameter()]
        [string]
        $ProxyServerURL = ""
    )

    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Get-PostSignature `
        -WorkspaceID $WorkspaceID `
        -WorkspaceKey $WorkspaceKey `
        -Date $rfc1123date `
        -ContentLength $contentLength `
        -Method $method `
        -ContentType $contentType `
        -Resource $resource
    $uri = "https://" + $WorkspaceID + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    Write-host "Posting to $uri ..."
    if([string]::IsNullOrEmpty($ProxyServerURL)){
        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    }
    else{
        $response = Invoke-WebRequest -Proxy $ProxyServerURL -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    }
    
    Write-host "Response body: $($response.body)"

    return $response.StatusCode
}


$MaxRecordsPerPost = 200 # arbitrary
# not used (yet?)
$MaxBytesPerPost = 28000000 # bytes before overflow, (30MB-2MB safety margin)

# Specify the name of the record type that you'll be creating
# _CL will be appended for a custom log format
$LogType = $TableName

if(Test-Path $CSVFile){
    $csv = Import-Csv $CSVFile
}
else{
    "No new CSV file found. Exiting."
    exit
}

# You can use an optional field to specify the timestamp from the data. 
# If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
$TimeStampField = ""

$batch=1
$start=0
$currentset=-1
$AllRows = $CSV.Count-1
$startTime = Get-Date

"Commencing at $startTime"
""

while ($currentset -lt $AllRows){
    $start = $currentset+1 # increment index
    $currentSet += ($MaxRecordsPerPost)
    if($currentSet -gt $AllRows){$currentSet = $AllRows}
    #$CurrentTime = Get-Date -format u
    Write-Host -ForegroundColor Green "BATCH $batch - Rows $($start+1) to $($currentSet+1)"
    # non-human rows 0 to X
    
    # get JSON
    if($csv.Count -gt 1){
        $postContent = $csv[$start..$currentSet] | ConvertTo-Json | foreach {$_ -replace ': "([0-9]+)"',': $1'}
    }
    else{
        $postContent = $csv[$start] | ConvertTo-Json | foreach {$_ -replace ': "([0-9]+)"',': $1'}
    }
    
    # encode for post
    $body = ([System.Text.Encoding]::UTF8.GetBytes($postContent))
    "  $($body.Count) bytes to send"
    # post
    $statuscode = Send-LogAnalyticsData -WorkspaceID $WorkspaceID -WorkspaceKey $WorkspaceKey -Body $Body -logType $logType -ProxyServerURL $ProxyServerURL
    "  Response code: $statuscode"

    if($statuscode -ne 200){
        $postContent | Out-File .\JSON_Error_Batch_$batch.JSON # for debugging
    }
    else{
        #$postContent | Out-File .\JSON_OK_Batch_$batch.JSON # for debugging
    }

    #Write-host -ForegroundColor Gray $postContent
    $batch++
}
$endTime = Get-Date
"Completed at $endTime"
