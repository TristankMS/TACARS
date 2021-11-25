@Echo Off
SETLOCAL 

:: Customize this file and save as GO.CMD (or save multiple versions as you like...)

:: Find your Log Analytics Workspace ID and key from the Azure portal https://portal.azure.com/ 
SET WORKSPACEID=12345678-blah-blah-blah-123456780123
SET WORKSPACEKEY=Base64encodingmeansthisisactuallyaSemiPlausibleOutcomebutthekeygoeshere==

:: ProxyURL format: http://nameOrIp:port or blank for no proxy
SET PROXYURL=
:: eg SET PROXYURL=http://10.1.1.1:3128 

:: Set the collection target type - defaults to AllRequests. 
:: Other options: ActiveCertsBasic, IssuedCertsBasic
SET COLLECTIONTARGET=AllRequests

:: If you want to vary the table name, replace %COMPUTERNAME% with the new table name
:: Note TABLENAME must obey Log Analytics conventions, and the eventual tablename will have _CL appended
SET TABLENAME=

:: Path to the PowerShell 7 (or later) executable. If in system PATH, just PWSH.EXE should suffice
SET PWSHPATH=PS7\PWSH.EXE

:: Want a backup of the intermediate CSV files? We can do that...
:: The folder will be created for you if it doesn't exist, so get it right!
SET ExtraBackup=
:: e.g. SET ExtraBackup=C:\ExtraLogs

:: Create backup folder if needed
if NOT "%PROXYURL%"=="" SET PROXYBIT= -ProxyServerURL %PROXYURL%
if NOT "%EXTRABACKUP%"=="" (
    IF NOT EXIST %EXTRABACKUP%(
        echo Creating %EXTRABACKUP%
        MD %EXTRABACKUP% 
        )
    )
:: Expand any required script parameters...
if NOT "%PROXYURL%"=="" SET PROXYBIT= -ProxyServerURL %PROXYURL%
if NOT "%EXTRABACKUP%"=="" SET EXTRABIT= -ExportBackupPath %EXTRABACKUP%
if "%COLLECTIONTARGET%"=="" SET COLLECTIONTARGET=AllRequests
if "%TABLENAME%"=="" SET TABLENAME=%COMPUTERNAME%
if "%1"=="NOUPLOAD" SET NOUPLOADBIT= -NoUpload

:: Run PowerShell 7 with the parameters above.
%PWSHPATH% -command "& {.\ExportCertificateData.ps1 -CollectionTarget %COLLECTIONTARGET% -TableName %TABLENAME% -WorkspaceID %WORKSPACEID% -WorkspaceKey %WORKSPACEKEY% %PROXYBIT% %EXTRABIT% %NOUPLOADBIT%}

:: And we're done!
ENDLOCAL