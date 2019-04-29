## 4.sh
A [4chan](https://4chan.org) utility/downloader script.
Originally developed by [vague](https://github.com/vaguelyr), now expanded by friends.


## Dependencies
The only dependencies are `bash` and GNU `coreutils`, which come preinstalled with any good Linux distro. 

Optionally, `recode` is used for prettier output, and `youtube-dl` for downloading media links found within the posts.


## Usage
<pre>
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


## Ideas for the Future
- Address TODOs and FIXMEs within the code
- Associate images and posts
- Preserve filenames for images (especially relevant for filename threads)
- Preserve names and tripcodes
- Add progress indicator, no matter the mode we are in.
- Add option to remove images deleted, as they are likely not worth keeping.
- Add prettyfication options for the update status. E.g. Let the lines of ='s be changed.
- Update the update status with what you are downloading, particularly yt/sc/bc links, etc
- Date past versisons / add a changelog file
- Add report of how many images/posts were downloaded each update
- Add report of thread information to a file / option for stdout too
- Consider adding/moving to `set -x` for debugging instead of just printing text.
- Continuous monitoring of a board with downloading of any thread matching given regex
- Add option to download banners and contest banners
- Put all downloaded content within respective folders
- Add option to download sitewide misc data, popular threads shown on the site home,blog, etc
- Add option for all boards mode to be all sfw or nsfw boards

GPL-3.0-or-later
