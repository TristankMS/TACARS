===============================================
Tenuously Adequate CA Reporting System (TACARS)
===============================================

# What is TACARS?

TACARS improves visibility of what certificate issuance looks like for an Active Directory Certificate Services (ADCS) Certification Authority (CA).

TACARS exports, then converts, then uploads ADCS database entries to Log Analytics, so that they can be queried and inspected with significantly more ease than with certutil.

## Database Export

The initial step of TACARS is a database export, using the LargeLogger derived from the ADCS Assessment.

The ADCS database is queried to provide a reasonably comprehensive log file containing fields of interest, such as the relevant NotBefore/NotAfter times, requestor, disposition, subject, SANs if present, and so on.

The collector is designed to run from the last certficate request logged to the current maximum record number.

## Export Conversion

The next step takes the text-format logs and converts them to a CSV file.

## CSV conversion and upload

The final step is to convert the CSV entries to JSON and post them in smallish batches to Log Analytics.

Once uploaded, the data is queryable using Log Analytics and associated Azure Monitor Workbooks, queries becoming orders of magnitude faster than when run from CertUtil, and allowing for easy but flexible and powerful reporting.

But...

===============================================


# Notes

Log Analytics retention is free for 90 days at time of writing, but maxes out at 2 years. This isn't long enough for your average CA (or in some cases manual) certificate. Re-running the collector more frequently is suggested to address this.

What you get from a NEW AllRequests run to a NEW table is a *point-in-time* snapshot of the database at that point.

You could conceivably run AllRequests every X (where X is 90 or less) days to populate a table and get the reporting you want/need.

    In fact, shouldn't we do this?
    Shouldn't this be the default? CA01-2021-MM-DD_CL as the table name for each version?
        With all current states uploaded each time?
            Yes!
    
    And what about ongoing reporting? Having stats for the last 7 or 30 days might be inherently valuable too!

        So do you run separate GOs to create separate tables, each with different params?

Crawling doesn't reflect changes to historical certs; you need to ignore older uploads and focus on the latest AllRequests upload.

# Future Ideas

Optimization! There's a lot of overhead in the series of steps above, and once the concept is validated and some useful workbooks or use cases are developed from it, the current plan is to unify the separate steps into a unified certificate database crawler, or possibly a two-stage (export and upload) set.

Outside of simple reporting, Microsoft Sentinel integration seems like it's a natural fit for the uploaded data.

Non-LA options: Azure Table sync might be an option... essentially replicating a subset of the CA database data to a permanent record, much as the CA does... 

We'll see...