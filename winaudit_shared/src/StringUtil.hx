package;

/**
 * Class StringUtil defines string utilities.
 * 
 * @author Pieter Bonne <xastor@gmail.com>
 */
class StringUtil
{
	public static function cleanAndTrimList(list:Array<String>):Array<String>
	{
		var newlist:Array<String> = new Array();
		for (item in list)
		{
			if (item == null) continue;
			if (StringTools.trim(item).length == 0) continue;
			newlist.push(clean(item));
		}
		return newlist;
	}
	
	public static function clean(serial:String):String
	{
		serial = StringTools.trim(serial);
		serial = StringTools.replace(serial,String.fromCharCode(10),"");
		serial = StringTools.replace(serial,String.fromCharCode(13),"");
		return serial;
	}

	/**
	 * Replaces metadata tags in a string.
	 */
	public static function replaceMeta(text:String):String
	{
		if (text == null) return null;
		var servicepath = Sys.programPath();
		servicepath = servicepath.substr(0, servicepath.lastIndexOf("\\"));
		return StringTools.replace(text,"<servicepath>",servicepath);
	}	
}