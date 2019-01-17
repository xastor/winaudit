# WinAudit Settings

Winsw uses 2 settings files : 
1. A local file : Service.ini (required)
2. A remote URL (optional)

Remote settings override local settings.  
Local and remote settings are reloaded each time before collecting information.

Service settings : 
* `settingsurl` : URL for the remote settings file (optional).
* `posturl` : URL of the server to post the collected information to.
* `postdelay` : The number of minutes the  between processing steps (the sleep time). You can use '-' to specify random value within some range.
* `updateurl` : The url to an updated version of the service executable.  This is used when self-updating the service using the 'update' [command](commands.md).

Capture settings : 
* `wmic_*` : Define WMIC data to be captured and returned.
* `reg_*` : Define a registry field to be captured and returned.
* `extra_*` : Define a static field to be returned (not captured).

# WMIC

WinAudit supports capturing information from WMIC, the Windows Management Instrumentation Console.

Settings starting with the prefix "wmic_<alias>" are collected using WMIC and are queries of a specific alias.  A comma-separated list of fields to return is required.

When remote settings and local settings define a query to the same alias, the list of queried fields is merged.  For example : the local settings file contains `wmic_os=Name` and the remote settings contain `wmic_os=LastBootUpTime`.  In this case, both Name and LastBootUpTime will be captured and returned.

For example : 

```ini
wmic_os=Name,Version,InstallDate,LastBootUpTime
wmic_bios=SerialNumber
```

This will result in the following information being captured : 

```json
{
  "osName": "Microsoft Windows 10 Pro|C:\\WINDOWS|\\Device\\Harddisk0\\Partition2",
  "osVersion": "10.0.17134",
  "osInstallDate": "20190102185432.000000+060",
  "osLastBootUpTime": "20190112200842.326929+060",
  "biosSerialNumber": "abc-def-ghi"
}
```

Here's a quick list of interesting aliases for inspiration : https://blogs.technet.microsoft.com/askperf/2012/02/17/useful-wmic-queries

# Registry

Winaudit supports capturing information from the windows registry.

Configurations starting with the prefix `reg_` can be used to collect information from the windows registry.

The value of the setting defines the registry key.  This will return the default value for that key.  You can add `,` and a node name to retrieve a specific node value.

For example : 

```ini
reg_uac=HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System,EnableLUA
```

This will result in the following information being captured :

```json
{
  "reg_uac": "0x0"
}
```

# Extra

Configurations starting with `extra_` can be used to push static data as collected information.

For example : 

```ini
extra_internal_id=ID01
```

This will result in the following information being captured :

```json
{
  "internal_id": "ID01"
}
```