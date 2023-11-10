# How to run `compare_di_change_events_to_dos.py`

This python script can be used to compare the latest change event specified openings for every ODS code received in DI, with the current specified dates on pharmacies in DoS.

## **How the script works**

The script takes two extracts of live data, one for DI and one from DoS to compare the specified opening times between what has been received in DI with what is on DoS. These extract are captured in files with the DI extract being in JSON and the DoS extract being in CSV.

These two file are processed and compared in the script using the python Pandas library. The script outputs a CSV file will an additional field called `sp_aligned`, which has a value True if a given service in dos matches the specified opening times for the latest change event for the base ODS Code it matches on.


## **Requesting clones**

Firstly a DoS live database clone and a DI Dynamodb clone are need to be able to get the extracts. For the best result the clone should be request around the same time

Clones for DoS and DI can be requested via the data clone tool that can be found here https://ddc-exeter-data-clone-prod-ddc-data-clone.k8s-prod.texasplatform.uk/data-source
To access the site a Prod VPN connection is required

Before requesting the clones it's worth checking these slack channels to see if someone else has requested clones recently

    #db-clone (DoS clones)
    #di-db-clone (DI clones)

### **DOS Clone**

To get a DoS Clone select the `CORE-DOS` option and use the prefilled username with the password found on the `DBCLONE_USER` in the `core-dos/deployment` secret found in the Prod Texas Account.

Then on the next page set the fields as follows:

    Recipent Email: [Your email]
    Database : uec-core-dos-live-db-12
    Instance Type: db.t2.medium (non-SQL Server)
    TTL: [Time in hours the clone should exist for (recommended no longer than close of play)]

Using these setting you should receive an email with the database connection detail for the clone about 30 minutes later but it can take longer.

**Once you submitted your request make sure to post in the `#db-clone` slack channel that a clone has been requested with TTL e.g. for a 6hr clone `live(6) requested`. When you receive the database details make sure to post them in the channel.**

### **DI Clone**

To get a DI Clone select the `UEC-DOS-INT` option and use the prefilled username with the password found on the `DBCLONE_USER` in the `dos-int-live/deployment` secret found in the Prod Texas Account.

Then on the next page set the fields as follows:

    Recipent Email: [Your email]
    Database : uec-dos-int-live-change-events
    Instance Type: NA for aurora / dynamo
    TTL: [Time in hours the clone should exist for (recommended no longer than close of play)]

Using these setting you should receive an email with the database connection detail for the clone about 30 minutes later but it can take longer.

**Once you submitted your request make sure to post in the `#di-db-clone` slack channel that a clone has been requested with TTL e.g. for a 6hr clone `live(6) requested`. When you receive the database details make sure to post them in the channel.**

## **How to get the extracts from DI and DOS**

Once the database clones are ready you can then use them to get the extracts files

### **Getting the DoS Extract**

Using a Database client like DBeaver connect to the DoS clone database and do a query from export (to CSV) with the following script:

    select service.id, service.odscode, service.uid, service.name, substring(odscode from 1 for 5) as base_odscode, array_to_json(array(select ssod_grouped_json.specified_opening_times
    from (select ssod_grouped.id, json_build_object('date', ssod_grouped."date", 'starttime', ssod_grouped.starttime, 'endtime', ssod_grouped.endtime, 'isclosed', ssod_grouped.isclosed) as "specified_opening_times" from (select s.id, s.uid, s.odscode, s."name", s.statusid, s.typeid, ssod."date", ssot.starttime, ssot.endtime, ssot.isclosed from services s
    join servicespecifiedopeningdates ssod on ssod.serviceid  = s.id
    join servicespecifiedopeningtimes ssot on ssot.servicespecifiedopeningdateid = ssod.id where ssod."date" > now()
    group by s.id, s.uid, s.odscode, s."name", s.statusid, s.typeid, ssod."date", ssot.starttime, ssot.endtime, ssot.isclosed) as ssod_grouped) as ssod_grouped_json
    where ssod_grouped_json.id = service.id )) as "specified_openings" from (select distinct s2.* from services s2 join servicespecifiedopeningdates ssod2 on ssod2.serviceid = s2.id where ssod2."date" > now() and s2.typeid in (13, 131, 132, 134, 137) and s2.statusid = 1 and s2.odscode like 'F%') as service

In DB Beaver this done by highlighting the script in the script editor then right clicking to get the mouse menu then opening the `Execute` menu and then select the `Export from Query` option. This will open an option box select the option to export to CSV and then click next.
On the next part just check the `fetch size` is quite large e.g. 100k and click next. Then on the next menu `output` set the location where you want to save the file to and give the file
an appropriate name. After click next for the last time check the summary is doing what you would expect it todo, finally click `proceed` and the query will be run and the output as CSV will be found in the file.

### **Getting the DI Extract**

To get the DoS Integration (DI) extract open the terminal and `assume` into the Prod account then from a suitable directory run the following aws command:

    aws dynamodb scan --table-name [table_name] --index-name gsi_ods_sequence --output json > di_extract.json

Where the table name can be gotten from the DI clone email, the `#di-db-clone` channel or the
data-clone-instance-uec-dos-int-QYBALXKFBT

`!!! Warning the DI extract is large 5GB+ should only be run over a fast un-metered connection !!!`

## Running the Script to compare Specified Dates

Once the extracts from DoS Integration and DoS the `compare_di_change_events_to_dos` python script can be used to compare the DI JSON with the CSV of DoS future specified dates for pharmacies.

### **Python Script Setup**

To run the python script the modules `pandas` and `dynamodb-json` need to be installed on the python running the script. The best way to do this is to setup a python environment in the directory this readme `script/compare_di_to_dos_scripts` is in:

    python -m venv pyenv
    source pyenv/bin/activate
    pip install pandas
    pip install dynamodb-json

### **Running the Python Script**

To run the `compare_di_change_events_to_dos.py` python script the file path for the DI change event extracts and the dos specified dates extract need to be specified:

    python compare_di_change_events_to_dos.py di_extract.json dos_specified_dates.csv

## How to use and read the generated report

The CSV file generated by the script is best look at and processed in Excel. In contains the following columns:

| [Unnamed] | OpeningTimeSpecified | NhsUkType | uid | name | specified_openings | sp_aligned |
| - | - | - | - | - | - | - |
| Base ODS Code | NHS UK pharmacy specified openings | Pharmacy type in NHS UK | DoS service UID | DoS service name | DoS service specified openings | True if the openings match |

In excel you can use the filter tool under the `Sort & Filter` -> `Filter` on the `Home` divider to be able to filter out records that aren't aligning by only showing row that are false in the `sp_aligned` column:

![how_to_filter](./how_to_filter.gif)

More details on how to use filtering further in Excel can be found here: https://support.microsoft.com/en-us/office/filter-data-in-a-range-or-table-01832226-31b5-4568-8806-38c37dcc180e
