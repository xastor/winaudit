

class Constants
{

	public static var Version = "2019.03.18";
	
	/** The file where saved startup tasks are stored so they can be checked for completion or restarted. */
	public static var SavedCommandsFile(get,null):String;
	static function get_SavedCommandsFile():String
	{
		return StringUtil.replaceMeta("<servicepath>/savedcommands.ini");
	}

}