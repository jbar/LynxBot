#!/bin/bash
#set -x

# a Lynxbot sample who make a search on google and save it's result

# source the bash library to pilot a lynx
. /usr/local/lib/lynxbot/init_lynxbot
# (open and read this bash library to know all available functions)

LB_startlynxbot
sleep 1
LB_go_to_url "google.com"
# show the return value of the previous call
echo -e " --$?--"
sleep 1

# search the first Text entry field
LB_search_linktype "Text entry field"

LB_write_string "OpenUDC"

LB_go_nextl 1
LB_go_link

LB_get_current_page "OpenUDC_Google_p1result.txt"

LB_stop

