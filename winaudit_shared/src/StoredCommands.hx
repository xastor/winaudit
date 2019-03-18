import sys.io.File;

import haxe.Json;
import sys.FileSystem;

class StoredCommands
{
	/**
	 * Load the stored commands.
	 * This function assumes a locking mechanism is setup outside of the scope of this function.
	 */
	public static function load():Array<Dynamic>
	{
		var list:Array<Dynamic> = null;
		if (FileSystem.exists(Constants.SavedCommandsFile) == false)
		{
			list = new Array<Dynamic>();
		}
		else 
		{
			list = loadJSON(Constants.SavedCommandsFile);	
		}
		return list;
	}

	/**
	 * Save the stored commands.
	 * This function assumes a locking mechanism is setup outside of the scope of this function.
	 */
	public static function save(list:Array<Dynamic>):Void
	{
		saveJSON(Constants.SavedCommandsFile,list);
	}	

    /**
	 * Loads a json document from a file.
	 */
	private static function loadJSON(file:String):Array<Dynamic>
	{
		return cast Json.parse(File.getContent(file));
	}
	
	/**
	 * Saves data as json to a file.
	 */
	private static function saveJSON(file:String, data:Array<Dynamic>):Void
	{
		File.saveContent(file, Json.stringify(data));
	}
}