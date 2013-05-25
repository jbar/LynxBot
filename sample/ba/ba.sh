#!/bin/bash

#BA_PASSWD=""

. /usr/local/lib/lynxbot/init_lynxbot
LB_startlynxbot

#set -x

function ba_login {
	baPlayer="${1:-$baPlayer}"
	export baPlayer
	local passwd="${2:-$BA_PASSWD}" tosleep
	if [ -z "$baPlayer" ] || [ -z "$passwd" ] ; then
		echo "usage: ba_login PLAYER [PASSWD]"
		return 9
	fi
	LB_get_current_info current_info
	if grep -i "arena.softgames.de/arena/SgGateway" current_info > /dev/null ; then
		LB_refresh_page
		ba_gohome
	else
		LB_go_to_url "http://arena.softgames.de"
	fi
	sleep 5
	LB_get_current_page current
	LB_go_firstl
	while ! grep "All you should know: protection," current >/dev/null ; do
	# while se are not in the Home page of the game	
		if greplog "chest-locked.png" current ; then
			# Already logged and the 1 day page to get money
			LB_go_firstl
			LB_go_link
			sleep 2
		elif greplog "SOFTGAMES Account" current ; then
			LB_go_firstl ; LB_go_nextl ; LB_go_link
			sleep 4
			if LB_go_firstl && LB_write_string "$baPlayer" && LB_go_nextl && LB_write_string "$passwd" ; then
				LB_go_nextl ; LB_go_link
			else
				echolog "ba_login warning: unexpected entry field"
				cp -vf current unexpected_login
				LB_go_to_url "http://arena.softgames.de"
				sleep $((RANDOM%60))
			fi
			sleep 4
		else
			((tosleep=5+RANDOM%1200)) # 20 min max
			echolog "ba_login warning: unexpected page ... ($tosleep sec.)"
			cp -vf current unexpected_login
			sleep $tosleep 
			LB_go_to_url "http://arena.softgames.de"
			sleep 10
		fi
		LB_get_current_page current
	done
	cp -vf current home.lxp
	status="$(grep -A 2 energy-ico.png current | tr -d '\n ')"
#	eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9/]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrgratio=$((100*\3)) coins=\4 crystals=\5, ' )
	eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9]\+\)/\([0-9]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrj=\3 nrjmax=\4 coins=\5 crystals=\6, ' )
	echolog "$baPlayer: lvl=$lvl($lvlratio%) nrj=$nrj/$nrjmax coins=$coins crystals=$crystals"
}

function ba_all {
	baPlayer="${1:-$baPlayer}"
	export baPlayer
	local time0 time1 tosleep
	local passwd="${2:-$BA_PASSWD}"

	if ! [ "$passwd" ] ; then
		read -s -t 60 -p "Password ? " passwd
		echo
	fi

	while true ; do
		ba_login "$baPlayer" "$passwd" || return 9

		time0=$(date +"%s")
		if ((baClanJobEnd<time0)) && LB_search_link "My clan" ; then
			LB_go_link && sleep 3
			ba_clanjob
			ba_gohome || continue
		fi

		if greplog "Quests \[plus-ico.png\]" home.lxp ; then
			LB_go_firstl
			LB_search_link Mastery && LB_go_nextl && LB_go_link && sleep $((RANDOM%2+1))
			ba_quests
		fi

		if greplog "(Submit) Map \[plus-ico.png\]" home.lxp ; then
			LB_go_firstl && LB_go_link && sleep 3
			ba_map
			ba_gohome || continue
		fi

		if greplog -o "Cup \[plus-ico.png\]" home.lxp ; then
			LB_go_firstl
			LB_search_link Mastery && LB_go_nextl 3 && LB_go_link && sleep 4
			LB_get_current_page cup_home.lxp
 # You are out of free tries!
 #   Price for the new try: [gold-ico.png] 5
			if ! greplog -i "You are out of" cup_home.lxp ; then
				if joinl="$(grep -o "(Submit) [A-Z][a-z]*" cup_home.lxp | grep -n Join | grep -o "^[0-9]*")" ; then
					LB_go_nextl $((joinl-1))
					LB_go_link && sleep $((RANDOM%2+1))
					ba_cup
				else
					# Maybe Already joined
					ba_cup
				fi
			fi
			ba_gohome || continue
		fi

		if ((nrjmax-nrj<5)) ; then # make a fight in the arena
			LB_go_firstl
			LB_go_nextl && LB_go_link && sleep $((RANDOM%2+1))
			ba_arena
			ba_gohome || continue
		fi
		
		time1=$(date +"%s")
		#((tosleep= ( time1-time0 < 300 ? 300-(time1-time0) : 0 )+RANDOM%(baModSleep+1) )) # at least 5 min
		(( tosleep=300+RANDOM%1500 )) # from 5 to 30 mins.
		if ((tosleep+time1>baMineEnd && baMineEnd>=(time0-20) )) ; then
			((tosleep= ( baMineEnd-time1 > 0 ? baMineEnd-time1 : 1 ) ))
		fi
		if ((tosleep+time1>baClanJobEnd && baClanJobEnd>=time0 )) ; then
			((tosleep= ( baClanJobEnd-time1 > 0 ? baClanJobEnd-time1 : 1 ) ))
		fi
		echolog -e "... ($tosleep s.)\n"
		sleep $tosleep 
	done
}

function ba_gohome {
	local try=3

	while ((try--)) ; do
		LB_get_current_page current
		# just to display that 1-day page
		grep "chest-locked.png" current > /dev/null && echolog "ba_gohome: chest-locked.png"
		LB_go_firstl
		grep "All you should know: protection," current > /dev/null && cp -f current home.lxp && return
		# to grep previous string means we are in our home page
		LB_go_link
		sleep 2
	done
	echolog "ba_gohome error: unexpected page"
	cp -vf current unexpected_home
	return 9
}

mkdir -p logs || exit 1
function echolog {
    ( echo -n "$(date +"%T"): " ; 
	  echo "$@" ) | tee -a "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt"
}

function greplog {
	local echoret
	if echoret="$(grep "$@")" ; then
    	echo "$(date +"%T"): grep: $echoret" | tee -a "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt"
	else
		return $?
	fi
}

function ba_arena {
	local masteries ref i g
	local baMastery="$(sed -n ' s,.*mastery-ico.png. *\([0-9]\+\).*,\1,p ' home.lxp)"

	#echo arena right
	LB_get_current_page arena.lxp
	LB_go_firstl
	while LB_search_link "arrow-right" ; do
		LB_go_link && sleep $((RANDOM%2+1))
		LB_get_current_page arena.lxp
		greplog Room arena.lxp
		LB_go_firstl
	done
	# we parse reversly as we will use LB_go_previoul
	masteries=($(sed -n 's,.*mastery-ico.png\] \([0-9]\+\).*,\1,p' arena.lxp | tac ) )
	# reverse order of lines (emulates "tac") :
	#  sed '1!G;h;$!d'               # method 1
	#  sed -n '1!G;h;$p'             # method 2
	if ! ((masteries[0])) ; then
		echolog "ba_arena warning: unexpected arena"
		cp -fv arena.lxp unexpected_arena.lxp
		return 9
	fi
	# search weakest opponent
	((ref=masteries[0]))
	for i in "${!masteries[@]}" ; do
		((masteries[$i]<=ref)) && ((ref=masteries[$i])) && g=$i
	done
	echolog " arena: $baMastery vs ${masteries[@]} => ${masteries[$g]} ($g)"

	LB_go_lastl
	if ((masteries[$g]>baMastery)) && ! [ "$1" ] ; then
		echolog "refreshing arena..."
		LB_go_previousl ; LB_go_link
		sleep $((RANDOM%8+5))
		ba_arena "norefresh"
	else
		if ((masteries[1])) ; then
			LB_go_previousl $((3+2*g))
		else
			# If there is only one opponent, "Attack all"
			LB_go_previousl $((2))
		fi
		LB_go_link && sleep $((RANDOM%2+1))
		LB_get_current_page arena_result.lxp
		if ! greplog "Experience" arena_result.lxp ; then
			echolog "ba_arena warning: unexpected result"
			cp -fv arena_result.lxp unexpected_arena_result.lxp
			return 9
		else
		    # Display who defeated us
			greplog -B1 Alive arena_result.lxp
			# refresh arena
			#LB_go_firstl ; LB_go_nextl ; LB_go_link ; sleep 2
			#LB_go_lastl ; LB_go_previousl ; LB_go_link ; sleep 3
		fi
	fi
}

function ba_clanjob {
	local clanchat tosleep
	
	LB_get_current_page clan_home.lxp

	if ! clanchat="$(grep -A5 "Clan chat " clan_home.lxp)" ; then
		echolog "ba_clanjob warning: unexpected clan's home"
		cp -fv clan_home.lxp unexpected_clan_home.lxp
		return 9
	fi
	echolog -e "Clan chat:\n $(echo "$clanchat" | grep ":")"
	LB_go_nextl 10 ; LB_go_link ; sleep $((RANDOM%2+1))
	LB_get_current_source clan_job.html ; sleep 1
	tosleep=$(sed -n ' s_.*CreateTimer( *[0-9]\+, *\([0-9]\+\).*_\1_p' clan_job.html)
	#if clanchat="$(greplog "CreateTimer" clan_job.html)" ; then
	if ((tosleep)) ; then
		((baClanJobEnd=$(date +"%s")+tosleep))
		echolog "clan job: $tosleep seconds more (end at $baClanJobEnd)"
	elif greplog -o -m1 ">Start<" clan_job.html ; then
		LB_go_lastl
		LB_go_previousl 2
		LB_go_link
	elif greplog -o ">Complete<" clan_job.html ; then
		LB_go_firstl
		LB_go_nextl 4
		LB_go_link
		sleep $((RANDOM%2+3))
		LB_go_lastl
		LB_go_previousl 2
		LB_go_link
	else
		echolog "ba_clanjob warning: unexpected job page"
		cp -fv clan_job.html unexpected_clan_job.html
		return 9
	fi
	sleep $((RANDOM%2+1))
}

function ba_cup {
	local reflife lifes result i

	while ((nrj>4)) ; do
		LB_get_current_page cup_opponent ; sleep $((RANDOM%2+1))
		lifes=($(sed -n 's,.*hp-ico.png\] \([0-9]\+\).*,\1,p' cup_opponent))
		((reflife=lifes[0]*3/4))
		printf "%5d "  ${lifes[1]}
		i=1
		# Search a weakest opponent
		while ((${lifes[1]})) && ((${lifes[1]}>reflife)) ; do
			LB_go_nextl 4 ; LB_go_link
			LB_get_current_page cup_opponent ; sleep $((RANDOM%2+1))
			lifes=($(sed -n 's,.*hp-ico.png\] \([0-9]\+\).*,\1,p' cup_opponent))
			((reflife+=RANDOM%(${baCupWins:=1}*3/2+1)))
			printf "%5d "  ${lifes[1]}
			((i++))
		done
		echo "<= $reflife ($baCupWins)"
		if ! ((${lifes[1]})) ; then 
			echolog "ba_cup warning: unexpected opponent"
			cp -fv cup_opponent unexpected_cup_opponent
			break
		fi
		# Fight
		LB_go_nextl 5 ; LB_go_link ; sleep $((RANDOM%2+1))
		LB_get_current_page cup_result
		# read left energy
		eval $(sed -n ' s,.*energy-ico.png. *\([0-9]\+\)/.*,nrj=\1,p ' cup_result)
		if result="$(grep -B1 Defeated cup_result)" ; then # Win !
			echolog $result "($((baCupWins++))|$i) nrj=$nrj"
			LB_go_link ; sleep $((RANDOM%2+1))
			continue
		elif result="$(grep -B1 Alive cup_result)" ; then # Lose
			echolog $result "($i) nrj=$nrj"
			baCupWins=1
			LB_go_nextl ; LB_go_link ; sleep $((RANDOM%2+1))
		else
			echolog "ba_cup warning: unexpected result"
			cp -fv cup_result unexpected_cup_result
		fi
		break
	done

	((nrj>4)) || echolog "ba_cup warning: energy low ($nrj)"
}

function ba_quests {
	LB_get_current_page quests.lxp
	while grep "A great deal" >/dev/null quests.lxp ; do
			echolog "$(grep -B5 -m1 "\(v-ico.png\|quest-ico.png\|back-ico.png\)" quests.lxp |  tr -d '\n')"
			LB_go_nextl 4 ; LB_go_link ; sleep $((RANDOM%2+1))
			LB_get_current_page quests.lxp
	done
}

function ba_map {
	LB_get_current_page map.lxp
	if grep "Mine \[plus-ico.png\]" map.lxp >/dev/null ; then
		# There is someting to click in
		LB_go_firstl
		LB_go_nextl 7
		LB_go_link
		sleep $((RANDOM%2+1))
		LB_get_current_page mine.lxp
		#if grep "In the mine, you can obtain the stones" mine
		if greplog "mine-ico.png.*Mining" mine.lxp ; then
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			((baMineEnd=$(date +"%s")+2400)) # 40 min
		elif greplog "bag-ico.png.*Take" mine.lxp ; then
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			sleep $((RANDOM%2+2))
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			((baMineEnd=$(date +"%s")+300)) # 5 min
		elif greplog "find-ico.png.*Search" mine.lxp ; then
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			((baMineEnd=$(date +"%s")+300)) # 5 min
		else
			echolog "ba_map warning: unexpected mine"
			cp -fv mine.lxp unexpected_mine.lxp
			return 9
		fi
		echolog $(grep "^               [^ ]" mine.lxp | tr -d '\n')
		sleep $((RANDOM%2+1))

		if grep "You can attack the Banker" map.lxp >/dev/null && ! grep "Banker Fight" "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null ; then
			LB_go_firstl && LB_go_nextl && LB_go_link && sleep 3
		#if ! grep "Banker attacked ....." "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null ; then
			#TODO
			LB_go_lastl ; sleep 1
			if LB_search_link -8 more ; then
				LB_go_link ; sleep $((RANDOM%2+1))
				LB_get_current_page banker.lxp
				if grep "Banker's knife" banker.lxp >/dev/null ; then
					LB_go_nextl 5 && LB_go_link && sleep $((RANDOM%2+1))
					echolog "Banker Fight ..."
					LB_get_current_page banker_result.lxp
					if ! greplog -A1 "Damage taken:" banker_result.lxp ; then
						echolog "ba_map warning: unexpected banker_result"
						cp -fv banker_result.lxp unexpected_banker_result.lxp
					fi
				else
						echolog "ba_map warning: unexpected banker"
						cp -fv banker.lxp unexpected_banker.lxp
				fi
			else
				echolog "ba_map warning: cannot find how to attack the banker"
			fi
		fi
	fi
}

