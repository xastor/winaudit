package;

import haxe.crypto.Md5;
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
class Service implements I_ServiceUpdater
{
	/** The service settings map. */
	var settings:Map<String,String>;
	/** The service information map of captured information. */
	var info:Map<String,Dynamic>;
	/** The capture error flag. */
	var error:Bool;
	
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
		StartupTask.processStartupTasks();
		
		while (true)
		{
			trace("Time: " + Date.now().toString());
			
			this.setupUserHelper();

			do
			{
				error = false;
	
				loadSettings();
				loadRemoteSettings();
				trace("Settings: " + settings);
				
				captureInfo();
				trace("Info: "+ Json.stringify(this.info));
				
				StartupTask.processStartupTasks();
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
	 * Check if the userhelper is registered as a startup task.
	 */
	function setupUserHelper()
	{
		var cmd = new Command("removestartuptask",{"id":"winaudit_userhelper"});
		var cmd = new Command("addstartuptask",{"id":"winaudit_userhelper", "task":'"<servicepath>\\nircmd.exe" exec hide "<servicepath>\\UserHelper.exe"'});
		CommandUtil.runCommands([cmd], this);
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
			var data = CommandUtil.doHttpGet(url);
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
		
		this.info["version"] = Constants.Version;
		
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
		trace('Sending info to $url...');
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
		CommandUtil.runCommands(list,this);
	}
	
	/**
	 * Runs the WinSW service update mechanism.
	 */
	public function update()
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
			var data = CommandUtil.doHttpGet(updateUrl);
			if (data!=null)
			{
				var bytes = Bytes.ofString(data);
				File.saveBytes(updateFile, bytes);
				trace('Update file downloaded : $updateFile');
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
			trace("Unexpacted error while updating : "+ error);
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
}