# WinAudit Commands

After capturing information and sending in to the server, the server's response may contain some commands for the service to execute. 

Commands should be returned by the service using a json array.  Each command can have : 
* A `name` property defining the name of the command.
* A `data` property defining extra configuration data.

```json
[
	{
		"name": "command name",
		"data": {}
	}
]
```

## Trigger a reboot

Reboot in 60 seconds.

Example:

```json
{
	"name": "reboot"
}
```

## Trigger a shutdown

Shutdown in 60 seconds.

Example:

```json
{
	"name": "shutdown"
}
```

## Delete a file 

```json
{
	"name": "delete",
	"data": {
		"filename": "<servicepath>\\junk.txt"
	}
}
```

## Download a file

Use <servicepath> to reference the path of the service installation folder.

Example:

```json
{
	"name": "download",
	"data": {
   		"url": "http://server.com/file.txt",
   		"filename": "<servicepath>\\file.txt"
   	}
}
```

## Execute a command

Lets the service execute a command.

Example: 

```json
{
	"name": "execute",
	"data": {
		"command": "cmd",
		"arguments": [
			"/c start https:\/\/www.apple.com"
		]
	}
}
```

## Execute a command as a user

Lets the User Helper execute a task as a user.
The first user that logs in gets to execute the task.  If multiple users are logged in, behaviour is unpredictable.

```json
{
	"name": "userexecute",
	"data": {
		"command": "cmd",
		"arguments": [
			"/c start https:\/\/www.apple.com"
		]
	}
}
```

## Set a registry key

Example: 

```json
{
	"name": "setreg",
	"data": {
   		"node": "HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System",
   		"key": "EnableLUA",
   		"value": "0",
   		"type": "REG_DWORD"
   	}
}
```

## Delete a registry key

Example: 

```json
{
	"name": "delreg",
	"data": {
   		"node": "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
   		"key": "Key"
   	}
}
```

## Add a startup task

A startup task is some task that needs to be executed when the user logs in.

Adding a startup task does 2 things : 
1. A node is added to the registry causing the task to be executed at login for every user.
2. The command is saved in the 'savedcommands.ini' file.  

Saving the command in the 'savedcommands.ini' file enables the service to check on the task whenever it is capturing information. 

If the file defined by the completedFile property is found : 
1. Registry nodes are removed to prevent the task from being executed at login.
2. The task is marked as completed in the 'savedcommands.ini' file.

The definition of the task is not removed, so you can use 'resetstartuptask' to re-activate a previously defined task.

Example :

```json
{
	"name": "addstartuptask",
	"data": {
   		"id": "changeowner",
   		"download_url": "http://server.com/test.exe",
   		"download_filename": "<servicepath>\\test.exe",
   		"task": "<servicepath>\\nircmd.exe elevate <servicepath>\\test.exe",
   		"completedFile": "<servicepath>\\test.done"
   	}
}
```

## Reset startup task

Reset a previously enabled startup task (see add startup task).

Example :

```json
{
	"name": "resetstartuptask",
	"data": {
   		"id": "changeowner"
   	}
}
```

## Remove a startup task

Remove a startup task (see add startup task).

1. Registry nodes are removed to prevent the task from being executed at login.
2. The task is removed from the local 'savedcommands.ini' file.

```json
{
	"name": "removestartuptask",
	"data": {
   		"id": "changeowner"
   	}
}
```

## Trigger a service update

Triggers a service update. 

The `updateurl` [setting](settings.md) is used to define the URL to an updated executable.

Also see https://github.com/kohsuke/winsw/blob/master/doc/selfRestartingService.md.


```json
{
	"name": "update"
}
```
