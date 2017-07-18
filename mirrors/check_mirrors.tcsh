#!/bin/tcsh

set MAIN="http://installer.hardenedbsd.org/pub/HardenedBSD/releases/amd64/amd64"
set MAIN_DISTS="${MAIN}/"
set MAIN_ISOS="${MAIN}/ISO-IMAGES/"
set date_now=`date "+%Y%m%d%H%M%S"`
set TEE_CMD="tee -a"
set DST_MAIL="robot@hardenedbsd.org"
set ENABLE_MAIL="YES"
setenv REPLYTO "robot@hardenedbsd.org"
set LOGS="/tmp/mirror-check/${date_now}"
set MAIL_FROM_EVERYTHING=0

test -d $LOGS || mkdir -p $LOGS

set mirrors="de-01.installer.hardenedbsd.org fr-01.installer.hardenedbsd.org pub.allbsd.org"

fetch -o - "${MAIN_DISTS}" | sed -n 's#.*\(hardenedbsd-.*\)\/<.*#\1#gp' | sort > /tmp/hbsd-main-dists-${date_now}.txt
fetch -o - "${MAIN_ISOS}" | sed -n 's#.*\(hardenedbsd-.*\)\/<.*#\1#gp' | sort > /tmp/hbsd-main-isos-${date_now}.txt

foreach mirror ( ${mirrors} )
	set MIRROR="http://${mirror}/pub/HardenedBSD/releases/amd64/amd64"
	set MIRROR_DIST="http://${mirror}/pub/HardenedBSD/releases/amd64/amd64/"
	set MIRROR_ISOS="${MIRROR}/ISO-IMAGES/"
	set _mail_subject_prefix=""
	set _send_mail=0

	echo "===== Check ${mirror} mirror" |& ${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log

	fetch -o - "${MIRROR_DIST}" | \
	sed -n 's#.*\(hardenedbsd-.*\)\/<.*#\1#gp' | sort > /tmp/hbsd-${mirror}-dists-${date_now}.txt
	fetch -o - "${MIRROR_ISOS}" | \
	sed -n 's#.*\(hardenedbsd-.*\)\/<.*#\1#gp' | sort > /tmp/hbsd-${mirror}-isos-${date_now}.txt

	echo "====== Check DISTFILES" |& ${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log
	diff -u /tmp/hbsd-main-dists-${date_now}.txt /tmp/hbsd-${mirror}-dists-${date_now}.txt |& \
		${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log
	set dists=$?

	echo "====== Check ISO-IMAGES" |& ${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log
	diff -u /tmp/hbsd-main-isos-${date_now}.txt /tmp/hbsd-${mirror}-isos-${date_now}.txt |& \
		${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log
	set isos=$?

	if ( ${dists} || ${isos} ) then
		echo "===== Finished checking of ${mirror} mirror: OUT-OF-SYNC" |& \
			${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log
		set _mail_subject_prefix="[OUT-OF-SYNC]"
		set _send_mail=1
	else
		echo "===== Finished checking of ${mirror} mirror: SUCCESS" |& \
			${TEE_CMD} ${LOGS}/${mirror}_${date_now}.log
		if ( ${MAIL_FROM_EVERYTHING} == 1 ) then
			set _mail_subject_prefix="[OK]"
			set _send_mail=1
		endif
	endif

	if ( ${_send_mail} == 1 ) then
		cat ${LOGS}/${mirror}_${date_now}.log | \
                    mail -s "${_mail_subject_prefix} ${mirror} @${date_now}" ${DST_MAIL}
	endif
end