#!/bin/bash
# vague

version=3.50041 # 19-4-17


usageMessage(){
	cat << USAGE
4chan downloader script - v. $version
Usage $0 [option] -u <target>
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
		$0 -u g 		
			download all of /g/
		$0 -n 2 -u wg	
			download all of /wg/, two images at a time
		$0 -o -t -u http://boards.4chan.org/g/thread/39894014/
			download everything from /g/'s sticky, once, text only
		$0 -i -m 'ignore,threads,with,these,words,in,the,titles' -u o
			download images from /o/, filtering by those words
USAGE
exit
}

if [ -z "$1" ] ; then
	usageMessage
	exit
fi

# Defaults
target=""
allBoards=""
imagesOnly=0
textOnly=0
oneshot=0
noDirectories=0
processLinks=0
imagesMax=10
threadsMax=1
boardsMax=1
sleepBetweenThreads=10s
outputText=0
debug="0"
wordFilter=""

progressChar="." 
textFile="./posts.txt"
directory="4chan"

# Process arguments
while getopts ":itp:s:u:n:or:d:haz:lOkbm:" input ; do
	case $input in
		O)# only output text to stdout
			outputText=1
			textOnly="1"
			noDirectories="1"
			;;
		b)# enable debugText
			debug="1"
			;;
		p)# progress bar character
			progressChar=$OPTARG	
			;;
		z)# boards at a time
			boardsMax=$OPTARG	
			;;
		i)# images only
			imagesOnly="1"
			;;
		a)# images only
			allBoards="1"
			;;
		t)# text only
			textOnly="1"
			;;
		d)# overall location
			directory=$OPTARG
			;;
		h)# show usage message
			usageMessage
			exit
			;;
		k)# dont make new directories
			noDirectories="1"
			;;
		m)# word filter list
			wordFilter=$(echo $OPTARG | sed -e 's/,/|/g')
			;;
		n)# max number of images at once
			imagesMax=$OPTARG
			;;
		r)# max number of threads at once
			threadsMax=$OPTARG
			;;
		s)# sleep time between threads
			sleepBetweenThreads=$OPTARG
			;;
		o)# oneShot
			oneShot="1"
			;;
		l)# process links
			processLinks=1
			;;
		u)# target
			target=$OPTARG
			;;
		?)# error	
			usageMessage
			;;
	esac
done


# do we have a usable target?
if [ -z "$target" -a -z "$allBoards" ] ; then
	echo "Error: No target. (Specifiy with -u <target>)"
	exit
fi

# ====================== functions

# the wget wrapper
# acts as in interface
# lets us do stuff like applying verbose mode to every single wget call
wget(){
	command wget "$@" -q --tries=3 --timeout=4 --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0"
	# even randomizing or setting the useragent here is possible
}


# make a directory (if we are suppose to) and cd to it
mkcd(){
	if [ ! "$noDirectories" = 1 ] ; then
		mkdir -p "$1"
	fi

	if [ "$1" = ' ' ] ;then
		debugText "mkcd: given empty?"
	fi

	cd "$1" 2>/dev/null
	
	debugText "mkcd: dir $1"
}

# debug output
# easily get debug text where regular text would break dirty hacks
debugText(){
	if [ "$debug" = "0" ] ; then
		return
	else
		echo DEBUG: $@ >&2
	fi	
}

# Find the threadname from $threadPage for the folder
findName(){  
	# whats the point of finding threadName if your not making any folders or using it anywhere?

	# Find the initial name from the page title
	threadName=$(echo $threadPage | sed -e 's/.*application\/rss+xml\"//' -e 's/text\/javascript.*//' -e 's/.*\/\ -\ //' -e 's/..title..script\ type..//' )

	# Clean up punctuation
	threadName=$(echo $threadName | sed -e 's/\&#039;//g' -e 's/\///g' -e 's/\&gt;//g' -e 's/\&amp;/and/g' -e 's/\&quot;//g' -e 's/........$//g')

	# Find the date to prevent duplicated threadnames
	threadName=$threadName\ $( echo $threadPage| sed -e 's/Link\ to\ this\ post.*//g' -e 's/.*>//g' -e 's/<.*//g' -e 's/(.*)/||/' -e 's_/_-_g' )

	debugText "findName: got name $threadName"

}

# output all the posts
findPosts(){  
	if [ "$imagesOnly" == "1" ] ; then
		return
	fi

	if [ "$outputText" == "1" ] ; then
		echo $threadPage | sed 's/class=\"nameBlock\"/\n/g' | grep "blockquote class=\"postMessage\"" | sed -e 's_./blockquote></div.*__g' | sed -e 's/.*postMessage\"\ //g' -e 's/<span\ class=\"quote\">&gt;/>/g' | sed -e 's/id=\"m/=========\ m/g' -e 's/m[0-9]*\">/&\n/' -e 's/\">/\ =============/' -e 's/<\/a>//g' -e 's/<br>/\n/g' -e 's/<\/span>//g' -e 's/&#039;/'"'"'/g' -e 's/&quot;/\"/g' -e 's/&gt;/>/g' -e 's/<wbr>//g' | sed -e 's/quotelink\">/asdftHisPartIsActuallyrEallyWeirdasdff\n/g' | grep -v asdftHisPartIsActuallyrEallyWeirdasdff
	else
		echo -n "Text, "

		echo $threadPage | sed 's/class=\"nameBlock\"/\n/g' | grep "blockquote class=\"postMessage\"" | sed -e 's_./blockquote></div.*__g' | sed -e 's/.*postMessage\"\ //g' -e 's/<span\ class=\"quote\">&gt;/>/g' | sed -e 's/id=\"m/=========\ m/g' -e 's/m[0-9]*\">/&\n/' -e 's/\">/\ =============/' -e 's/<\/a>//g' -e 's/<br>/\n/g' -e 's/<\/span>//g' -e 's/&#039;/'"'"'/g' -e 's/&quot;/\"/g' -e 's/&gt;/>/g' -e 's/<wbr>//g' | sed -e 's/quotelink\">/asdftHisPartIsActuallyrEallyWeirdasdff\n/g' | grep -v asdftHisPartIsActuallyrEallyWeirdasdff > $textFile

	fi

	debugText "findPosts"
}

# download all the images
findImages(){ 
	if [ "$textOnly" == "1" ] ; then
		return
	fi
	echo -n Downloading images

	
	#allImages=$( echo $threadPage | sed -e 's/<div\ class=\"file\"/\n/g' | sed -e 's/\ target=\"_blank\".*//g' -e 's/.*href=\"//g' -e 's/.$//g' | grep 4cdn.org )
	# i think they might have just changed the cdn text
	allImages=$(echo $threadPage |  sed -e 's/File/\nFile/g' | grep File:.*target -o  | sed -e 's/\"\ .*//' | grep href | sed -e 's/.*\/\///' )


	debugText "findImages"
	debugText "got $allImages"
	

	num=0
	for image in $allImages ; do

		debugText "findImages: getting $image"

		wget -N $image 

		num=$((num + 1)) # better
		#let num=num+1 # shellbuiltin for math. faster
		#num=$( echo "$num + 1" | bc ) # increment num

		if [ $num -ge $imagesMax ] ; then
			echo -n "$progressChar"
			wait
			num=0
		fi
	done

}	

# find and process urls
findLinks(){ 
	if [ ! "$processLinks" = 1 ];then
		return
	fi

	debugText "findLinks"

	# download all the bandcamp links
	youtube-dl $( echo $threadPage | sed -e 's/http/\n&/g' | sed -e 's/<wbr>//g'| grep bandcamp.com\/ | sed -e 's/<br>.*//g' -e 's/<\/blockquote>.*//g' ) 2>/dev/null &
	# download all the soundcloud links
	youtube-dl $( echo $threadPage | sed -e 's/https:\/\/soundcloud/\n&/g' -e 's/<wbr>//g' | sed -e 's/<.*//g' ) 2>/dev/null&
	# download all the youtube links
	youtube-dl $( echo $threadPage | sed -e 's/youtube.com/\n&/g' |sed -e 's/<wbr>//g' | sed -e 's/<.*//g' -e 's/\s.*//g' )  2>/dev/null &

	wait
}

# dynamically find the boards so we dont have to
findBoards(){
	boards="$(wget -q -O - http://www.4chan.org/ | grep class=\"boardlink\" | sed -e 's/.*.org\///'  -e 's/\/.*//' | sort -u)"

        # filter out the boards we dont want
        boards="$(echo $boards | sed -e 's/\ f\ //')"

	debugText "findBoards: found $boards"	
}


# populate $catalogue with all the threads
findThreads(){
	debugText "findThreads in board $board"

	# also works
	#catalogue=$(wget -O - http://boards.4chan.org/$board/catalog )
	#catalogue=$(echo $catalogue  | sed -e 's/\"/\n/g' | grep -P "^[0-9]{4}" | grep -v "\." )

	catalogue=$(wget -q -O -  "http://boards.4chan.org/$board/catalog" | sed -e 's/{\"date/\n/g' | sed -e 's/.*,//' -e 's/^.//' -e 's/\"://' | sed -e 's/.*\"://' | grep -v false)


}

# process the thread
workThread(){
	debugText "workThread: start"

	threadPage=$(wget -O - http://boards.4chan.org/$board/thread/$1 2>&1) # download page

	# Error?
	if [ -z "$threadPage" ] ; then
		debugText "workThread: empty page check is empty"
		echo no page
		cd $path
		return
	fi

	#populates $threadName
	findName 

	# Filter out threads
	if [ ! -z "$wordFilter" ] && [ "$(echo $threadName | grep -E "$wordFilter" )" ] ; then
		cd $path
		return
	fi

	# if findName fails, it is assigned to the thread number
	if [ -z "$threadName" ] ; then
		threadName=$1
	fi

	mkcd "$threadName"	

	echo ============================================ $'\n'http://boards.4chan.org/$board/thread/$1 $'\n'$threadName

	# download all the text
	findPosts &

	# download all the images	
	findImages &
	
	# download all the soundcloud links	
	findLinks &

 	wait 

	echo

	cd "$path"
}


# ====================== end functions

mkcd "$directory"

# Prevents threads that are deleted while we're working on them resulting in calling "cd .."
# Prevents randomly ascending to higher directories 
path=$(pwd) 

## Process arguments and run

# thread
if [ "$(echo $target | grep http.*org )" ] ;then 
	debugText "single thread: final loop enter"

	board=$(echo $target | sed -e 's/\/thread\/[0-9]*.*//' -e 's/.*\///g' )
	thread=$(echo $target | sed -e 's/.*thread\///g' -e 's/\/.*//g')

	while true; do 
		workThread $thread

		if [ "$oneShot" = 1 ] ; then
			exit 0
		fi
		debugText "sleeping $sleepBetweenThreads"
		sleep "$sleepBetweenThreads"
	done
fi

# all boards
if [ "$allBoards" ];then
	debugText "all boards: final loop enter"

	findBoards
	while true ; do
		boardsRunning=0
		for board in $boards; do
			if [ "$boardsRunning" -ge "$boardsMax" ];then
				wait
				boardsRunning=0
			fi	

			mkcd "$board"

			boardsRunning=$(( boardsRunning + 1 ))

			findThreads

			threadsRunning=0
			for thread in $catalogue ; do
				workThread $thread &

				threadsRunning=$((threadsRunning + 1))
				if [ "$threadsRunning" -ge "$threadsMax" ];then
					wait
					threadsRunning=0
				fi	
				debugText "sleeping $sleepBetweenThreads"
				sleep "$sleepBetweenThreads"
			done &

			cd "$path"
			sleep 1s
		done

		if [ "$oneShot" = 1 ] ; then
			exit 0
		fi

	done
fi

board=$target
mkcd "$board"

# Entire board
while true ; do
	echo ============================================	
	debugText "Entire board: final loop enter"

	threadsRunning=0

	findThreads

	for thread in $catalogue ; do
		workThread $thread &

		threadsRunning=$((threadsRunning + 1))
		if [ "$threadsRunning" -ge "$threadsMax" ];then
			wait
			threadsRunning=0
		fi	
		debugText "sleeping $sleepBetweenThreads"
		sleep "$sleepBetweenThreads"
	done

	if [ "$oneShot" = 1 ] ; then
		exit 0
	fi
done
