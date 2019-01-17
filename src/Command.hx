package;

/**
 * Class Command models a command to be run by the service.
 * 
 * @author Pieter Bonne <xastor@gmail.com>
 */
class Command
{
	/** The command name. */
	public var name(default, null):String;
	/** The command data/parameters. */
	public var data(default, null):Dynamic;
	
	/**
	 * Create a new command instance.
	 */
	public function new(name:String,data:Dynamic=null)
	{
		this.name = name;
		this.data = data;
	}
}