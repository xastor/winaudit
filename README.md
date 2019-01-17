# WinAudit : a Windows Auditing Daemon

WinAudit is a small service that collects information on a Windows machine and pushes it to some remote server, on a regular basis. 

It is written using the [Haxe](https://haxe.org) language.

* [Service Documentation](docs/service.md)

## Build instructions

* Install [Visual Studio](https://visualstudio.microsoft.com/vs/community/) (be sure to install C++ support)
* Install [Haxe](https://haxe.org) 3.4 or higher 
* Install hxcpp by running `haxelib install hxcpp`
* Install HaxeDevelop
* Open the project file `winaudit.hxproj` and build.

## Running as a service

I recommend running the service using [winsw](https://github.com/kohsuke/winsw).

This service wrapper was used during development, and winaudit has custom support for the winsw self-updating feature.

TODO : Add a sample service configuration.

## Disclaimer

This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What The Fuck You Want
To Public License, Version 2, as published by Sam Hocevar. See
http://sam.zoy.org/wtfpl/COPYING for more details. 

