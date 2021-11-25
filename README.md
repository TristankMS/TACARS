# TACARS - Tenuously Adequate CA Reporting System
(See [1])

**Short**: Makes a copy of certificate requests from your Active Directory Certificate Services (ADCS) 
certificate database in a Log Analytics workspace.

From there, you can do *!exciting!* things like:
- Enjoy orders-of-magnitude **faster queries** about **certificate issuance/failure** and related stats
- Include details of historical certificate issuance in **Log Analytics/Microsoft Sentinel** queries
- Use **Azure Monitor Workbooks** to provide comfortable reporting insights (in progress) 

2021-11-25 - This is the initial release, designed to test the concept.

----------------------------------------------------------------------------------------------------
## Prerequisites In Brief
### Azure Monitor - a Log Analytics Workspace ID and Key
https://portal.azure.com to set one up.
No additional library or agent is needed, we just use the LA REST API for uploads.

### Local CA - A local folder with some disk space
The Collector etc is designed to run locally on a CA in this release.

### PowerShell 7.x
Can be installed system-wide or in its own little subfolder.

----------------------------------------------------------------------------------------------------
# Setup
Suggestion: Read through the whole section before starting! (Or just go for it...)
## Decide whether to use PowerShell 7 systemwide or isolated
This'll help you set some variables over the next few steps. If it's already installed systemwide, no problem.
If you want to install it isolated (eg, just for TACARS), that's covered in step 2.
## Copy everything into a local folder, make a copy of GO_TEMPLATE.CMD

Copy the contents of the repo into a folder - we'll use D:\TACARS as our example.

In that folder, make a copy of the GO_TEMPLATE.CMD - we'll use GO.CMD as our name.

Then edit GO.CMD in your favourite text editor.

You'll need to add your Log Analytics Workspace ID and Key need in your GO.CMD, and your proxy URL if you need one.

You can also edit the sort of requests you want: 
 - AllRequests          - every request fielded by the CA, whether issued, denied, failed, revoked 
 - ActiveCertsBasic     - certificates which were issued successfully, which are still within their validity period
 - IssuedCertsBasic     - certificates which were issued successfully at any point

Each type is a built-in option implemented in LargeLogger.cmd.

----------------------------------------------------------------------------------------------------
## Designed to run on PowerShell 7

If you've got PS7 installed systemwide, things should Just Work.

But if you want to install PS7 in an isolated folder, you can!

### Download the standalone PowerShell 7 Zip
https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.1#installing-the-zip-package

### Extract the PS7 binaries to a folder under this one, eg:
  - if we're in D:\TACARS now, 
  - I'd suggest D:\TACARS\PS7

### Edit GO.CMD and change SET PWSHPATH=PS7\PWSH.EXE to SET PWSHPATH=MYIDEAWASBETTER\PWSH.EXE
  - (and it wasn't, btw)

----------------------------------------------------------------------------------------------------
## Ready to run! 

- Open an Admin command prompt in this folder
- Run GO.CMD
- Marvel at the speed with which things run (no, really, PS7 is super impressive)
- Check any errors!
- Report any problems!

----------------------------------------------------------------------------------------------------
## When Things Go Wrong

Oh yes, it'll happen.

If the problem's during the upload, easy option is to Delete all the files beginning with the name 
of your upload type (del AllRequests*.*), then run it again, use query filters to exclude one result 
set, or just use a different table name.

Harder: selectively edit the *-Watermark-Last.txt file to reset the maximum request ID seen 
and re-run from there...

Hardest: just fix it all for me, there's a dear.

----------------------------------------------------------------------------------------------------
# Known Issues

- General fragility/fiddliness 
  - TACARS initial release is cobbleware, not engineering!
  - Maybe later it'll be the Totally Awesome CA Reporting System!
  - but to counter that, designed so that if it ran once, it'll run next time and just upload the delta

- Assume you'll need a new LA table occasionally
  - Log Analytics currently retains records for up to 2 years
    - and is read-only once records are uploaded
  - This could be a benefit or a hazard for CA reporting
  - Keep in mind that LA is not a "live" copy of the CA database
    - You may need to run AllRequests / ActiveCertsBasic to another table in order to see any changes 

- There's an odd set of dependencies between the logging systems, which results in the last log
  being overwritten when there's nothing new to do. This is by design for this version, considering a
  more integrated logging system for future versions.

----------------------------------------------------------------------------------------------------\
# Footnotes
[1] aka TristanK's Awful CA Reporting System