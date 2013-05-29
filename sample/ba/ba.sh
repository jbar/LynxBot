#!/bin/bash

#BA_PASSWD=""

. /usr/local/lib/lynxbot/init_lynxbot
LB_startlynxbot

#set -x

mkdir -p rsc || exit 1
mkdir -p logs || exit 1
function echolog {
    ( echo -n "$(date +"%T"): " ; 
	  echo "$@" ) | tee -a "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt"
}

function greplog {
	local echoret
	if echoret="$(grep "$@")" ; then
    	echo "$(date +"%T"):  grep -> $echoret" | tee -a "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt"
	else
		return $?
	fi
}

function ba_login {
	baPlayer="${1:-$baPlayer}"
	export baPlayer
	local passwd="${2:-$BA_PASSWD}" tosleep maxtry=2
	if [ -z "$baPlayer" ] || [ -z "$passwd" ] ; then
		echo "usage: ba_login PLAYER [PASSWD]"
		return 9
	fi
	LB_get_current_info rsc/current_info
	LB_go_to_url "http://arena.softgames.de"
	if grep -i "arena.softgames.de/arena/SgGateway" rsc/current_info > /dev/null ; then
		LB_refresh_page
		ba_gohome
	fi
	sleep 5
	LB_get_current_page rsc/current.lxp
	LB_go_firstl
	while ! grep "All you should know: protection," rsc/current.lxp >/dev/null ; do
	# while se are not in the Home page of the game	
		if greplog "chest-locked.png" rsc/current.lxp ; then
			# Already logged and the 1 day page to get money
			LB_go_firstl
			LB_go_link
			sleep 2
		elif greplog "SOFTGAMES Account" rsc/current.lxp ; then
			LB_go_firstl ; LB_go_nextl ; LB_go_link
			sleep 4
			if LB_go_firstl && LB_write_string "$baPlayer" && LB_go_nextl && LB_write_string "$passwd" ; then
				LB_go_nextl ; LB_go_link
			else
				((tosleep=5+RANDOM%25)) # 30 sec max
				echolog "ba_login warning: unexpected entry field ... ($tosleep sec.)"
				cp -vf rsc/current.lxp rsc/unexpected_login.lxp
				LB_go_to_url "http://arena.softgames.de"
				sleep $tosleep
			fi
			sleep 4
		else
			if ((maxtry--)) ; then
				echolog "ba_login error: unexpected page ... (exiting)"
				return 9
			fi
			((tosleep=5+RANDOM%600)) # 10 min max
			echolog "ba_login warning: unexpected page ... ($tosleep sec.)($maxtry)"
			cp -vf rsc/current.lxp rsc/unexpected_login.lxp
			sleep $tosleep 
			LB_go_to_url "http://arena.softgames.de"
			sleep 5
		fi
		LB_get_current_page rsc/current.lxp
	done
	cp -vf rsc/current.lxp rsc/home.lxp
	status="$(grep -A 2 energy-ico.png rsc/current.lxp | tr -d '\n ')"
#	eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9/]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrgratio=$((100*\3)) coins=\4 crystals=\5, ' )
	eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9]\+\)/\([0-9]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrj=\3 nrjmax=\4 coins=\5 crystals=\6, ' )
	echolog "$baPlayer: lvl=$lvl($lvlratio%) nrj=$nrj/$nrjmax coins=$coins crystals=$crystals"
}

function ba_all {
# usage: ba_all [minutes] [player] [passwd]

	if [[ "$1" =~ ^[0-9]+$ ]] ; then 
		((baAllEnd=$(date +"%s")+$1*60))
		shift
	else
		baAllEnd=0
	fi
	baPlayer="${1:-$baPlayer}"
	export baPlayer

	local time0 time1 tosleep h hcup
	local passwd="${2:-$BA_PASSWD}"

	if ! [ "$passwd" ] ; then
		read -s -t 60 -p "Password ? " passwd
		echo
	fi



	while true ; do
		ba_login "$baPlayer" "$passwd" || return 9

		time0=$(date +"%s")
		h=$(date +"%H")

		if ((baClanJobEnd<time0)) && LB_search_link "My clan" ; then
			LB_go_link && sleep 3
			ba_clanjob
			ba_gohome || continue
		fi

		if greplog "Quests \[plus-ico.png\]" rsc/home.lxp ; then
			LB_go_firstl
			LB_search_link Mastery && LB_go_nextl && LB_go_link && sleep $((RANDOM%2+1))
			ba_quests
		fi

		if greplog "(Submit) Map \[plus-ico.png\]" rsc/home.lxp ; then
			LB_go_firstl && LB_go_link && sleep 3
			ba_map
			ba_gohome || continue
		fi

		if greplog -o "Cup \[plus-ico.png\]" rsc/home.lxp || [[ $h != $hcup ]] ; then
			hcup=$h
			LB_go_firstl
			LB_search_link Mastery && LB_go_nextl 3 && LB_go_link && sleep 4
			LB_get_current_page rsc/cup_home.lxp
 # You are out of free tries!
 #   Price for the new try: [gold-ico.png] 5
			if ! greplog -i "\(You are out of\|There are no active cups in the moment\)" rsc/cup_home.lxp ; then
				if joinl="$(grep -o "(Submit) [A-Z][a-z]*" rsc/cup_home.lxp | grep -n Join | grep -o "^[0-9]*")" ; then
					LB_go_nextl $((joinl-1))
					LB_go_link && sleep $((RANDOM%2+1))
					ba_cup
				elif greplog "Left [1-9]" rsc/cup_home.lxp && joinl="$(grep -o "(Submit) [A-Z][a-z]*" rsc/cup_home.lxp | grep -n "Register\>" | grep -o "^[0-9]*")" ; then
					LB_go_nextl $((joinl-1))
					LB_go_link && sleep $((RANDOM%2+1))
					continue
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

		if ((tosleep+time1>baAllEnd && baAllEnd )) ; then
			if (( baAllEnd-time1 > 0 )) ; then
				((tosleep=baAllEnd-time1))
			else
				break
			fi
		fi
		if ((tosleep+time1>baMineEnd && baMineEnd>=(time0-30) )) ; then
			((tosleep= ( baMineEnd-time1 > 0 ? baMineEnd-time1 : 1 ) ))
		fi
		if ((tosleep+time1>baClanJobEnd && baClanJobEnd>=time0 )) ; then
			((tosleep= ( baClanJobEnd-time1 > 0 ? baClanJobEnd-time1 : 1 ) ))
		fi
		echolog -e "... ($tosleep s.)\n"
		sleep $tosleep 
	done

	echolog "ba_all $1 $baPlayer Terminating."
}

function ba_gohome {
	local try=3
	#LB_go_previouspage
	#sleep 1

	while ((try--)) ; do
		LB_get_current_page rsc/current.lxp
		# just to display that 1-day page
		grep "chest-locked.png" rsc/current.lxp > /dev/null && echolog "ba_gohome: chest-locked.png"
		LB_go_firstl
		grep "All you should know: protection," rsc/current.lxp > /dev/null && cp -f rsc/current.lxp rsc/home.lxp && return
		# to grep previous string means we are in our home page
		LB_go_link
		sleep 2
	done
	echolog "ba_gohome error: unexpected page"
	cp -vf rsc/current.lxp rsc/unexpected_home.lxp
	LB_get_current_source rsc/unexpected_home.html
	return 9
}

function ba_arena {
	local masteries ref i g
	local baMastery="$(sed -n ' s,.*mastery-ico.png. *\([0-9]\+\).*,\1,p ' rsc/home.lxp)"

	#echo arena right
	LB_get_current_page rsc/arena.lxp
	LB_go_firstl
	while LB_search_link "arrow-right" ; do
		LB_go_link && sleep $((RANDOM%2+1))
		LB_get_current_page rsc/arena.lxp
		greplog Room rsc/arena.lxp
		LB_go_firstl
	done
	# we parse reversly as we will use LB_go_previoul
	masteries=($(sed -n 's,.*mastery-ico.png\] \([0-9]\+\).*,\1,p' rsc/arena.lxp | tac ) )
	# reverse order of lines (emulates "tac") :
	#  sed '1!G;h;$!d'               # method 1
	#  sed -n '1!G;h;$p'             # method 2
	if ! ((masteries[0])) ; then
		echolog "ba_arena warning: unexpected arena"
		cp -fv rsc/arena.lxp rsc/unexpected_arena.lxp
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
		LB_get_current_page rsc/arena_result.lxp
		if ! greplog "Experience" rsc/arena_result.lxp ; then
			echolog "ba_arena warning: unexpected result"
			cp -fv rsc/arena_result.lxp rsc/unexpected_arena_result.lxp
			return 9
		elif greplog -B1 Alive rsc/arena_result.lxp ; then # Display who defeated us
			# refresh arena
			LB_go_firstl ; LB_go_nextl ; LB_go_link ; sleep 2
			LB_go_lastl ; LB_go_previousl ; LB_go_link ; sleep 3
		fi
	fi
}

function ba_clanjob {
	local clanchat tosleep
	
	LB_get_current_page rsc/clan_home.lxp

	if ! clanchat="$(grep -A5 "Clan chat " rsc/clan_home.lxp)" ; then
		echolog "ba_clanjob warning: unexpected clan's home"
		cp -fv rsc/clan_home.lxp rsc/unexpected_clan_home.lxp
		return 9
	fi
	echolog -e "Clan chat:\n $(echo "$clanchat" | grep ":")"
	LB_go_nextl 10 ; LB_go_link ; sleep $((RANDOM%2+1))
	LB_get_current_source rsc/clan_job.html ; sleep 1
	tosleep=$(sed -n ' s_.*CreateTimer( *[0-9]\+, *\([0-9]\+\).*_\1_p' rsc/clan_job.html)
	#if clanchat="$(greplog "CreateTimer" rsc/clan_job.html)" ; then
	if ((tosleep)) ; then
		((baClanJobEnd=$(date +"%s")+tosleep))
		echolog "clan job: $tosleep seconds more (end at $baClanJobEnd)"
	elif greplog -o -m1 ">Start<" rsc/clan_job.html ; then
		LB_go_lastl
		LB_go_previousl 2
		LB_go_link
	elif greplog -o ">Complete<" rsc/clan_job.html ; then
		LB_go_firstl
		LB_go_nextl 4
		LB_go_link
		sleep $((RANDOM%2+3))
		LB_go_lastl
		LB_go_previousl 2
		LB_go_link
	else
		echolog "ba_clanjob warning: unexpected job page"
		cp -fv rsc/clan_job.html rsc/unexpected_clan_job.html
		return 9
	fi
	sleep $((RANDOM%2+1))
}

function ba_cup {
	local reflife lifes result i

	while ((nrj>4)) ; do
		LB_get_current_page rsc/cup_opponent.lxp ; sleep $((RANDOM%2+1))
		lifes=($(sed -n 's,.*hp-ico.png\] \([0-9]\+\).*,\1,p' rsc/cup_opponent.lxp))
		((reflife=lifes[0]*3/4))
		printf "%5d "  ${lifes[1]}
		i=1
		# Search a weakest opponent
		while ((${lifes[1]})) && ((${lifes[1]}>reflife)) ; do
			LB_go_nextl 4 ; LB_go_link
			LB_get_current_page rsc/cup_opponent.lxp ; sleep $((RANDOM%2+1))
			lifes=($(sed -n 's,.*hp-ico.png\] \([0-9]\+\).*,\1,p' rsc/cup_opponent.lxp))
			((reflife+=RANDOM%(${baCupWins:=1}*3/2+1)))
			printf "%5d "  ${lifes[1]}
			((i++))
		done
		echo "<= $reflife ($baCupWins)"
		if ! ((${lifes[1]})) ; then 
			echolog "ba_cup warning: unexpected opponent"
			cp -fv rsc/cup_opponent.lxp rsc/unexpected_cup_opponent.lxp

			break
		fi
		# Fight
		LB_go_nextl 5 ; LB_go_link ; sleep $((RANDOM%2+1))
		LB_get_current_page rsc/cup_result.lxp
		# read left energy
		eval $(sed -n ' s,.*energy-ico.png. *\([0-9]\+\)/.*,nrj=\1,p ' rsc/cup_result.lxp)
		if result="$(grep -B1 Defeated rsc/cup_result.lxp)" ; then # Win !
			echolog $result "($((baCupWins++))|$i) nrj=$nrj"
			LB_go_link ; sleep $((RANDOM%2+1))
			continue
		elif result="$(grep -B1 Alive rsc/cup_result.lxp)" ; then # Lose
			echolog $result "($i) nrj=$nrj"
			baCupWins=1
			LB_go_nextl ; LB_go_link ; sleep $((RANDOM%2+1))
		else
			echolog "ba_cup warning: unexpected result"
			cp -fv rsc/cup_result.lxp rsc/unexpected_cup_result.lxp
		fi
		break
	done

	((nrj>4)) || echolog "ba_cup warning: energy low ($nrj)"
}

function ba_quests {
	LB_get_current_page rsc/quests.lxp
	while grep "A great deal" >/dev/null rsc/quests.lxp ; do
			echolog "$(grep -B5 -m1 "\(v-ico.png\|quest-ico.png\|back-ico.png\)" rsc/quests.lxp |  tr -d '\n')"
			LB_go_nextl 4 ; LB_go_link ; sleep $((RANDOM%2+1))
			LB_get_current_page rsc/quests.lxp
	done
}

function ba_map {
	LB_get_current_page rsc/map.lxp
	if grep "Mine \[plus-ico.png\]" rsc/map.lxp >/dev/null ; then
		# There is someting to click in
		LB_go_firstl
		LB_go_nextl 7
		LB_go_link
		sleep $((RANDOM%2+1))
		LB_get_current_page rsc/mine.lxp
		#if grep "In the mine, you can obtain the stones" mine
		if greplog "mine-ico.png.*Mining" rsc/mine.lxp ; then
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			((baMineEnd=$(date +"%s")+2400)) # 40 min
		elif greplog "bag-ico.png.*Take" rsc/mine.lxp ; then
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			sleep $((RANDOM%2+2))
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			((baMineEnd=$(date +"%s")+300)) # 5 min
		elif greplog "find-ico.png.*Search" rsc/mine.lxp ; then
			LB_go_firstl
			LB_go_nextl 4
			LB_go_link
			((baMineEnd=$(date +"%s")+300)) # 5 min
		else
			echolog "ba_map warning: unexpected mine"
			cp -fv rsc/mine.lxp rsc/unexpected_mine.lxp
			return 9
		fi
		echolog $(grep "^               [^ ]" rsc/mine.lxp | tr -d '\n')
		sleep $((RANDOM%2+1))

		if grep "You can attack the Banker" rsc/map.lxp >/dev/null && ! grep "Banker Fight" "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null ; then
			LB_go_firstl && LB_go_nextl && LB_go_link && sleep 3
		#if ! grep "Banker attacked ....." "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null ; then
			#TODO
			LB_go_lastl ; sleep 1
			if LB_search_link -8 more ; then
				LB_go_link ; sleep $((RANDOM%2+1))
				LB_get_current_page rsc/banker.lxp
				if grep "Banker's knife" rsc/banker.lxp >/dev/null ; then
					LB_go_nextl 5 && LB_go_link && sleep $((RANDOM%2+1))
					echolog "Banker Fight ..."
					LB_get_current_page rsc/banker_result.lxp
					if ! greplog -A1 "Damage taken:" rsc/banker_result.lxp ; then
						echolog "ba_map warning: unexpected banker_result"
						cp -fv rsc/banker_result.lxp rsc/unexpected_banker_result.lxp
					fi
				else
						echolog "ba_map warning: unexpected banker"
						cp -fv rsc/banker.lxp rsc/unexpected_banker.lxp
				fi
			else
				echolog "ba_map warning: cannot find how to attack the banker"
			fi
		fi
	fi
}

