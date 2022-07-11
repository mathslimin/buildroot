#!/usr/bin/env bash

######################################################################
# @author      : alpha (alpha@mascot)
# @created     : Tuesday Mar 29, 2022 23:47:17 CST
#
# @description :
######################################################################

# default values
DEFAULT_IMAGES_DIR=images
DEFAULT_KERNEL=${DEFAULT_IMAGES_DIR:-.}/zImage
DEFAULT_INITRD=${DEFAULT_IMAGES_DIR:-.}/rootfs.cpio
DEFAULT_DRIVER=${DEFAULT_IMAGES_DIR:-.}/rootfs.ext4
DEFAULT_DTB=${DEFAULT_IMAGES_DIR:-.}/vexpress-v2p-ca15_a7.dtb
DEFAULT_HOST=10.0.2.1
DEFAULT_PORT=9981
DEFAULT_SHARE=

# uncomment to set default
ARG_KERNEL=${DEFAULT_KERNEL}
# ARG_INITRD=${DEFAULT_INITRD}
# ARG_DRIVER=${DEFAULT_DRIVER}
ARG_DTB=${DEFAULT_DTB}
ARG_HOST=${DEFAULT_HOST}
ARG_PORT=${DEFAULT_PORT}
ARG_SHARE=${DEFAULT_SHARE}

function usage()
{
	echo "$0 arguments:"
	echo -e "\t-h|-help: print this usage and exit"
	echo -e "\t-k|-kernel [kernel image file]"
	echo -e "\t\tdefault: <${ARG_KERNEL}>[${DEFAULT_KERNEL}]"
	echo -e "\t-r|-initrd [rootfs initial ram disk file]"
	echo -e "\t\tdefault: <${ARG_INITRD}>[${DEFAULT_INITRD}]"
	echo -e "\t-d|-driver [rootfs driver disk file]"
	echo -e "\t\tdefault: <${ARG_DRIVER}>[${DEFAULT_DRIVER}]"
	echo -e "\t-D|-dtb [device tree image file]"
	echo -e "\t\tdefault: <${ARG_DTB}>[${DEFAULT_DTB}]"
	echo -e "\t-p|-port [ssh host forward port]"
	echo -e "\t\tdefault: <${ARG_PORT}>[${DEFAULT_PORT}]"
	echo -e "\t-H|-host [ssh host ip]"
	echo -e "\t\tdefault: <${ARG_HOST}>[${DEFAULT_HOST}]"
	echo -e "\t-s|-share [host share path]"
	echo -e "\t\tdefault: <${ARG_SHARE}>[${DEFAULT_SHARE}]"
	echo -e "\t-- [extra arguments pass to QEMU]"
}

# parse arguments
while [ -n "$1" ]; do
	# if $1 is last argument, set arg=--, otherwise set arg=$2
	arg=${2:---}
	case "$1" in
	"-k" | "-kernel")
		if [[ $arg == -* ]]; then
			ARG_KERNEL=${DEFAULT_KERNEL}
			shift 1
		else
			ARG_KERNEL=$arg
			shift 2
		fi
		;;
	"-r" | "-initrd")
		if [[ $arg == -* ]]; then
			ARG_INITRD=${DEFAULT_INITRD}
			shift 1
		else
			ARG_INITRD=$arg
			shift 2
		fi
		;;
	"-d" | "-driver")
		if [[ $arg == -* ]]; then
			ARG_DRIVER=${DEFAULT_DRIVER}
			shift 1
		else
			ARG_DRIVER=$arg
			shift 2
		fi
		;;
	"-D" | "-dtb")
		if [[ $arg == -* ]]; then
			ARG_DTB=${DEFAULT_DTB}
			shift 1
		else
			ARG_DTB=$arg
			shift 2
		fi
		;;
	"-p" | "-port")
		if [[ $arg == -* ]]; then
			ARG_PORT=${DEFAULT_PORT}
			shift 1
		else
			ARG_PORT=$arg
			shift 2
		fi
		;;
	"-H" | "-host")
		if [[ $arg == -* ]]; then
			ARG_HOST=${DEFAULT_HOST}
			shift 1
		else
			ARG_HOST=$arg
			shift 2
		fi
		;;
	"-s" | "-share")
		if [[ $arg == -* ]]; then
			ARG_SHARE=${DEFAULT_SHARE}
			shift 1
		else
			ARG_SHARE=$arg
			shift 2
		fi
		;;
	"--")
		shift
		ARG_EXTRA="$@"
		break
		;;
	"-h" | "-help")
		usage
		exit 0
		;;
	*)
		echo "unknown option: $1"
		usage
		exit -1
		;;
	esac
done

# default boot from ram disk
if [[ "${ARG_INITRD:-n}" == "n" && "${ARG_DRIVER:-n}" == "n" ]]; then
	ARG_INITRD=${DEFAULT_INITRD}
fi

#
# set default qemu options
#

QEMU_OPT_EXTRA="${ARG_EXTRA}"

if [[ "${ARG_KERNEL:-n}" != "n" ]]; then
	QEMU_OPT_kernel="-kernel ${ARG_KERNEL}"
fi

if [[ "${ARG_DRIVER:-n}" != "n" ]]; then
	device="-device virtio-blk-device,drive=hd0"
	driver="-drive if=none,file=${ARG_DRIVER},format=raw,id=hd0"
	QEMU_OPT_driver="${device} ${driver}"
	QEMU_OPT_append_root="root=/dev/vda rw"
fi

if [[ "${ARG_INITRD:-n}" != "n" ]]; then
	QEMU_OPT_initrd="-initrd ${ARG_INITRD}"
	QEMU_OPT_append_root="root=/dev/ram rw"
fi

if [[ "${ARG_DTB:-n}" != "n" ]]; then
	QEMU_OPT_dtb="-dtb ${ARG_DTB}"
fi

# ssh forward
# in host: ssh root@localhost -p ${ARG_PORT}
if [[ "${ARG_HOST:-n}" != "n" || "${ARG_PORT:-n}" != "n" ]]; then
	device="-device virtio-net-device,netdev=net0"
	netdev="-netdev user,id=net0,"
	netdev=${netdev}"host=${ARG_HOST:-$DEFAULT_HOST},"
	netdev=${netdev}"hostfwd=tcp::${ARG_PORT:-$DEFAULT_PORT}-:22"
	QEMU_OPT_netdev="${device} ${netdev}"
fi

# share folder
# in guest: mount -t 9p share9p /mnt
# kernel must enable 9P options
if [[ "${ARG_SHARE:-n}" != "n" ]]; then
	device="-device virtio-9p-pci,fsdev=dev9p,mount_tag=share9p"
	fsdev="-fsdev local,id=dev9p,"
	fsdev=${fsdev}"path=${ARG_SHARE},security_model=none"
	QEMU_OPT_fsdev="${fsdev} ${device}"
fi

QEMU_OPT_append_console="console=ttyAMA0"
QEMU_OPT_append="-append \""
QEMU_OPT_append=${QEMU_OPT_append}"${QEMU_OPT_append_console}"
QEMU_OPT_append=${QEMU_OPT_append}" ${QEMU_OPT_append_root}"
QEMU_OPT_append=${QEMU_OPT_append}"\""

QEMU_OPT_machine="-machine vexpress-a15"
QEMU_OPT_cpu="-cpu cortex-a15"
QEMU_OPT_smp="-smp 2"
QEMU_OPT_m="-m 1024M"
QEMU_OPT_display="-display none"
QEMU_OPT_nographic="-nographic"

# concat all qemu options
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_machine}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_cpu}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_smp}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_m}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_display}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_nographic}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_kernel}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_dtb}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_initrd}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_driver}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_netdev}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_fsdev}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_append}"
QEMU_OPT=${QEMU_OPT}" ${QEMU_OPT_EXTRA}"

# QEMU command
QEMU_PRG=qemu-system-arm
QEMU_CMD="${QEMU_PRG} ${QEMU_OPT}"
echo ${QEMU_CMD}

# waiting for confirmation
echo
TMOUT=3
read -p "Continue in ${TMOUT} seconds? [Y/n]: " -t ${TMOUT} choice
if [[ $choice != "" && $choice != "y" && $choice != "Y" ]]; then
	echo "Cancel"
	exit 0
fi
echo

# run QEMU now
eval "${QEMU_CMD}"
