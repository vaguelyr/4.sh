<pre>4.sh was the first major thing I programmed and keep maintaining. 

The only dependancies are bash and gnu coreutils, which come preinstalled with any good Linux distro. 

4chan downloader script - v. 3.50041
Usage ./4.sh [option] -u <target>
	Required:
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
		-m 		: filter thread names by a given block list, comma delimited.
		-l 		: download soundcloud,youtube, and bandcamp links (requires youtube-dl)
		-z <number>	: boards at a time (for use with -a, default is 1)
		-d <dirname>	: choose the directory to use
		-n <number>	: number of images at a time (default is 10)
		-r <number>	: number threads at a time (default is 1)
		-s <number>	: time between threads (default is 1s)
		-p <character>	: progress bar character (default is ".")
	Examples:
		./4.sh -u g 		
			download all of /g/
		./4.sh -n 2 -u wg	
			download all of /wg/, two images at a time
		./4.sh -o -t -u http://boards.4chan.org/g/thread/39894014/
			download everything from /g/'s sticky, once, text only
		./4.sh -i -m 'ignore,threads,with,these,words,in,the,titles' -u o
			download images from /o/, filtering by those words

</pre>
