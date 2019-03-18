package;

import filelock.FileLock;

import cpp.link.StaticStd;
import cpp.link.StaticZlib;

/**
 * Class UserHelper is the entrypoint of the userspace helper for WinAudit.
 * 
 * The userspace helper does one thing : executing saved tasks of type "userexecute".
 * After executing, the task is marked as executed and won't execute again.
 * 
 * @author Pieter Bonne <xastor@gmail.com>
 */
class UserHelper
{	
	/** 
	 * The application entrypoint.
	 */
	public static function main() : Void
	{
		new UserHelper();
	}
	
	public function new() 
	{
		while (true)
		{
			trace("Looking for commands...");
			FileLock.lock(Constants.SavedCommandsFile).handle(function(o) switch o {	
				case Success(lock):
					try
					{
						var commands:Array<Dynamic> = StoredCommands.load();
						for(command in commands)
						{
							if (command.name != "userexecute") continue;
							if (Reflect.hasField(command,"completed") && command.completed==true) continue;
							else
							{
								try
								{
									var list:Array<Command> = new Array();
									list.push(new Command("execute",command.data));
									command.completed = true;
									CommandUtil.runCommands(list,null);
									trace("Command executed.");
								}
								catch(error:Dynamic)
								{
									trace("error",error);
								}
							}
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

			trace("Sleeping...");
			Sys.sleep(5);
		}
	}
}