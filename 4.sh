#!/bin/bash

# Copyright (C) 2019 vague

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


version=3.50041 # 19-4-17

## Colors
green="\e[32m"
white="\e[97m"

## Defaults
target=""
allBoards=""
downloadText="1"
downloadImages="1"
oneshot="0"
noDirectories="0"
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

# Used to prevent ascending to a higher directory if a thread is deleted while we're working on it
path=""



## Usage
# cat won't interpret the escape sequences for colors

usageMessage(){
	cat <<USAGE
4chan downloader script - v. $version
$(echo -e "${green}")
Usage: $0 [option] -u <target>
	Required:
    $(echo -e "${white}")
		-u <target> 	: target (board or thread)
    $(echo -e "${green}")
	Options:
        $(echo -e "${white}")
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
    $(echo -e "${green}")
	Examples:
        $(echo -e "${white}")
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


# Update our path
path="$(pwd)/$directory"

# No argument, so inform our user of what they should do.
if [ -z "$1" ] ; then
	usageMessage
	exit
fi


# Process arguments
while getopts ":itp:s:u:n:or:d:haz:lOkbm:" input ; do
	case $input in
		O)# Only output text to stdout
			outputText="1"
			downloadImages="0"
			noDirectories="1"
			;;
		b)# Enable debug text mode
			debug="1"
			;;
		p)# Progress bar character
			progressChar=$OPTARG	
			;;
		z)# Boards taken at a time
			boardsMax=$OPTARG	
			;;
		i)# Download only images
			downloadText="0"
			;;
		a)# All Boards mode
			allBoards="1"
			;;
		t)# Text only
			downloadImages="0"
			;;
		d)# Overall location
			directory=$OPTARG
			;;
		h)# Show usage message
			usageMessage
			exit
			;;
		k)# Don't make new directories
			noDirectories="1"
			;;
		m)# Word filter list
			wordFilter=$(echo $OPTARG | sed -e 's/,/|/g')
			;;
		n)# Max number of images at once
			imagesMax=$OPTARG
			;;
		r)# Max number of threads at once
			threadsMax=$OPTARG
			;;
		s)# Sleep time between threads
			sleepBetweenThreads=$OPTARG
			;;
		o)# Run once then exit
			oneShot="1"
			;;
		l)# Process links
			processLinks="1"
			;;
		u)# Target
			target=$OPTARG
			;;
		?)# Error	
			usageMessage
			;;
	esac
done


# Do we have a usable target?
if [ -z "$target" -a -z "$allBoards" ] ; then
	echo "Error: No target. (Specifiy with -u <target>)"
	exit
fi



#============================= Functions ===============================#


# wget wrapper, acts as interface so we may do things like apply verbose mode to every call
wget(){
	command wget "$@" -q --tries=3 --timeout=4 --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0"
	# TODO even randomizing or setting the useragent here is possible
}


# Makes a directory (If we are suppose to) and cd's to it.
mkcd(){
	if [ ! "$noDirectories" == "1" ] ; then
		mkdir -p "$1"
	fi

	if [ "$1" = ' ' ] ;then
		debugText "mkcd: given empty?"
	fi

	cd "$1" 2>/dev/null
	
	debugText "mkcd: dir $1"
}


# If debug text mode is enabled, outputs all arguments to stderr.
# Otherwise, does nothing.
debugText(){
	if [ "$debug" = "0" ] ; then
		return
	else
		echo DEBUG: $@ >&2
	fi	
}


# Finds the threadname from $threadPage for the folder
findName(){  
	# TODO whats the point of finding threadName if your not making any folders or using it anywhere?

	# Find the initial name from the page title
	threadName=$(echo $threadPage | sed -e 's/.*application\/rss+xml\"//' \
					    -e 's/text\/javascript.*//' \
					    -e 's/.*\/\ -\ //' \
					    -e 's/..title..script\ type..//' )

	# Clean up punctuation
	threadName=$(echo $threadName | sed -e 's/\&#039;//g' \
					    -e 's/\///g' \
					    -e 's/\&gt;//g' \
					    -e 's/\&amp;/and/g' \
					    -e 's/\&quot;//g' \
					    -e 's/........$//g')

	# Find the date to prevent duplicated threadnames
	threadName=$threadName\ $( echo $threadPage| sed -e 's/Link\ to\ this\ post.*//g' \
							 -e 's/.*>//g' \
							 -e 's/<.*//g' \
							 -e 's/(.*)/||/' \
							 -e 's_/_-_g' )

	# Convert html character entities to their UTF-8 equivalents if we have recode.
	if [ ! -z "$(command -v recode)" ] ; then
		threadName=$(echo $threadName | recode html..utf-8)
	fi

	debugText "findName: got name $threadName"

}


# Scrapes all the posts and outputs them
findPosts(){  

	# FIXME XXX the "reallyweirdasdf" part?
	if [ "$outputText" == "1" ] ; then
		echo $threadPage | sed 's/class=\"nameBlock\"/\n/g' \
				 | grep "blockquote class=\"postMessage\"" \
				 | sed -e 's_./blockquote></div.*__g' \
				 | sed -e 's/.*postMessage\"\ //g' \
				       -e 's/<span\ class=\"quote\">&gt;/>/g' \
				 | sed -e 's/id=\"m/=========\ m/g' \
				       -e 's/m[0-9]*\">/&\n/' \
				       -e 's/\">/\ =============/' \
				       -e 's/<\/a>//g' \
				       -e 's/<br>/\n/g' \
				       -e 's/<\/span>//g' \
				       -e 's/&#039;/'"'"'/g' \
				       -e 's/&quot;/\"/g' \
				       -e 's/&gt;/>/g' \
				       -e 's/<wbr>//g' \
				 | sed -e 's/quotelink\">/asdftHisPartIsActuallyrEallyWeirdasdff\n/g' \
				 | grep -v asdftHisPartIsActuallyrEallyWeirdasdff
	else

		echo $threadPage | sed 's/class=\"nameBlock\"/\n/g' \
				 | grep "blockquote class=\"postMessage\"" \
				 | sed -e 's_./blockquote></div.*__g' \
				 | sed -e 's/.*postMessage\"\ //g' \
				       -e 's/<span\ class=\"quote\">&gt;/>/g' \
				 | sed -e 's/id=\"m/=========\ m/g' \
				       -e 's/m[0-9]*\">/&\n/' \
				       -e 's/\">/\ =============/' \
				       -e 's/<\/a>//g' \
				       -e 's/<br>/\n/g' \
				       -e 's/<\/span>//g' \
				       -e 's/&#039;/'"'"'/g' \
				       -e 's/&quot;/\"/g' \
				       -e 's/&gt;/>/g' \
				       -e 's/<wbr>//g' \
				 | sed -e 's/quotelink\">/asdftHisPartIsActuallyrEallyWeirdasdff\n/g' \
				 | grep -v asdftHisPartIsActuallyrEallyWeirdasdff > $textFile

	fi

	debugText "findPosts"
}


# Downloads all the images within our current thread
findImages(){ 
	# TODO
	#allImages=$( echo $threadPage | sed -e 's/<div\ class=\"file\"/\n/g' | sed -e 's/\ target=\"_blank\".*//g' -e 's/.*href=\"//g' -e 's/.$//g' | grep 4cdn.org )
	# TODO FIXME i think they might have just changed the cdn text
	allImages=$(echo $threadPage |  sed -e 's/File/\nFile/g' \
				     | grep File:.*target -o \
				     | sed -e 's/\"\ .*//' \
				     | grep href \
				     | sed -e 's/.*\/\///' )


	debugText "findImages"
	debugText "got $allImages"
	

	num=0
	for image in $allImages ; do

		debugText "findImages: getting $image"

		wget -N $image 

		num=$((num + 1)) # better
		# TODO FIXME - confirm we are at the best solution, then remove these commented ones
		#let num=num+1 # shellbuiltin for math. faster
		#num=$( echo "$num + 1" | bc ) # increment num

		# TODO Refactor this out into showing progress no matter the mode we are in
		#if [ $num -ge $imagesMax ] ; then
		#	echo -n "$progressChar"
		#	wait
		#	num=0
		#fi
	done

}	


# Finds and processes URLs within our current thread.
findLinks(){ 
	debugText "findLinks"


	# Download all the bandcamp links
	youtube-dl $( echo $threadPage | sed -e 's/http/\n&/g' \
				       | sed -e 's/<wbr>//g' \
				       | grep bandcamp.com\/ \
			               | sed -e 's/<br>.*//g' \
			      		     -e 's/<\/blockquote>.*//g' ) 2>/dev/null &

	# Download all the soundcloud links
	youtube-dl $( echo $threadPage | sed -e 's/https:\/\/soundcloud/\n&/g' \
				     	     -e 's/<wbr>//g' \
				       | sed -e 's/<.*//g' ) 2>/dev/null&

	# Download all the youtube links
	youtube-dl $( echo $threadPage | sed -e 's/youtube.com/\n&/g' \
				       | sed -e 's/<wbr>//g' \
				       | sed -e 's/<.*//g' \
				             -e 's/\s.*//g' )  2>/dev/null &

	wait
}


# Finds the current location of the boards, so we don't have to.
findBoards(){
	boards="$(wget -q -O - http://www.4chan.org/ | grep class=\"boardlink\" \
						     | sed -e 's/.*.org\///' \
						     	   -e 's/\/.*//' \
						     | sort -u)"

        # filter out the boards we dont want
        boards="$(echo $boards | sed -e 's/\ f\ //')"

	debugText "findBoards: found $boards"	
}


# Populates $catalogue with all the current threads
findThreads(){
	debugText "findThreads in board $board"

	# TODO - figure out best solution here
	# also works
	#catalogue=$(wget -O - http://boards.4chan.org/$board/catalog )
	#catalogue=$(echo $catalogue  | sed -e 's/\"/\n/g' | grep -P "^[0-9]{4}" | grep -v "\." )

	catalogue=$(wget -q -O -  "http://boards.4chan.org/$board/catalog" | sed -e 's/{\"date/\n/g' \
									   | sed -e 's/.*,//' \
										 -e 's/^.//' \
										 -e 's/\"://' \
								           | sed -e 's/.*\"://' \
									   | grep -v false)


}


# Processes our current thread
workThread(){
	debugText "workThread: start"

	# download page
	threadPage=$(wget -O - http://boards.4chan.org/$board/thread/$1 2>&1)

	# Do we have an error?
	if [ -z "$threadPage" ] ; then
		debugText "workThread: empty page check is empty"
		echo no page
		cd $path
		return
	fi

	# Find our current thread name and populate $threadName with it.
	findName 

	# Filter out threads
	if [ ! -z "$wordFilter" ] && [ "$(echo $threadName | grep -E "$wordFilter" )" ] ; then
		cd $path
		return
	fi

	# If findName failed, we have a thread number instead.
	if [ -z "$threadName" ] ; then
		threadName=$1
	fi

	mkcd "$threadName"	

	echo ============================================ $'\n'http://boards.4chan.org/$board/thread/$1 $'\n'$threadName


	echo -n "Downloading "
	# Download text if requested
	if [ "$downloadText" == "1" ] ; then
		echo -n "Text "
		findPosts &
	fi

	# Download images if requested
	if [ "$downloadImages" == "1" ] ; then
		echo -n "Images "
		findImages &
	fi
	
	# Process links if requested
	if [ "$processLinks" == "1" ] && [ ! -z "$(command -v youtube-dl)" ] ; then
		echo "Links"
		findLinks &
	fi

 	wait 

	echo

	cd "$path"
}


#=========================== End Functions =============================#



# Make our directory to hold what we download, then cd to it.
mkcd "$directory"

### Process arguments and run.

## One Thread Mode
if [ "$(echo $target | grep http.*org )" ] ;then 
	debugText "single thread: final loop enter"

	board=$(echo $target | sed -e 's/\/thread\/[0-9]*.*//' \
				   -e 's/.*\///g' )
	thread=$(echo $target | sed -e 's/.*thread\///g' \
				    -e 's/\/.*//g')

	while true; do 
		workThread $thread

		if [ "$oneShot" == 1 ] ; then
			exit 0
		fi
		debugText "sleeping $sleepBetweenThreads"
		sleep "$sleepBetweenThreads"
	done
fi

## All Boards Mode
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

		if [ "$oneShot" == "1" ] ; then
			exit 0
		fi

	done
fi

board=$target
mkcd "$board"

## Single Board Mode
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

	if [ "$oneShot" == "1" ] ; then
		exit 0
	fi
done
