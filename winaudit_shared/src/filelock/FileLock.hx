package filelock;

import haxe.Timer;

import cpp.Stdio;

using tink.CoreApi;

class FileLock {
	
	public static function lock(path:String, ?options:LockOptions):Surprise<FileLockObject, Error> {
		
		if(options == null) options = {};
		if(options.retryCount == null) options.retryCount = 10;
		if(options.retryInterval == null) options.retryInterval = 100;
		
		var lock = new FileLockObject(path);
		

		return lock.lock(options) >> function(_) return lock;
	}
}

typedef LockOptions = {
	?retryCount:Int,
	?retryInterval:Int, // ms
}

class FileLockObject {
	
	var path:String;
	var lockFilePath(get, never):String;
	
	public function new(path:String) {
		this.path = path;
	}
	
	public function lock(options:LockOptions) {
		return Future.async(function(cb) {
			var trials = 0;
			
			function tryCreate() {
				try {
					
					if (sys.FileSystem.exists(lockFilePath)) throw "Cannot take lock file.";
					else sys.io.File.saveContent(lockFilePath, "");
					try
					{
						cb(Success(Noise));
					}
					catch (error:Dynamic)
					{
						trace("Unexpected error in success callback!");
						this.unlock();
					}
					
				} catch (e:Dynamic) {
					if(trials++ > options.retryCount)
						cb(Failure(new Error('Maximum number of retry')));
					else
						Timer.delay(tryCreate, options.retryInterval);
				}
			}
			
			tryCreate();
			
		});
	}
	
	public function unlock() {
		if (sys.FileSystem.exists(lockFilePath))
		{
			sys.FileSystem.deleteFile(lockFilePath);
		}
	}
	
	inline function get_lockFilePath() return '$path.lock';
	
	#if neko
	static var file_close = neko.Lib.load("std","file_close",1);
	static var file_open = neko.Lib.load("std","file_open",2);
	#end
}

#if cpp

// @:include("sys/stat.h")
@:include("fcntl.h")
extern class CppIo {
	@:native("open")
	public static function open(path:String, flags:Int):Int;
	@:native("close")
	public static function close(fd:Int):Void;
}
#end