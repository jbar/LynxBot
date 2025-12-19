#!/bin/bash

LynxBotVersion="LynxBot/0.7 05Sep2013"

function exitlynxbot {
	# Check lynxpid still exist before kill it
	if ps -p $lynxpid -o args --noheaders | grep -i lynx > /dev/null 2>&1; then
		kill $lynxpid >&2;
	fi
	# Check teepid still exist before kill it
	if ps -p $teepid -o args --noheaders | grep -ie lynx -ie tee > /dev/null 2>&1; then
		kill $teepid >&2;
	fi
	rm /tmp/lynx_cmd_input.$$ >&2
	rm /tmp/lynx_output.$$ >&2
	wait
}

trap "exitlynxbot" 0

# create input and output fifo
mkfifo /tmp/lynx_cmd_input.$$ || exit -1
mkfifo /tmp/lynx_output.$$ || exit -1

# Set the UserAgent
	UserAgent="$(lynx -version | head -1)  $LynxBotVersion"
	#UserAgent="Mozilla/5.0 (X11; Linux i686; rv:17.0) Gecko/20100101 Firefox/17.0"

# be sure that lynx will use default english langage
unset LANG
unset LC_MESSAGES

# Start lynx browser
lynx -term="xterm" -nopause -accept_all_cookies -useragent="$UserAgent" -cmd_script=/tmp/lynx_cmd_input.$$ "$@" | tee /tmp/lynx_output.$$ &
teepid=$!
lynxpid=$(jobs -p)

wait

