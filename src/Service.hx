package;

import haxe.crypto.Md5;
import haxe.ds.HashMap;
import haxe.Http;
import haxe.io.Bytes;
import haxe.Json;
import haxe.Utf8;
import sys.FileSystem;
import sys.io.File;

import cpp.link.StaticStd;
import cpp.link.StaticZlib;

/**
 * Class Service defines the main class for the WinAudit Service. 
 * 
 * @author Pieter Bonne <xastor@gmail.com>
 */
class Service
{
	/** The service settings map. */
	var settings:Map<String,String>;
	/** The service information map of captured information. */
	var info:Map<String,Dynamic>;
	/** The capture error flag. */
	var error:Bool;
	
	/** The registry node for startup tasks. */
	static inline var STARTUP_NODE = "HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";
	/** The file where saved startup tasks are stored so they can be checked for completion or restarted. */
	static inline var SAVED_COMMANDS = "<servicepath>/savedcommands.ini";
	
	var Version = "2019.01.11";
	
	/** 
	 * The application entrypoint.
	 */
	public static function main() : Void
	{
		new Service();
	}
	
	/** 
	 * Create a new service instance.
	 */
	public function new()
	{
		processStartupTasks();
		
		while (true)
		{
			trace("Time: " + Date.now().toString());

			do
			{
				error = false;
	
				loadSettings();
				loadRemoteSettings();
				trace("Settings: " + settings);
				
				captureInfo();
				trace("Info: "+ Json.stringify(this.info));
				
				processStartupTasks();
				trace("Checked saved commands.");
				
				sendInfo();
				trace("Done.");
				
				if (error == true)
				{
					trace("An error occurred, sleeping 10 seconds before retry...");
					Sys.sleep(10);
				}
			}
			while (error == true);
			
			// default is 10 minutes.
			var sleep = 10;
			
			if (this.settings.exists("postdelay"))
			{
				var value = this.settings["postdelay"];
				if (value.indexOf("-")>0)
				{
					var parts = value.split("-");
					if (parts.length > 1)
					{
						var min = Std.parseInt(parts[0]);
						var max = Std.parseInt(parts[1]);
						if (min != null && max != null)
						{
							sleep = min + Math.round(Math.random() * (max - min));
						}
					}
					else
					{
						var v:Null<Int> = Std.parseInt(value);
						if (v != null) value = cast v;
					}
				}
			}
			
			trace("Sleeping " + sleep +" minutes...");
			Sys.sleep(sleep*60);
		}
	}

	/**
	 * Load the local settings ini file.
	 */
	function loadSettings()
	{
		try
		{
			this.settings = new Map();
			var path = Sys.programPath();
			path = path.substr(0, path.lastIndexOf(".")) + ".ini";
			var content = sys.io.File.getContent(path);
			this.settings = parseProperties(content);
		}
		catch (error:Dynamic)
		{
			trace("Error while loading settings: " + error);
		}
	}
	
	/**
	 * Load the remote settings ini file.
	 * When a collision occurs, wmic settings are merged, all other settings are overridden.
	 */
	function loadRemoteSettings()
	{
		try
		{
			var url = this.settings["settingsurl"];
			if (url == null) return; // return if not defined, remote settings are optional.
			if (url != null) trace("Loading remote settings...");
			var data = this.doHttpGet(url);
			if (data != null)
			{
				var props:Map<String,String> = parseProperties(data);
				for (key in props.keys())
				{
					if (this.settings.exists(key) && key.indexOf("wmic_")==0)
					{
						this.settings[key] = this.settings[key]+","+props[key];
					}
					else
					{
						this.settings[key] = props[key];
					}
				}
			}
			else
			{
				error = true;
				trace("Error loading remote settings.");
			}
		}
		catch (errorObj:Dynamic)
		{
			error = true;
			trace("Unexpected error processing remote settings : $errorObj");
		}
	}
	
	/**
	 * Captures information.
	 * Looks at all settings and fills the this.info map with captured information.
	 */
	function captureInfo()
	{
		trace("Capturing info...");
		this.info = new Map();
		
		for (setting in this.settings.keys())
		{
			if (setting.indexOf("wmic_") == 0)
			{
				var alias = setting.substring(5, setting.length);
				var names = StringUtil.cleanAndTrimList(settings[setting].split(","));
				for (name in names)
				{
					captureWmic(alias, name);
				}
			}
			if (setting.indexOf("reg_") == 0)
			{
				var alias = setting.substring(4, setting.length);
				var keyAndName = StringUtil.cleanAndTrimList(settings[setting].split(","));
				var nodeName = keyAndName.length>1 ? keyAndName[1] : ""/*default-value*/;
				captureReg(alias, keyAndName[0], nodeName);
			}
		}
		
		this.info["version"] = Version;
		
		captureUptime();
		captureTeamViewerClientID();
		
		for (key in this.settings.keys())
		{
			if (key.indexOf("extra_") == 0)
			{
				this.info[key.substring(6, key.length)] = Utf8.encode(settings[key]);
			}
		}
	}

	/**
	 * Send captured information to the remote service.
	 */
	function sendInfo()
	{
		var url = this.settings["posturl"];
		trace("Sending info to $url...");
		trace("Info: " + Json.stringify(this.info));
		if (url == null)
		{
			error = true;
			return;
		}

		try
		{
			var http:Http = new Http(url);
			http.onStatus = function(data) { trace("Status: " + data); };
			http.onError = function(data) { error = true;  trace("Error: " + data); };
			http.onData = 
				function(data) 
				{ 
					trace("Return data : " + data);
					try
					{
						executeCommands(data);
					}
					catch(error:Dynamic)
					{
						trace("Error while executing commands: "+ error);
					}
				};
			http.setPostData(Json.stringify(this.info));
			http.request(true/*post*/);
		}
		catch (errorObject:Dynamic)
		{
			error = true;
			trace("Error while sending info: " + errorObject);
		}
	}
	
	/**
	 * Try to execute any commands returned by the remote service.
	 */
	function executeCommands(data:String):Void
	{
		if (StringTools.trim(data).length==0) return;
		var commands:Array<Command> = new Array();
		if (data == "shutdown")
		{
			commands.push(new Command("shutdown"));
		}
		else if (data == "update")
		{
			commands.push(new Command("update"));
		}
		else if (data.indexOf("cmd:") == 0)
		{
			var cmd:Dynamic = Json.parse(data.substring(4, data.length));
			commands.push(new Command("execute", cmd));
		}
		else
		{
			var list:Array<Dynamic> = cast Json.parse(data);
			for (item in list)
			{
				commands.push(new Command(item.name,item.data));
			}
		}
		this.runCommands(commands);
	}
	
	/**
	 * Run a list of commands.
	 */
	function runCommands(list:Array<Command>):Void
	{
		for (command in list)
		{	
			switch(command.name)
			{
				case "shutdown":
					trace("Command: shutdown");
					CommandlineUtil.getOutput("shutdown", ["-s","-t","60"]);
					
				case "reboot":
					trace("Command: reboot");
					CommandlineUtil.getOutput("shutdown", ["-r","-t","60"]);
					
				case "update":
					trace("Command: update");
					this.update();
					
				case "execute":
					trace("Command: execute '"+command.data.command+"'");
					trace("Arguments: " + command.data.arguments);
					var output = CommandlineUtil.getOutput(command.data.command, command.data.arguments);
					trace("Output: " + output);
					
				case "download":
					trace("Command: download");
					var url = command.data.url;
					var filename = replaceMeta(command.data.filename);
					var force = false;
					if (Reflect.hasField(command.data, "force"))
						force = cast command.data.force;
					trace("Url: " + url);
					trace("Filename: " + filename);
					trace("Force: " + force);
					var target = filename;
					if (force==false && FileSystem.exists(target))
					{
						trace("Skipped download, file already exists.");
					}
					else
					{
						var data = this.doHttpGet(url);
						if (data != null)
						{
							try
							{
								var bytes = Bytes.ofString(data);
								File.saveBytes(target, bytes);
							}
							catch (error:Dynamic)
							{
								trace("Error saving download: " + error);
							}
						}
					}
					
				case "setreg":
					trace("Command: setreg");
					var type = RegistryUtil.sanitizeType(command.data.type);
					trace("Node: " + command.data.node);
					trace("Key name: " + command.data.key);
					trace("Key value: " + command.data.value);
					trace("Key type: " + type);
					RegistryUtil.writeKey(command.data.node, command.data.key, replaceMeta(command.data.value), type);

				case "delreg":
					trace("Command: delreg");
					trace("Node: " + command.data.node);
					trace("Key name: " + command.data.key);
					RegistryUtil.deleteKey(command.data.node, command.data.key);

				case "delete":
					trace("Command: delete");
					var filename = replaceMeta(command.data.filename);
					trace("Filename: " + filename);
					if (FileSystem.exists(filename))
						FileSystem.deleteFile(filename);
					
				case "addstartuptask":
					trace("Command: addstartuptask");
					var id:String = command.data.id;
					var download_url:String = command.data.download_url;
					var download_filename:String = replaceMeta(command.data.download_filename);
					var task:String = replaceMeta(command.data.task);
					var completedFile:String = replaceMeta(command.data.completedFile);
					trace("Id: " + id);
					trace("download_url: " + download_url);
					trace("download_filename: " + download_filename);
					trace("Task: " + task);
					trace("CompletedFile: " + completedFile);
					
					saveStartup(command);
					resetStartup(id);
					
				case "resetstartuptask":
					trace("Command: resetstartuptask");
					var id:String = command.data.id;
					trace("Id: " + id);
					
					resetStartup(id);
					
				case "removestartuptask":
					trace("Command: deletestartuptask");
					var id:String = command.data.id;
					trace("Id: " + id);
					
					deleteStartup(id);
					
				default:
					trace("unkown command '"+ command.name +"'");
			}
		}
	}
	
	/**	
	 * Create (end enable) a startup task.
	 *  - Adds a startup task to the local file with startup tasks.
	 *  - Downloads the task executable.
	 */
	function saveStartup(command:Dynamic)
	{
		var startupTaskFile = replaceMeta(SAVED_COMMANDS);
		var tasks:Array<Dynamic> = null;
		if (FileSystem.exists(startupTaskFile) == false)
		{
			tasks = new Array<Dynamic>();
		}
		else 
		{
			tasks = loadJSON(startupTaskFile);	
		}
		var found:Bool = false;
		for (i in 0...tasks.length)
		{
			if (tasks[i].id == command.id)
			{
				found = true;
				tasks[i] = command;
			}
		}
		if (found == false)
		{
			tasks.push(command);
		}
		saveJSON(startupTaskFile, tasks);
		// Get info
		var id:String = command.data.id;
		var download_url:String = command.data.download_url;
		var download_filename:String = replaceMeta(command.data.download_filename);
		var task:String = replaceMeta(command.data.task);
		var completedFile:String = replaceMeta(command.data.completedFile);
		// Download task file
		var commands:Array<Command> = new Array();
		commands.push(new Command("download", { "url":download_url, "filename":download_filename, "force":true } ));
		// Reset (add to registry, remove "completed" file).
		runCommands(commands);
	}
	
	/**
	 * Resets (and enables) a startup task.
	 *  - Marks a startup task as not completed.
	 *  - Removes the task completion file.
	 *  - Adds the task to the registry.
	 */
	function resetStartup(id:String)
	{
		var startupTaskFile = replaceMeta(SAVED_COMMANDS);
		var tasks:Array<Dynamic> = null;
		if (FileSystem.exists(startupTaskFile) == false)
		{
			tasks = new Array<Dynamic>();
		}
		else 
		{
			tasks = loadJSON(startupTaskFile);	
		}
		var command:Dynamic = null;
		for (task in tasks)
		{
			if (task.name=="addstartuptask" && task.data.id == id)
			{
				command = task;
				break;
			}
		}
		if (command == null) 
		{
			trace("Command '" + id +"' not found in list.");
			return;
		}
		// Remove "completed"
		Reflect.deleteField(command, "completed");
		saveJSON(startupTaskFile, tasks);
		// Get info
		var task:String = replaceMeta(command.data.task);
		var completedFile:String = replaceMeta(command.data.completedFile);
		// Add startup task
		var commands:Array<Command> = new Array();
		commands.push(new Command("delete",
			{
				"filename":completedFile
			}));
		commands.push(new Command("setreg",
			{
				"node":STARTUP_NODE, 
				"key":"winaudit_startup_"+id,
				"value":task 
			}));
		runCommands(commands);
	}
		
	/**
	 * Removes a startup task from the system entirely.
	 * - Deletes a startup task from the local file
	 * - Removes the task from the registry
	 * - Deletes the task and completion file.
	 */
	function deleteStartup(id)
	{
		var startupTaskFile = replaceMeta(SAVED_COMMANDS);
		if (FileSystem.exists(startupTaskFile) == false) return;
		var tasks:Array<Dynamic> = this.loadJSON(startupTaskFile);
		var command:Dynamic = null;
		for (task in tasks)
		{
			if (task.name=="addstartuptask" && task.data.id == id)
			{
				command = task;
				break;
			}
		}
		if (command != null)
		{
			// Remove task 
			tasks.remove(command);
			saveJSON(startupTaskFile, tasks);
			// Get info
			var download_url:String = command.data.download_url;
			var download_filename:String = replaceMeta(command.data.download_filename);
			var task:String = replaceMeta(command.data.task);
			var completedFile:String = replaceMeta(command.data.completedFile);
			// Remove files
			var commands:Array<Command> = new Array();
			commands.push(new Command("delete",{ "filename":download_filename }));
			commands.push(new Command("delete", { "filename":completedFile } ));
			// Remove startup task
			commands.push(new Command("delreg", { "node":STARTUP_NODE, "key":"winaudit_startup_" + id } ));
			runCommands(commands);
		}
		else
		{
			trace("Startup task '" + id +"' not found in list.");
		}
	}
	
	/**
	 * Loads a json document from a file.
	 */
	function loadJSON(file:String):Array<Dynamic>
	{
		return cast Json.parse(File.getContent(file));
	}
	
	/**
	 * Saves data as json to a file.
	 */
	function saveJSON(file:String, data:Array<Dynamic>):Void
	{
		File.saveContent(file, Json.stringify(data));
	}
	
	/**
	 * Process the startup tasks.
	 * For tasks that are not yet completed, it looks for the completedFile file.
	 * It found, the startup task is removed from registry, preventing it from starting at user login.
	 */
	function processStartupTasks()
	{
		var startupTaskFile = replaceMeta(SAVED_COMMANDS);

		if (FileSystem.exists(startupTaskFile) == false) return;	
		var commands:Array<Dynamic> = loadJSON(startupTaskFile);
		for (command in commands)
		{
			var id = command.data.id;
			if (Reflect.hasField(command,"completed") == false)
			{
				var completedFile:String = replaceMeta(command.data.completedFile);
				var task:String = replaceMeta(command.data.task);
				if (FileSystem.exists(completedFile))
				{
					/* Mark as completed. */
					trace("Startup task '" + id +"' was completed.");
					command.completed = true;
					saveJSON(startupTaskFile,commands);
					/* Remove startup task */
					var commands:Array<Command> = new Array();
					commands.push(new Command("delreg", { "node":STARTUP_NODE, "key":"winaudit_startup_" + id } ));
					runCommands(commands);
				}
			}
		}
	}
	
	/**
	 * Replaces metadata tags in a string.
	 */
	function replaceMeta(text:String):String
	{
		var servicepath = Sys.programPath();
		servicepath = servicepath.substr(0, servicepath.lastIndexOf("\\"));
		return StringTools.replace(text,"<servicepath>",servicepath);
	}
	
	/**
	 * Runs the WinSW service update mechanism.
	 */
	function update()
	{
		try
		{
			/* Get updateurl */
			var updateUrl = this.settings["updateurl"];
			if (updateUrl == null) 
			{
				trace("No updateurl found in settings.");
				return;
			}
			/* Get updatefile */
			var updateFile = Sys.programPath();
			updateFile = updateFile.substr(0, updateFile.lastIndexOf("\\")) + "\\update.exe";
			/* Download updatefile */
			var data = this.doHttpGet(updateUrl);
			if (data!=null)
			{
				var bytes = Bytes.ofString(data);
				File.saveBytes(updateFile, bytes);
				trace("Update file downloaded : $updateFile");
			}
			else
			{
				trace("Canceling update because download of the updated file failed.");
				return;
			}
			/* Check difference */
			if (Md5.make(File.getBytes(Sys.programPath())).compare(Md5.make(File.getBytes(updateFile)))==0)
			{
				FileSystem.deleteFile(updateFile);
				trace("Not restarting : updated file has same hash as current one.");
				return;
			}
			/* Create .copies file (check winsw documentation on service updates). */
			var copiesFile = Sys.programPath();
			copiesFile = updateFile.substr(0, updateFile.lastIndexOf("\\")) + "\\winsw.copies";
			var content = updateFile +">"+ Sys.programPath();
			File.saveContent(copiesFile, content);
			trace("Created copies file " + copiesFile);
			/* Trigger restart */
			var serviceFile = Sys.programPath();
			serviceFile = serviceFile.substr(0, serviceFile.lastIndexOf("\\")) + "\\winsw.exe";
			CommandlineUtil.getOutput(serviceFile, ["restart!"]);
			trace("Triggered restart.");
		}
		catch (error:Dynamic)
		{
			trace("Unexpacted error while updating : $error");
		}
	}
	
	/**
	 * Captures the system uptime. 
	 */
	function captureUptime():Void
	{
		try
		{
			var boot = wmicDate("os", "LastBootUpTime");
			var now = Date.now();
			this.info["uptime"] = ""+ Std.int((now.getTime() / 1000) - (boot.getTime() / 1000));
		}
		catch (error:Dynamic)
		{
			trace("Error capturing uptime: "+ error);
		}
	}
	
	/**
	 * Captures the system's teamviewer identifier.
	 */
	function captureTeamViewerClientID():Void
	{
		try
		{
			var value:Null<Int> = RegistryUtil.readKeyInt("HKLM\\SOFTWARE\\Wow6432Node\\TeamViewer", "ClientID");
			if (value == null) value = RegistryUtil.readKeyInt("HKLM\\SOFTWARE\\TeamViewer", "ClientID");
			if (value == null)
			{
				var max = 20;
				for (i in 0...max)
				{
					var v:Null<Int> = RegistryUtil.readKeyInt("HKLM\\SOFTWARE\\Wow6432Node\\TeamViewer\\Version" + ((max+1) - i), "ClientID");
					if (v == null)
					{
						v = RegistryUtil.readKeyInt("HKLM\\SOFTWARE\\TeamViewer\\Version" + ((max+1) - i), "ClientID");
						if (v == null) continue;
					}
					 
					value = v;
					break;
				}
			}
			if (value!=null) this.info["teamviewer"] = "" + value;
		}
		catch (error:Dynamic)
		{
			trace("Error capturing teamviewer id: "+ error);
		}
	}
	
	/**
	 * Captures a single registry key's value.
	 */
	function captureReg(alias:String, nodeName:String, keyName:String=""):Void
	{
		var value:String = RegistryUtil.readKey(nodeName, keyName);
		if (value != null) this.info["reg_" + alias] = value;
	}
	
	/**
	 * Captures wmic alias data. 
	 */
	function captureWmic(alias:String, setting:String):Void
	{
		try
		{
			var value:Array<String> = wmic(alias, setting);
			if (value == null) return;
			if (value.length == 1) this.info[alias + setting] = value[0];
			else this.info[alias+setting] = value;
		}
		catch (error:Dynamic)
		{
			trace("Error: " + error);
		}
	}
	
	/**
	 * Runs the wmic command and returns its output.
     *
     * TODO: Add more documentation.
	 *
	 * @param	alias
	 * @param	setting
	 * @return returns an array with at least one value or null.
	 */
	function wmic(alias:String, setting:String):Array<String>
	{
		var arguments = new Array<String>();
		var parts = alias.split("__");
		for (part in parts) arguments.push(part);
		arguments.push("get");
		arguments.push(setting);
		var lines:Array<String> = CommandlineUtil.getOutput("wmic", arguments);
		if (lines == null) return null;
		if (lines.length >= 3) 
		{
			lines.splice(2, 1);
		}
		if (lines != null && lines.length >= 3 && lines[0].toLowerCase()!=setting.toLowerCase()) return null;
		if (lines != null && lines.length > 1)
		{
			lines.splice(0, 1);
			return lines;
		}
		return null;
	}
	
	/**
	 * Runs a wmic command that returns a date.
	 * Parses that date and returns it as a haxe Date.	 
	 */
	function wmicDate(alias:String, setting:String):Date
	{
		var lines = wmic(alias, setting);
		if (lines == null) return null;
		var time = lines[0];
		var year = Std.parseInt(time.substr(0, 4));
		var month = Std.parseInt(time.substr(4, 2));
		var day = Std.parseInt(time.substr(6, 2));
		var hour = Std.parseInt(time.substr(8, 2));
		var min = Std.parseInt(time.substr(10, 2));
		var sec = Std.parseInt(time.substr(12, 2));
		return new Date(year, month - 1, day, hour, min, sec);
	}
	
	/**
	 * Simple function to read text from an ini file.
	 */
	static function parseProperties(text:String):Map<String, String> {
		var map:Map<String, String> = new Map();
		var ofs:Int = 0;
		var len:Int = text.length;
		var i:Int; 
		var j:Int;
		var endl:Int;
		while(ofs < len) 
		{
			// find line end offset:
			endl = text.indexOf("\n", ofs);
			if (endl < 0) endl = len; // last line
			// do not process comment lines:
			i = text.charCodeAt(ofs);
			if (i != "#".code && i != "!".code) 
			{
				// find key-value delimiter:
				i = text.indexOf("=", ofs);
				j = text.indexOf(":", ofs);
				if (j != -1 && (i == -1 || j < i)) i = j;
				if (i >= ofs && i < endl) 
				{
					// key-value pair "key: value\n"
					map.set(StringTools.trim(text.substring(ofs, i)),StringTools.trim(text.substring(i + 1, endl)));
				} 
				else 
				{
					// value-less declaration "key\n"
					map.set(StringTools.trim(text.substring(ofs, endl)), "");
				}
			}
			// move on to next line:
			ofs = endl + 1;
		}
		return map;
	}
	
	/**
	 * Simple function to write properties to an ini file.
	 */
	function writeProperties(file:String,props:Map<String, String>):Void
	{
		var output = new StringBuf();
		for (item in props.keys())
		{
			output.add(item + "=" + props.get(item));
		}
		File.saveContent(file, output.toString());
	}
	
	/**
	 * Execute a HTTP Get request.
	 * @return Returns the response data or null in case the status code was not in the 200 range.
	 */
	function doHttpGet(url:String):String
	{
		var status:Int = 200;
		var content:String = null;
		var http:Http = new Http(url);
		http.onStatus = function(data) { status = data;  trace("Status: " + data); };
		http.onError = function(data) { status = 400; trace("Error: " + data); };
		http.onData = 
			function(data) 
			{
				content = data; 
			};
		http.request(false/*post*/);
		/* No success? */
		if (status<200 || status>299)
		{
			trace("Download of $url failed with status code $status");
			return null;
		}
		return content;
	}
}