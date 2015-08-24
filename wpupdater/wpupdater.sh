#!/bin/bash
# This script is a simple tool for removing a large amount of files quickly and safely.
author="Dan Pock"
ver="0.0.1 alpha"
progFolder="/root/scripts/wpupdater"
progMD5="/root/scripts/wpupdater/wpupdater.md5"
tempFolder="/home/temp/wpupdater"
temp="${tempFolder}/failtemp"
ftemp="${tempFolder}/ftemp"
dtemp="${tempFolder}/dtemp"
utemp="${tempFolder}/utemp"
ltemp="${tempFolder}/ltemp"

# Vars
DEBUG=0
SKIP=0
liveVer=`curl -s 'https://api.wordpress.org/core/version-check/1.7/?latest'|grep -Po '"current":.*?[^\\\]",'|head -1|cut -d'"' -f4`
wpSRC="https://wordpress.org/latest.tar.gz"
wpSRCmd5="https://wordpress.org/latest.tar.gz.md5"
wpSRCzip="https://wordpress.org/latest.zip"
wpSRCzipmd5="https://wordpress.org/latest.zip.md5"
webColor="https://raw.githubusercontent.com/MallardDuck/rmsafe/safeColor/rmsafe/colors?token=AAl1ohgbNeMspd4YzW4X7HglIGQ1ZSZXks5V42q_wA%3D%3D"
webMD5="https://raw.githubusercontent.com/MallardDuck/rmsafe/safeColor/rmsafe/colors?token=AAl1ohgbNeMspd4YzW4X7HglIGQ1ZSZXks5V42q_wA%3D%3D"
sshIP=`echo $SSH_CLIENT|awk '{print$1}'`
DATE=`date +%y%m%d%H%S`
color="${progFolder}/colors"

# init function
prep() {
  if [ ! -d "${progFolder}" ]; then
    mkdir -p ${progFolder} 
    wget -o /dev/null --output-document ${color} ${webColor} > /dev/null
    wget -o /dev/null --output-document ${progMd5} ${webMD5} > /dev/null
  fi 
  if [ -d "${tempFolder}" ]; then
    rm -rf ${tempFolder};
  fi
  if [ ! -d "${tempFolder}" ]; then
    mkdir -p ${tempFolder};
  fi
  echo "Prep Done. Temps Cleared";
}

# First run
if [ ! -d "${progFolder}" ]; then
  prep
fi
if [ -d "${progFolder}" ]; then
  if [ ! -f "${progMD5}" ]; then
    echo "Program folder exists but not the MD5 file"
    #rm -rf ${progFolder}
    #prep
    echo "Doing nothing; will now exit."
    exit;
  fi
fi

# Function to catch the priority flags.
while getopts ":u:t:hpaldsu" opt; do
  case "${opt}" in
    s)
      SKIP=1
    ;;
    d)
      DEBUG=1
      echo "Debugging Enabled"
    ;;
  esac
done;

# Debug for web versions
if [[ ${DEBUG} -eq "1" ]]; then
  echo "The web version is: ${liveVer}";
fi


# Hash Check
#   If the has of this script doesn't checkout then
#   the script should kill itself to prevent issues.
valHash=`cat ${progMD5}|cut -d" " -f1`
liveHash=`md5sum ${progFolder}/wpupdater.sh|cut -d" " -f1`
if [[ ${DEBUG} -eq "1" ]]; then
  echo "The live hash is: ${liveHash}";
  echo "The comparing hash is: ${valHash}";
fi
if [ "${valHash}" == "${liveHash}"  ]; then
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The Hashs match each other; the program will proceed";
  fi
elif [ "${valHash}" != "${liveHash}"  ]; then
    echo "There is a Hash mismatch; exiting now."
    echo "In the future you might be able to skip this with a flag."
    if [[ ${SKIP} -eq "0" ]]; then
      exit;
    fi
    if [[ ${SKIP} -eq "1" ]]; then
      echo "Hash validation being skipped; proceeding.";
    fi
else  
  echo "Something very odd occured; exiting."
  echo "This can be reported to: dpock@liquidweb.com"
  echo "Please provdie at least the following info: `date;hostname;w;pwd;`"
  exit;
fi;

# Imports
. ${color}

# Determine the IP to be used
if [ -z "${sshIP}" ]; then
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "No SSH IP; setting to Local."
  fi
  AIP="127.0.0.1"
else
  AIP=${sshIP} 
fi

# Header
header() {
        echo -e "${blue}Easy WPupdater v$ver"
        echo "         (C) 2015, Dan Pock <dpock@liquidweb.com>, LiquidWeb"
        echo -e "${bcyan}This program may be freely redistributed under the terms of the GNU GPL v2"
        echo ""
        echo -e ${On_Purple}${bblack}${line}${esc}
}

# Usage function
usage() {
    echo -e "${bblue}Usage:${bcyan}"
    echo -e "  wpupdater.sh [options] location"
    echo ""
    echo -e "${bblue}  Options:${bcyan}"
    echo -e "    -t - Runs the script in test mode. [DRYRUN mode]"
    echo -e "    -u - Runs the script in active mode."
    echo -e "    -f - Finds and displays WordPress instances that were found."
    echo -e "    -h - Prints the header and help info."
    echo ""
    echo -e "${bblue}Example:${bcyan}"
    echo -e "      wpupdater.sh -f /home/cpuser/public_html/blog"
    echo -e "${esc}"
    exit 1
}

# function to check if a directoyr exists
function exists {
if [[ -d $1 ]]; then
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "$1 is a directory"
  fi
elif [[ -L $1 ]]; then
    echo -e "${byellow}$1 is a link."
    echo -e "${esc}"
    exit 1
elif [[ -f $1 ]]; then
    echo -e "${bgreen}$1 is a file."
    echo -e "${esc}"
    exit 1
else
    echo -e "${On_Purple}${bred}$1 is not valid"
    echo -e "${esc}"
    exit 1
fi
}

# Saving this incase we need it
countDis(){
  ecnt=$(($1+1))
}

###############################
#                             #
# Script specific code starts #
#                             #
###############################

# checks if folder has structure to match a WP install
function wpCheck {
  wpValid=0;
  echo "Starting WordPress check on: $1"
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "doing a check for wp-admin"  
  fi
  if [[ -d $1/wp-admin ]]; then
    wpValid=1;
  fi

  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The wp-admin results are [1]: ${wpValid}"  
    echo "doing a check for wp-include"  
  fi
  if [[ -d $1/wp-includes ]]; then
    wpValid=2;
  fi

  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The wp-includes results are [2]: ${wpValid}"  
    echo "doing a check for both wp-admin & wp-include"  
  fi
  if [[ -d $1/wp-admin ]] & [[ -d $1/wp-includes ]]; then
    wpValid=3;
  fi
  echo "This will have done things and it will report back"
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The results for both are [3]: ${wpValid}"  
    echo "The overall results are [3]: ${wpValid}"  
  fi
  if [[ ${wpValid} -eq "4" ]]; then
    echo "Invalid value retuned for wpValid; exiting."
    exit
  fi
  if [[ ${wpValid} -eq "0" ]] & [[ ${wpValid} -eq "1" ]] & [[ ${wpValid} -eq "2" ]]; then
    echo "Seems to be missing one of the core folders; exiting."
    exit
  fi
  if [[ ${wpValid} -eq "3" ]]; then
    echo "I think we found a valid WordPress, checking version now."
    if [[ ${DEBUG} -eq "1" ]]; then
      echo "Checking ${1}wp-includes/version.php for the version."  
    fi
    wpVersion $1
  fi
}

# the wpValid variable will have a few states
# 0 = default [Nothing has been checked]
# 1 = found the wp-admin folder
# 2 = found the wp-include folder
# 3 = found both wp-{admin,include} folders
# 4 = ERROR: You've gone too far!

# checks if the install has a valid version file
function wpVersion {
  echo "This will check the version of WordPress in the directory"
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The dir being checked: ${1}"  
  fi
  if [[ -d "${1}wp-includes/" ]]; then
    liveVer=`grep "wp_version" ${1}wp-includes/version.php|grep =|cut -d"'" -f2`
    echo "Found version: ${liveVer}";
  fi
  webVer="";
}

# Any script code should be declared above this.
OPTIND=1;
# Anything in the case above has priority over flags below
while getopts ":u:t:hpaldsu" opt; do
  case "${opt}" in
    u)
      header;
      LOCATION=${OPTARG}
      exists $LOCATION;
      echo "The directory: ${LOCATION} is a thing.";
      wpCheck $LOCATION;
    ;;
    t)
      header;
      LOCATION=${OPTARG}
      exists $LOCATION;
      echo "The directory: ${LOCATION} is a thing.";
      wpCheck $LOCATION;
    ;;
    h)
      header;
    ;;
    p)
      header;
    ;;
    a)
      header;
    ;;
    l)
      header;
    ;;
    \?)
      header;
      echo "Invalid option: -$OPTARG" >&2
      usage;
      exit 1
    ;;
    :)
      header;
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
    ;;
  esac
done;

[ -z $1 ] && { header;usage; }
