#!/bin/bash
# This script is a simple tool for quickly updating or fixing WordPress core files.
author="Dan Pock"
ver="0.0.7 alpha"
progFolder="/root/scripts/wpupdater"
progMD5="/root/scripts/wpupdater/wpupdater.sh.md5"
tempFolder="/home/temp/wpupdater"
temp="${tempFolder}/failtemp"

# Vars
DEBUG=0
SKIP=0
latestStaged=0;
liveVer=`curl -s 'https://api.wordpress.org/core/version-check/1.7/?latest'|grep -Po '"current":.*?[^\\\]",'|head -1|cut -d'"' -f4`
wpSRC="https://wordpress.org/latest.tar.gz"
wpSRCmd5="https://wordpress.org/latest.tar.gz.md5"
wpSRCzip="https://wordpress.org/latest.zip"
wpSRCzipmd5="https://wordpress.org/latest.zip.md5"
webColor="https://raw.githubusercontent.com/MallardDuck/rmsafe/safeColor/rmsafe/colors?token=AAl1ohgbNeMspd4YzW4X7HglIGQ1ZSZXks5V42q_wA%3D%3D"
webMD5="https://grandmascookieblog.com/wpupdater/wpupdater.sh.md5"
sshIP=`echo $SSH_CLIENT|awk '{print$1}'`
DATE=`date +%y%m%d%H%S`
color="${progFolder}/colors"


# Function to catch the priority flags.
while getopts ":u:t:hds" opt; do
  case "${opt}" in
    s)
      SKIP=1
      echo "Skiping self hash check"
    ;;
    t)
      TEST=1
    ;;
    d)
      DEBUG=1
      echo "Debugging Enabled"
    ;;
  esac
done;

# clear temps
clearTemp() {
  if [ -d "${tempFolder}" ]; then
    rm -rf ${tempFolder};
  fi
  if [ ! -d "${tempFolder}" ]; then
    mkdir -p ${tempFolder};
  fi
}
clearTemp;

# init function
prep() {
  if [ ! -d "${progFolder}" ]; then
    mkdir -p ${progFolder} 
    wget -o /dev/null --output-document ${color} ${webColor} > /dev/null
    wget -o /dev/null --output-document ${progMd5} ${webMD5} > /dev/null
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


# Debug for web versions
if [[ ${DEBUG} -eq "1" ]]; then
  echo "The web version is: ${liveVer}";
fi

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
        echo "         (C) 2015, Dan Pock <dpock@liquidweb.com>, LiquidWeb, Inc."
        echo -e "${bcyan}This program may be freely redistributed under the terms of the GNU GPL v2"
        echo ""
        echo -e ${bgreen}${line}${esc}
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
    echo -e "    -s - Skips the MD5 checking of this script."
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
  echo -e "${bcyan}Starting WordPress check on: ${esc}$1"
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "Doing a check for wp-admin"  
  fi
  if [[ -d $1/wp-admin ]]; then
    wpValid=1;
  fi

  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The wp-admin results are [1]: ${wpValid}"  
    echo "Doing a check for wp-include"  
  fi
  if [[ -d $1/wp-includes ]]; then
    wpValid=2;
  fi

  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The wp-includes results are [2]: ${wpValid}"  
    echo "Doing a check for both wp-admin & wp-include"  
  fi
  if [[ -d $1/wp-admin ]] & [[ -d $1/wp-includes ]]; then
    wpValid=3;
    if [[ -f $1/wp-config.php ]]; then
      wpValid=4;
      cpUser=`ls -l ${1}/wp-config.php|awk '{print $3"."$4}'`
    fi
  fi
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The overall results are [3/4]: ${wpValid}"  
  fi
  if [[ ${wpValid} -eq "5" ]]; then
    echo "Invalid value retuned for wpValid; exiting."
    exit
  fi
  if [[ ${wpValid} -eq "0" ]] || [[ ${wpValid} -eq "1" ]] || [[ ${wpValid} -eq "2" ]]; then
    echo "Seems to be missing one, or more, of the core folders; exiting."
    exit
  fi
  if [[ ${wpValid} -eq "3" ]] || [[ ${wpValid} -eq "4" ]]; then
    echo -e "${bgreen}I think we found a valid WordPress, checking version now.${esc}"
    if [[ ${DEBUG} -eq "1" ]]; then
      echo "Checking ${1}/wp-includes/version.php for the version"  
    fi
    wpVersion $1
  fi
}

# the wpValid variable will have a few states
# 0 = default [Nothing has been checked]
# 1 = found the wp-admin folder
# 2 = found the wp-include folder
# 3 = found both wp-{admin,include} folders
# 4 = found both and wp-config.php
# 5 = ERROR: You've gone too far!

# checks if the install has a valid version file
function wpVersion {
  echo -e "${bblue}Checking the version of WordPress...${esc}"
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "First we check if it exists and then the version: ${1}"  
  fi
  if [[ -f "${1}/wp-includes/version.php" ]]; then
    if [[ ${DEBUG} -eq "1" ]]; then
      echo "The version file exists: ${1}/wp-includes/version.php"  
    fi
    if [[ ${wpValid} -eq "2" ]] || [[ ${wpValid} -eq "3" ]] || [[ ${wpValid} -eq "4" ]]; then
      curVer=`grep "wp_version" ${1}/wp-includes/version.php|grep =|cut -d"'" -f2`
      if [[ `echo ${curVer}|cut -d"." -f1` -lt `echo ${liveVer}|cut -d"." -f1` ]];then
        echo -e "${cyan}Found local version:  ${bred}${curVer}${esc}";
      elif [[ `echo ${curVer}|cut -d"." -f1` -eq `echo ${liveVer}|cut -d"." -f1` ]] & [[ `echo ${curVer}|cut -d"." -f2` -lt `echo ${liveVer}|cut -d"." -f2` ]];then
        echo -e "${cyan}Found local version:  ${bred}${curVer}${esc}";
      else
        echo -e "${cyan}Found local version:  ${green}${curVer}${esc}";
      fi
      if [[ `echo ${curVer}|cut -d"." -f1` -lt `echo ${liveVer}|cut -d"." -f1` ]];then
        echo -e "${cyan}The 'latest' version: ${bblue}${liveVer}${esc}";
      elif [[ `echo ${curVer}|cut -d"." -f1` -eq `echo ${liveVer}|cut -d"." -f1` ]] & [[ `echo ${curVer}|cut -d"." -f2` -lt `echo ${liveVer}|cut -d"." -f2` ]];then
        echo -e "${cyan}The 'latest' version: ${bblue}${liveVer}${esc}";
      else
        echo -e "${cyan}The 'latest' version: ${green}${liveVer}${esc}";
      fi
    fi
  fi
  # After this we will do some logic to compare the version
  # it will also provide choices on how to proceed.
  if [[ ${curVer} == ${liveVer} ]];then
    if [[ ${DEBUG} -eq "1" ]]; then
      echo "The version found and that in 'latest' are the same."
    fi
  else
    echo -e "${cyan}The versions are different.${esc}"
  fi
}

# BACKUP: staging wordpress files
function stagingFallback {
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "Fallback stage the new WordPress zip."
    echo "Cleaning up the tar first."
  fi
  rm ${tempFolder}/latest.tar.gz
  # Pull the zip file 
  if [[ ${TEST} -ne "1" ]]; then
    wget -o /dev/null --output-document ${tempFolder}/latest.zip ${wpSRCzip} > /dev/null
  fi
  localMD5=`md5sum ${tempFolder}/latest.zip|cut -d" " -f1`
  webMD5=`curl -s ${wpSRCzipmd5}`
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The downloaded MD5: ${localMD5}."
    echo "The comparison MD5: ${webMD5}."
  fi
  if [[ ${localMD5} == ${webMD5} ]];then
    echo -e "${bgreen}Downloaded 'latest.zip' and the hash checked out.${esc}"
    # Extracting contents
    if [[ ${TEST} -ne "1" ]]; then
      unzip ${tempFolder}/latest.zip -d  ${tempFolder} > /dev/null
    fi
    latestStaged=1;
  else
    echo -e "${bred}Downloaded 'latest.zip' and the hash didn't match.${esc}"
    rm ${tempFolder}/latest.zip
    echo "Cleaned up the files"
    exit;
  fi  
}

# stages the wordpress files to be updated
function staging {
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "Now we stage the new WordPress files."
  fi
  # Pull the tar file 
  wget -o /dev/null --output-document ${tempFolder}/latest.tar.gz ${wpSRC} > /dev/null
  localMD5=`md5sum ${tempFolder}/latest.tar.gz|cut -d" " -f1`
  webMD5=`curl -s ${wpSRCmd5}`
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The downloaded MD5: ${localMD5}."
    echo "The comparison MD5: ${webMD5}."
  fi
  if [[ ${localMD5} == ${webMD5} ]];then
    echo -e "${bgreen}Downloaded 'latest.tar.gz' and the hash checked out.${esc}"
    # Extracting contents
    if [[ ${TEST} -ne "1" ]]; then
      tar xvzf ${tempFolder}/latest.tar.gz -C ${tempFolder} > /dev/null
    fi
    latestStaged=1;
  else
    echo "Downloaded 'latest.tar.gz' and the hash didn't match."
    echo "Will attempt to fall back to zip before failing."
    if [[ ${TEST} -ne "1" ]]; then
      stagingFallback;
    fi
  fi  
}

# makes a quick backup of the WP core folders 
function backUp {
read -p "Are you sure you would like to proceed?: [Yes/No]" yn
case $yn in
  [Yy]* ) echo "Will now continue.";;
  [Nn]* ) echo "Thanks, now exiting.";exit;;
  * ) echo "Please answer yes or no.";;
esac
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "Now we backup the current WP core files/folders."
    echo "The dir being backed up are: ${1}wp-{admin,includes}"
  fi
  if [[ ${wpValid} -eq "3" ]] || [[ ${wpValid} -eq "4" ]]; then
    echo -e "${cyan}Backing up each WP core folder to dir.bak${esc}"
    if [[ ${TEST} -ne "1" ]]; then
      echo "Backing up wp-admin"
      mv ${1}/wp-admin{,.${DATE}.old};
      echo "Backing up wp-includes"
      mv ${1}/wp-includes{,.${DATE}.old};
    fi
  fi
}

# updates the files as needed
function updateFiles {
if [[ ${latestStaged} -eq "1" ]]; then
  if [[ ${wpValid} -eq "3" ]] || [[ ${wpValid} -eq "4" ]]; then
    echo -e "${bcyan}Updating each WP core folder${esc}"
    echo -e "${byellow}The ownership will be: ${esc}${cpUser}";
    if [[ ${DEBUG} -eq "1" ]]; then
      echo -e "${byellow}Updating files into ${esc}${LOCATION}"
    fi
    if [[ ${TEST} -ne "1" ]]; then
      echo -e "${cyan}Replacing ${bred}wp-admin${esc}"
      mv ${tempFolder}/wordpress/wp-admin ${LOCATION};
      chown -R ${cpUser} ${LOCATION}/wp-admin;
      echo -e "${cyan}Replacing ${bred}wp-includes${esc}"
      mv ${tempFolder}/wordpress/wp-includes ${LOCATION};
      chown -R ${cpUser} ${LOCATION}/wp-includes;
      echo -e "${bgreen}SUCCESS: ${On_ICyan}The files have now been updated/replaced!${esc}";
    fi
    if [[ ${TEST} -eq "1" ]]; then
      echo "Acutally doing nothing since this is testing mode.";
      echo "Exiting now."
    fi
  fi
else
  echo -e "${bred}FAILURE: ${On_Yellow}The files were not staged properly; cannot proceed.${esc}";
  exit;
fi
}

# Any script code should be declared above this.
OPTIND=1;
# Anything in the case above has priority over flags below
while getopts ":u:t:hsd" opt; do
  case "${opt}" in
    u)
      header;
      LOCATION=${OPTARG}
      exists $LOCATION;
      if [[ ${DEBUG} -eq "1" ]]; then
        echo "The directory being checked is: ${LOCATION}";
      fi
      wpCheck $LOCATION;
      staging
      backUp $LOCATION;
      updateFiles;
    ;;
    t)
      header;
      LOCATION=${OPTARG}
      exists $LOCATION;
      if [[ ${DEBUG} -eq "1" ]]; then
        echo "The directory being checked is: ${LOCATION}";
      fi
      wpCheck $LOCATION;
      staging
      backUp $LOCATION;
      updateFiles;
    ;;
    h)
      header;
      usage;
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

[ -z $1 ] && { SKIP=1;header;usage; }

# Hash Check
#   If the has of this script doesn't checkout then
#   the script should kill itself to prevent issues.
#   Moved here for better functionality
valHash=`cat ${progMD5}|cut -d" " -f1`
liveHash=`md5sum ${progFolder}/wpupdater.sh|cut -d" " -f1`
if [[ ${DEBUG} -eq "1" ]]; then
  echo "The current hash is: ${liveHash}";
  echo "The expect. hash is: ${valHash}";
fi
if [ "${valHash}" == "${liveHash}"  ]; then
  if [[ ${DEBUG} -eq "1" ]]; then
    echo "The Hashs match each other; the program will proceed";
  fi
elif [ "${valHash}" != "${liveHash}"  ]; then
    echo "There is a Hash mismatch."
    # Need to add some fall back code that will attempt to pull the hash file,
    # recheck compared to the new file and then proceed as needed.
    #wget -o /dev/null --output-document ${progMd5} ${webMD5} > /dev/null
    if [[ ${SKIP} -eq "0" ]]; then
      echo "In the future you might be able to skip this with a flag."
      echo "Exiting now."
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

