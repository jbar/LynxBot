#!/bin/bash

LynxBotVersion="LynxBot/0.2"

function exitlynxbot {
	kill $lynxpid
	kill $teepid
	rm /tmp/lynx_cmd_input.$$
	rm /tmp/lynx_output.$$
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
lynx -nopause -accept_all_cookies -useragent="$UserAgent" -cmd_script=/tmp/lynx_cmd_input.$$ "$@" | tee /tmp/lynx_output.$$ &
teepid=$!
lynxpid=$(jobs -p)

wait

