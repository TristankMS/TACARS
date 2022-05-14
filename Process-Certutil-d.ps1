<#
Disclaimer
The sample scripts are not supported under any Microsoft standard support 
program or service. 
The sample scripts are provided AS IS without warranty of any kind. Microsoft
further disclaims all implied warranties including, without limitation, any 
implied warranties of merchantability or of fitness for a particular purpose.
The entire risk arising out of the use or performance of the sample scripts and 
documentation remains with you. In no event shall Microsoft, its authors, or 
anyone else involved in the creation, production, or delivery of the scripts be
liable for any damages whatsoever (including, without limitation, damages for 
loss of business profits, business interruption, loss of business information, 
or other pecuniary loss) arising out of the use of or inability to use the 
sample scripts or documentation, even if Microsoft has been advised of the 
possibility of such damages.
 -----------------------
 Process-Certutil-D.ps1
-----------------------
# Original by Russell Tomkins
# Revisions by TristanK
# Debug Test Line: .\process-certutil-d.ps1 -InputFile ".\Allrequests.log" -ExportFile ".\DEBUG.csv" -CAName "DEBUGCA" -AdditionalExportPath C:\LogBackups -Debug

  .SYNOPSIS
  Imports the output of a CA database query by LargeCollector.cmd (using "certutil.exe -view" with restrictions)
  and converts it into a CSV file, or a PowerShell XML object.

  .DESCRIPTION
  Allows an administrator to work with a Powershell Object or CSV version of the Certutil CA Database view command.
  
  An example command that generates the output for all issued certificates that will expire in the next 90 days is
  certutil.exe -view -restrict "NotAfter<=now+90:00,Disposition=20"

  Imports the certutil.exe dump output and outputs the contents to xml.
  Process-CertUtil.ps1 -InputFile .\CertUtilExport.txt -OutputFile .\CertutilExport.xml

  .EXAMPLE
  Imports the certutil.exe dump output and outputs the contents to xml.
  Process-CertUtil.ps1 -InputFile .\CertUtilExport.txt -OutputFile .\CertutilExport.xml

  
  .PARAMETER InputFile
  The certutil.exe -dump output file file to be processed. 
  This file will be record of the stdout ">" the certutil.exe command executed 
  against a CA database.
  .PARAMETER OutputFile
  The resulting processed powershell object as an XML object
  .PARAMETER ExpiresIn
  The resulting processed powershell object
  .PARAMETER ExportFile
  The CSV export of the PowerShell object 
  .PARAMETER ExportBackupPath
  A folder to which to copy an export of the current CSV file being processed.
  Files will be ISO-Named (2021-12-13-1030-AllRequests.csv)
  .PARAMETER CAName
  Optional name for the CA Issuer
  #>

[CmdletBinding()]
    Param (
	# Input File
    [Parameter(Mandatory=$true,ValueFromPipeline=$True,Position=0)]
	[ValidateNotNullOrEmpty()]
	[String]$InputFile,
	
   	# Export File
    [Parameter(Mandatory=$true,
    ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
    Position=1,ParameterSetName = "Export")]
	[ValidateNotNullOrEmpty()]
	[String]$ExportFile,

    [Parameter(Mandatory=$false)]
    [string]
    $ExportBackupPath,
    
    [Parameter(Mandatory=$false)]
	[String]$CAName,

    [Parameter(Mandatory=$false)]
	[Bool]$Append = $false
    )

    function DTString {
        param( [string]$InputDate )
            [string]$DT = Get-Date -Format o $InputDate
            "$DT"
       }


    function ISODateTime{
        return (Get-Date).tostring("yyyy-MM-dd-HHmmss")
    }

    function DateToUniversalString{
        param ([datetime]$InputDate)
        [datetime] $inDateUTC = $InputDate.ToUniversalTime()
        [string]$UT = [string]::Format("{0:yyyy-MM-ddThh:mm:ss.fffZ}", $inDateUTC)
        $UT
    }
    function ConvertDateToUTC{
        param ([string] $PossibleDate)
        if([string]::IsNullOrEmpty($PossibleDate))
        {
            return ""
        }
        try{
            $tempdate = Get-Date $PossibleDate
        }
        catch{
            return $null
        }

        if(!$null -eq $tempdate){
            return DateToUniversalString($tempdate)
        }
        else{
            return $null
        }
    }
    function ParseHexDumpToString($lineInput){
        $oneLine = $lineInput.TrimStart()
        $startcol = 57
        $endColChars = $oneLine.Length - $startcol
        $cheatRange = $oneLine.SubString($StartCol, $endColChars)
        $cheatrange
    }
    function ParseSIDString($lineInput){
        if([String]::IsNullOrEmpty($lineinput)){
            return ""
        }
        if($lineInput.Length -lt 26){
            return ""
        }
        $Startcol = 20
        $EndCol = $lineInput.Length - $StartCol
        $SID = $lineInput.SubString($StartCol,$endCol)
        $SID
    }

# Preparation
$Rows = @()
$InputFile = (Get-Item $InputFile).FullName
$ExportFilenamePortionOnly = $ExportFile.Split("\")[-1]
$ExportBackupFilename = "$ExportBackupPath\$(ISODateTime)-$ExportFilenamePortionOnly"


if($ExportBackupPath){
    if(Test-Path $ExportBackupPath -PathType Container){
        "  Additional backup will be copied to $ExportBackupFileName "
    }
    # else disable export backup?
}


Write-Host "Process-Certutil-D Reading Input File " $InputFile
Switch($PSCmdlet.ParameterSetName)
    {
		"Export"    
        {
            if($Append -ne $True){
                if(Test-Path $ExportFile){
                    Remove-Item $ExportFile -Force
                }
            }
        }
		"Output"
		{
			if(Test-Path $OutputFile){
				Remove-Item $OutputFile -Force
			}
		}

    }

$rowfakeID=1

# Loop through the input file, one line at a time.
ForEach ($Line in [System.IO.File]::ReadLines("$InputFile")) {
    
    if($skipNextLine -eq $true){
        $skipNextLine = $false
        continue
    }
    # Look for the word Row in othe output
    If($Line -Match "Row \d" -or $Line -match "_ADCS_ROW_COUNT:" ){
        Write-Debug "New Row line / End of previous Certificate Row"
        #If we have a RowID populated on a Row custom object, finalise the custom object.
        If($null -ne $Row.RowID){
            $Rows += $Row
        }
        
        # Last line of ADCS Collector files... cos the Certutil command line might simply be an error or a midpoint
        If($Line -Match "_ADCS_ROW_COUNT:")
        {
            #$Rows += $Row # save out any in-flight rows!
            Write-Debug "_ADCS_ROW_COUNT hit"
            $rowfakeID--
            Break
        }
        
        # Create a new row for the next record
        $Row = "" | Select-Object Host,RowID,RequestID,RequestSubmitted,Requester,Disposition,DispositionMessage,Serial,Subject-CN,ValidFrom,ValidTo,EKU,CDP,AIA,AKI,SKI,Subject-C,Subject-O,Subject-OU,Subject-DN,Subject-Email,SAN,Template,TemplateMajor,TemplateMinor,BinaryCert,RequestStatusCode,RevocationDate,EffectiveRevocationDate,RequestAttributes,SIDExt
        $Row.Host = $CAName
        [int]$Row.RowID = $rowfakeID -as [int] #($Line.Replace("Row ","")).Replace(":","")
        $Row.EKU = 'Empty'
        $Row.SAN = 'Empty'
        $Row.CDP = 'Empty'
        $Row.AIA = 'Empty'
        
        $rowfakeID++
        if($rowfakeID % 100 -eq 0){
            "$rowfakeID"
        }

        if($rowfakeID % 4000 -eq 0){
                
                # Export-As-We-Go
                Switch($PSCmdlet.ParameterSetName){
                    "Export"    
                        {
                        Write-Host "Exporting CSV records"
                        $Rows | Export-CSV $ExportFile -NoTypeInformation -Append -UseQuotes AsNeeded # note for PSv7 can use -UseQuotes AsNeeded
                        
                        Write-Host "Checkpoint records written to file $ExportFile"
                        $Rows = @()
                        }
                        # possible spot for "Upload" activity every 4K records
                }
                
        }
    } # end of Row setup

    # Prepare the Field and Values
    $Line = $Line.Trim()
    $arrLine = $Line.Split(":",2)
    $Field = $arrLIne[0].Trim()
    $Value = $arrLIne[1]
    $Value = $Value -Replace '"',''
    $Value = $Value.Trim()

    # Well known single lines
    Switch($Field) {
        "Request ID" { if ($Value -match "(?:\()(\d*)(?:\))"){ $Row.RequestID = $matches[1] -as[int]} else{$Row.RequestID = $Value.Replace("0x","") -as[int]} } # want to modify this to extract bracketed number? eg 0x77 (119)
        "Request Disposition" {$Row.Disposition = $Value} # not an int, hex/int/message ->  Request Disposition: 0x14 (20) -- Issued
        "Request Disposition Message" {$Row.DispositionMessage = $Value} 
        "Requester Name" {$Row.Requester = $Value}
        "Request Submission Date" { $Row.RequestSubmitted = ConvertDateToUTC($Value) }
        "Serial Number" {$Row.Serial = $Value}
        "Certificate Effective Date" { $Row.ValidFrom  = ConvertDateToUTC($Value) }
        "Issued Common Name" {$Row."Subject-CN" = $Value}
        "Issued Country/Region" {$Row."Subject-C" = $Value}
        "Issued Organization" {$Row."Subject-O" = $Value}
        "Issued Organization Unit" {$Row."Subject-OU" = $Value}
        "Issued Distinguished Name" {$Row."Subject-DN" = $Value}
        "Issued Email Address" {$Row."Subject-Email" = $Value}
        "Issued Subject Key Identifier" {$Row.SKI = $Value}
        "Revocation Date" {$Row.RevocationDate = ConvertDateToUTC($Value) }
        "Effective Revocation Date" {$Row.EffectiveRevocationDate = ConvertDateToUTC($Value) }
        # note that this will cause a breakage when trying to go cross-region (eg interpreting an en-US date from anywhere else)
        # so rem it out if needed
        "Certificate Expiration Date"  {$Row.ValidTo = ConvertDateToUTC($Value) } #  {$Row.ValidTo = $Value}
        #$Row.DaysTilExpiry = (([Decimal]::Round((New-TimeSpan $Now $Row.ValidTo).TotalDays))*-1)}   
        
        # and specifically because it's not done in the same way as a "whole" export, we need a template catcher
        "Certificate Template" {$Row.Template = $Value}
        "Request Status Code" {$Row.RequestStatusCode = $Value}
        # OID stripping is an exercise for the reader
    }    

    # Process the Multi Line Values if we identified them on the last loop
    Switch ($NextSection){
        "Template" {
            If($Line -match "Template="){
                $Row.Template = $Line.Split("=",2)[1]}
            If($Line -match "Major Version Number="){
                $Row."TemplateMajor" = $Line.Split("=",2)[1]}
            If($Line -match "Minor Version Number="){
                $Row."TemplateMinor" = $Line.Split("=",2)[1]}
            } 
            "AKI"{
                If(($Line -match "KeyID")){$Row.AKI = $Line}
            }       
            "EKU"{ 
                If ($Line -ne ''){
                    If($Row.EKU -eq 'Empty'){
                        $Row.EKU = $Line}
                    Else {$Row.EKU = $Row.EKU + "|" + $Line}
                }
            }
            "SAN"{
                If(($Line -match "Principal Name=") -or ($Line -match "DNS Name=") -or ($line -match "DS Object Guid=") -or ($line -match "RFC822 Name=")){
                    If($Row.SAN -eq 'Empty'){
                        $Row.SAN = $Line}
                    Else {$Row.SAN = $Row.SAN + "|" + $Line}
                }
            }
            "CDP"{ 
                If(($Line -match "URL")){
                    If($Row.CDP -eq 'Empty'){
                        $Row.CDP = $Line}
                    Else {$Row.CDP = $Row.CDP + "|" + $Line}
                }
            }
            "AIA"{ 
                If(($Line -match "URL")){
                    If($Row.AIA -eq 'Empty'){
                        $Row.AIA = $Line}
                    Else {$Row.AIA = $Row.AIA + "|" + $Line}
                }
            }
            "BinaryCert"{ 
                If ($Line -ne ''){
                    $Row.BinaryCert = $Row.BinaryCert + $Line
                }
            }
            "SIDExt"{
                If (![String]::IsNullOrWhiteSpace($line)){
                    $Row.SIDExt += ParseHexDumpToString($Line)
                }
                else{
                    $Row.SIDExt = ParseSIDString($Row.SIDExt)
                }
            }
        }
        Switch($Field) {
            "Authority Key Identifier" {$NextSection = "AKI"}
            "Subject Alternative Name" {$NextSection = "SAN"}
            "Enhanced Key Usage" {$NextSection = "EKU"}
            "CRL Distribution Points" {$NextSection = "CDP"}
            "1.3.6.1.5.5.7.1.1" {$NextSection = "AIA"}
            "1.3.6.1.4.1.311.21.7" {$NextSection = "Template"}
            "1.3.6.1.4.1.311.25.2" {$NextSection = "SIDExt"; $SkipNextLine = $true ;} # there's a one-line blank for SID extension output in release of kb5014754
            "-----BEGIN CERTIFICATE-----" {$NextSection = "BinaryCert";$Row.BinaryCert="-----BEGIN CERTIFICATE-----"}
            "" {$NextSection=$Null}
        }    

    }
"Completed $rowfakeID"

# Finished processing lines
# Add the final row if we reached the end or just stopped receiving "row" lines.
#$Rows += $Row


# Output depending on our purpose
Switch($PSCmdlet.ParameterSetName){
    "Export"    {
                    Write-Host "Final CSV Export..."
                    if($Rows.Count -gt 0)
                    {
                        Write-Debug "Rows.Count = $($Rows.Count)"
                        $Rows | Export-CSV $ExportFile -NoTypeInformation -Append -UseQuotes AsNeeded
                        Write-Host "$($Rows.Count) written to file $ExportFile"
                        if($ExportBackupPath){
                            "  Backing up Export file to $ExportBackupPath "
                            Copy-Item $ExportFile -Destination $ExportBackupFilename -Force
                        }
                        
                    }else{
                        "No rows to export."
                    }
                }
                
}
# ==============================================    
# End of Main Script
# ==============================================
