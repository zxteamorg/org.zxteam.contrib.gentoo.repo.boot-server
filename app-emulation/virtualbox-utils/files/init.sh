#!/sbin/runscript
# Copyright (c) 2012 Max Anurin <theanurin@gmail.com>
#

# Not sure why but gentoo forgot to add /opt/bin to the path.
VBOXPATH="/usr/bin:/opt/bin"
VBOXNAME="${SVCNAME#*.}"

depend() {
        need net

        if [ "${SVCNAME}" != "virtualbox" ] ; then
                need virtualbox
        fi
}


checkconfig() {
        if [ ! -r /etc/conf.d/$SVCNAME ] ; then
                eerror "Please create /etc/conf.d/$SVCNAME"
                eerror "Sample conf: /etc/conf.d/virtualbox.example"
                return 1
        fi

        return 0
}

checkpath() {
        local r=0

        if ! su $VM_USER -c "PATH=$VBOXPATH command -v VBoxHeadless &>/dev/null" -s /bin/sh ; then
                eerror "Could not locate VBoxHeadless"
                r=1
        fi

        if ! su $VM_USER -c "PATH=$VBOXPATH command -v VBoxManage &>/dev/null" -s /bin/sh ; then
                eerror "Could not locate VBoxManage"
                r=1
        fi

        if [ $r -gt 0 ] ; then
                eerror "Please verify the vm users path."
        fi

        return $r
}

isloaded() {
        lsmod | grep -q "$1[^_-]"
}

isvm() {
        [ $SVCNAME != "virtualbox" ]
}

loadmodules() {
        if ! isloaded vboxdrv ; then
                if ! modprobe vboxdrv > /dev/null 2>&1 ; then
                        eerror "modprobe vboxdrv failed."
                        return 1
                fi
        fi

        if ! isloaded vboxnetflt ; then
                if ! modprobe vboxnetflt > /dev/null 2>&1 ; then
                        eerror "modprobe vboxnetflt failed."
                        return 1
                fi
        fi

        if ! isloaded vboxnetadp ; then
                if ! modprobe vboxnetadp > /dev/null 2>&1 ; then
                        eerror "modprobe vboxnetadp failed."
                        return 1
                fi
        fi

        return 0
}

unloadmodules() {
        if isloaded vboxnetflt ; then
                if ! rmmod vboxnetflt > /dev/null 2>&1 ; then
                        eerror "rmmod vboxnetflt failed."
                        return 1
                fi
        fi

        if isloaded vboxnetadp ; then
                if ! rmmod vboxnetadp > /dev/null 2>&1 ; then
                        eerror "rmmod vboxnetadp failed."
                        return 1
                fi
        fi

        if isloaded vboxdrv ; then
                if ! rmmod vboxdrv > /dev/null 2>&1 ; then
                        eerror "rmmod vboxdrv failed."
                        return 1
                fi
        fi

        return 0
}

start() {
        # If we are the original virtualbox script [ $SVCNAME = "virtualbox" ]
        if ! isvm ; then
                ebegin "Starting Virtualbox"
                loadmodules
                eend $?
        else
                checkconfig || return $?
                checkpath   || return $?

                ebegin "Starting Virtualbox: $VBOXNAME"

                if [ -n "$VM_STARTUP_REVERT_SNAPSHOT" ]; then
                    echo "    Restore snapshot $VM_STARTUP_REVERT_SNAPSHOT"
                    su "$VM_USER" -c "PATH=$VBOXPATH VBoxManage snapshot \"$VM_NAME\" restore \"$VM_STARTUP_REVERT_SNAPSHOT\"" -s /bin/sh

                    # TODO: Check error code
                fi


                if [ -n "$VM_VNC_PORT" -a -n "$VM_VNC_PASSWORD" ]; then
		    su "$VM_USER" -c "PATH=$VBOXPATH nice -n $VM_NICE VBoxHeadless -startvm \"$VM_NAME\" --vnc --vncport \"$VM_VNC_PORT\" --vncpass \"$VM_VNC_PASSWORD\" --vrde config &>/dev/null" -s /bin/sh &
                    pid=$!
                else
                    su "$VM_USER" -c "PATH=$VBOXPATH nice -n $VM_NICE VBoxHeadless -startvm \"$VM_NAME\" --vrde config &>/dev/null" -s /bin/sh &
                    pid=$!
                fi
                sleep 1

                kill -CHLD $pid &>/dev/null
                eend $?
        fi
}

stop() {
        # If we are the original virtualbox script [ $SVCNAME = "virtualbox" ]
        if ! isvm ; then
                ebegin "Stopping Virtualbox"
                unloadmodules
                eend $?
        else
                checkconfig || return $?
                checkpath   || return $?

                ebegin "Stopping Virtualbox: $VBOXNAME"
                su ${VM_USER} -c "PATH=$VBOXPATH VBoxManage controlvm \"$VM_NAME\" $VM_SHUTDOWN &>/dev/null" -s /bin/sh &
                c=0
                 while [ "$(su ${VM_USER} -c "PATH=$VBOXPATH VBoxManage showvminfo \"$VM_NAME\" | grep State | grep 'runn\|saving' 2>/dev/null")" != "" ]
                do
                    echo -n "."
                    sleep 1
                    let c=c+1

                    if [ "$c" = "300" ]; then
                        echo -n " Trying again $VM_SHUTDOWN..."
                        su ${VM_USER} -c "PATH=$VBOXPATH VBoxManage controlvm \"$VM_NAME\" $VM_SHUTDOWN &>/dev/null" -s /bin/sh &
                    fi

                    if [ "$c" = "360" ]; then
                        echo ""
                        echo -n "$VM_SHUTDOWN not working, trying poweroff."
                        su ${VM_USER} -c "PATH=$VBOXPATH VBoxManage controlvm \"$VM_NAME\" poweroff &>/dev/null" -s /bin/sh &
                    fi

                done

                sleep 1
                echo

                eend $?
        fi
}
