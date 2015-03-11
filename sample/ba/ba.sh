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
	local passwd="${2:-$BA_PASSWD}" tosleep maxtry=4
	if [ -z "$baPlayer" ] || [ -z "$passwd" ] ; then
		echo "usage: ba_login PLAYER [PASSWD]"
		return 9
	fi
	LB_get_current_info rsc/current_info
	LB_go_to_url "http://arena.softgames.de/arena/SgGateway"
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
				((maxtry-- <= 0)) && echolog "ba_login error: entry field ... (exiting)" && return 9
				((tosleep=5+RANDOM%25)) # 30 sec max
				echolog "ba_login warning: unexpected entry field ... ($tosleep sec.)($maxtry)"
				cp -vf rsc/current.lxp rsc/unexpected_login.lxp
				LB_go_to_url "http://arena.softgames.de/arena/SgGateway"
				sleep $tosleep
			fi
			sleep 4
		else
			((maxtry-- <= 0)) && echolog "ba_login error: unexpected page ... (exiting)" && return 9
			((tosleep=5+RANDOM%900)) # 15 min max
			echolog "ba_login warning: unexpected page ... ($tosleep sec.)($maxtry)"
			cp -vf rsc/current.lxp rsc/unexpected_login.lxp
			sleep $tosleep 
			LB_go_to_url "http://arena.softgames.de/arena/SgGateway"
			sleep 5
		fi
		LB_get_current_page rsc/current.lxp
	done
	cp -vf rsc/current.lxp rsc/home.lxp
	status="$(grep -A 2 energy-ico.png rsc/current.lxp | tr -d '\n ')"
#	eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9/]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrgratio=$((100*\3)) coins=\4 crystals=\5, ' )
# Lvl.59(43%)[energy-ico.png]74/100[money-ico.png]112384[gold-ico.png]290
# Lvl.80/16%[energy-ico.png]100^/100[mastery-ico.png]43202[money-ico.png]133337[gold-ico.png]210
	eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)/\([0-9]\+\)%.energy-ico.png.\([0-9]\+\)./\([0-9]\+\).mastery-ico.png.\([0-9]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrj=\3 nrjmax=\4 mastery=\5 coins=\6 crystals=\7, ' )
	echolog "$baPlayer -> lvl=$lvl($lvlratio%) nrj=$nrj/$nrjmax mastery=$mastery coins=$coins crystals=$crystals"
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

	local time0 time1 tosleep mailstatus h hcup leftcup
	local passwd="${2:-$BA_PASSWD}"

	if ! [ "$passwd" ] ; then
		read -s -t 60 -p "Password ? " passwd
		echo
	fi



	while true ; do
		ba_login "$baPlayer" "$passwd" || return 9

		time0=$(date +"%s")
		h=$(date +"%H")

		grep -C1 " +$" rsc/home.lxp > rsc/todo

		if greplog -i "Quest" rsc/todo ; then
			LB_go_firstl
			LB_search_link Mastery && LB_go_nextl && LB_go_link && sleep $((RANDOM%2+1))
			ba_quests
			ba_gohome || continue
		fi

		#if greplog -i "\<Map\>" rsc/todo || [[ $h == 09 ]] ; then # Don't forget to attack the banker
		if greplog -i "\<Map\>" rsc/todo || [[ $h == 08 ]] ; then # Don't forget to attack the banker
			LB_go_firstl && LB_go_nextl && LB_go_link && sleep 3
			ba_map
			ba_gohome || continue
		fi

		if greplog -i "Mail \[[0-9]" rsc/home.lxp ; then
			if ((mailstatus==0)) ; then
				mailstatus=1
				#sendmail...
			fi
		else
			mailstatus=0
		fi

		if greplog -o -i "tournament" rsc/todo || [[ $h != $hcup ]] ; then
		if ! ((baNoCup)) ; then
			hcup=$h
			LB_go_firstl
			LB_search_link Mastery && LB_go_nextl 3 && LB_go_link ; sleep 5
			LB_get_current_page rsc/cup_home.lxp
 # You are out of free tries!
 #   Price for the new try: [gold-ico.png] 5
			if greplog -i "\(You are out of\|There are no active cups in the moment\)" rsc/cup_home.lxp ; then
				baCupEnd=0
				echo -n > rsc/to_avoid_in_cup
			else
				if joinl="$(grep -o "(\(Submit\|BUTTON\)) [A-Z][a-z]*" rsc/cup_home.lxp | grep -n Join | grep -o -m1 "^[0-9]*" )" ; then
					baCupEnd="$(($(date +"%s")+$(sed -n " s,.*eft \+\(\([0-9]\+\) *h. \)*\(\([0-9]\+\) *m. \)*\([0-9]\+\) *s.*,(\2+0)*3600+(\4+0)*60+\5,p " rsc/cup_home.lxp | head -1 )-50 ))" || baCupEnd=$((time0+590))
					cp rsc/cup_home.lxp rsc/cup_home_join.lxp
					if ((nrj<35)) ; then
						echolog "energy is too low to try cup again ($nrj)"
					elif ((time0>baCupEnd-300)) ; then
						echolog "not enough time to try cup again ($((baCupEnd-time0)) sec.)"
						baCupEnd=0
					else
						greplog "eft [1-9]" rsc/cup_home.lxp
						LB_go_nextl $((joinl-1))
						LB_go_link && sleep $((RANDOM%2+1))
						ba_cup
					fi
				elif greplog "\<Registered\>" rsc/cup_home.lxp && greplog -m1 "Start in" rsc/cup_home.lxp ; then
					# Do nothing
					true 
				elif leftcup="$(greplog -B1 "Left [1-9]" rsc/cup_home.lxp)" && joinl="$(grep -o "(\(Submit\|BUTTON\)) [A-Z][a-z]*" rsc/cup_home.lxp | grep -n "Register\>" | grep -o -m1 "^[0-9]*")" ; then
					echo "$leftcup"
					#joinl=${joinl##*0}
					if ((baCupAutoRegister)) && ((nrj>30)) ; then
						if ! echo "$leftcup" | grep "Tournament *(8 Lvl. - 90 Lvl.)" ; then
							LB_go_nextl $((joinl-1))
							LB_go_link && sleep $((RANDOM%2+1))
							continue
						fi
					fi
				else
					# Maybe Already joined
						ba_cup
				fi
			fi
			ba_gohome || continue
		fi
		fi

		if [[ "$baDonjon" ]] && ((nrj>5)) && ! grep "Donjon completed" "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null ; then
			if ((nrjmax-nrj<6)) || ((time0<baDonjonEnd)) ; then # make or finish a donjon
				LB_search_link Mastery && LB_go_nextl 5 && LB_go_link
				#set -x
				ba_donjon "${baDonjon[@]}"
				ba_gohome || continue
			fi
		fi

		if ((nrjmax-nrj<6)) && [[ "$baClanAttack" ]] ; then # attack the specified clan
			LB_search_link Mastery && LB_go_nextl 6 && LB_go_link
			ba_clanattack "${baClanAttack[@]}"
			ba_gohome || continue
		fi

		if ((baClanJobEnd<time0)) && LB_search_link 24 "My clan" ; then
			LB_go_link && sleep 3
			ba_clanjob
			ba_gohome || continue
		elif (( time0 > baClanJobEnd-3600 )) ; then
			echolog " ... $((baClanJobEnd-time0)) s. left before Clan's Job's End."
		fi

		while ((nrj>nrjmax-6)) && ! ((baNoArena)) ; do # make a fight in the arena
			LB_go_firstl
			LB_go_nextl 2 && LB_go_link && sleep $((RANDOM%2+1))
			ba_arena
			((nrj-=10))
			ba_gohome || break
			#status="$(grep -A 2 energy-ico.png rsc/current.lxp | tr -d '\n ')"
			#eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9]\+\)./\([0-9]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\),lvl=\1 lvlratio=\2 nrj=\3 nrjmax=\4 coins=\5 crystals=\6, ' ) 2>&1 | tee -a "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" 
		done

		time1=$(date +"%s")

		#((tosleep= ( time1-time0 < 300 ? 300-(time1-time0) : 0 )+RANDOM%(baModSleep+1) )) # at least 5 min
		if [[ $h == 07 ]] && (($(date +"%-M")>29)) ; then
		#if [[ $h == 08 ]] && (($(date +"%-M")>29)) ; then
			(( tosleep=120+RANDOM%180 )) # from 2 to 3 mins, don't miss the banker !
		else
			(( tosleep=300+RANDOM%900 )) # from 5 to 15 mins.
		fi

		if ((tosleep+time1>baAllEnd && baAllEnd )) ; then
			if (( baAllEnd-time1 > 0 )) ; then
				((tosleep=baAllEnd-time1))
			else
				break
			fi
		fi
		if ((tosleep+time1>baMineEnd && baMineEnd>=(time0-60) )) ; then
			((tosleep= ( baMineEnd-time1 > 0 ? baMineEnd-time1 : 1 ) ))
		fi
		if ((tosleep+time1>baClanJobEnd && baClanJobEnd>=time0 )) ; then
			((tosleep= ( baClanJobEnd-time1 > 0 ? baClanJobEnd-time1 : 1 ) ))
		fi
		if ((tosleep+time1>baCupEnd && baCupEnd>=time0 )) ; then
			((tosleep= ( baCupEnd-time1 > 0 ? (baCupEnd-time1)/2 : 1 ) ))
		fi
		echolog -e "... ($tosleep s.)\n"
		sleep $tosleep 
	done

	echolog "ba_all $1 $baPlayer Terminating."
}

function ba_donjon_init {
	local n 

	LB_get_current_page rsc/donjon_list.lxp
	n=$( grep Level: rsc/donjon_list.lxp | sed -n "/$1/=" )
	if ((n)) ; then
		echolog "Donjon '$1' -> $n"
	else
		echolog "ba_donjon_init warning: Donjon '$1' not found (will try first)"
		n=1
	fi
	LB_go_firstl
	LB_go_nextl $((3+n)) ; LB_go_link ; sleep 1
}

function ba_donjon {
	local remain buttonposition i rurl
	local f missmin=$((${2:-0})) 

	LB_get_current_page rsc/donjon.lxp

	remain=$(sed -n ' s_.*emain: \([0-9]\+\)min.*_\1_p' rsc/donjon.lxp)

	if [[ -z "$remain" ]] ; then
		ba_donjon_init "$1" || return 9
		LB_get_current_page rsc/donjon.lxp
		remain=$(sed -n ' s_.*emain: \([0-9]\+\)min.*_\1_p' rsc/donjon.lxp)
	fi
	if [[ "$remain" ]] ; then
		((baDonjonEnd=$(date +"%s")+remain*60))
		echolog "ba_donjon: $remain min. more (end at $baDonjonEnd)"
	else
		echolog "ba_donjon warning: unexpected donjon"
		cp -fv rsc/donjon.lxp rsc/unexpected_donjon.lxp
		return 9
	fi

	# try to Invite friend (if needed)
	LB_go_lastl ; sleep 1
	LB_go_previousl 3 ; LB_go_link ; sleep 1
	LB_get_current_page rsc/donjon_start.lxp
	f=$( grep -c "freePlace.png" rsc/donjon_start.lxp )

	echolog "Donjon '$1' ->  freeplace: $f >= $missmin"

	while ((f>missmin)) ; do
		LB_go_lastl ; sleep 1
		LB_go_previousl 4 ; LB_go_link ; sleep 1
		LB_get_current_page rsc/donjon_flist.lxp
		if grep -c " ([0-9]\+)" rsc/donjon_flist.lxp ; then

			LB_go_lastl ; sleep 1
			LB_go_previousl 4 ; LB_go_link ; sleep 1
			LB_get_current_page rsc/donjon.lxp
			if ! grep -i "remain: [0-9]\+min" rsc/donjon.lxp  > /dev/null ; then
				echolog "ba_donjon warning: unexpected donjon"
				cp -fv rsc/donjon.lxp rsc/unexpected_donjon.lxp
				return 9
			fi

			LB_go_lastl ; sleep 1
			LB_go_previousl 3 ; LB_go_link ; sleep 1
			LB_get_current_page rsc/donjon_start.lxp
			f=$( grep -c "freePlace.png" rsc/donjon_start.lxp )
			echolog "Party: $(grep -B1 "astery:" rsc/donjon_start.lxp | tr -d '\n')"

		else
			echolog "ba_donjon warning: missing friends"
			#LB_go_lastl ; sleep 1
			#LB_go_previousl 3 ; LB_go_link ; sleep 1
			#LB_get_current_page rsc/donjon_start.lxp
			break;
		fi

	done

	# start
	LB_go_lastl ; sleep 1
	LB_go_previousl 3 ; LB_go_link ; sleep 1
	LB_get_current_page rsc/donjon.lxp
	if ! grep -i "remain: [0-9]\+min" rsc/donjon.lxp  > /dev/null ; then
		echolog "ba_donjon warning: unexpected donjon"
		cp -fv rsc/donjon.lxp rsc/unexpected_donjon.lxp
		return 9
	fi

	while true ; do
		buttonposition=0

		i=0
		while grep "ake reward" rsc/donjon.lxp > /dev/null && ((i++<4)) ; do
			echolog $(grep -B3 "ake reward" rsc/donjon.lxp | tr -d '\n')

			# they fucking use javascript, next 2 lines are now useless
			#LB_go_firstl ; sleep $((RANDOM%2))
			#LB_go_nextl 4 ; LB_go_link ; sleep 1

			LB_get_current_source rsc/donjon.html
			rurl="$( sed -n " s,.*window.location=[ '\"]\+\([^ '\"]\+\)[ '\"]\+.*ake reward.*,http://arena.softgames.de/arena/SgGateway\1,p " rsc/donjon.html )"
			if [[ "$rurl" ]] ; then 
				LB_go_to_url "$rurl"
				sleep 1
			else
				echolog "ba_donjon warning: unexpected reward"
				cp -fv rsc/donjon.html rsc/unexpected_donjon_reward.html
				return 9
			fi
			LB_get_current_page rsc/donjon.lxp
		done

		# To show what we can't take (no place in inventory)
		greplog -B2 "ake reward" rsc/donjon.lxp && buttonposition=1

		LB_go_firstl ; sleep 1

		if grep "\[arrow-right.*png" rsc/donjon.lxp > /dev/null ; then
			for ((i=0;i<3;i++)) ; do 
				LB_search_link 10 "arrow-right" && break
				LB_go_firstl ; sleep 1
			done
			LB_go_link ; sleep 1
			LB_get_current_page rsc/donjon.lxp
			continue
		elif greplog "(\(Submit\|BUTTON\)) \(Attack\|Open\)" rsc/donjon.lxp ; then
			if grep "\[arrow-left.*png" rsc/donjon.lxp > /dev/null ; then
				((buttonposition+=5))
			else
				((buttonposition+=4))
			fi

			# attack or open
			LB_go_firstl ; LB_go_nextl $buttonposition ; LB_go_link ; sleep 1

		#elif grep "^   Party$" rsc/donjon.lxp ; then # donjon should be ended
		elif grep "on is completed" rsc/donjon.lxp ; then # donjon ended
			echolog "Donjon completed !-)"
			break
		else
			echolog "ba_donjon warning: unexpected page"
			cp -fv rsc/donjon.lxp rsc/unexpected_donjon.lxp
			return 9
		fi

		if grep "(\(Submit\|BUTTON\)) Attack" rsc/donjon.lxp > /dev/null ; then
			LB_get_current_page rsc/donjon_result.lxp

			greplog -m1 Experience rsc/donjon_result.lxp
			# If there is no kill, give up the donjon
			if ! greplog -m1 -B1 "\<Defeated\>" rsc/donjon_result.lxp ; then
				echolog "Donjon completed :-("
				return 9
			fi

			while greplog -B1 "\<Alive\>" rsc/donjon_result.lxp ; do
				# first link is "Continue", second is "Attack"

				# attack !
				LB_go_firstl ; LB_go_nextl ; LB_go_link ; sleep 1
				LB_get_current_page rsc/donjon_result.lxp

				greplog -m1 Experience rsc/donjon_result.lxp
			done
			# first link is "Continue"
			LB_go_firstl ; LB_go_link ; sleep 1

			status="$(grep -A 2 energy-ico.png rsc/donjon.lxp | tr -d '\n ')"
			eval $(echo $status | sed ' s,Lvl.\([0-9]\+\)(\([0-9]\+\)%).energy-ico.png.\([0-9]\+\)./\([0-9]\+\).money-ico.png.\([0-9]\+\).gold-ico.png.\([0-9]\+\).*,lvl=\1 lvlratio=\2 nrj=\3 nrjmax=\4 coins=\5 crystals=\6, ' )
			echolog "$baPlayer: lvl=$lvl($lvlratio%) nrj=$nrj/$nrjmax coins=$coins crystals=$crystals"
			if ((nrj<7)) ; then
				echolog "ba_donjon warning: energy low ($nrj)"
				return 9
			fi
		fi
		LB_get_current_page rsc/donjon.lxp
	done
}

function ba_clanattack {
	LB_get_current_page rsc/clan_list.lxp
	if greplog "Search clan" rsc/clan_list.lxp && LB_search_linktype "entry field" && LB_write_string "$1" ; then
		sleep $((1+RANDOM%4)) && LB_go_nextl && LB_go_link
		LB_get_current_page rsc/clan_list.lxp
		[[ "$2" ]] && shift
		if LB_search_link -i "$1" ; then
			LB_go_link ; sleep 1
			LB_get_current_page "rsc/current.lxp"
			cp "rsc/current.lxp" "rsc/$1.lxp"
			LB_go_lastl ; sleep $((1+RANDOM%2))
			LB_go_previousl 4 && LB_go_link && sleep 1
			LB_get_current_page rsc/arena_result.lxp
			if ! greplog -m1 -B1 "clan-rating-ico" rsc/arena_result.lxp ; then
				echolog "ba_clanattack warning: unexpected result"
				cp -fv rsc/arena_result.lxp rsc/unexpected_clanattack_result.lxp
				return 9
			fi
			greplog -B1 Alive rsc/arena_result.lxp # Display who defeated us
			((nrj-=10))
		else
			echolog "ba_clanattack error: \"$1\" not found"
			cp -vf rsc/clan_list.lxp rsc/unexpected_clan_search_result.lxp
			return 9
		fi
	else
		echolog "ba_clanattack error: unexpected page"
		cp -vf rsc/clan_list.lxp rsc/unexpected_clan_list.lxp
		return 9
	fi
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
	local masteries ns=0 i j w

	LB_get_current_page rsc/arena.lxp

	greplog "League:" rsc/arena.lxp

	for ((j=0;;)) ; do 

		masteries=($(sed -n 's,.*mastery-ico.png\] \([0-9]\+\).*,\1,p' rsc/arena.lxp) )
		if ! ((masteries[1])) ; then
			echolog "ba_arena warning: unexpected arena"
			cp -fv rsc/arena.lxp rsc/unexpected_arena.lxp
			return 9
		fi

		# Count the number of too strong opponents and search the weakest opponents
		((refw=masteries[1]))
		ns=0
		for ((i=1;i<${#masteries[@]};i++)) ; do
			(( masteries[$i]> masteries[0]-450 )) && ((ns++))
			((masteries[$i]<=refw)) && ((refw=masteries[$i])) && w=$i
		done

		# OK
		((ns<2)) && (( masteries[$w] <= masteries[0]-450 )) && break

		(( j++ > 1+RANDOM%6)) && break

		echolog " arena: ${masteries[@]} => refreshing arena..."
		LB_go_lastl ; LB_go_previousl 3 ; LB_go_link
		sleep $((RANDOM%4+1))
		LB_get_current_page rsc/arena.lxp
	done

	LB_go_firstl
	echolog " arena: ${masteries[@]} => ${masteries[$w]} ($w)"
	LB_go_nextl $((3+2*w))
	LB_go_link && sleep $((RANDOM%2+1))
	LB_get_current_page rsc/arena_result.lxp
	if ! greplog "Experience" rsc/arena_result.lxp ; then
		echolog "ba_arena warning: unexpected result"
		cp -fv rsc/arena_result.lxp rsc/unexpected_arena_result.lxp
		return 9
	else
	   	greplog -B1 Alive rsc/arena_result.lxp # Display who defeated us
	fi
}

function ba_arena_1 {
	local masteries refs refw reftot i g s w
	local baMastery="$(sed -n ' s,.*mastery-ico.png. *\([0-9]\+\).*,\1,p ' rsc/home.lxp)"

	#echo arena right
	LB_get_current_page rsc/arena.lxp
	LB_go_firstl
	while LB_search_link 20 "arrow-right" ; do
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

	# Calculate average

	# search strongest and weakest opponents
	((refs=masteries[0]))
	((refw=masteries[0]))
	for i in "${!masteries[@]}" ; do
		((masteries[$i]>=refs)) && ((refs=masteries[$i])) && s=$i
		((masteries[$i]<=refw)) && ((refw=masteries[$i])) && w=$i
		((reftot+=masteries[$i]))
	done

	if ((masteries[$s]> baMastery*9/10)) ; then
	# the strongest have good chances to win a duel.
		if [ "$1" ] ; then 
			if ((masteries[1])) ; then
				# attack weakest opponent
				g=$w
			else
				# he is alone
				g=-1
			fi
		else
			echolog " arena: $baMastery vs ${masteries[@]} => refreshing arena..."
			LB_go_previousl 3 ; LB_go_link
			sleep $((RANDOM%8+5))
			ba_arena_1 "norefresh"
			return $?
		fi
	else
		case "${#masteries[@]}" in
			4)
				if ((reftot <= baMastery*7/3 )) ; then
				# if their average mastery is at most 7/12 of mine
					# attack all
					g=-1
				else
					# attack strongest
					g=$s
				fi
			;;
			3)
				if ((reftot <= baMastery*2 )) ; then
				# if their average mastery is at most 2/3 of mine
					# attack all
					g=-1
				else
					# attack strongest
					g=$s
				fi
			;;
			2)
				if ((reftot <= baMastery*3/2 )) ; then
				# if their average mastery is at most 3/4 of mine
					# attack all
					g=-1
				else
					# attack weakest
					g=$w
				fi
			;;
			1)
				# attack all
				g=-1
			;;
			*)
				echolog " arena: warning unexpected opponent number: ${#masteries[@]}"
				g=$s
			;;
		esac
	fi

	LB_go_lastl
	if ((g<0)) ; then
		echolog " arena: $baMastery vs ${masteries[@]} => * All * "
		LB_go_previousl $((3+1))
	else
		echolog " arena: $baMastery vs ${masteries[@]} => ${masteries[$g]} ($g)"
		LB_go_previousl $((4+2*g+1))
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
		LB_go_lastl ; LB_go_previousl 3 ; LB_go_link ; sleep 3
	fi
}

function ba_clanjob {
	local clanchat tosleep bonuscode
	
	LB_get_current_page rsc/clan_home.lxp

	#if ! clanchat="$(grep -A5 "Clan chat " rsc/clan_home.lxp)" ; then
	if ! clanchat="$(grep -C6 "Events log" rsc/clan_home.lxp)" ; then
		echolog "ba_clanjob warning: unexpected clan's home"
		cp -fv rsc/clan_home.lxp rsc/unexpected_clan_home.lxp
		return 9
	fi
	echolog -e "$clanchat"
	
	#bonuscode="$(sed -n ' s,.*[Cc][Oo][Dd][Ee].* \([A-Za-z0-1]\{6\}\)\>.*,\1,p ' rsc/clan_home.lxp | head -1 )"

	LB_go_nextl 10 ; LB_go_link ; sleep $((RANDOM%2+1))
	LB_get_current_source rsc/clan_job.html ; sleep 1
	tosleep=$(sed -n ' s_.*CreateTimer( *[0-9]\+, *\([0-9]\+\).*_\1_p' rsc/clan_job.html)
	#if clanchat="$(greplog "CreateTimer" rsc/clan_job.html)" ; then
	if ((tosleep)) ; then
		((baClanJobEnd=$(date +"%s")+tosleep))
		echolog "clan job: $tosleep seconds more (end at $baClanJobEnd)"
	elif greplog -o -m1 ">Start<" rsc/clan_job.html ; then
		local pl=$((2+(RANDOM%3+1)/2))
		LB_go_lastl
		LB_go_previousl $pl
		LB_go_link
		#LB_refresh_page
	elif greplog -o ">Complete<" rsc/clan_job.html ; then
		LB_go_firstl
		LB_go_nextl 4
		LB_go_link
		#LB_refresh_page
		LB_get_current_source rsc/clan_job.html
		sleep $((RANDOM%2+2))
		#local pl=$((4+(RANDOM)%2))
		local pl=$((6+(RANDOM%3+1)/2))
		while greplog -o -m1 ">Start<" rsc/clan_job.html ; do
			LB_go_lastl
			#LB_go_previousl $((4+(RANDOM%3)%2)) # chances: 0->66% 1->33%
			LB_go_previousl $pl
			LB_go_link
			LB_refresh_page
			LB_get_current_source rsc/clan_job.html
		done
	else
		echolog "ba_clanjob warning: unexpected job page"
		cp -fv rsc/clan_job.html rsc/unexpected_clan_job.html
		return 9
	fi
	sleep $((RANDOM%2+1))
}

function ba_cup {
	local reflife lifes result i j plife ennemy timec maxr

	while ((nrj>2)) ; do
		LB_get_current_page rsc/cup_opponent.lxp ; sleep $((RANDOM%2+1))
		lifes=($(sed -n 's,.*hp-ico.png\] \([0-9]\+\).*,\1,p' rsc/cup_opponent.lxp))
		((reflife=lifes[0]*(baCupRatio?baCupRatio:75)/100))
		printf "%5d "  ${lifes[1]}
		i=1
		j=-1
		plife=0
		timec=$(date +"%s")
		maxr=$((timec>= baCupEnd-40 ? 2 : 8))
		# Search a weakest opponent
		while ((${lifes[1]})) && ((${lifes[1]}>reflife)) && ((j<maxr)) ; do
			LB_go_nextl 4 ; LB_go_link ; sleep $((RANDOM%2+1))
			LB_get_current_page rsc/cup_opponent.lxp ; sleep $((RANDOM%2+1))
			lifes=($(sed -n 's,.*hp-ico.png\] \([0-9]\+\).*,\1,p' rsc/cup_opponent.lxp))
			baCupWins="$(sed -n ' s,.*ins: .*ico.png\] \([0-9]\+\),\1,p ' rsc/cup_opponent.lxp)"
			(( reflife+=RANDOM%(${baCupWins:=1}*2+4) ))
			#ennemy=$(grep -m1 -A2 stand_girl_1.png rsc/cup_opponent.lxp | tail -1 | tr -d " ")
			ennemy=$(grep -m1 -A2 stand_girl_1.png rsc/cup_opponent.lxp | sed -n 's, \+\([^[]\+\)$,\1,p ' )
			((i++))
			if grep "\<$ennemy$" rsc/to_avoid_in_cup >/dev/null ; then
				((lifes[1]=reflife*100))
				((j++))
			elif ((lifes[1]==plife)) ; then
				((j++))
			else
				plife=${lifes[1]}
				j=0
			fi
			printf "%6d $ennemy "  ${lifes[1]}
			
		done
		echo "<= $reflife ($baCupWins)"
		if ! ((${lifes[1]})) ; then
			if greplog "You lead " rsc/cup_opponent.lxp ; then
				if ((maxr>4)) ; then
					break
				else
					LB_go_nextl 4 ; LB_go_link ; sleep 1
					continue
				fi
			else
				echolog "ba_cup warning: unexpected opponent"
				cp -fv rsc/cup_opponent.lxp rsc/unexpected_cup_opponent.lxp
				break
			fi
		fi
		# Fight
		LB_go_nextl 5 ; LB_go_link ; sleep $((RANDOM%2+1))
		LB_get_current_page rsc/cup_result.lxp
		# read left energy
		eval $(sed -n ' s,.*energy-ico.png. *\([0-9]\+\).*,nrj=\1,p ' rsc/cup_result.lxp)
		if result="$(grep -B1 Defeated rsc/cup_result.lxp)" ; then # Win !
			echolog ${lifes[1]} $result "($((baCupWins++))|$i) nrj=$nrj $(grep -o ".honor-ico.png.*" rsc/cup_opponent.lxp)"
			LB_go_firstl
			LB_go_link ; sleep $((RANDOM%2+1))
			continue
		elif result="$(grep -B1 Alive rsc/cup_result.lxp)" ; then # Lose
			echo "$result" | sed -n 1p >> rsc/to_avoid_in_cup
			echolog ${lifes[1]} ${result} "($i) nrj=$nrj $(grep -o ".honor-ico.png.*" rsc/cup_opponent.lxp)"
			baCupWins=1
			LB_go_nextl ; LB_go_link ; sleep $((RANDOM%2+1))
		else
			echolog "ba_cup warning: unexpected result"
			cp -fv rsc/cup_result.lxp rsc/unexpected_cup_result.lxp
		fi
		break
	done

	((nrj>2)) || echolog "ba_cup warning: energy low ($nrj)"
}

function ba_quests {
	local quest xpquest=0
	LB_get_current_page rsc/quests.lxp
	#cp rsc/quests.lxp rsc/quests_debug.lxp
	#while grep "Big deal" >/dev/null rsc/quests.lxp ; do
	while (($(grep -c " \(Accept\|Complete\)$" rsc/quests.lxp) > xpquest ))  ; do
			#echolog "$(grep -B5 -m1 "\(v-ico.png\|quest-ico.png\|back-ico.png\)" rsc/quests.lxp |  tr -d '\n')"
			quest="$(grep -B6 -m1 " \(Accept\|Complete\)$" rsc/quests.lxp |  tr -d '\n')"
			if ((baNoXPQuest)) && ((! xpquest)) && echo "$quest" | grep "exp-ico.png"  >/dev/null ; then
				xpquest=1
				continue
			fi

			((xpquest)) && quest="$(grep -B5 -m2 " \(Accept\|Complete\)$" rsc/quests.lxp |  tr -d '\n')"

			echolog "$quest"
			LB_go_firstl ; LB_go_nextl $((4+xpquest))
			#LB_get_current_link | grep -i "Invite Friend" && break
			LB_go_link ; sleep $((RANDOM%2+1))
			LB_get_current_page rsc/quests.lxp
	done
}

function ba_map {
	LB_get_current_page rsc/map.lxp
	if grep -B1 " +$" rsc/map.lxp | grep -i Mine >/dev/null ; then
		# There is someting to click in
		LB_go_firstl
		LB_go_nextl 8
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
			echolog $(grep "^               [^ ]" rsc/mine.lxp | tr -d '\n')
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
		#echolog $(grep "^               [^ ]" rsc/mine.lxp | tr -d '\n')
		sleep $((RANDOM%2+1))
		LB_go_firstl && LB_go_nextl && LB_go_link && sleep 3
	fi

	if ! grep "Banker Fight" "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null && ((nrj>4)) && grep "You can attack the Banker" rsc/map.lxp >/dev/null ; then
	#if ! grep "Banker attacked ....." "logs/$(date +"%Y.%m.%d").$baPlayer.log.txt" >/dev/null ; then
		#TODO
		LB_go_lastl ; sleep 2
		if LB_search_link -8 more ; then
			LB_go_link ; sleep $((RANDOM%2+1))
			LB_get_current_page rsc/banker.lxp
			if grep -i "Banker's knife" rsc/banker.lxp >/dev/null ; then
				LB_go_nextl 5 && LB_go_link && sleep $((RANDOM%2+1))
				echolog "Banker Fight ..."
				LB_get_current_page rsc/banker_result.lxp
				if greplog -A1 "Damage taken:" rsc/banker_result.lxp ; then
					((nrj-=5))
				else
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
	elif ((baTryWarden)) && ((nrjmax-nrj<14)) && grep "You can attack the Warden" rsc/map.lxp >/dev/null ; then
		LB_go_firstl && LB_go_nextl && LB_go_link && sleep 3
		LB_go_firstl ; sleep 2
		if LB_search_link more ; then
			LB_go_link ; sleep $((RANDOM%2+1))
			LB_get_current_page rsc/warden.lxp
			if grep "When the Warden will be defeated" rsc/warden.lxp >/dev/null ; then
				LB_go_nextl 5 && LB_go_link && sleep $((RANDOM%2+1))
				echolog "Warden Fight ..."
				LB_get_current_page rsc/warden_result.lxp
				if greplog -A1 "Damage taken:" rsc/warden_result.lxp ; then
					((nrj-=7))
				else
					echolog "ba_map warning: unexpected warden_result"
					cp -fv rsc/warden_result.lxp rsc/unexpected_warden_result.lxp
				fi
			else
					echolog "ba_map warning: unexpected warden"
					cp -fv rsc/warden.lxp rsc/unexpected_warden.lxp
			fi
		else
			echolog "ba_map warning: cannot find how to attack the warden"
		fi
	fi
}

