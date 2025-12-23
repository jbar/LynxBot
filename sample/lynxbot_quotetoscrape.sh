#! /bin/bash
                                                                                                    
#######################
# VARIABLES A DEFINIR #
#######################
# exemples d'auteurs : 
# austen, einstein, lennon, gide, edison, roosevelt, martin,
# monroe, rowling, marley, seuss, adams, wiesel, nietzsche,
# twain, saunders, neruda, emerson, teresa, henson, borges,
# king ... plus sur le site.
#
# exemples de TAGs :
# love, life, simile, girls, dumbledore, inspirational, humor,
# reading, friends, truth, tea ... plus sur le site.
# --------------------
# Obligatoire
auteur_a_chercher="lennon"
# --------------------
# Optionel (soit renseigné, soit vide)
#tag="humor"
tag=""
# --------------------


###############################
# VARIABLES DE FONCTIONNEMENT #
###############################
# Je récupère 'init_lynxbot', le fichier le plus récent
source_file="$(sudo find / -type f -path '*/LynxBot/src/*' -name 'init_lynxbot' -exec ls -t {} + 2> /dev/null | head -n 1)"
url="https://quotes.toscrape.com/"
fichier_auteur="current_page_about_$auteur_a_chercher.txt"
fichier_auteur_fr="current_page_about_$auteur_a_chercher.fr.txt"

source $source_file > /dev/null

# Option fun
# Afficher ou non le lynx en ascii dès que le script se termine
afficher_lynx="oui"

###########################
# DEPENDANCES NECESSAIRES #
###########################
if ! dpkg -s curl &> /dev/null; then
	echo "package - curl : installation..."
	sudo apt install -y curl &> /dev/null
fi

if ! dpkg -s jq &> /dev/null; then
	echo "package - jq : installation..."
	sudo apt install -y jq &> /dev/null
fi

#######################
#   Petit nettoyage   #
#######################

if [[ -a tmp_current_page ]]; then
       rm tmp_current_page
fi
if [[ -a $fichier_auteur ]]; then
       rm $fichier_auteur
fi
if [[ -a $fichier_auteur_fr ]]; then
       rm $fichier_auteur_fr
fi

# Fonction pour formatter le texte de log dans la fenêtre d'exécution du script
# Utilisation : 
# log "fonction de parsing"
# log "vérification..."
log() {
	echo "..... $1"
}

# Fonction permettant d'ajouter une signature à la fin d'un fichier
# Utilisation : ajouter_signature fichier.txt
ajouter_signature() {
	echo -e '\n\n\t¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸' >> $1
	echo -e "\n\n\t\tFait avec amour et passion." >> $1
	echo -e '\n\n\t¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯`·.¸.·´¯' >> $1
}

# Fonction permettant de s'authentifier sur le site.
# J'ai testé avec 'test' 'test' et cela semble fonctionner.
login_home() {
	log "login"
	sleep 1
	if LB_search_link Login > /dev/null; then
		sleep 1
		LB_go_link
		sleep 1
	else
		clean_and_exit 9 "Lien LOGIN non trouvé"
	fi	
	# On cherche le 1er champ d'entrée de texte
	if LB_search_linktype 'Textfield "%s"' > /dev/null; then
		sleep 1
		LB_write_string 'test'
		sleep 1
	else
		clean_and_exit 9 "Champ Textfield du login non trouvé"
	fi

	# On va sur le champ Password
	LB_go_nextl
	sleep 1
	LB_write_string 'test'
	sleep 1

	# On valide
	if LB_search_linktype 'Form submit button' > /dev/null; then
		sleep 1
		LB_go_link
		sleep 1
	else
		clean_and_exit 9 "Bouton de validation non trouvé"
	fi
}

# Fonction de traduction du texte.
# Le texte au sujet de l'auteur est récupéré en anglais.
# Ici, avec l'API de google, nous traduisons ce texte en français.
# Utilisation : traduire_texte fichier_entree_EN fichier_sortie_FR
traduire_texte() {
	curl -s -G "https://translate.googleapis.com/translate_a/single" \
	--data-urlencode "client=gtx" \
	--data-urlencode "sl=en" \
	--data-urlencode "tl=fr" \
	--data-urlencode "dt=t" \
	--data-urlencode "q=$(cat $1)" \
	| jq -r '.[0][][0]' \
	| tr -d '\n' \
	| tr -s ' ' \
	| fmt -w 90 > $2
}

# Utilisation : 
# 'clean_and_exit 0' pour un exit 0 avec un message par défaut "SORTIE"
# 'clean_and_exit 9' pour un exit 9 avec un message par défaut "SORTIE"
# 'clean_and_exit 9 "Nom de pesonne non trouvé"' pour un exit 9 avec un message perso
clean_and_exit() {
	echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
	if [[ -n $2 ]]; then
		echo "				$2"
	else
		echo "				SORTIE"
	fi
	if [[ -a $fichier_auteur ]]; then
		echo "	fichier EN : $PWD/$fichier_auteur"
	fi
	if [[ -a $fichier_auteur_fr ]]; then
		echo "	fichier FR : $PWD/$fichier_auteur_fr"
	fi
	echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
	if [[ -a tmp_current_page ]]; then
		rm tmp_current_page
	fi
	if [[ -a current_page_about ]]; then
		rm current_page_about
	fi
	LB_stop
	sleep 1
	afficher_lynx_ascii
	exit $1
}

# Recherche du TAG souhaité
# Si le TAG n'est pas vide, on le cherche.
search_tag_in_page() {
	if [[ -n "$tag" ]]; then
		log "recherche du TAG : $tag"
		while ! LB_search_link 200 "$tag" > /dev/null; do
		    log "	-> tag : $tag, non trouvé, je passe à la page suivante..."
		    #LB_go_firstl
		    sleep 1
		    if LB_search_link -200 'Next'; then
			sleep 1
			LB_go_link
			sleep 1
		    else
			    clean_and_exit 9 "TAG non trouvé"
		    fi
		done
	fi
	sleep 2
	LB_go_link
	sleep 2
}

# Fonction permettant de rechercher sur la page courante si le nom de la personne
# recherchée est présent.
# Si oui : on sort de la fonction.
# Si non : on passe sur la page suivante jusqu'à atteindre la dernière page
search_people_in_page() {
	#counter=0
	
	log "recherche du nom dans la page : $auteur_a_chercher"
	LB_get_current_page tmp_current_page
	#while ! grep -q -i "$auteur_a_chercher" tmp_current_page && (( counter < 10 ))
	while ! grep -q -i "$auteur_a_chercher" tmp_current_page
	do
		#log "	-> $auteur_a_chercher : n'est pas sur cette page"
		if LB_search_link 200 'Next' > /dev/null; then
			log "	+"
			sleep 1
			LB_go_link
			sleep 1
		else
			log "	-> pas de page suivante. Sortie de la boucle"
			break
		fi
		LB_get_current_page tmp_current_page
		sleep 1
		#((counter++))
	done
}

# Fonction permettant de chercher dans chaque 'about' de la page
# afin de voir si ce 'about' correspond à la personne que l'on recherche.
# Si oui : on crée un fichier propre et on quitte
# Si non : on sort du 'about' en revenant à la page précédente, on itère sur chaque 'about'
# 	   et si rien n'est trouvé sur la page courante, on passe à la page suivante,
# 	   on appelle à nouveau la fonction 'search_people_in_page' pour ne pas 
# 	   faire tous les 'about' inutilement, et on recommence le tout.
search_people_in_about() {
	if grep -q -i $auteur_a_chercher tmp_current_page; then
		auteur="x"
		while [ "$auteur" != "$auteur_a_chercher" ]
		do
			log "recherche des 'about'"
			while LB_search_link 'about' > /dev/null
			do
				log "	+."
				sleep 1
				LB_go_link
				LB_get_current_page current_page_about
				if grep -q -i $auteur_a_chercher current_page_about; then
					log " +++ Page de $auteur_a_chercher trouvée +++"
					sleep 1
					auteur="$auteur_a_chercher"
					sleep 1
					# Ici, je ne garde que la partie 'description' de la page
					sed -n '0,/Description:/d; /Quotes by:/q; p' current_page_about > $fichier_auteur
					traduire_texte $fichier_auteur $fichier_auteur_fr
					sed -i "1iAuteur : $auteur_a_chercher\n" $fichier_auteur_fr
					ajouter_signature $fichier_auteur_fr
					clean_and_exit 0 "+++++ (*^‿^*) +++++"
				else
					sleep 1
					LB_go_previouspage
					sleep 1
					LB_go_nextl
					sleep 1
				fi
			done
			if LB_search_link -200 'Next' > /dev/null; then
				log "	+"
				sleep 1
				LB_go_link
				sleep 1
				search_people_in_page
			else
				clean_and_exit 9 "Nom de la personne non trouvé"
			fi

		done
	else
		clean_and_exit 9 "Nom de la personne non trouvé"
	fi
}

afficher_lynx_ascii() {
	if [[ "${afficher_lynx,,}" == "oui" ]]; then

	echo ' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ '
	echo '                                                                             '
	echo '                                                .                            '
	echo '                 -------+--+.                   -#- ..+                      '
	echo '             --+---++---+++++--++-              .##+.--.+-                   '
	echo '           .-++--+++-++++#++++-++++-+-#+-.    .-------#+##+-                 '
	echo '          .-+----+---+++#++##+++++#+++--++--+-.+-+++++-.+++++-               '
	echo '     .-++-----+#+--+++-+###++##+##++++-----++.+#-++#++###+++++++             '
	echo '    -##-.------+#--++-++######+++#+++++-++-++-.#-+++#++++++##+++++           '
	echo '     --.-------+#+-+-+++#+###++++++++++++++.+##--#--#-#-+-++++++-+.          '
	echo '      .......--++#--+--+-####++----+-+++++++..-.-....+-#-++++++++++          '
	echo '            .-----+-+--++-####+----++-++++++--+--   .-+#--+++++-+-+.         '
	echo '          .---+--++++#--+-++###--+--+--++++--#+-. ..  #.-+#+++-+++-.         '
	echo '       .---++-+++---#++++-+-#+#+--+++--++++-+#++-.#+-.#---+-#-+++++          '
	echo '      -###+###+++#+#+#+#++#++##++--+-+++---++#++-++#+-------++-++++          '
	echo '      -+--+++++#+++++#++##-+-#+++-----------+#+-++++--------+---++-          '
	echo '      -++#++++++++++-#-.-....-----+---------###+-+-----.......+--+-          '
	echo '       +++++--         .---+..-------------++#+#++--.-......-.----.          '
	echo '       .------         -++#++--...-...------+#++++++#-......---++-           '
	echo '        .-+++-----     -#+++++--............-#+###+----...--+----+           '
	echo '          ###+++#-+   .####+++-..            .-#++++--.  .---+++--           '
	echo '                .--    .+###++-..             .+-+#+++    .#----+-           '
	echo '                         +###++---....         -+-++++-    ..-----           '
	echo '                           +###+++++#++.        --+#+++    .------           '
	echo '                               .++++++#          --++++-    .-++--           '
	echo '                                                  ++++##-.  .----.           '
	echo '                                                  .-++-+-++ .--+--           '
	echo '                                                   -+-+#+++ --++-#+.         '
	echo '                                                            +++++#++-        '
	echo '                                                                  .+.        '
	echo ' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ '
	fi
}


# ********************
# Début des exécutions
# ********************
log "......................................"
log "auteur à chercher : $auteur_a_chercher"
if [[ -n "$tag" ]]; then
	log "TAG : $tag"
else
	log "TAG : <pas de tag>"
fi
log "......................................"
sleep 2.5

log "lancement de lynxbot"
LB_startlynxbot
sleep 1

log "url : $url"
LB_go_to_url "$url"
sleep 1

# On s'authentifie sur le site
login_home
# On recherche le TAG définit au début du fichier, si TAG non vide
search_tag_in_page
# On recherche déjà sur la page, si le nom apparait. Sinon on va à la page suivante
search_people_in_page
# Une fois que l'on sait que le nom est sur la page, on cherche dans chaque 'About'
search_people_in_about

clean_and_exit 0
