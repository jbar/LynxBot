libexec_PROGRAMS = extractlastlinkfromlynx setstrforlynx usleep
extractlastlinkfromlynx_SOURCES = extractlastlinkfromlynx.c
setstrforlynx_SOURCES = setstrforlynx.c
usleep_SOURCES = usleep.c
bin_SCRIPTS = lynxbot.sh
libexec_SCRIPTS = init_lynxbot
libexecdir = @libdir@/lynxbot
POST_INSTALL = sed -i s,LynxBotBin='.*',LynxBotBin=\"${libexecdir}/lynxbot\",  ${libexecdir}/init_lynxbot
