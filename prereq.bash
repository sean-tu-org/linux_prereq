#!/bin/bash

# last updated: 2024-06-21

enableVerbose="";

build_log_dir="logs";
buildlog="pre-req__`date +%Y%m%d\_%H%M%S`.log";

tmpRCFile="/tmp/tmp.$$";

# Setup secho (time stamped echo to stdout) routine without debug log writing.
secho () {
        tstamp=`date +%Y-%m-%d\ %H:%M\:%S 2>/dev/null`;
        echo "${tstamp} | $@" 2>/dev/null;
        }

CurrentPWD=$(pwd);
chkFPN=`echo "${build_log_dir}" 2>/dev/null | grep "^/" 2>/dev/null`;
if [ -z "${chkFPN}" ]; then
	build_log_dir="${CurrentPWD}/${build_log_dir}";
fi

echo "";
# Setup log directory if applicable
if [ -n "${build_log_dir}" ] && [ ! -d "${build_log_dir}" ]; then 

	build_log_dir=`echo ${build_log_dir} 2>/dev/null | sed 's/\/$//'`;

	tstamp=`date +%Y-%m-%d\ %H:%M\:%S 2>/dev/null`;
	secho "Log directory, '${build_log_dir}', does not exist.";
	secho "Attempting to create log directory, '${build_log_dir}'.";

	mkdir -p ${build_log_dir} 1>/dev/null 2>&1;
	mkdirRC=$?;
	if [ "${mkdirRC}" ne "0" ]; then
			secho "ERROR! Could not create log directory, '${build_log_dir}'!" 2>/dev/null;
	else
		tstamp=`date +%Y-%m-%d\ %H:%M\:%S 2>/dev/null`;
		echo "${tstamp} | Successfully created log directory, '${build_log_dir}'!" 1>${build_log_dir}/${buildlog} 2>/dev/null;
		echo "${tstamp} | Successfully created log directory, '${build_log_dir}'!" 
	fi
fi

WRITE_LOGFILE="${buildlog}";
if [ -d "${build_log_dir}" ]; then
	build_log_dir=`echo ${build_log_dir} 2>/dev/null | sed 's/\/$//'`;
	WRITE_LOGFILE="${build_log_dir}/${buildlog}";
fi


# Setup techo (time stamped echo to stdout) routine.
techo () {
        tstamp=`date +%Y-%m-%d\ %H:%M\:%S 2>/dev/null`;
        # write to debug build log first
        echo "${tstamp} | $@" 1>>${WRITE_LOGFILE} 2>/dev/null;
        # then write to stdout
        echo "${tstamp} | $@" 2>/dev/null;
        }

# Setup decho (time stamp echo to stderr for debug) routine.
decho () {
        tstamp=`date +%Y-%m-%d\ %H:%M\:%S 2>/dev/null`;
        # write to debug build log first
        echo "${tstamp} | $@" 1>>${WRITE_LOGFILE} 2>/dev/null;
        # then write to stderr
        echo "${tstamp} | $@" 1>&2;
        }

# Setup vecho (verbosed time stamp echo to stderr for verbosed debug messages) routine.
vecho () {
        if [ -n "${enableVerbose}" ]; then
                if [ "${enableVerbose}" != "0" ]; then
                        tstamp=`date +%Y-%m-%d\ %H:%M\:%S 2>/dev/null`;
                        # write to debug build log first
                        echo "${tstamp} | $@" 1>>${WRITE_LOGFILE} 2>/dev/null;
                        # then write to stderr
                        echo "${tstamp} | $@" 1>&2;
                fi
        fi
        }

# Exit
ExitError () {
	exitRC=$1;
	techo "Subroutine or function did not exit correctly.";
	techo "Exiting with code, '${exitRC}'.";
	exit ${exitRC};
	}

############################################################################################

VerifyRoot () {

	IsRootUser=`whoami 2>/dev/null | grep "^root$" 2>/dev/null`;
	if [ -z "${IsRootUser}" ]; then
		techo "Must be root user to run this or use 'sudo'".
		techo "Exiting with code 2.";
		ExitError 2;
	fi
	}

VerifyRoot;
tmpFilTS=`date +%Y%m%d%H%M%S 2>/dev/null`;

############################################################################################

OSNAME="Unknown";
if [ -f "/etc/os-release" ]; then
	OSNAME=`grep "^NAME=" /etc/os-release | sed 's/\"//g' | awk -F\= '{print $NF}'`;
fi
techo "OS: ${OSNAME}";

UPDATE_MODE="";
SUBMODE="";
if [ -f "/etc/redhat-release" ]; then
	UPDATE_MODE="RHEL";
	techo "Package update mode: ${UPDATE_MODE}";
elif [ -n `grep "ID_LIKE=debian" /etc/os-release` ] || [ -n `grep "ID_LIKE=ubuntu" /etc/os-release` ]; then
	UPDATE_MODE="DEBIAN";
	SUBMODE="DEBIAN";
	techo "Package update mode: ${UPDATE_MODE}";

	if [ -n `grep "ID_LIKE=ubuntu" /etc/os-release` ]; then
		SUBMODE="UBUNTU";
	elif [ -n `grep -i "^NAME=\"Ubuntu\"" /etc/os-release` ]; then
		SUBMODE="UBUNTU";
	fi
	techo "Package update sub-mode: ${SUBMODE}";		
fi

	


if [ "${UPDATE_MODE}" = "RHEL" ]; then
	
	#do system upgrade
	techo "Performing system update.";
	(/usr/bin/yum -y update 2>&1 && yumRC=$? && echo "[EXIT_CODE] ${yumRC}") | while read stdout;
	do
		chkforRC=`echo "${stdout}" 2>/dev/null | grep "^\[EXIT_CODE]" 2>/dev/null`;
		if [ -n "${chkforRC}" ]; then
			exitCode=`echo "${chkforRC}" 2>/dev/null | awk '{print \$2}' 2>/dev/null`;
			#echo "exitCode: ${exitCode}";
			echo "${exitCode}" 1>${tmpRCFile}.${tmpFilTS} 2>/dev/null;
		else
			techo "${stdout}"
		fi

	done;
	ExitCode=59;
	if [ -f "${tmpRCFile}.${tmpFilTS}" ]; then
		ExitCode=`cat ${tmpRCFile}.${tmpFilTS} 2>/dev/null | grep "^[0-9]" 2>/dev/null | tail -1 2>/dev/null`;
		techo "Exit Code was: '${ExitCode}'";
		rm -f ${tmpRCFile}.${tmpFilTS} 1>/dev/null 2>&1;
	fi
	if [ "${ExitCode}" != "0" ]; then
		ExitError ${ExitCode};
	fi
	techo "System update completed.";


	techo "Installing pre-requisite packages.";

	#PACKAGES_LIST="apr-util-devel autoconf automake curl expat-devel gcc gcc-c++ gdbm-devel libdb-devel libffi-devel libtool libxml2-devel make ncurses-devel nss-devel openssl openssl-devel pcre2-devel perl perl-core perl-devel python3 python3-devel readline-devel wget zlib-devel";
	# Removed from list due to not found issues: gdbm-devel libdb-devel

	PACKAGES_LIST="apr-util-devel autoconf automake curl expat-devel gcc gcc-c++ gdbm-devel libdb-devel libffi-devel libtool libxml2-devel make ncurses-devel nss-devel openssl openssl-devel pcre2-devel perl perl-core perl-devel python3 python3-devel readline-devel wget zlib-devel";

	#do install pre-req packages.
	(/usr/bin/yum -y install ${PACKAGES_LIST} 2>&1 && yumRC=$? && echo "[EXIT_CODE] ${yumRC}") | while read stdout;
	do
		chkforRC=`echo "${stdout}" 2>/dev/null | grep "^\[EXIT_CODE]" 2>/dev/null`;
		if [ -n "${chkforRC}" ]; then
			exitCode=`echo "${chkforRC}" 2>/dev/null | awk '{print \$2}' 2>/dev/null`;
			#echo "exitCode: ${exitCode}";
			echo "${exitCode}" 1>${tmpRCFile}.${tmpFilTS} 2>/dev/null;
		else
			techo "${stdout}"
		fi

	done;
	ExitCode=59;
	if [ -f "${tmpRCFile}.${tmpFilTS}" ]; then
		ExitCode=`cat ${tmpRCFile}.${tmpFilTS} 2>/dev/null | grep "^[0-9]" 2>/dev/null | tail -1 2>/dev/null`;
		techo "Exit Code was: '${ExitCode}'";
		rm -f ${tmpRCFile}.${tmpFilTS} 1>/dev/null 2>&1;
	fi
	if [ "${ExitCode}" != "0" ]; then
		ExitError ${ExitCode};
	fi
	
	techo "Installed pre-requisite packages.";


# Debian based distro 
elif [ "${UPDATE_MODE}" = "DEBIAN" ]; then

	techo "";
	if [ -n "`grep \"^deb cdrom\" /etc/apt/sources.list`" ]; then
		techo "[ERROR] It appears you have a CDROM source in /etc/apt/sources.list.";
		techo "[ERROR] Script has issues with calling APT with this.";
		techo "[ERROR] Here's the line(s) from /etc/apt/sources.list:";
		techo "[ERROR] ('grep \"^deb cdrom\" /etc/apt/sources.list')";
		grep -n "^deb cdrom" /etc/apt/sources.list | while read line
		do
			techo "[ERROR]	Line=${line}";
		done
		techo "[ERROR] Before running this again please comment these out.";
		ExitError 9;
	fi

	techo "Performing system update.";
	techo "";
	#check for latest updates and update local DB 
	(/usr/bin/apt update 2>&1; aptRC=$?; echo "[EXIT_CODE] ${aptRC}") | while read stdout;
	do
		chkforRC=`echo "${stdout}" 2>/dev/null | grep "^\[EXIT_CODE]" 2>/dev/null`;
		if [ -n "${chkforRC}" ]; then
			exitCode=`echo "${chkforRC}" 2>/dev/null | awk '{print \$2}' 2>/dev/null`;
			techo "Captured apt update exitCode: ${exitCode}";
			echo "${exitCode}" 1>${tmpRCFile}.${tmpFilTS} 2>/dev/null;
		fi
		techo "${stdout}"
	done;
	ExitCode=59;
	if [ -f "${tmpRCFile}.${tmpFilTS}" ]; then
		ExitCode=`cat ${tmpRCFile}.${tmpFilTS} 2>/dev/null | grep "^[0-9]" 2>/dev/null | tail -1 2>/dev/null`;
		techo "Exit Code was: '${ExitCode}'";
		rm -f ${tmpRCFile}.${tmpFilTS} 1>/dev/null 2>&1;
	fi
	if [ "${ExitCode}" != "0" ]; then
		ExitError ${ExitCode};
	fi
	###
	

	#do system upgrade
	techo "";
	(/usr/bin/apt upgrade -y 2>&1 && aptRC=$? && echo "[EXIT_CODE] ${aptRC}") | while read stdout;
	do

		chkforRC=`echo "${stdout}" 2>/dev/null | grep "^\[EXIT_CODE]" 2>/dev/null`;
		if [ -n "${chkforRC}" ]; then
			exitCode=`echo "${chkforRC}" 2>/dev/null | awk '{print \$2}' 2>/dev/null`;
			#echo "exitCode: ${exitCode}";
			echo "${exitCode}" 1>${tmpRCFile}.${tmpFilTS} 2>/dev/null;
		else
			techo "${stdout}"
		fi

	done;
	ExitCode=59;
	if [ -f "${tmpRCFile}.${tmpFilTS}" ]; then
		ExitCode=`cat ${tmpRCFile}.${tmpFilTS} 2>/dev/null | grep "^[0-9]" 2>/dev/null | tail -1 2>/dev/null`;
		techo "Exit Code was: '${ExitCode}'";
		rm -f ${tmpRCFile}.${tmpFilTS} 1>/dev/null 2>&1;
	fi
	if [ "${ExitCode}" != "0" ]; then
		ExitError ${ExitCode};
	fi

	techo "System update completed.";
	techo "";
	techo "Installing pre-requisite packages.";
	
	PACKAGES_LIST="build-essential perl libperl-dev libssl-dev libdb-dev python3 zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libreadline-dev libffi-dev wget libexpat-dev libpcre3-dev libapr1-dev libaprutil1-dev libxml2-dev python3-dev";
	if [ "${SUBMODE}" = "UBUNTU" ]; then
		techo "Using package names for ${SUBMODE}.";	
		PACKAGES_LIST="build-essential perl libperl-dev libssl-dev libdb-dev python3 zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libreadline-dev libffi-dev wget libexpat-dev libpcre3-dev libapr1-dev libaprutil1-dev libxml2-dev python3-dev";
	
	elif [ "${SUBMODE}" = "DEBIAN" ]; then
		techo "Using package names for ${SUBMODE}.";
		PACKAGES_LIST="build-essential perl libperl-dev libssl-dev libdb-dev python3 zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libreadline-dev libffi-dev wget libexpat-dev libpcre3-dev libapr1-dev libaprutil1-dev libxml2-dev python3-dev";
	else
		techo "Using package names for other Debian/Ubuntu distribution.";
	fi


	#do installtion of pre-requisites
	techo "";
	(/usr/bin/apt ${WORKAROUND} install -y ${PACKAGES_LIST} 2>&1 && aptRC=$? && echo "[EXIT_CODE] ${aptRC}") | while read stdout;
	do
		chkforRC=`echo "${stdout}" 2>/dev/null | grep "^\[EXIT_CODE]" 2>/dev/null`;
		if [ -n "${chkforRC}" ]; then
			exitCode=`echo "${chkforRC}" 2>/dev/null | awk '{print \$2}' 2>/dev/null`;
			#echo "exitCode: ${exitCode}";
			echo "${exitCode}" 1>${tmpRCFile}.${tmpFilTS} 2>/dev/null;
		else
			techo "${stdout}"
		fi
	done;
	ExitCode=59;
	if [ -f "${tmpRCFile}.${tmpFilTS}" ]; then
		ExitCode=`cat ${tmpRCFile}.${tmpFilTS} 2>/dev/null | grep "^[0-9]" 2>/dev/null | tail -1 2>/dev/null`;
		techo "Exit Code was: '${ExitCode}'";
		rm -f ${tmpRCFile}.${tmpFilTS} 1>/dev/null 2>&1;
	fi
	if [ "${ExitCode}" != "0" ]; then
		ExitError ${ExitCode};
	fi

	techo "Installed pre-requisite packages.";

fi




techo "Installing pre-requisites for ${OSNAME} completed."
echo "";
exit 0;
 
