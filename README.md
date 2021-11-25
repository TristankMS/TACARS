# TACARS - *Tenuously Adequate CA Reporting System*
Backronym! *(See [1])*

**Short**: Makes a copy of an Active Directory Certificate Services (ADCS) Certification Authority (CA) 
certificate database in a Log Analytics (LA) workspace.

From there, you can do *!exciting!* things like:
- Enjoy *orders-of-magnitude* **faster queries** about **certificate issuance/failure** and related stats
- Reference historical certificate issuance in **Log Analytics/Microsoft Sentinel** queries/threat hunting
- Use **Azure Monitor Workbooks** to provide comfortable reporting insights (in progress)

**2021-11-25** - This is the initial release, designed to test the concept.

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
## Copy everything into a local folder
Copy the contents of the repo into a folder - we'll use D:\TACARS as our example. You can either do git magic for that if you're super pro, or hit Code->Download Zip from the Github button thingy at the top right, and extract the Zip to that folder...

## Make a copy of GO_TEMPLATE.CMD
In that folder, make a copy of `GO_TEMPLATE.CMD` - we'll use `GO.CMD` as our name.
Then edit GO.CMD in your favourite text editor.

You'll need to add your Log Analytics Workspace ID and Key need in your GO.CMD, and your proxy URL if you need one.

You can also edit the type of requests you want to collect: 
| CollectionTarget | Description |
| ---------------- | ----------- |
|`AllRequests`     | every request (still) in the CA database[2], whether issued, denied, failed, revoked |
|`ActiveCertsBasic`| certificates which were issued successfully, which are still within their validity period|
|`IssuedCertsBasic`| certificates which were issued successfully at any point|

Each type listed above is a built-in option implemented in `LargeLogger.cmd` - see that file for possible options.

And finally, you can edit the table name. I haven't sorted out what to do about versioning here yet, so you
can manually version any collection into a specific (new) LA table, which will show up about 5-10 minutes
after the first upload to a newly-named table.

`SET TABLENAME=` defaults to the computer name if blank, use `SET TABLENAME=%COMPUTERNAME%20210101` or similar for versioning. Or call it Julio? Julio is a fine name for a table.

----------------------------------------------------------------------------------------------------
## Install/specify PowerShell 7 EXE

TACARS was originally made for PS 5.1, but the feature and performance benefits of PS7 turned out to be 
very compelling!

It wouldn't be hard to retrofit for PS 5.1 again, accepting a few limitations and ~50% performance, so if
you need that, go for it! Otherwise, an isolated PS7 instance is the recommended option.

If you've got PS7 installed system-wide, you (probably) need to edit the line:

`SET PWSHPATH=PS7\PWSH.EXE`
to

`SET PWSHPATH=PWSH.EXE`

... Assuming the system PATH contains the path to the PWSH EXE.

But if you want to install PS7 in an isolated folder, you can! (And on a production CA, arguably *should*!) 

Here's how:
### Download the standalone PowerShell 7.x Zip
https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2#installing-the-zip-package
### Extract the PS7 binaries to a folder under this one
eg: if we're in `D:\TACARS` now, I'd suggest `D:\TACARS\PS7` so that PWSH.EXE is at `D:\TACARS\PS7\PWSH.EXE`
### Edit GO.CMD 
And depending on where you extracted to, change the line

`SET PWSHPATH=PS7\PWSH.EXE` to 

`SET PWSHPATH=MYIDEAWASBETTER\PWSH.EXE`
(and it wasn't, btw!) 

You can use a relative (more flexible) or fully-qualified (more robust) path to PWSH as needed.

----------------------------------------------------------------------------------------------------
## Ready to run! 

- Open an Admin command prompt in `D:\TACARS`
- Run `GO.CMD`
- Marvel at the speed with which things run (no, really, PS7 is super impressive)
- Check for and fix any errors!
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
  - TACARS initial release is *cobbleware*, not *engineering*! It's designed to be Proof Of Concept-y.
  - Maybe later it'll be the *Totally Awesome* CA Reporting System! Maybe...
  - But designed so that if it runs once, it'll run next time as well, and just upload the new IDs since last time

- Assume you'll need a new LA table occasionally
  - Log Analytics currently retains records for up to 2 years
    - and is read-only once records are uploaded
  - This could be a benefit or a hazard for CA reporting
  - Keep in mind that the LA table is not a *live* copy of the CA database
    - You may need to run AllRequests / ActiveCertsBasic to another table in order to see any changes
    - Example: When you issue a request, disposition changes to 20 - if that happens for a request issued in the past, you won't see that in the next upload, you need a complete new DB upload to see that. 

- There's an odd set of dependencies between the logging systems, which results in the last log
  being overwritten when there's nothing new to do. 
  - Assume this is by-design for this version, but considering a more integrated logging system for future versions.

----------------------------------------------------------------------------------------------------
# Footnotes
[1] aka *TristanK's Awful CA Reporting System*, but that didn't seem like it'd *sell*!

[2] Couple of things about "DB" history: `certutil -deleterow` will purge requests from the CA database,
and you can configure the CA not to log issuance of certain templates in the database *at all*. TACARS 
can only report on requests it can find, so if you've purged a buncha requests from the database, it's 
not going to find them [3].

[3] Other methods might, though, like CA Auditing - they might still be visible from the CA Event Logs,
if they're being collected and archived somewhere. See editorial in [4].

[4] General Windows Event Log archival/collection is considered a *solved problem* by this project. 
TACARS is more about the forensic value remaining in the database itself. Not logging something to 
the DB implies two things: 1- it's so short-lived that it's not of value, or 2- it's so low-value it's 
not worth logging [5]. There's a CA-level switch *as well as* a template-level switch required to 
implement *non-logging*, so it has already been considered twice in most cases...

[5] Not all human decisions are good ones.
