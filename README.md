# BuaBook Archive System

The BuaBook Archive System provides the ability to archive data (using `rsync`) and delete data in regular intervals via cron.

To configure the archive system, 2 files need to be created for _each_ host:

* `archive.config`: Specifies the files to archive or delete
* `archive.target`: The target where the files should be archived.

The configuration should be stored within a folder referenced by the variable `${BAS_CONFIG}` and there should be a sub-folder with the name of the host the configuration belongs to. The name should be the output of `$(hostname)` on the target host.

We configure the archive script to run every day at 02:00 with the cron job definition defined in `config/cron-template/cron.template`. This should be modified and installed into `/etc/cron.d` on the source machine.

## Date Filtering

The archive system has an added feature of allowing you to specify which files should be archived based on today's date. This allows for recent data to be kept on the source machine before archiving and deleting. We use this to save space on Production hosts.

For example if you have a log file created every day, but it is useful to keep this month's data, the configuration would specify a period of 1 and a frequency of month.

To use this feature, your files to be archived should contain a date in the format `YYYYMMDD` (e.g. `java-service-20170201.log`). You can then specify when these files should be archived in the `archive.config` file below.

## `archive.config`

For each host that is configured, any number of archiving rules can be specified. For each archive rule the following parameters are required:

* `path-regex`: File path or partial file path
    * Do not add a final `*` to the regex. It will automatically added by the archive script
    * If your files to archive support date filtering, replace where the date is within the file name with `{BBDATE}`
* `period`: The period of time to go back as an integer value
* `frequency`: The frequency with which to archive
    * Supported values are: `day`, `month`, `year`
    * If you specify a period and frequency without `{BBDATE}` being present in the path regex, it will be ignored
* `how-to-archive`: What to do with the matching files
    * `archive-delete`: Archive matching files AND delete source after successful archive
    * `archive-keep`: Archive the specified files and keep source
    * `delete-only`: NO archive, just delete files

### Examples

Archive all OPTA tickerplant journals from the previous month and delete them once the archive is successful:

```
# path-regex,period,frequency,how-to-archive
/u01/data/kdb/journal/optaTpJournal_{BBDATE},1,month,archive-delete
```

Archive all OPTA feedhandler journals and keep them on the source host afterwards:

```
# path-regex,period,frequency,how-to-archive
/u01/data/kdb/journal/optaFeedJournal_,0,day,archive-keep
```

Delete the previous month's cache data (in hidden dot folder) without archiving:

```
# path-regex,period,frequency,how-to-archive
/u01/data/kdb/cache/image/suspend.opta/.*/{BBDATE},1,month,delete-only
```

## `archive.target`

If you specify `archive-delete` or `archive-keep`, the target of the archiving is specified within this file. The configuration must only be a single line with the following parameters:

* `backup-type`: Supported values are `local` or `remote`
* `backup-location`: Where to save the archived files
    * If it's a local backup, just a file path is required
    * If it's a remote backup, an SCP style target is required (e.g. `user@host:/remote/file/location`)

### Examples

For local `rsync` archiving:

```
# backup-type,backup-location
local,/local/path/location
```

For remote `rsync` via `scp` archiving:

```
# backup-type,backup-location
remote,target-host:/remote/path/location
```
