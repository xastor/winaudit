package;

/**
 * Class RegistryUtil defines some utility functions for interacting
 * with the windows reg.exe utility.
 * 
 * @author Pieter Bonne <xastor@gmail.com>
 */
class RegistryUtil
{
	
	public static function sanitizeType(type:String):String
	{
		switch(type)
		{
			case "REG_SZ":
				return type;
			case "REG_MULTI_SZ":
				return type;
			case "REG_EXPAND_SZ":
				return type;
			case "REG_DWORD":
				return type;
			case "REG_QWORD":
				return type;
			case "REG_BINARY":
				return type;
			case "REG_NONE":
				return type;
			default: 
				return "REG_SZ";
		}
	}
	
	public static function readKey(nodeName:String, keyName:String=""):Null<String>
	{
		var output:Array<String> = CommandlineUtil.getOutput("reg", ["query", nodeName, "/v", keyName]);
		var list:Array<String> = StringUtil.cleanAndTrimList(output[2].split(" "));
		if (list.length < 3) return null;
		var name = list.shift();
		var type = list.shift();
		return list.join(" ");
	}
	
	public static function readKeyInt(nodeName:String, keyName:String=""):Null<Int>
	{
		var value = RegistryUtil.readKey(nodeName, keyName);
		if (value == null) return null;
		return Std.parseInt(value);
	}
	
	public static function writeKey(nodeName:String, keyName:String, keyValue:String, type:String):Array<String>
	{
		// reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Run /v ChangeOwner /f /d data
		// reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /f /d 0 /t REG_DWORD
		
		var params = [
			"add",
			nodeName,
			"/v",
			keyName,
			"/f",
			"/d",
			keyValue,
			"/t",
			type];
			
		var output:Array<String> = CommandlineUtil.getOutput("reg", params);
		return StringUtil.cleanAndTrimList((output));
	}

	public static function deleteKey(nodeName:String, keyName:String):Array<String>
	{
		// reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run /v ChangeOwner /f
		var params = [
			"delete",
			nodeName,
			"/v",
			keyName,
			"/f"];
			
		var output:Array<String> = CommandlineUtil.getOutput("reg", params);
		return StringUtil.cleanAndTrimList((output));
	}
	
}