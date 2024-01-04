#!/bin/bash
#
# MIT License
#
# Copyright (c) 2023 Rick Hoppe
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# VSX Export script v1.3
#
# Version History
# 0.1    Initial script
# 0.2    Display status on screen
# 0.3    Implemented new method to find Virtual System IDs
# 0.4    Extra Clish commands added to Clish script
#        Added Affinity + Multi-Queue settings
# 0.5    Modified output format (splitted conf and log files)
# 0.6    Rewritten backup of VSes other than VS0
# 0.7    Fix: -i option added to Clish batch command to ignore failures
# 0.8    Fix: Cleanup temporary files
#        Added "set virtual-system" to export of Clish config per Virtual System
# 0.8.1  Export Clish config of all Virtual Systems (other than VS0) to VS-all.config
# 0.9    Added support for 3.10 kernel
# 0.9.1  Implemented some "QA" fixes before 1.0 release of this script
# 1.0    Public release 1.0
# 1.0.1  Output of other Virtual Systems now have same style as output of VS0
# 1.0.2  Added commands starting with "set prefix-" to export of Clish config per Virtual System
# 1.0.3  Added commands starting with "set bootp" to export of Clish config per Virtual System
# 1.0.4  Added commands starting with "set route-redistribution" to export of Clish config per Virtual System
# 1.0.5  Added commands starting with "add arp" to export of Clish config per Virtual System
#        Added commands starting with "set max-path-splits" to export of Clish config per Virtual System
#        Added commands starting with "set inbound-route-filter" to export of Clish config per Virtual System
#        Added commands starting with "set pbr" to export of Clish config per Virtual System
#        Minor change in CoreXL status check
# 1.1    Added self-update mechanism
# 1.2    Added status of Dynamic Balancing
#        Added status of SecureXL Fast Accelerator
#        Log information about interfaces
# 1.3    Log active proxy ARP entries per Virtual System



#====================================================================================================
# Global variables
#====================================================================================================
if [[ -e /etc/profile.d/CP.sh ]]; then
    source /etc/profile.d/CP.sh
fi


if [[ -e /etc/profile.d/vsenv.sh ]]; then
    source /etc/profile.d/vsenv.sh
fi



#====================================================================================================
# Variables
#====================================================================================================
HOSTNAME=$(hostname -s)
DATE=$(date +%Y%m%d-%H%M%S)
VERSION="1.3"
OUTPUTDIR="$HOSTNAME/$DATE"
KERNVER=$(uname -r | awk -F. '{print $1 "." $2}')
SCRIPT_URL="https://raw.githubusercontent.com/Rick-Hoppe/vsxexport/main/vsxexport.sh"
SCRIPT_LOCATION="${BASH_SOURCE[@]}"
UPDATER="updater.sh"



#====================================================================================================
# Environment checks
#====================================================================================================
ISVSX=`$CPDIR/bin/cpprod_util FwIsVSX`
if [[ ! $ISVSX -eq 1 ]]; then
    printf "This script is only supported on VSX\n"
    exit 1
fi

CLCHK=$(clish -c exit)
if [[ ! -z "$CLCHK" ]]; then
    printf "Clish returns error: $CLCHK\n"
    printf "Please resolve this before executing the script again.\n\n"
    exit 1
fi

CPVER=$(clish -c "show version product" | sed 's/.*R//' | awk -F. '{print "R" $1 "." $2}')
if [[ $CPVER != *"R8"* ]]; then
    printf "This script is only supported on VSX with R80.10 and higher\n"
    exit 1
fi

if [[ -f $UPDATER ]]; then
   rm -f $UPDATER
fi


#====================================================================================================
# Colors
#====================================================================================================
txt_reset=$(tput sgr0)
txt_red=$(tput setaf 1)
txt_green=$(tput setaf 2)
txt_yellow=$(tput setaf 3)



#====================================================================================================
#  Functions to show results of checks
#====================================================================================================
check_passed()
{
    printf "${txt_green} OK${txt_reset}\t\t|\n"
}

check_failed()
{
    printf "${txt_red} FAILED${txt_reset}\t|\n"
}

check_enabled()
{
    printf "${txt_green} ENABLED${txt_reset}\t|\n"
}

check_disabled()
{
    printf "${txt_yellow} DISABLED${txt_reset}\t|\n"
}

check_notsupported()
{
    printf "${txt_green} NOT SUPPORTED${txt_reset}\t|\n"
}



#====================================================================================================
# Update function
#====================================================================================================
update()
{
    TMP_FILE=$(mktemp -p "" "XXXXXXXXX.sh")
    printf "Checking for updates..."
    curl_cli -s -k -L "$SCRIPT_URL" > "$TMP_FILE"
    WEBOK=$(echo $?)

    if [[ ! $WEBOK -eq 0 ]]; then
        printf "FAILED\n\n"
    else
    NEW_VER=$(grep "^VERSION" "$TMP_FILE" | awk -F'[="]' '{print $3}')
    ABS_SCRIPT_PATH=$(readlink -f "$SCRIPT_LOCATION")
     if [ "$VERSION" != "$NEW_VER" ]; then
        printf "Updating script \e[31;1m%s\e[0m -> \e[32;1m%s\e[0m\n" "$VERSION" "$NEW_VER"
        echo "cp \"$TMP_FILE\" \"$ABS_SCRIPT_PATH\"" > $UPDATER
        echo "rm -f \"$TMP_FILE\"" >> $UPDATER
        echo "echo" >> $UPDATER
        echo "echo Restarting script..." >> $UPDATER
        echo "sleep 2" >> $UPDATER
        echo "exec \"$ABS_SCRIPT_PATH\" \"$@\"" >> $UPDATER
        chmod +x "$UPDATER"
        chmod +x "$TMP_FILE"
        exec ./$UPDATER
     else
        printf "Version is up-to-date\n\n"
        rm -f "$TMP_FILE"
     fi
    fi
}



#====================================================================================================
# It's time to show something to the world...
#====================================================================================================
vsenv 0 > /dev/null 2>&1
clear
printf "vsxexport.sh $VERSION\n\n"
update "$@"

mkdir -p $OUTPUTDIR
mkdir -p $OUTPUTDIR/VS0
printf "Detected Check Point VSX ${CPVER%.} with $KERNVER kernel...\n"

if [[ "$CPVER" == "R80.10" && $(vs_bits -stat) == *"32"* ]];then
    printf "64-bit Virtual System Support configured: No\n"
elif [[ "$CPVER" == "R80.10" && $(vs_bits -stat) == *"32"* ]];then
    printf "64-bit Virtual System Support configured: Yes\n"
fi



#====================================================================================================
# Print table header
#====================================================================================================
printf "\n+=======================+=======================================+===============+\n"
printf "| VS/Setting/Parameter  | Check                                 | Status        |\n"
printf "+=======================+=======================================+===============+\n"



#====================================================================================================
# Check status of CoreXL
#====================================================================================================
CXL=$(fw ctl multik stat 2>&1)
fw ctl multik stat >$OUTPUTDIR/corexl.log 2>&1

printf "| CoreXL\t\t| Log status\t\t\t\t|"
if [[ -e $OUTPUTDIR/corexl.log ]] && [[ $CXL == *"disabled"* ]]; then
    check_disabled
else
    check_enabled
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Check status of Dynamic Balancing
#====================================================================================================
if [[ -e $FWDIR/bin/dynamic_balancing ]]; then
  DYNBAL=$(dynamic_balancing -p)
  dynamic_balancing -p >$OUTPUTDIR/dynamic_balancing.log 2>&1

  printf "| Dynamic Balancing\t| Log status\t\t\t\t|"
  if [[ $DYNBAL == *"off"* ]] || [[ $DYNBAL == *"Off"* ]]; then
    check_disabled
  else
    check_enabled
  fi
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Check status of Hyper-Threading (SMT)
#====================================================================================================
HT=$(clish -c "show asset system" | grep Hyperthreading | awk {'print $3'})
clish -c "show asset system" | grep Hyperthreading | awk {'print $3'} >$OUTPUTDIR/hyperthreading.log

printf "| Hyper-Threading\t| Log status\t\t\t\t|"
if [[ -e $OUTPUTDIR/hyperthreading.log ]] && [[ $HT == "Enabled" ]]; then
    check_enabled
elif [[ -e $OUTPUTDIR/hyperthreading.log ]] && [[ $HT == "Disabled" ]]; then
      check_disabled
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Log Network Interfaces to file
#====================================================================================================
printf "| Network Interfaces\t| Log ifconfig output to file\t\t|"
ifconfig >$OUTPUTDIR/VS0/ifconfig.log
if [[ -e $OUTPUTDIR/VS0/ifconfig.log ]]; then
    check_passed
else
    check_failed
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Log SecureXL Affinity to file
#====================================================================================================
printf "| SecureXL Affinity\t| Log current settings to file\t\t|"
sim affinity -l >$OUTPUTDIR/simaffinity.log
if [[ -e $OUTPUTDIR/simaffinity.log ]]; then
    check_passed
else
    check_failed
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Log CoreXL Affinity to file
#====================================================================================================
printf "| CoreXL Affinity\t| Log current settings to file\t\t|"
fw ctl affinity -l >$OUTPUTDIR/fwctlaffinity.log
if [[ -e $OUTPUTDIR/fwctlaffinity.log ]]; then
    check_passed
else
    check_failed
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Log Multi-Queue settings to file
#====================================================================================================
printf "| Multi-Queue\t\t| Log current settings to file\t\t|"
if [[ "$KERNVER" == "2.6" ]]; then
    cpmq get >$OUTPUTDIR/multiqueue.log 2>&1
    cpmq get -vv >>$OUTPUTDIR/multiqueue.log 2>&1
else
if [[ "$KERNVER" == "3.10" ]]; then
    mq_mng --show -a >$OUTPUTDIR/multiqueue.log
    mq_mng --show -a -vv >>$OUTPUTDIR/multiqueue.log
    fi
fi

if [[ -e $OUTPUTDIR/multiqueue.log ]]; then
    check_passed
else
    check_failed
fi

printf "+-----------------------+---------------------------------------+---------------+\n"



#====================================================================================================
# Check status of SecureXL Fast Accelerator and log to file
#====================================================================================================
SXL_FAST_ACC=$(fw ctl fast_accel show_state 2>&1)
fw ctl fast_accel show_state >$OUTPUTDIR/VS0/securexl_fast_accel.log 2>&1
fw ctl fast_accel show_table >>$OUTPUTDIR/VS0/securexl_fast_accel.log 2>&1


printf "| SXL Fast Accelerator\t| Log status and settings to file\t|"
if [[ -e $OUTPUTDIR/VS0/securexl_fast_accel.log ]] && [[ $SXL_FAST_ACC == *"disabled"* ]]; then
    check_disabled
else
    check_enabled
fi

printf "+-----------------------+---------------------------------------+---------------+\n"


#====================================================================================================
# Check for active proxy ARP in VS0
#====================================================================================================
PROXY_ARP=$(fw ctl arp -n 2>&1)
fw ctl arp -n >$OUTPUTDIR/VS0/proxy_arp.log 2>&1


if [[ -e $OUTPUTDIR/VS0/proxy_arp.log ]]; then
    printf "| Active Proxy ARP\t| Log entries to file\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| Active Proxy ARP\t| Log entries to file\t\t\t|${txt_green} NOT SAVED${txt_reset}\t|\n"
fi

printf "+-----------------------+---------------------------------------+---------------+\n"


#====================================================================================================
# Save VS0 config to OUTPUTDIR
#====================================================================================================
printf "| VS0\t\t\t| Export Clish configuration\t\t|"
clish -c "save configuration VS0.config"
mv VS0.config $OUTPUTDIR/VS0

if [[ -e $OUTPUTDIR/VS0/VS0.config ]]; then
    check_passed
else
    check_failed
fi


#====================================================================================================
# Find customized configuration files and copy it inluding full path to OUTPUTDIR
#====================================================================================================
    printf "| \t\t\t| \t\t\t\t\t|\t\t|\n"
    printf "| \t\t\t| Searching for configuration files:\t|\t\t|\n"
if [[ -e $FWDIR/boot/modules/fwkern.conf ]]; then
    cp --parents $FWDIR/boot/modules/fwkern.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| fwkern.conf found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| fwkern.conf NOT found\t\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

if [[ -e $FWDIR/boot/modules/vpnkern.conf ]]; then
    cp --parents $FWDIR/boot/modules/vpnkern.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| vpnkern.conf found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| vpnkern.conf NOT found\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

if [[ -e $PPKDIR/boot/modules/simkern.conf ]]; then
    cp --parents $PPKDIR/boot/modules/simkern.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| simkern.conf found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| simkern.conf NOT found\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

if [[ -e $PPKDIR/boot/modules/sim_aff.conf ]]; then
    cp --parents $PPKDIR/boot/modules/sim_aff.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| sim_aff.conf found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| sim_aff.conf NOT found\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

FWAFF=$(md5sum $FWDIR/conf/fwaffinity.conf | awk {'print $1'})
if [[ $FWAFF != "a1603a26029ebf4aba9262fa828c4685" ]]; then
    cp --parents $FWDIR/conf/fwaffinity.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| Custom fwaffinity.conf\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| Default fwaffinity.conf\t\t|${txt_green} NOT SAVED${txt_reset}\t|\n"
fi

if [[ -e $FWDIR/conf/fwauthd.conf ]]; then
    cp --parents $FWDIR/conf/fwauthd.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| fwauthd.conf found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| fwauthd.conf NOT found\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

if [[ -e $FWDIR/conf/local.arp ]]; then
    cp --parents $FWDIR/conf/local.arp $OUTPUTDIR/VS0
    printf "| \t\t\t| local.arp found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| local.arp NOT found\t\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

if [[ -e $FWDIR/conf/discntd.if ]]; then
    cp --parents $FWDIR/conf/discntd.if $OUTPUTDIR/VS0
    printf "| \t\t\t| discntd.if found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| discntd.if NOT found\t\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

CPHABOND=$(md5sum $FWDIR/conf/cpha_bond_ls_config.conf | awk {'print $1'})
if [[ $CPHABOND != "a8a4a618c05f08a952cb10b0c440a9de" ]]; then
    cp --parents $FWDIR/conf/cpha_bond_ls_config.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| Custom cpha_bond_ls_config.conf\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| Default cpha_bond_ls_config.conf\t|${txt_green} NOT SAVED${txt_reset}\t|\n"
fi

if [[ -e $FWDIR/conf/resctr ]]; then
    cp --parents $FWDIR/conf/resctr $OUTPUTDIR/VS0
    printf "| \t\t\t| resctr found\t\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| resctr NOT found\t\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

VSAFFEXCP=$(md5sum $FWDIR/conf/vsaffinity_exception.conf | awk {'print $1'})
if [[ $VSAFFEXCP != "0a4472f1fd49086e9df58cf12fc7d9f4" ]]; then
    cp --parents $FWDIR/conf/vsaffinity_exception.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| Custom vsaffinity_exception.conf\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| Default vsaffinity_exception.conf\t|${txt_green} NOT SAVED${txt_reset}\t|\n"
fi

if [[ -e $FWDIR/database/qos_policy.C ]]; then
    cp --parents $FWDIR/database/qos_policy.C $OUTPUTDIR/VS0
    printf "| \t\t\t| qos_policy.C found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| qos_policy.C NOT found\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi

TRAC=$(md5sum $FWDIR/conf/trac_client_1.ttm | awk {'print $1'})
if [[ $TRAC != "9d898b072aa5e0d3646ce81829c45453" ]]; then
    cp --parents $FWDIR/conf/trac_client_1.ttm $OUTPUTDIR/VS0
    printf "| \t\t\t| Custom trac_client_1.ttm\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| Default trac_client_1.ttm\t\t|${txt_green} NOT SAVED${txt_reset}\t|\n"
fi

if [[ -e $FWDIR/conf/ipassignment.conf ]]; then
    cp --parents $FWDIR/conf/ipassignment.conf $OUTPUTDIR/VS0
    printf "| \t\t\t| ipassignment.conf found\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
else
    printf "| \t\t\t| ipassignment.conf NOT found\t\t|${txt_green} OK${txt_reset}\t\t|\n"
fi



#====================================================================================================
# Save custom configuration other VS's + checks
#====================================================================================================
printf "+-----------------------+---------------------------------------+---------------+\n"

arr=($(vsx stat -l | grep -B 1 "Virtual System" | grep -v "Virtual System" | grep -v "\--" | awk '{print $2}'))
for i in "${arr[@]}"
do
    touch $OUTPUTDIR/$HOSTNAME-VS$i.clish
    mkdir -p $OUTPUTDIR/VS$i
    printf "| VS$i\t\t\t| Export VS$i Clish configuration\t|"
    echo "set virtual-system $i" >$OUTPUTDIR/$HOSTNAME-VS$i.clish
    echo "save configuration VS$i.tmp" >>$OUTPUTDIR/$HOSTNAME-VS$i.clish
    clish -i -f $OUTPUTDIR/$HOSTNAME-VS$i.clish >/dev/null 2>&1
    mv VS$i.tmp $OUTPUTDIR/VS$i
    echo "set virtual-system $i" >$OUTPUTDIR/VS$i/VS$i.config
    echo "set virtual-system $i" >>$OUTPUTDIR/VS-all.config
    grep -E 'set router-id|set as|set bgp|set prefix-|set routemap|set igmp|set pim|set ospf|set bootp|set route-redistribution|add arp|set max-path-splits|set inbound-route-filter|set pbr' $OUTPUTDIR/VS$i/VS$i.tmp >>$OUTPUTDIR/VS$i/VS$i.config
    grep -E 'set router-id|set as|set bgp|set prefix-|set routemap|set igmp|set pim|set ospf|set bootp|set route-redistribution|add arp|set max-path-splits|set inbound-route-filter|set pbr' $OUTPUTDIR/VS$i/VS$i.tmp >>$OUTPUTDIR/VS-all.config
    rm $OUTPUTDIR/$HOSTNAME-VS$i.clish
    rm $OUTPUTDIR/VS$i/VS$i.tmp
    if [[ -e $OUTPUTDIR/VS$i/VS$i.config ]]; then
        check_passed
    else
        check_failed
    fi

    printf "| \t\t\t| Log current routes to file\t\t|"
    echo "set virtual-system $i" >$OUTPUTDIR/$HOSTNAME-VS$i.clish
    echo "show bgp peers" >>$OUTPUTDIR/$HOSTNAME-VS$i.clish
    echo "show ospf neighbors" >>$OUTPUTDIR/$HOSTNAME-VS$i.clish
    echo "show route" >>$OUTPUTDIR/$HOSTNAME-VS$i.clish
    echo "show route summary" >>$OUTPUTDIR/$HOSTNAME-VS$i.clish
    clish -i -f $OUTPUTDIR/$HOSTNAME-VS$i.clish > $OUTPUTDIR/$HOSTNAME-VS$i.tmp
    sed '/^Processing\|^Context\|^Done.\|^RTGRTG\|^CLICMD/d' $OUTPUTDIR/$HOSTNAME-VS$i.tmp >$OUTPUTDIR/VS$i/VS$i.log
    rm $OUTPUTDIR/$HOSTNAME-VS$i.clish
    rm $OUTPUTDIR/$HOSTNAME-VS$i.tmp
    if [[ -e $OUTPUTDIR/VS$i/VS$i.log ]]; then
        check_passed
    else
        check_failed
    fi

    vsenv $i > /dev/null 2>&1
    SXL_FAST_ACC=$(fw ctl fast_accel show_state 2>&1)
    fw ctl fast_accel show_state >$OUTPUTDIR/VS$i/securexl_fast_accel.log 2>&1
    fw ctl fast_accel show_table >>$OUTPUTDIR/VS$i/securexl_fast_accel.log 2>&1
    printf "| SXL Fast Accelerator\t| Log status and settings to file\t|"
    if [[ -e $OUTPUTDIR/VS$i/securexl_fast_accel.log ]] && [[ $SXL_FAST_ACC == *"disabled"* ]]; then
        check_disabled
    else
        check_enabled
    fi

    printf "| Network Interfaces\t| Log ifconfig output to file\t\t|"
    ifconfig >$OUTPUTDIR/VS$i/ifconfig.log
    if [[ -e $OUTPUTDIR/VS$i/ifconfig.log ]]; then
        check_passed
    else
        check_failed
    fi

    printf "| Active Proxy ARP\t| Log fw ctl arp output to file\t\t|"
    fw ctl arp -n >$OUTPUTDIR/VS$i/proxy_arp.log 2>&1
    if [[ -e $OUTPUTDIR/VS$i/proxy_arp.log ]]; then
        check_passed
    else
        check_failed
    fi

    printf "| \t\t\t| \t\t\t\t\t|\t\t|\n"
    printf "| \t\t\t| Searching for configuration files:\t|\t\t|\n"

    VSZEROED=$(printf '%05d\n' $i)
    CTXPATH=$(find /var/opt/CPsuite* -name CTX)
    VSVARPATH="$CTXPATH/CTX$VSZEROED/conf"
    find $VSVARPATH -name local.arp | cpio -pdm --quiet $OUTPUTDIR/VS$i
    if [[ -e $VSVARPATH/local.arp ]]; then
        printf "| \t\t\t| local.arp found\t\t\t|${txt_green} SAVED${txt_reset}\t\t|\n"
    else
        printf "| \t\t\t| local.arp NOT found\t\t\t|${txt_green} OK${txt_reset}\t\t|\n"
    fi
    find $VSVARPATH -name cpha_bond_ls_config.conf | cpio -pdm --quiet $OUTPUTDIR/VS$i
    if [[ -e $VSVARPATH/cpha_bond_ls_config.conf ]]; then
        printf "| \t\t\t| cpha_bond_ls_config.conf found\t|${txt_green} SAVED${txt_reset}\t\t|\n"
    else
        printf "| \t\t\t| cpha_bond_ls_config.conf NOT found\t|${txt_green} OK${txt_reset}\t\t|\n"
    fi
    printf "| Active Proxy ARP\t| Log fw ctl arp output to file\t\t|"

    echo "+-----------------------+---------------------------------------+---------------+"
done



#====================================================================================================
# Create tarball of all files
#====================================================================================================
tar -zcf /var/tmp/$HOSTNAME-$DATE.tgz $OUTPUTDIR
mv /var/tmp/$HOSTNAME-$DATE.tgz $OUTPUTDIR

printf "\nAll files are saved in:\n"
printf "DIRECTORY: $(pwd)/$OUTPUTDIR\n"
printf "COMPRESSED FILE (containing all files): $HOSTNAME-$DATE.tgz\n\n"

exit 0
