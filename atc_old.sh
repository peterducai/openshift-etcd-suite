#!/bin/bash

#
# Author : Peter Ducai <peter.ducai.dev@gmail.com>
# Homepage : https://github.com/peterducai/automatic_traffic_shaper
# License : Apache2
# Copyright (c) 2017, Peter Ducai
# All rights reserved.
#

# Purpose : dynamic linux traffic shaper
# Usage : ats.sh for more options


# TERMINAL COLORS -----------------------------------------------------------------

NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
BLACK='\033[30m'
BLUE='\033[34m'
VIOLET='\033[35m'
CYAN='\033[36m'
GREY='\033[37m'

# INTERFACES

EXT_IF="eth0"
INT_IF="eth1"
IP="xxx" #HERE PUT SERVER IP ADDRESS

TC="/sbin/tc"
IPT="/sbin/iptables"
MOD="/sbin/modprobe"

#  tc uses the following units when passed as a parameter.
#  kbps: Kilobytes per second
#  mbps: Megabytes per second
#  kbit: Kilobits per second
#  mbit: Megabits per second
#  bps: Bytes per second

# DO NOT EDIT BELOW THIS LINE ______________________________________________
totaldown=0
totalup=0
total_clients=0
total_groups=0

groups_index=()
groups_name=()
groups_id=()
groups_down=()
groups_up=()
groups_aggr=()
groups_prio=()
groups_active=()
groups_client_count=()
groups_sub_count=()

all_ip=()
all_parentid=()
all_classid=()

#########################################
# increment and set to 2 decimal places #
#########################################
function inc_2_leadzeroes {
    local val=$1
    val=$(($val+1))
    
    if [[ $val -lt 10 ]]; then
        val="0"$val
        echo "$val"
        return $val
    fi
    echo "$val"
    return $val
}

#########################################
# increment and set to 3 decimal places #
#########################################
function inc_3_leadzeroes {
    local val=$1
    val=$(($val+1))
    
    if [[ $val -lt 10 ]]
    then
        val="00"$val
        echo "$val"
        return $val
    elif [[ $val -gt 9 && $val -lt 100 ]]
    then
        val="0"$val
        echo "$val"
        return $val
    else
        echo "$val"
        return $val
    fi
}

#################################
# Check if IP address is valid  #
#################################
function validate_IP {
    local ip=$1
    local stat=1
    # Check the IP address under test to see if it matches the extended REGEX
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Record current default field separator
        OIFS=$IFS
        # Set default field separator to .
        IFS='.'
        # Create an array of the IP Address being tested
        ip=($ip)
        # Reset the field separator to the original saved above IFS=$OIFS
        # Is each octet between 0 and 255?
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        # Set the return code.
        stat=$?
    fi
}

###########################################
# load kernel modules for shaper/firewall #
###########################################
function ipt_load_modules {
    $MOD ip_tables ## Core Netfilter Module
    $MOD ip_conntrack ## Stateful Connections
    $MOD ip_filter
    $MOD ip_mangle
    $MOD ip_nat
    $MOD ip_nat_ftp
    $MOD ip_nat_irc
    $MOD ip_conntrack
    $MOD ip_conntrack_ftp
    $MOD ip_conntrack_irc
    $MOD iptable_filter ## Filter Table
    $MOD ipt_MASQUERADE   ## Masquerade Target
    
    #$MOD ip6_tables
    #$MOD ip6_filter
    #$MOD ip6_mangle
    
}


#TODO
function tc_print_counters {
    echo -e "${GREEN}total download:$totaldown upload:$totalup${NONE}"
    echo -e "${GREEN}========================================================${NONE}"
    echo -e "${YELLOW}total ${totalgroups} groups and ${totalsubs} subgroups ${NONE}"
}

######################
# remove root qdisc  #
######################
function tc_remove {
    echo "REMOVING ROOT QDISC"
    $TC qdisc del dev $INT_IF root
    $TC qdisc del dev $EXT_IF root
    $TC qdisc del dev $INT_IF ingress
    $TC qdisc del dev $EXT_IF ingress
}

function tc_add_group { # $parent, $classid, $total, $ceil
    local parent=$1
    local classid=$2
    local total=$3
    local ceil=$4
    local DEV=$5
    $TC class add dev $DEV parent $parent classid $classid htb rate ${total}kbit ceil ${ceil}kbit
}

function tc_add_group_down {
    tc_add_group $1 $2 $3 $4 $EXT_IF
    totaldown=$(($(($totaldown))+$(($4))))
}

function tc_add_group_up {
    tc_add_group $1 $2 $3 $4 $INT_IF
    totalup=$(($(($totalup))+$(($4))))
}

#####################################
# list root qdisc and it's classes  #
#####################################
function tc_show {
    echo "SHOW ROOT QDISC"
    $TC -s qdisc show dev $EXT_IF
    $TC -s class show dev $EXT_IF
    $TC -s qdisc show dev $INT_IF
    $TC -s class show dev $INT_IF
}

##########################################################################
# load groups from definition file and compute traffic values like ceil  #
##########################################################################
function prepare_group_definitions {
    local z=0
    #check if group.definitions exist, if not, create it with default Fiber30 group
    if [ -s "config/group.definitions" ]; then
        echo -e "${GREEN}found group.definitions and processing...${NONE}" >> /dev/null
    else
        echo -e "${RED} group.definitions NOT FOUND!!! recreating...${NONE}"
        mkdir config
        touch config/group.definitions;
        echo "#name           download        upload          aggregation     prio_group" > config/group.definitions
        echo "Fiber30         30720           5120            8               0" >> config/group.definitions
        exit
    fi
    
    #read group.definitions and fill arrays with values
    while read line
    do
        #take line and split it into array, first value is main! (aka group,client..etc)
        arrl=($(echo $line | tr " " "\n"))
        if [ -z "$line" ]; then
            echo "EMPTY LINE"
        else
            case "${arrl[0]}" in
                '#'*)
                ;;
                *)      echo "--------------------------------------------------------------------------------------"
                    echo -e "${GREEN}found GROUP called ${arrl[0]} | download $((arrl[1] / 1024)) Mbs | upload $((arrl[2]/1024)) Mbs | aggr ${arrl[3]} ${NONE}"
                    echo "--------------------------------------------------------------------------------------"
                    groups_name[$z]=${arrl[0]}
                    groups_index[$z]=$((${z}+1))
                    groups_down[$z]=${arrl[1]}
                    groups_up[$z]=${arrl[2]}
                    groups_aggr[$z]=${arrl[3]}
                    groups_prio[$z]=${arrl[4]}
                    groups_sub_count[$z]=0
                    groups_active[$z]=0 #by default mark group inactive
                    
                    #if file .group exist, MARK GROUP ACTIVE
                    if [ -f config/${arrl[0]}.group ];
                    then
                        groups_active[$z]=1
                    else
                        echo -e "${RED}#### ERROR! #### File ${groups_name[$z]}.group does NOT EXIST but is defined in group.definitions${NONE}"
                        echo "creating dummy .group file"
                        touch config/${arrl[0]}.group
                        echo "127.0.0.0" > config/${arrl[0]}.group
                        echo -e "${RED}FIX config/${arrl[0]}.group FILE BEFORE RUNNING AGAIN!!!${NONE}"
                        exit #exit so user can change 127.0.0.1 in .group file
                    fi
                    
                    z=$((${z}+1))
                ;;
            esac
        fi
    done <config/group.definitions
    
    echo "END OF DEFINITIONS"
}

########################################
# generate sub groups from main groups #
########################################
function gen_subgroups {
    #echo "gen_subgroups $1 $2 ---------------------------------------------------------------"
    local dd=0
    local cc=0
    local ddd
    local i=0
    while read line
    do
        if [[ cc -ge "${groups_aggr[$1]}" ]]; then
            dd=$(($dd+1))
            cc=0
        fi
        
        ddd=`inc_2_leadzeroes $dd`
        
        all_groupid[${#all_groupid[*]}]=$2
        all_classid[${#all_classid[*]}]=$2${ddd}
        echo "$line | group $1/$ddd | $cc |  classid $2${ddd}"
        
        i=$(($i+1))
        cc=$(($cc+1))
    done <config/${groups_name[$1]}.group
}

#######################################
# get all clients for certain group   #
#######################################
function count_clients {
    # Count clients and load IPs into all_ip[]
    local size=${#groups_index[@]}
    echo "counting clients of $size groups"
    for (( i=0; i <size; i++ ))
    do
        while read line
        do
            # VALIDATE IP ADDRESS
            local templine=$line
            validate_IP $templine
            local valid=$?
            if [[ $valid -ne 0 ]]; then
                echo -e "${RED}IP ADDRESS $line IS NOT VALID!!! fix before running again.${NONE}"
                exit
            else
                allip_size=${#all_ip[*]}
                all_ip[$allip_size]=$line
            fi
            
            total_clients=$((${total_clients}+1))
            groups_client_count[$i]=$((${groups_client_count[$i]}+1))
            
        done <config/${groups_name[$i]}.group
    done
    echo "FOUND $total_clients CLIENTS IN TOTAL"
    
    #
    # Compute number of subgroups depending on aggregations
    #
    for (( i=0; i <size; i++ ))
    do
        if [[ ${groups_client_count[$i]} -le ${groups_aggr[$i]} ]];then
            groups_sub_count[$i]=1
            elif [[ ${groups_aggr[$i]} == 1 ]]; then
            groups_sub_count[$i]=${groups_client_count[$i]}
        else
            groups_sub_count[$i]=$(($(($((${groups_client_count[$i]})) / $((${groups_aggr[$i]}))))+1))
        fi
        
        echo "got ${groups_name[$i]} with ${groups_client_count[$i]} clients divided into ${groups_sub_count[$i]} subs"
        totaldown=$(($((${totaldown}))+$((${groups_down[$i]}))))
        totalup=$(($((${totalup}))+$((${groups_up[$i]})) ))
    done
    
    #
    # Generate class ID for each group, subgroup, IP..
    #
    for (( i=0; i <size; i++ ))
    do
        local grid=`inc_2_leadzeroes $i`
        groups_id[$i]="${grid}"
        if [[ ${groups_active[$i]} == 1 ]]; then
            gen_subgroups $i ${groups_id[$i]}
        fi
    done
}

##########################################
# print all IPs with such classid        #
##########################################
function print_IP_only_with_classid {
    local size=${#all_ip[*]}
    
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            echo "  |       |                   |     - ${all_ip[$m]} " #>> /dev/null
        else
            echo "no match: ${all_classid[$m]} " >> /dev/null
        fi
    done
}

#####################################################################
# print commands of all IP addresses with certain download class ID #
#####################################################################
function print_command_with_classid_down {
    local size=${#all_ip[*]}
    
    local subdown=$2
    local subceil=$3
    local NIC=$4
    local class_set=0
    
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            par=${all_classid[$m]%?}
            par=${par%?}
            
            if [[ $class_set == '0' ]]; then
                echo -e "  |       |                   |              |_ $TC class add dev $NIC parent 1:$(printf %x $((1$par))) classid 1:$(printf %x $((1${all_classid[$m]}))) htb rate ${GREEN}${subdown}${NONE}Kbit ceil ${GREEN}${subceil}${NONE}Kbit buffer 1600"
                class_set=1
            fi
            
            echo -e "  |       |                   |              |_ $IPT -A POSTROUTING -t mangle -o $NIC -d ${YELLOW}${all_ip[$m]}${NONE} -j CLASSIFY --set-class 1:$(printf %x $((1${all_classid[$m]}))) "
            
        else
            echo "no match: ${all_classid[$m]}" >> /dev/null
        fi
    done
}

###################################################################
# print commands of all IP addresses with certain upload class ID #
###################################################################
function print_command_with_classid_up {
    #echo "print_command_with_classid_up for ${#all_ip[*]} addresses"
    
    local size=${#all_ip[*]}
    
    local subdown=$2
    local subceil=$3
    local NIC=$4
    local class_set=0
    
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            #echo "MATCH ${all_classid[$m]} == $1"
            #echo "  |       |                   |     - " #>> /dev/null
            par=${all_classid[$m]%?}
            par=${par%?}
            
            if [[ $class_set == '0' ]]; then
                echo -e "  |       |                   |              |_ $TC class add dev $NIC parent 1:$(printf %x $((2$par))) classid 1:$(printf %x $((2${all_classid[$m]}))) htb rate ${GREEN}${subdown}${NONE}Kbit ceil ${GREEN}${subceil}${NONE}Kbit buffer 1600"
                class_set=1
            fi
            
            echo -e "  |       |                   |              |_ $IPT -A POSTROUTING -t mangle -o $NIC -s ${YELLOW}${all_ip[$m]}${NONE} -j CLASSIFY --set-class 1:$(printf %x $((2${all_classid[$m]})))"
            
        else
            echo "no match: ${all_classid[$m]}" >> /dev/null
        fi
    done
}


##########################################################################
# execute commands of all IP addresses with certain download class ID    #
##########################################################################
function execute_command_with_classid_down {
    local size=${#all_ip[*]}
    
    local subdown=$2
    local subceil=$3
    local NIC=$4
    local class_set=0
    
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            par=${all_classid[$m]%?}
            par=${par%?}
            
            if [[ $class_set == '0' ]]; then
                echo "$TC class add dev $NIC parent 1:$(printf %x $((1$par))) classid 1:$(printf %x 1${all_classid[$m]}) htb rate ${subdown}Kbit ceil ${subceil}Kbit buffer 1600"
                $TC class add dev $NIC parent 1:$(printf %x $((1$par))) classid 1:$(printf %x 1${all_classid[$m]}) htb rate ${subdown}Kbit ceil ${subceil}Kbit buffer 1600
                class_set=1
            fi
            echo "$IPT -A POSTROUTING -t mangle -o $NIC -d ${all_ip[$m]} -j CLASSIFY --set-class 1:$(printf %x $((1${all_classid[$m]})))"
            $IPT -A POSTROUTING -t mangle -o $NIC -d "${all_ip[$m]}" -j CLASSIFY --set-class 1:$(printf %x $((1${all_classid[$m]})))
            
        else
            echo "no match: ${all_classid[$m]}" >> /dev/null
        fi
    done
    echo "END execute_command_with_classid_down"
}

#########################################################################
# execute commands of all IP addresses with certain download class ID   #
#########################################################################
function execute_command_with_classid_up {
    #echo "print_command_with_classid_up for ${#all_ip[*]} addresses"
    
    local size=${#all_ip[*]}
    
    local subdown=$2
    local subceil=$3
    local NIC=$4
    local class_set=0
    
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            #echo "MATCH ${all_classid[$m]} == $1"
            #echo "  |       |                   |     - " #>> /dev/null
            par=${all_classid[$m]%?}
            par=${par%?}
            
            if [[ $class_set == '0' ]]; then
                echo "TC class add dev $NIC parent 1:$(printf %x $((2$par))) classid 1:$(printf %x 2${all_classid[$m]}) htb rate ${subdown}Kbit ceil ${subceil}Kbit buffer 1600"
                $TC class add dev $NIC parent 1:$(printf %x $((2$par))) classid 1:$(printf %x 2${all_classid[$m]}) htb rate ${subdown}Kbit ceil ${subceil}Kbit buffer 1600
                class_set=1
            fi
            echo "$IPT -A POSTROUTING -t mangle -o $NIC -s ${all_ip[$m]} -j CLASSIFY --set-class 1:$(printf %x 2${all_classid[$m]})"
            $IPT -A POSTROUTING -t mangle -o $NIC -s "${all_ip[$m]}" -j CLASSIFY --set-class 1:$(printf %x 2${all_classid[$m]})
            
        else
            echo "no match: ${all_classid[$m]}" >> /dev/null
        fi
    done
}


######################################################################
# Generate only tree visualization of leaves, don't create anything  #
######################################################################
function tc_generate_tree {
    local size=${#groups_index[*]}
    
    echo -e "${GREEN}=============================${NONE}"
    echo -e "${GREEN}= Shaper tree visualization =${NONE}"
    echo -e "${GREEN}=============================${NONE}"
    echo -e "interfaces:"
    echo -e "-LAN--->---${GREEN}[$EXT_IF]${NONE}--|| SERVER ||--${YELLOW}[$INT_IF]${NONE}--->---WAN-"
    echo -e ""
    echo -e "${GREEN}=============================${NONE}"
    
    #-- download ------------------------
    echo "  |"
    echo "[root qdisc]"
    echo "  |"
    echo "  [1:1]------"
    echo "  |       |"
    
    for (( i=0; i<$size; i++ ))
    do
        pgridd=`inc_2_leadzeroes $i`
        echo "  |       |"
        echo "  |       |-[${groups_name[$i]}]- $(printf %x $((1${pgridd}))) ---------"
        echo "  |       |                   |"
        
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridd=`inc_2_leadzeroes $z`
            echo "  |       |                   |"
            echo "  |       |                   |--sub $(printf %x $((1${pgridd}${sgridd}))) -"
            #echo "print_IP_only_with_classid ${pgridd}${sgridd}"
            print_IP_only_with_classid ${pgridd}${sgridd}
        done
    done
    
    #-- upload ------------------------
    
    echo "  |"
    echo "  [1:2]------"
    echo "  |       |"
    
    for (( i=0; i<$size; i++ ))
    do
        pgridu=`inc_2_leadzeroes $i`
        echo "  |       |"
        echo "  |       |-[${groups_name[$i]}]- $(printf %x $((2${pgridu}))) ---------"
        echo "  |       |                   |"
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridu=`inc_2_leadzeroes $z`
            echo "  |       |                   |"
            echo "  |       |                   |--sub $(printf %x $((2${pgridu}${sgridu}))) -"
            
            print_IP_only_with_classid ${pgridu}${sgridu}
        done
    done
}

##########################################################
# Generate only printed tc commands, don't run anything  #
##########################################################
function tc_generate_fake_commands {
    local size=${#groups_index[*]}
    
    echo -e "${GREEN}=======================================${NONE}"
    echo -e "${GREEN}= Shaper command visualization NO RUN =${NONE}"
    echo -e "${GREEN}=======================================${NONE}"
    echo -e "interfaces:"
    echo -e "-LAN--->---${GREEN}[$EXT_IF]${NONE}--|| SERVER ||--${YELLOW}[$INT_IF]${NONE}--->---WAN-"
    echo -e ""
    echo -e "${GREEN}=============================${NONE}"
    
    #-- remove old qdisc
    echo "  |"
    echo -e "${RED}[deleting root qdisc] ${NONE}"
    echo "-------------------------------------------"
    echo "$TC qdisc del dev $INT_IF root"
    echo "$TC qdisc del dev $EXT_IF root"
    echo "$TC qdisc del dev $INT_IF ingress"
    echo "$TC qdisc del dev $EXT_IF ingress"
    echo "-------------------------------------------"
    
    #-- root qdisc ----------------------
    
    totaldown=0
    totalup=0
    
    for (( i=0; i<$size; i++ ))
    do
        totaldown=$(($(($totaldown))+$(($(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))))))
    done
    
    for (( i=0; i<$size; i++ ))
    do
        totalup=$(($(($totalup))+$(($(($((${groups_sub_count[$i]}))*$((${groups_up[$i]}))))))))
    done
    echo "  |"
    echo -e "${YELLOW}==| TOTAL down: $(($((${totaldown}))/1024))Mbit up: $(($((${totalup}))/1024))Mbit |==${NONE}"
    echo "  |"
    echo "  |"
    echo "--------------------------------------------------------------------------------------------------------------"
    echo "$TC qdisc add dev $INT_IF root handle 1: htb default 1 r2q 10"
    echo "$TC qdisc add dev $EXT_IF root handle 1: htb default 1 r2q 10"
    echo "$TC class add dev $INT_IF parent 1: classid 1:1 htb rate ${totaldown}Kbit ceil ${totaldown}Kbit buffer 1600"
    echo "$TC class add dev $EXT_IF parent 1: classid 1:2 htb rate ${totalup}Kbit ceil ${totalup}Kbit buffer 1600  "
    echo "--------------------------------------------------------------------------------------------------------------"
    
    #-- download ------------------------
    echo "  |"
    echo "  1:1------"
    echo "  |       |"
    
    for (( i=0; i<$size; i++ ))
    do
        pgridd=`inc_2_leadzeroes $i`
        echo "  |       |"
        echo -e "  |       |--------${GREEN}[${groups_name[$i]}]${NONE}----------"
        echo "  |       |         |_$TC class add dev $EXT_IF parent 1:1 classid 1:$(printf %x $((1${pgridd}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600"
        echo "  |       |                   |"
        
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridd=`inc_2_leadzeroes $z`
            echo "  |       |                   |"
            echo "  |       |                   |--sub 1${pgridd}${sgridd} (hex $(printf %x $((1${pgridd}${sgridd})))) -"
            print_command_with_classid_down ${pgridd}${sgridd} $(($((${groups_down[$i]}))/$((${groups_aggr[$i]})))) ${groups_down[$i]} $EXT_IF
        done
    done
    
    #-- upload ------------------------
    echo "  |"
    echo "  1:2------"
    echo "  |       |"
    
    for (( i=0; i<$size; i++ ))
    do
        pgridu=`inc_2_leadzeroes $i`
        echo "  |       |"
        echo -e "  |       |--------${GREEN}[${groups_name[$i]}]${NONE}----------"
        echo "  |       |         |_$TC class add dev $INT_IF parent 1:1 classid 1:$(printf %x $((2${pgridu}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600"
        echo "  |       |                   |"
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridu=`inc_2_leadzeroes $z`
            echo "  |       |                   |"
            echo "  |       |                   |--sub $((2${pgridu}${sgridu})) hex $(printf %x $((2${pgridu}${sgridu})))-"
            print_command_with_classid_up ${pgridu}${sgridu} $(($((${groups_up[$i]}))/$((${groups_aggr[$i]})))) ${groups_up[$i]} $INT_IF
        done
    done
}


#########################################################
# Generate only printed tc commands, don't run anything #
#########################################################
function tc_execute_commands {
    local size=${#groups_index[*]}
    
    echo -e "${GREEN}=========================================${NONE}"
    echo -e "${GREEN}= Shaper command REAL RUN visualization =${NONE}"
    echo -e "${GREEN}=========================================${NONE}"
    echo -e "interfaces:"
    echo -e "-LAN--->---${GREEN}[$EXT_IF]${NONE}--|| SERVER ||--${YELLOW}[$INT_IF]${NONE}--->---WAN-"
    echo -e ""
    echo -e "${GREEN}=============================${NONE}"
    
    #-- remove old qdisc
    echo "  |"
    echo -e "${RED}[deleting root qdisc] ${NONE}"
    echo "-------------------------------------------"
    echo "$TC qdisc del dev $INT_IF root"
    $TC qdisc del dev $INT_IF root
    echo "$TC qdisc del dev $EXT_IF root"
    $TC qdisc del dev $EXT_IF root
    echo "$TC qdisc del dev $INT_IF ingress"
    $TC qdisc del dev $INT_IF ingress
    echo "$TC qdisc del dev $EXT_IF ingress"
    $TC qdisc del dev $EXT_IF ingress
    echo "-------------------------------------------"
    
    #-- root qdisc ----------------------
    
    totaldown=0
    totalup=0
    
    for (( i=0; i<$size; i++ ))
    do
        totaldown=$(($(($totaldown))+$(($(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))))))
    done
    
    for (( i=0; i<$size; i++ ))
    do
        totalup=$(($(($totalup))+$(($(($((${groups_sub_count[$i]}))*$((${groups_up[$i]}))))))))
    done
    echo "  |"
    echo -e "${YELLOW}==| TOTAL down: $(($((${totaldown}))/1024))Mbit up: $(($((${totalup}))/1024))Mbit |==${NONE}"
    echo "  |"
    echo "  |"
    echo "--------------------------------------------------------------------------------------------------------------"
    echo "$TC qdisc add dev $INT_IF root handle 1: htb default 1 r2q 10"
    $TC qdisc add dev $INT_IF root handle 1: htb default 1 r2q 10
    echo "$TC qdisc add dev $EXT_IF root handle 1: htb default 1 r2q 10"
    $TC qdisc add dev $EXT_IF root handle 1: htb default 1 r2q 10
    
    echo "$TC class add dev $INT_IF parent 1: classid 1:1 htb rate ${totaldown}Kbit ceil ${totaldown}Kbit buffer 1600"
    $TC class add dev $INT_IF parent 1: classid 1:1 htb rate ${totaldown}Kbit ceil ${totaldown}Kbit buffer 1600
    echo "$TC class add dev $EXT_IF parent 1: classid 1:2 htb rate ${totalup}Kbit ceil ${totalup}Kbit buffer 1600"
    $TC class add dev $EXT_IF parent 1: classid 1:2 htb rate ${totalup}Kbit ceil ${totalup}Kbit buffer 1600
    echo "--------------------------------------------------------------------------------------------------------------"
    
    #-- download ------------------------
    
    echo "  |"
    echo "  1:1------"
    echo "  |       |"
    
    for (( i=0; i<$size; i++ ))
    do
        pgridd=`inc_2_leadzeroes $i`
        echo "  |       |"
        echo -e "  |       |--------${GREEN}[${groups_name[$i]}]${NONE}----------"
        echo "  |       |         |_$TC class add dev $INT_IF parent 1:1 classid 1:$(printf %x $((1${pgridd}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600"
        $TC class add dev $INT_IF parent 1:1 classid 1:$(printf %x $((1${pgridd}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600
        echo "  |       |                   |"
        
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridd=`inc_2_leadzeroes $z`
            echo "  |       |                   |"
            echo "  |       |                   |--sub 1${pgridd}${sgridd} (hex $(printf %x $((1${pgridd}${sgridd})))) -"
            
            
            
            execute_command_with_classid_down ${pgridd}${sgridd} $(($((${groups_down[$i]}))/$((${groups_aggr[$i]})))) ${groups_down[$i]} $INT_IF
        done
    done
    
    #-- upload ------------------------
    
    echo "  |"
    echo "  1:2------"
    echo "  |       |"
    
    for (( i=0; i<$size; i++ ))
    do
        pgridu=`inc_2_leadzeroes $i`
        echo "  |       |"
        echo -e "  |       |--------${GREEN}[${groups_name[$i]}]${NONE}----------"
        echo "  |       |         |_$TC class add dev $EXT_IF parent 1:2 classid 1:$(printf %x $((2${pgridu}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600"
        $TC class add dev $EXT_IF parent 1:2 classid 1:$(printf %x $((2${pgridu}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600
        echo "  |       |                   |"
        
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridu=`inc_2_leadzeroes $z`
            echo "  |       |                   |"
            echo "  |       |                   |--sub $((2${pgridu}${sgridu})) hex $(printf %x $((2${pgridu}${sgridu})))-"
            
            
            
            execute_command_with_classid_up ${pgridu}${sgridu} $(($((${groups_up[$i]}))/$((${groups_aggr[$i]})))) ${groups_up[$i]} $EXT_IF
        done
    done
}


#######################################
# print download commands into file   #
#######################################
function execute2file_command_with_classid_down {
    local size=${#all_ip[*]}
    
    local subdown=$2
    local subceil=$3
    local NIC=$4
    local oufile=$5
    local class_set=0
    
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            par=${all_classid[$m]%?}
            par=${par%?}
            
            if [[ $class_set == '0' ]]; then
                echo -e "$TC class add dev $NIC parent 1:$(printf %x $((1$par))) classid 1:$(printf %x 1${all_classid[$m]}) htb rate ${subdown}Kbit ceil ${subceil}Kbit buffer 1600" >> "$oufile"
                class_set=1
            fi
            echo -e "$IPT -A POSTROUTING -t mangle -o $NIC -d ${all_ip[$m]} -j CLASSIFY --set-class 1:$(printf %x $((1${all_classid[$m]})))" >> "$oufile"
        else
            echo "# no match: ${all_classid[$m]}" >> /dev/null
        fi
    done
    echo "END execute_command_with_classid_down"
}

####################################
# print upload commands into file  #
####################################
function execute2file_command_with_classid_up {
    #echo "print_command_with_classid_up for ${#all_ip[*]} addresses"
    
    local size=${#all_ip[*]}
    
    local subdown=$2
    local subceil=$3
    local NIC=$4
    local ofile=$5
    local class_set=0
    
    echo "execute2file_command_with_classid_up GENERATE $ofile"
    for (( m=0; m<$size; m++ ))
    do
        if [[ ${all_classid[$m]} == $1 ]];
        then
            #echo "MATCH ${all_classid[$m]} == $1"
            #echo "  |       |                   |     - " #>> /dev/null
            par=${all_classid[$m]%?}
            par=${par%?}
            
            if [[ $class_set == '0' ]]; then
                echo -e "$TC class add dev $NIC parent 1:$(printf %x $((2$par))) classid 1:$(printf %x 2${all_classid[$m]}) htb rate ${subdown}Kbit ceil ${subceil}Kbit buffer 1600" >> "$ofile"
                class_set=1
            fi
            echo -e "$IPT -A POSTROUTING -t mangle -o $NIC -d ${all_ip[$m]} -j CLASSIFY --set-class 1:$(printf %x 2${all_classid[$m]})" >> "$ofile"
        else
            echo "# no match: ${all_classid[$m]}" >> /dev/null
        fi
    done
}

#################################################
# Generate file with all tc/iptables commands   #
#################################################
function generate_file {
    
    prepare_group_definitions
    count_clients
    
    local size=${#groups_index[*]}
    local file=$1
    
    echo "re-creating $file"
    rm -rf $file
    touch $file
    chmod 777 $file
    echo "adding shebang to $file"
    
    echo -e "#!/bin/bash" >> "$file"
    echo -e "" >> "$file"
    echo -e "# generated by https://sourceforge.net/projects/bashtools/" >> "$file"
    echo -e "" >> "$file"
    
    echo -e "# deleting root qdisc" >> "$file"
    echo -e "$TC qdisc del dev $INT_IF root" >> "$file"
    echo -e "$TC qdisc del dev $EXT_IF root" >> "$file"
    echo -e "$TC qdisc del dev $INT_IF ingress" >> "$file"
    echo -e "$TC qdisc del dev $EXT_IF ingress" >> "$file"
    echo -e "" >> "$file"
    
    totaldown=0
    totalup=0
    
    for (( i=0; i<$size; i++ ))
    do
        totaldown=$(($(($totaldown))+$(($(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))))))
    done
    
    for (( i=0; i<$size; i++ ))
    do
        totalup=$(($(($totalup))+$(($(($((${groups_sub_count[$i]}))*$((${groups_up[$i]}))))))))
    done
    
    echo -e "adding ROOT"
    echo -e "# COMPUTATED ESTIMATE TRAFFIC: total download $(($((${totaldown}))/1024))Mbit upload $(($((${totalup}))/1024))Mbit " >> "$file"
    echo -e "" >> "$file"
    echo -e "# create root" >> "$file"
    echo -e "$TC qdisc add dev $INT_IF root handle 1: htb default 1 r2q 10" >> "$file"
    echo -e "$TC qdisc add dev $EXT_IF root handle 1: htb default 1 r2q 10" >> "$file"
    echo -e "$TC class add dev $INT_IF parent 1: classid 1:1 htb rate ${totaldown}Kbit ceil ${totaldown}Kbit buffer 1600" >> "$file"
    echo -e "$TC class add dev $EXT_IF parent 1: classid 1:2 htb rate ${totalup}Kbit ceil ${totalup}Kbit buffer 1600" >> "$file"
    
    
    
    #-- download ------------------------
    echo "download leaves..."
    for (( i=0; i<$size; i++ ))
    do
        pgridd=`inc_2_leadzeroes $i`
        echo -e "$TC class add dev $EXT_IF parent 1:1 classid 1:$(printf %x $((1${pgridd}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600" >> "$file"
        
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridd=`inc_2_leadzeroes $z`
            execute2file_command_with_classid_down ${pgridd}${sgridd} $(($((${groups_down[$i]}))/$((${groups_aggr[$i]})))) ${groups_down[$i]} $EXT_IF "$file"
        done
    done
    
    #-- upload ------------------------
    
    for (( i=0; i<$size; i++ ))
    do
        pgridu=`inc_2_leadzeroes $i`
        echo -e "$TC class add dev $INT_IF parent 1:2 classid 1:$(printf %x $((2${pgridu}))) htb rate $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit ceil $(($((${groups_sub_count[$i]}))*$((${groups_down[$i]}))))Kbit buffer 1600" >> "$file"
        
        #process sub groups
        subsize=${groups_sub_count[$i]}
        for (( z=0; z<$subsize; z++ ))
        do
            sgridu=`inc_2_leadzeroes $z`
            execute2file_command_with_classid_up ${pgridu}${sgridu} $(($((${groups_up[$i]}))/$((${groups_aggr[$i]})))) ${groups_up[$i]} $INT_IF "$file"
        done
    done
}

#################################
# print tree of shaper leaves   #
#################################
function print_tree {
    #echo "############################################################################################"
    
    prepare_group_definitions
    count_clients
    tc_generate_tree
    
    #echo "############################################################################################"
}

##############################################
# print tree with commands of shaper leaves  #
##############################################
function print_tc_tree {
    #echo "############################################################################################"
    
    prepare_group_definitions
    count_clients
    tc_generate_fake_commands
    
    #echo "############################################################################################"
}

#########################
# execute normal start  #
#########################
function tc_start {
    tc_remove
    tc_show
    tc_print_counters
    echo "############################################################################################"
    
    ipt_load_modules
    prepare_group_definitions
    count_clients
    tc_execute_commands
    
    echo "############################################################################################"
    tc_print_counters
    tc_show
}


###############
# MAIN        #
###############
echo " "
echo "----------------------------------------------------------------------------------------"
echo "ATS aka automatic traffic shaper. https://github.com/peterducai/automatic_traffic_shaper"
echo "----------------------------------------------------------------------------------------"

case "$1" in
    start)
        tc_start
    ;;
    printtree) print_tree
    ;;
    printtc) print_tc_tree
    ;;
    generatetc) generate_file $2
    ;;
    stop)   tc_remove
    ;;
    restart) tc_remove
        tc_start
    ;;
    
    status)
        echo -e "${GREEN}= IPSET =========================================${NONE}";
        ipset -L;
        echo -e "${GREEN}= IPTABLES ======================================${NONE}";
        iptables -L -n -v --line-numbers;
        tc_print_counters
    ;;
    
    version)
        echo "ATS aka automatic traffic shaper. https://github.com/peterducai/automatic_traffic_shaper"
    ;;
    
    *)
        echo "usage: $0 (start|printtree|printtc|generatetc <generated.file>|stop|restart|status|version)"
        exit 1
esac

exit $?
