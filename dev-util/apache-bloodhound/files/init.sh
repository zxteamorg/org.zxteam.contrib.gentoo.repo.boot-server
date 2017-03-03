#!/sbin/runscript
#//************************************//
#//** Developed by ZX Team           **//
#//** Web: http://www.zxteam.net     **//
#//** E-Mail: dev@zxteam.net         **//
#//************************************//
#//** Developer Maxim Anurin         **//
#//** Web: http://www.anurin.name    **//
#//** E-Mail: maxim.anurin@gmail.com **//
#//** Skype: maxim.anurin            **//
#//************************************//

INSTANCE=${SVCNAME#*.}


#extra_commands="backup"

: ${pidfile:=${pidfile:-/run/bloodhound.pid}}
: ${user:=${user:-bloodhound}}
: ${home:=${home:-/var/lib/bloodhound}}
: ${env:=${env:-bloodhound-environments/main}}
: ${logfile:=${logfile:-/var/log/bloodhound.log}}
: ${port:=${port:-8000}}

depend() {
    need net
    use dns logger
}

checkconfig() {
    if [ -z "$user" ]; then
        eerror "Variable \"user\" is not configured"
        return 1
    fi
    if ! id -u "$user" >/dev/null 2>&1; then
        eerror "User \"$user\" is not exists"
        return 1
    fi

    if [ -z "$home" ]; then
        eerror "Variable \"home\" not configured"
        return 1
    fi
    if [ ! -d "$home" ]; then
        eerror "Home directory does not exist: $home"
        return 1
    fi
    if [ "$user" != "`stat -c %U "$home"`" ]; then
        eerror "Bad owner of directory $home. Should be \"$user\""
        return 1
    fi

#TODO 
# - check for python 2.7

    return 0
}

start() {
    checkconfig || return 1

    ebegin "Starting ${SVCNAME}"
    source "${home}/bhenv/bin/activate"
    start-stop-daemon --start --quiet --background --make-pidfile --pidfile "${pidfile}" --user "${user}" --exec "tracd" -- --port=${port} ${home}/${env}
    eend $?
}

stop() {
    ebegin "Stopping ${SVCNAME}"
    start-stop-daemon --stop --quiet --retry TERM/15/KILL/20 --pidfile "${pidfile}"
    eend $?
}
