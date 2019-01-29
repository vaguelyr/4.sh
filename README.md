<pre> 4chan downloader script - v. 3.5004
Usage 4.sh [option] -u <target>
	Required: (unless -a is used)
		-u <target> 	: target (board or thread) 
	Options:
		-a		: do all boards
		-b 		: debug output
		-h 		: show this message
		-i		: only download images 
		-t		: only download text
		-o		: oneShot (once then exit)
		-O 		: only output posts to stdout
		-k		: dont make any new directories
		-l 		: download soundcloud,youtube, and bandcamp links (requires youtube-dl)
		-z <number>	: boards at a time (for use with -a, default is 1)
		-d <dirname>	: choose the directory to use
		-n <number>	: number of images at a time (default is 10)
		-r <number>	: number threads at a time (default is 1)
		-s <number>	: time between threads (default is 1s)
		-p <character>	: progress bar character (default is ".")
	Examples:
		4.sh -u g 		
			download all of /g/
		4.sh -n 2 -u wg	
			download all of /wg/, two images at a time
		4.sh -o -u http://boards.4chan.org/g/thread/39894014/
			download everything from /g/'s sticky, once
</pre>
