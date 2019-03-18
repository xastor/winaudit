import filelock.FileLock;

import sys.FileSystem;
import sys.io.File;

import haxe.Http;

import haxe.io.Bytes;

class CommandUtil
{
    public static function runCommands(list:Array<Command>,service:I_ServiceUpdater)
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
					service.update();
				
				case "userexecute":
					trace("Command: userexecute '"+command.data.command+"'");
					trace("Arguments: " + command.data.arguments);
                    FileLock.lock(Constants.SavedCommandsFile).handle(function(o) switch o {
                        case Success(lock):
							try
							{
								var commands:Array<Dynamic> = StoredCommands.load();
								commands.push(command);
								StoredCommands.save(commands);
							} 
							catch(error:Dynamic)
							{
								trace("Unexpected error: "+ error);
							}
				        	lock.unlock();
                        case Failure(err):
                            trace(err);
                    });
					trace("Added to stored commands.");

				case "execute":
					trace("Command: execute '"+command.data.command+"'");
					trace("Arguments: " + command.data.arguments);
					var output = CommandlineUtil.getOutput(command.data.command, command.data.arguments);
					trace("Output: " + output);
					
				case "download":
					trace("Command: download");
					var url = command.data.url;
					var filename = StringUtil.replaceMeta(command.data.filename);
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
						var data = CommandUtil.doHttpGet(url);
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
					RegistryUtil.writeKey(command.data.node, command.data.key, StringUtil.replaceMeta(command.data.value), type);

				case "delreg":
					trace("Command: delreg");
					trace("Node: " + command.data.node);
					trace("Key name: " + command.data.key);
					RegistryUtil.deleteKey(command.data.node, command.data.key);

				case "delete":
					trace("Command: delete");
					var filename = StringUtil.replaceMeta(command.data.filename);
					trace("Filename: " + filename);
					if (FileSystem.exists(filename))
						FileSystem.deleteFile(filename);
					
				case "addstartuptask":
					trace("Command: addstartuptask");
					var id:String = command.data.id;
					var download_url:String = command.data.download_url;
					var download_filename:String = StringUtil.replaceMeta(command.data.download_filename);
					var task:String = StringUtil.replaceMeta(command.data.task);
					var completedFile:String = StringUtil.replaceMeta(command.data.completedFile);
					trace("Id: " + id);
					trace("download_url: " + download_url);
					trace("download_filename: " + download_filename);
					trace("Task: " + task);
					trace("CompletedFile: " + completedFile);
					
					StartupTask.addStartupTask(command);
					StartupTask.resetStartupTask(command.data.id);
					
				case "resetstartuptask":
					trace("Command: resetstartuptask");
					var id:String = command.data.id;
					trace("Id: " + id);
					
					StartupTask.resetStartupTask(id);
					
				case "removestartuptask":
					trace("Command: deletestartuptask");
					var id:String = command.data.id;
					trace("Id: " + id);
					
					StartupTask.deleteStartupTask(id);
					
				default:
					trace("unkown command '"+ command.name +"'");
			}
		}
	}

    /**
	 * Execute a HTTP Get request.
	 * @return Returns the response data or null in case the status code was not in the 200 range.
	 */
	public static function doHttpGet(url:String):String
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
			trace('Download of $url failed with status code $status');
			return null;
		}
		return content;
	}
}