#!/bin/bash
# Fedora 10 

. /var/www/lighttpd/shellscript/config.sh

CONF_FNAME="cloudrainbow.conf"
CONF_FPATH="/var/$CONF_FNAME"
MPDIR="/mnt"
VERSION="1.2"
${DEBUG:=false}

debug(){
	test $DEBUG && echo "*********" $*
}
_confget(){
	declare MP=$1
	cp  "$MP${CONF_FPATH}" "${CONF_FPATH}" && return 0 || return 1
}
_confmountandget(){
	declare PART=$1
	declare MP=$MPDIR/$PART
	mkdir -p $MP
	mount /dev/$PART $MP 
	if [ "$?" = "0" ]; then
		_confget $MP 
		if [ "$?" = "0" ]; then
			echo $PART > $CONF_FPATH.part
			echo $PART
			umount $MP
			
			if [ "`ls -l $MP | wc -l`" = "0" ]; then
				rm -rf $MP
			fi
			return 0
		else
			umount $MP
			return 1
		fi
	else
		return 1
	fi
}
_confwhateverget(){
	declare PART=$1
	df -T 2>/dev/null | grep "^/dev/$PART " 
	if [ "$?" = "0" ]; then 
	# if the partition had been mounted, just save it
		declare MP=`df -T | grep "^/dev/$PART " | awk '{print $7}'`
		_confget $MP
		if [ $? = 0 ]; then
			echo $PART > $CONF_FPATH.part
			echo $PART
			return 0
		else
			return 1
		fi
		
	else
		debug "try to mount $PART and get"
	# try to mount it and save
		_confmountandget $PART && return 0 || return 1
	fi
}

getconfig()
{
	if [ -n "$1" ]; then		
		if [ -f "${CONF_FPATH}.part" ]; then
			declare PART=`cat ${CONF_FPATH}.part`
			# if the partition had been mounted
			_confwhateverget $PART && return 0 || return 1
		else
			# if not specify what partition, then try to mount one by one
			#declare ALLDISKS=`fdisk -l 2>/dev/null | grep /dev | grep Disk | grep ":"| awk '{print $2}' | cut -c 6- | tr -d :`
			declare ALLDISKS=`fdisk -l 2>/dev/null| grep ":" | grep 'Disk /dev/[a-z]\{1,2\}d.'|sort|awk '{print $2}'|cut -c 6-|cut -d: -f1`
			debug "try all disks " $ALLDISKS
			for DISK in $ALLDISKS; do
				for PART in `fdisk -l /dev/$DISK 2>/dev/null| grep ^/dev | tr -d \* |awk '{print $1}'| cut -c 6-`; do
					debug "try to probe::" $PART  
					
					if [ $DEBUG ];then
						_confwhateverget $PART && return 0 || continue
					else
						_confwhateverget $PART 2>/dev/null && return 0 || continue
					fi
				done
			done
			# fail at last
			return 1
		fi
	else
		declare PART=$1
		if [ $DEBUG ];then
			_confwhateverget $PART && return 0 || return 1
		else
			_confwhateverget $PART 2>/dev/null && return 0 || return 1
		fi

	fi
	
}
usage()
{
  echo "usage: $1 [-h] [PARTITION_ID]"
  echo " version $VERSION: copy the configure file from disk"
  echo "	-h print this message and exist"
  echo ""
  echo "	if specify the PARTITION_ID, then get the configure file from $CONF_FPATH to the disk."
  echo "	if PARTITION_ID didn't specify, first try to get the PARTITION_ID from $CONF_FPATH.part"
  echo "		or try to mount the partition one by one, and get from the partition"
  echo ""
  echo "	print the partition_id that had get the configure file"
  echo ""
  echo "	the supported filesystem had been registed in /etc/filesystem: "
  echo "	version 1.2: support vfat;minix;xfs;ext2;ntfs;ext3;ntfs-3g;jfs;reiserfs;"
  exit 1
}

if [ "$1" = "-h" ]; then
	usage $0
else
	getconfig $1 && exit 0 || exit 1
fi
