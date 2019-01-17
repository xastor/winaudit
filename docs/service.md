# WinAudit Service 

The service is implemented to run the same cycle in an infinite loop.

## 1. Capturing information

The service captures information that is defined in a local and optionally remote [settings](settings.md) file.

## 2. Returning information

After capturing information, a JSON document is send using HTTP POST.  The `posturl` [setting](settings.md) setting defines the URL.

For example these settings : 

```ini
extra_test=value
wmic_bios=SerialNumber
wmic_os=Name,Version,InstallDate,LastBootUpTime
reg_uac=HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System,EnableLUA
```

Will result in these fields being returned : 

```json
{
  "biosSerialNumber": "LR52F48",
  "test": "value",
  "reg_uac": "0x0",
  "osVersion": "10.0.17134",
  "osLastBootUpTime": "20190112200842.326929+060",
  "osInstallDate": "20190102185432.000000+060",
  "osName": "Microsoft Windows 10 Pro|C:\\WINDOWS|\\Device\\Harddisk0\\Partition2",
  "version": "2018.02.12",
  "uptime": "87067",
  "teamviewer": "123456"
}
```

Some extra fields are always returned : 
* version : Version of the service
* uptime : uptime of the service in seconds
* teamviewer : the teamviewer-id of the machine (if installed).

## 3. Execute commands

After posting the captured information, a JSON document can be returned holding [commands](commands.md) for the service to execute.  

For example the following can be returned to reboot the computer : 

```json
[
  {
    "name": "reboot"
  }
]
```

## 4. Sleep

The service then sleeps.  Sleep duration is 10 minutes by default but can be customized using the `postdelay` [setting](settings.md).

