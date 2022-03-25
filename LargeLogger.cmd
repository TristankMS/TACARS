@echo off
rem .
rem ADCS Large Logger
rem .
Setlocal

:CheckUsage
if "%1"=="" goto Usage
if "%2"=="" goto Usage

rem LargeLogger.CMD <CLEARLOG>
rem LargeLogger.CMD <OutputFilename> <mode> [[DateToday] [DateAMonthAgo]]
rem %1 is REQUIRED and is either CLEARLOG or the name of the output file name
rem %2 is the mode in which to run the collector (Issued, Active, etc - See Usage)
rem %3 is OPTIONAL for W2008R2+ and is today's date - or any date you want to use as an ending point
rem %4 is OPTIONAL for W2008R2+ and is the date a month ago - or at any date prior to %3
rem if %3 is set, it's a good idea to set %4 as well

SET _Version=0.6
rem .
rem * PageSize is the number of rows attemptedly dumped at a time.
rem * on slow IO or shared IO systems, this may be orders of magnitude slower,
rem * and you may need to customize the _PAGESIZESMALL value even lower.
SET _PAGESIZE=50000
SET _PAGESIZESMALL=1000

rem We're going to use the Collector Type to track differing watermarks for differing situations
rem SET _PROGRESSLOGFILE=%~dp1 for same folder as output file.
SET _PROGRESSLOGFILE=.\%2_LargeDBProgress.log
SET _WATERMARKFILE=.\%2_WaterMark-Hi.TXT
SET _LASTWATERMARKFILE=.\%2_WaterMark-Last.TXT
SET _FINDTEMP=.\_Findtemp.txt

echo Large Logger - Variables established.
SET LEGACY=0
SET FALLBACKCOUNT=0

:ClearLogFile
if "%1"=="CLEARLOG" echo. > %_PROGRESSLOGFILE%
if "%1"=="CLEARLOG" goto ExitNow

:GetHighWatermark
rem _HighWaterMark is just the highest request ID, not the count of items of type X
rem initialize everything

SET _HighWaterMark=0
SET _LastWaterMark=0
SET _Count=0
rem remove this one
SET /A "_Range=_PAGESIZE"
SET _Total=0

rem Avoid CSV for 2003 and 2008
ver | find "5.2"
if %ERRORLEVEL%==0 SET LEGACY=1
ver | find "6.0"
if %ERRORLEVEL%==0 SET LEGACY=1

if %LEGACY%==1 GOTO LEGACY2003

:CSV2008R2
echo Non-Legacy Mode
Rem init high watermark and last watermark
certutil -view -restrict "RequestID=$" -out RequestID csv > %_WATERMARKFILE%
FOR /F "tokens=1" %%i in (%_WATERMARKFILE%) do SET /A _HighWaterMark=%%i
FOR /F "tokens=1" %%i in (%_LASTWATERMARKFILE%) do SET /A _LastWaterMark=%%i
::if %_LastWaterMark% GEQ %_HighWaterMark% echo LWM %_LastWaterMark% equals HWM %_HighWaterMark% - Nothing to do && GOTO FastExit
if %_LastWaterMark% GTR %_Count% SET _Count=%_LastWaterMark%
SET /A "_Range=_Count+_PAGESIZE"
SET _NOW=now
SET _MonthAgo=now-30:00
:: override if needed
if NOT "%3"=="" SET "_NOW=%3"
if NOT "%4"=="" SET "_MonthAgo=%4"

goto Collection

:LEGACY2003
Rem init high watermark and last watermark
Echo Legacy Mode
certutil -view -restrict "RequestID=$" -out RequestID > .\HighRequestID.TXT
findstr /C:"Issued Request ID:" .\HighRequestID.TXT > %_WATERMARKFILE%
FOR /F "delims=(): tokens=2" %%i in (%_WATERMARKFILE%) do SET /A _HighWaterMark=%%i
FOR /F "delims=(): tokens=2" %%i in ((%_LASTWATERMARKFILE%) do SET /A _LastWaterMark=%%i
::if %_LastWaterMark% GEQ %_HighWaterMark% echo LWM %_LastWaterMark% equals HWM %_HighWaterMark% - Nothing to do && GOTO FastExit
if %_LastWaterMark% GTR %_Count% SET _Count=%_LastWaterMark%
SET /A "_Range=_Count+_PAGESIZE"
set _NOW=%3
set _MonthAgo=%4
goto Collection



:FallBack
rem If you got here, you failed PAGESIZE record collection, so we're trying again with a smaller pagesize
rem THIS WILL TAKE LONGER
Echo Falling back to smaller page size...
Set _PAGESIZE=%_PAGESIZESMALL%
SET /A "_Range=_PAGESIZE"
SET /A _Count=0
SET FALLBACKCOUNT=1
echo =============================================================== >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - HELLO AGAIN LARGE COLLECTOR %_Version% >> %_PROGRESSLOGFILE%
echo Re running with page size %_PAGESIZE% ================================ >> %_PROGRESSLOGFILE%
goto Collection


:Collection
Echo Collection Start
echo %DATE% %TIME% > %1
echo. >> %1

Echo Hello Large Collector! Last Watermark was %_LastWaterMark% and high is %_HighWaterMark%
echo --------------------------------------------------------------- >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - HELLO LARGE COLLECTOR %_Version% >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - Running in %2 mode to %1 >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - High watermark is %_HighWaterMark% >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - Last watermark is %_LastWaterMark% >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - Page size is %_PAGESIZE% >> %_PROGRESSLOGFILE%
echo %DATE% %TIME% - Starting... >> %_PROGRESSLOGFILE%


:LoopStart
Echo Start Logging Loop
if %_LastWaterMark% GEQ %_HighWaterMark% GOTO End

if %_Range% GTR %_HighWaterMark% SET _Range=%_HighWaterMark%

echo %DATE% %TIME% - %_Count% to %_Range% of %_HighWaterMark%
echo %DATE% %TIME% - %_Count% to %_Range% of %_HighWaterMark% >> %_PROGRESSLOGFILE%

set CommonFields=Request.RequestID,certificatetemplate,notafter,commonname,ext:2.5.29.17,Request.SubmittedWhen

goto %2

:AllRequests
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%" -out Request.RequestID,Request.StatusCode,Request.Disposition,Request.DispositionMessage,Request.SubmittedWhen,Request.ResolvedWhen,Request.RevokedWhen,Request.RevokedEffectiveWhen,Request.RevokedReason,Request.CallerName,certificatetemplate,EnrollmentFlags,GeneralFlags,PrivateKeyFlags,SerialNumber,IssuerNameID,SubjectKeyIdentifier,NotBefore,NotAfter,commonname,ext:2.5.29.17,ext:2.5.29.37,Request.RequesterName,Request.RequestAttributes,RawCertificate,Request.RawOldCertificate >> %1
goto ContinueLoop

:IssuedCertsBasic
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=20" -out Request.RequestID,Request.StatusCode,Request.Disposition,Request.DispositionMessage,Request.SubmittedWhen,Request.ResolvedWhen,Request.RevokedWhen,Request.RevokedEffectiveWhen,Request.RevokedReason,Request.CallerName,certificatetemplate,EnrollmentFlags,GeneralFlags,PrivateKeyFlags,SerialNumber,IssuerNameID,SubjectKeyIdentifier,NotBefore,NotAfter,commonname,ext:2.5.29.17,ext:2.5.29.37,Request.RequesterName,Request.RequestAttributes >> %1
goto ContinueLoop

:ActiveCertsBasic
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,NotAfter>%_now%,disposition=20" -out Request.RequestID,Request.StatusCode,Request.Disposition,Request.DispositionMessage,Request.SubmittedWhen,Request.ResolvedWhen,Request.RevokedWhen,Request.RevokedEffectiveWhen,Request.RevokedReason,Request.CallerName,certificatetemplate,EnrollmentFlags,GeneralFlags,PrivateKeyFlags,SerialNumber,IssuerNameID,SubjectKeyIdentifier,NotBefore,NotAfter,commonname,ext:2.5.29.17,ext:2.5.29.37,Request.RequesterName,Request.RequestAttributes >> %1
goto ContinueLoop

:: Quick warning - this will be LARGE in text form
:Everything
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=20" -out Request.RequestID,Request.StatusCode,Request.Disposition,Request.DispositionMessage,Request.SubmittedWhen,Request.ResolvedWhen,Request.RevokedWhen,Request.RevokedEffectiveWhen,Request.RevokedReason,Request.CallerName,certificatetemplate,EnrollmentFlags,GeneralFlags,PrivateKeyFlags,SerialNumber,IssuerNameID,SubjectKeyIdentifier,NotBefore,NotAfter,commonname,ext:2.5.29.17,ext:2.5.29.37,ext:1.3.6.1.4.1.311.21.7,Request.RequesterName,Request.RequestAttributes,RawCertificate,Request.RawOldCertificate >> %1
goto ContinueLoop

:EverythingCurrent
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,NotAfter>%_now%,disposition=20" Request.RequestID,Request.StatusCode,Request.Disposition,Request.DispositionMessage,Request.SubmittedWhen,Request.ResolvedWhen,Request.RevokedWhen,Request.RevokedEffectiveWhen,Request.RevokedReason,Request.CallerName,certificatetemplate,EnrollmentFlags,GeneralFlags,PrivateKeyFlags,SerialNumber,IssuerNameID,SubjectKeyIdentifier,NotBefore,NotAfter,commonname,ext:2.5.29.17,ext:2.5.29.37,ext:1.3.6.1.4.1.311.21.7,Request.RequesterName,Request.RequestAttributes,RawCertificate,Request.RawOldCertificate >> %1
goto ContinueLoop


:Issued
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=20" -out Request.RequestID,certificatetemplate,notafter,commonname,ext:2.5.29.17,Request.SubmittedWhen,Request.RequesterName >> %1
goto ContinueLoop

:Issued30Day
  certutil -view -restrict "Request.SubmittedWhen>%_MonthAgo%,RequestID>%_Count%,RequestID<=%_Range%,disposition=20" -out Request.RequestID,certificatetemplate,notafter,commonname,ext:2.5.29.17,Request.SubmittedWhen,Request.RequesterName >> %1
goto ContinueLoop

:Active
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,NotAfter>%_now%,disposition=20" -out Request.RequestID,certificatetemplate,notafter,commonname,ext:2.5.29.17,Request.SubmittedWhen,Request.RequesterName >> %1
goto ContinueLoop

:Failed
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=30" -out Request.RequestID,certificatetemplate,Request.RequesterName,Request.SubmittedWhen,Request.StatusCode >> %1
goto ContinueLoop

:Failed30Day
  certutil -view -restrict "Request.SubmittedWhen>%_MonthAgo%,RequestID>%_Count%,RequestID<=%_Range%,disposition=30" -out Request.RequestID,Request.SubmittedWhen,Request.commonname,ext:2.5.29.17,certificatetemplate,Request.RequesterName,Request.StatusCode >> %1
goto ContinueLoop

:Denied
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=31" -out Request.RequestID,certificatetemplate,Request.SubmittedWhen,Request.RequesterName,Request.CommonName,Request.StatusCode >> %1
goto ContinueLoop

:Denied30Day
  certutil -view -restrict "Request.SubmittedWhen>%_MonthAgo%,RequestID>%_Count%,RequestID<=%_Range%,disposition=31" -out Request.RequestID,Request.SubmittedWhen,Request.commonname,ext:2.5.29.17,certificatetemplate,Request.RequesterName,Request.StatusCode >> %1
goto ContinueLoop

:Revoked
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=21" -out Request.RequestID,certificatetemplate,commonname,ext:2.5.29.17,Request.SubmittedWhen,notafter,Request.RevokedWhen,Request.RevokedEffectiveWhen >> %1
goto ContinueLoop

:Revoked30Day
  certutil -view -restrict "Request.SubmittedWhen>%_MonthAgo%,RequestID>%_Count%,RequestID<=%_Range%,disposition=21" -out Request.RequestID,certificatetemplate,commonname,ext:2.5.29.17,Request.SubmittedWhen,notafter,Request.RevokedWhen,Request.RevokedEffectiveWhen >> %1
goto ContinueLoop

:Pending
  certutil -view -restrict "RequestID>%_Count%,RequestID<=%_Range%,disposition=9" -out Request.RequestID,certificatetemplate,Request.Commonname,ext:2.5.29.17,Request.SubmittedWhen, >> %1
goto ContinueLoop

:ContinueLoop

if %_Range%==%_HighWaterMark% goto End

IF %ERRORLEVEL% NEQ 0 (
  echo Export Failure %ERRORLEVEL%
	echo %DATE% %TIME% - %_Count% to %_Range% of %_HighWaterMark% - ### Error Occurred - %ERRORLEVEL%
	echo %DATE% %TIME% - %_Count% to %_Range% of %_HighWaterMark% - ### Error Occurred - %ERRORLEVEL% >> %_PROGRESSLOGFILE%
	if %FALLBACKCOUNT% EQU 0 (
		goto FallBack
	) ELSE (
		rem Nowhere to go from here except down.
		echo ### ERROR ### Didn't survive fallback - try a lower set of page sizes
		echo %DATE% %TIME% - ### ERROR ### Didn't survive 1 fallback - try a lower set of page sizes >> %_PROGRESSLOGFILE%
		goto ExitNow
	)
)

SET /A "_Count+=_PAGESIZE"
SET /A "_Range+=_PAGESIZE"

goto LoopStart

:Usage
echo.
echo Usage
echo =====
echo.
echo LargeLogger.CMD CLEARLOG
echo LargeLogger.CMD ^<OutputFilename^> ^<mode^> [[DateToday] 
echo                                                 [DateAMonthAgo]]
echo.
echo   OutputFilename - path and filename to send output to
echo   CLEARLOG       - clears the global progress log.
echo.
echo   Mode - can be one of: Issued, Issued30,    - non-revoked certs in db
echo                         Active               - non-expired non-revoked                           
echo                         Revoked, Revoked30,
echo                         Failed, Failed30, 
echo                         Denied, Denied30, 
echo                         Pending
echo.
echo                         '30'(day) modes work on Windows Server 2008 R2 
echo                         or later only, unless the [Date]s are provided
echo.
echo This release backs off from 50K records to 1K records per certutil
echo query, in order to account for the slowest CAs observed (poor IO).
goto ExitNow
:End

:AppendRowCount
Echo Appending row count and we're nearly done...
echo %DATE% %TIME% - Checking item counts... >> %_PROGRESSLOGFILE%

findstr "^Row " %1 > %_FINDTEMP%
for /f "tokens=3" %%k  in ('find /C "Row" %_FINDTEMP%') do set _RowCount=%%k
del %_FINDTEMP%

rem update lowest ID for next run
copy %_WATERMARKFILE% %_LASTWATERMARKFILE%
echo %DATE% %TIME% - Completed >> %_PROGRESSLOGFILE%

echo. >> %1
echo %DATE% %TIME% >> %1
echo. >> %1
echo _ADCS_ROW_COUNT: %_RowCount% >> %1

:FastExit
Echo LargeCollector is done.

:ExitNow
