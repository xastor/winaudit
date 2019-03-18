import filelock.FileLock;

import sys.FileSystem;

class StartupTask
{
	/** The registry node for startup tasks. */
	private static inline var STARTUP_NODE = "HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";
	
	/**
	 * Process "addstartuptask" commands that have been stored.
	 * They are checked to mark them as "executed" if a marker file exists that is part of the task definition.
	 * Tasks are also removed from the registry so they don't start again on user login.
	 */
	public static function processStartupTasks()
	{
		FileLock.lock(Constants.SavedCommandsFile).handle(function(o) switch o {
		 	case Success(lock):
				try
				{
					var commands:Array<Dynamic> = StoredCommands.load();
					for (command in commands)
					{
						var id = command.data.id;
						var completed = Reflect.hasField(command.data, "completed") ? command.data.completed : false;
						var completedFile = Reflect.hasField(command.data,"completedFile") ? StringUtil.replaceMeta(command.data.completedFile) : null;
						if (completed == false && completedFile != null)
						{
							if (FileSystem.exists(completedFile))
							{
								/* Mark as completed. */
								trace("Startup task '" + id +"' was completed.");
								command.completed = true;
								StoredCommands.save(commands);
								/* Remove startup task */
								var commands:Array<Command> = new Array();
								commands.push(new Command("delreg", { "node":STARTUP_NODE, "key":"winaudit_startup_" + id } ));
								CommandUtil.runCommands(commands, null/*service*/);
							}
						}
					}
				}
				catch(error:Dynamic)
				{
					trace("Unexpected error: "+ error);
				}
			    lock.unlock();
			case Failure(err):
		    	trace(err);
		});
	}

	/**	
	 * Create (end enable) a startup task.
	 *  - Adds a startup task to the local file with startup tasks.
	 *  - Downloads the task executable.
	 */
	public static function addStartupTask(command:Dynamic)
	{
		FileLock.lock(Constants.SavedCommandsFile).handle(function(o) switch o {
		 	case Success(lock):
				try
				{
					var commands:Array<Dynamic> = StoredCommands.load();
					var found:Bool = false;
					for (i in 0...commands.length)
					{
						if (commands[i].id == command.id)
						{
							found = true;
							commands[i] = command;
						}
					}
					if (found == false)
					{
						commands.push(command);
					}
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

		// Get info
		var download_url:String = Reflect.hasField(command.data,"download_url") ? command.data.download_url : null;
		var download_filename:String = Reflect.hasField(command.data,"download_filename") ? StringUtil.replaceMeta(command.data.download_filename) : null;
		var download_force:Bool = Reflect.hasField(command.data, "download_force") ? command.data.download_force == "true" : false;
		var commands:Array<Command> = new Array();
		if (download_url != null && download_filename != null)
		{
			// Download task file
			commands.push(new Command("download", { "url":download_url, "filename":download_filename, "force":download_force } ));
		}
		// Reset (add to registry, remove "completed" file).
		CommandUtil.runCommands(commands,null/*service*/);
	}
	
	/**
	 * Resets (and enables) a startup task.
	 *  - Marks a startup task as not completed.
	 *  - Removes the task completion file.
	 *  - Adds the task to the registry.
	 */
	public static function resetStartupTask(id:String)
	{
		var command:Dynamic = null;
		FileLock.lock(Constants.SavedCommandsFile).handle(function(o) switch o {
		 	case Success(lock):
				try
				{
					var commands:Array<Dynamic> = StoredCommands.load();
					for (task in commands)
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
					if (command != null)
					{
						Reflect.deleteField(command, "completed");
						StoredCommands.save(commands);
					}
				}
				catch(error:Dynamic)
				{
					trace("Unexpected error: "+ error);
				}
			    lock.unlock();
			case Failure(err):
		    	trace(err);
		});
		
		if (command == null)
		{
			trace('Command with id $id not found.');
			return;
		}

		// Get info
		var task:String = StringUtil.replaceMeta(command.data.task);
		var completedFile:String = Reflect.hasField(command.data,"completedFile") ? StringUtil.replaceMeta(command.data.completedFile) : null;
		// Add startup task
		var commandsToRun:Array<Command> = new Array();
		if (completedFile!=null && FileSystem.exists(completedFile))
		{
			commandsToRun.push(new Command("delete",
				{
					"filename":completedFile
				}));
		}
		commandsToRun.push(new Command("setreg",
			{
				"node":STARTUP_NODE, 
				"key":"winaudit_startup_"+id,
				"value":task 
			}));
		CommandUtil.runCommands(commandsToRun,null);
	}
		
	/**
	 * Removes a startup task from the system entirely.
	 * - Deletes a startup task from the local file
	 * - Removes the task from the registry
	 * - Deletes the task and completion file.
	 */
	public static function deleteStartupTask(id:String)
	{
		var command:Dynamic = null;
		FileLock.lock(Constants.SavedCommandsFile).handle(function(o) switch o {
		 	case Success(lock):
				try
				{
					var commands:Array<Dynamic> = StoredCommands.load();
					for (task in commands)
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
						commands.remove(command);
						// Save
						StoredCommands.save(commands);
					}
				}
				catch(error:Dynamic)
				{
					trace("Unexpected error: "+ error);
				}
			    lock.unlock();
			case Failure(err):
		    	trace(err);
		});

		if (command!=null)
		{
			// Get info
			var download_filename:String = Reflect.hasField(command.data,"download_filename") ? StringUtil.replaceMeta(command.data.download_filename) : null;
			var completedFile:String = Reflect.hasField(command.data,"completedFile") ? StringUtil.replaceMeta(command.data.completedFile) : null;
			// Remove files
			var commands:Array<Command> = new Array();
			if (download_filename!=null) commands.push(new Command("delete",{ "filename":download_filename }));
			if (completedFile!=null) commands.push(new Command("delete", { "filename":completedFile } ));
			// Remove startup task
			commands.push(new Command("delreg", { "node":STARTUP_NODE, "key":"winaudit_startup_" + id } ));
			CommandUtil.runCommands(commands,null);
		}
		else
		{
			trace("Startup task '" + id +"' not found in list.");
		}
	}
}