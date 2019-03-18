package;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.Utf8;
import sys.io.Process;

/**
 * Class CommandlineUtil defines utility functions for interacting with commandline processes.
 * 
 * @author Pieter Bonne <xastor@gmail.com>
 */
class CommandlineUtil
{
	/**
	 * Get the output of a command.
	 * @param cmd the command to execute.
	 * @param arguments the list of arguments to provide.
	 * @return Returns the lines of output of the command 
	 */
	public static function getOutput( cmd, arguments:Array<String> ) : Array<String>
	{
		trace('Executing $cmd $arguments');
		var p:Process = new Process(cmd, arguments);
		//var exitCode:Int = p.exitCode();
		//trace("Exit code: " + exitCode);
		var list:Array<String> = new Array();
		try
		{
			while (true)
			{
				var line = Utf8.encode(p.stdout.readLine());
				list.push(StringUtil.clean(line));
			}
		}
		catch (eof:Eof)
		{
		}
		catch (error:Dynamic)
		{
			trace(error);
		}
		return list;
	}
}