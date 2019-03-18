# WinAudit : A Simple Windows Reporting Daemon

WinAudit is a simple service that collects information on a Windows machine and pushes it to some remote server, on a regular basis. 

It is written using the [Haxe](https://haxe.org) language.

* [Service Documentation](docs/service.md)

## Build instructions

* Install [Visual Studio](https://visualstudio.microsoft.com/vs/community/) (be sure to install C++ support)
* Install [Haxe](https://haxe.org) 3.4 or higher 
* Install hxcpp by running `haxelib install hxcpp`
* Install HaxeDevelop
* Open the project file `winaudit_service/project.hxproj` and build.
* Open the project file `winaudit_userhelper/project.hxproj` and build.

## Running as a service

I recommend running the service using [winsw](https://github.com/kohsuke/winsw).

* To use : 
  * Copy the winsw_template folder
  * Add `winaudit_service/bin/Service.exe`
  * Add `winaudit_userhelper/bin/UserHelper.exe` 
  * Add [settings](docs/settings.md) to `Service.ini`

Install and start/stop using the provided batch scripts.

This service wrapper was used during development, and winaudit has custom support for the winsw self-updating feature.

## Disclaimer

This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What The Fuck You Want
To Public License, Version 2, as published by Sam Hocevar. See
http://sam.zoy.org/wtfpl/COPYING for more details. 

