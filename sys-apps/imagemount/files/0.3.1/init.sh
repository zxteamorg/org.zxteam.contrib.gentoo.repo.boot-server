#!/sbin/runscript
# Copyright (c) 2014 Max Anurin <theanurin@gmail.com>
#

INSTANCE=${SVCNAME#*.}

if [ -n "${INSTANCE}" ] && [ ${INSTANCE} != "imagemount" ]; then
	RUNDIR=/var/run/imagemount.$INSTANCE
else
	RUNDIR=/var/run/imagemount
fi

USEDLOOPFILE=${RUNDIR}/loop
USEDVGFILE=${RUNDIR}/vg
USEDMOUNTFILE=${RUNDIR}/mount


depend() {
	need localmount
	after bootmisc netmount
	before hostname
}

checkconfig() {
	[ -n "${IMAGE_FILES_FIND_PATTERNS}" ] || eend 1 "IMAGE_FILES_FIND_PATTERNS is not defined" || return 1
	return 0
}

checkenv() {
	losetup -h >/dev/null 2>&1 || eend $? "losetup inaccessible" || return 1
	mount.crypt_LUKS --help >/dev/null 2>&1 || eend $? "mount.crypt_LUKS inaccessible" || return 1

	return 0
}

start_pre() {
	checkpath --directory-truncate --owner root:root --mode 0644 --quiet ${RUNDIR}
}

stop_post() {
	rm -rf "${RUNDIR}"
}

__helper_is_device_mounted() {
# returns: 0 - when mounted!
	local DEVICE=$1
	[ -z "${DEVICE}" ] && return 1
	
	local REALDEVICE=
	REALDEVICE=`readlink -f "${DEVICE}"` || return 1
	
	local MOUNTED_DEVICES=
	MOUNTED_DEVICES=`mount -l | awk '{print $1}'` || return 1
	[ -z "${MOUNTED_DEVICES}" ] && return 1
	for MOUNTED_DEVICE in ${MOUNTED_DEVICES}; do
		if [ -a "${MOUNTED_DEVICE}" ]; then
			local REAL_MOUNTED_DEVICE=
			REAL_MOUNTED_DEVICE=`readlink -f ${MOUNTED_DEVICE}`
			if [ $? -eq 0 ]; then
				if [ "${REALDEVICE}" == "${REAL_MOUNTED_DEVICE}" ]; then
#					einfo "Real mounted device ${MOUNTED_DEVICE} for device ${DEVICE}"
					return 0
				fi
			fi
		fi
	done
	
	return 1
}

_attach_loop() {

	ebegin "	Attach loop device"

#	local IMAGE_FILES_FIND_PATTERNS=
#	IMAGE_FILES_FIND_PATTERNS=`grep "^IMAGE_FILES_FIND_PATTERNS=.*" "${INSTANCECONF}" 2>/dev/null | awk -F= '{print $2}'`
	if [ -z "${IMAGE_FILES_FIND_PATTERNS}" ]; then
		ewarn "	No images to attach."
		return 0
	fi

	local BAD_PATTERNS=
	for PATTERN in ${IMAGE_FILES_FIND_PATTERNS}; do
		if [ -n "$PATTERN" ]; then
			if IMG_FILES=`ls "${PATTERN}" 2>/dev/null`; then
				for IMG_FILE in $IMG_FILES; do
					ATTACHED_LOOP_DEVICE=`losetup -j "${IMG_FILE}" | head -n 1 | awk -F: '{print $1}'` || eend 1 "Cannot check attached device." || return 1
					if [ -n "${ATTACHED_LOOP_DEVICE}" ]; then
						ewarn "Skip ${IMG_FILE}. The file already associated with ${ATTACHED_LOOP_DEVICE}"
						echo "${ATTACHED_LOOP_DEVICE}" >> "${USEDLOOPFILE}"
					else
						local LOOP_DEVICE=
						LOOP_DEVICE=`losetup -f` || eend 1 "Unused loop device not found" || return 1
						losetup "${LOOP_DEVICE}" "${IMG_FILE}" >/dev/null 2>&1
						if [ $? -eq 0 ]; then
							echo "${LOOP_DEVICE}" >> "${USEDLOOPFILE}"
						else
							echo "${LOOP_DEVICE}" >> "${USEDLOOPFILE}"
							eerror "Cannot setup loop device for file ${IMG_FILE}"
						fi
					fi
				done
			else
				BAD_PATTERNS="${BAD_PATTERNS} ${PATTERN}"
			fi
		fi
	done
	[ -z "${BAD_PATTERNS}" ] || eerror "Cannot process patterns: ${BAD_PATTERNS}" || return 1
	
	return 0
}

_detach_loop() {
	# skip if file is not exists
	[ -f "${USEDLOOPFILE}" ] || return 0;

	ebegin "	Detach loop device"

	local LOOP_DEVICES=`cat "${USEDLOOPFILE}"`
	if [ -n "$LOOP_DEVICES" ]; then
		for LOOP_DEVICE in ${LOOP_DEVICES}; do
			if [ -a "$LOOP_DEVICE" ]; then
				losetup -d "${LOOP_DEVICE}" >/dev/null 2>&1
			fi
		done
	fi

	rm -f "${USEDLOOPFILE}"
}

function _activate_vg() {

#	local ACTIVATE_VOLUMES=
#	ACTIVATE_VOLUMES=`grep "^ACTIVATE_VOLUMES=.*" "${INSTANCECONF}" 2>/dev/null | awk -F= '{print $2}'`
	if [ -z "${ACTIVATE_VOLUMES}" ]; then
		einfo "	No volumes to activate."
		return 0
	fi

	local ERRCODE=0
	for VOLUME in ${ACTIVATE_VOLUMES}; do
		ebegin "	Activate ${VOLUME}"
		vgchange -a y $VOLUME >/dev/null 2>&1
		eend $? "Cannot activate volume $VOLUME"
		if [ $? -eq 0 ]; then
			echo "${VOLUME}" >> "${USEDVGFILE}"
		else
			ERRCODE=1
		fi
	done

	return ${ERRCODE}
}

function _deactivate_vg() {
	# skip if file is not exists
	[ -f "${USEDVGFILE}" ] || return 0;

	local VOLUMES=`cat "${USEDVGFILE}"`
	[ -z "${VOLUMES}" ] && return 0

	local RETCODE=0
	for VOLUME in ${VOLUMES}; do
		if vgdisplay "${VOLUME}" >/dev/null 2>&1; then
			ebegin "	Deactivate ${VOLUME}"
			vgchange -a n "${VOLUME}" >/dev/null 2>&1
			eend $? "	Cannot deactivate volume ${VOLUME}"
			if [ $? -ne 0 ]; then
				RETCODE=1
			fi
		else
			ewarn "	! Skip ${VOLUME}. Volume not found."
		fi
	done	
	[ ${RETCODE} -eq 0 ] && rm -f "${USEDVGFILE}"

	return ${RETCODE}
}

function _mount() {
#	local MOUNT_POINTS=
#	MOUNT_POINTS=`grep "^MOUNT_POINTS=.*" "${INSTANCECONF}" 2>/dev/null | awk -F= '{print $2}'`
	if [ -z "${MOUNT_POINTS}" ]; then
		einfo "	Mount points are not defined."
		return 0
	fi

	local ERRCODE=0
	for POINT in ${MOUNT_POINTS}; do
		ebegin "	Mount ${POINT}"
		mount $POINT >/dev/null 2>&1
		eend $? "Cannot mount $POINT"
		if [ $? -eq 0 ]; then
			echo "${POINT}" >> "${USEDMOUNTFILE}"
		else
			ERRCODE=1
		fi
	done

	return ${ERRCODE}
}

function _umount() {
	# skip if file is not exists
	[ -f "${USEDMOUNTFILE}" ] || return 0;

	local MOUNTS=""
	[ -n "${MOUNT_POINTS}" ] && MOUNTS="${MOUNTS} ${MOUNT_POINTS}"
	[ -n "${MOUNT_POINTS}" ] && MOUNTS="${MOUNTS} ${LAZY_MOUNT_POINTS}"

	[ -z "${MOUNTS}" ] && return 0

	local RETCODE=0
	for MOUNT in ${MOUNTS}; do
		__helper_is_device_mounted "${MOUNT}"
		if [ $? -eq 0 ]; then
			ebegin "	Umount ${MOUNT}"
			umount ${MOUNT} >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				ewarn "	Friendly killing locked processes..."
				sleep 5
				fuser -km "${MOUNT}" >/dev/null 2>&1
				umount ${MOUNT} >/dev/null 2>&1
				if [ $? -ne 0 ]; then
					ewarn "	Hard killing locked processes..."
					sleep 5
					fuser -km "${MOUNT}" >/dev/null 2>&1
					umount ${MOUNT} >/dev/null 2>&1
					eend $? "	Cannot umount ${MOUNT}"
					if [ $? -ne 0 ]; then
						RETCODE=1
					fi
				fi
				eend $? "	Cannot umount ${MOUNT}"
				if [ $? -ne 0 ]; then
					RETCODE=1
				fi
			fi
		fi
	done

	return ${RETCODE}
}

start() {
	ebegin "Starting ${SVCNAME}"
	
	checkenv || return 1
	checkconfig || return 1

	local FAIL_FLAG=1

	if _attach_loop; then
		if _activate_vg; then
			if _mount; then
				# Success
				FAIL_FLAG=0
			fi
		fi
	fi

	if [ ${FAIL_FLAG} -ne 0 ]; then
		_umount && _deactivate_vg && _detach_loop
		return 1
	fi

	return 0
}

stop() {
	ebegin "Stopping ${SVCNAME}"

	checkenv || return 1

	_umount && _deactivate_vg && _detach_loop

	return $?
}

# vim: set ts=4 :
