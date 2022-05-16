#!/bin/bash

MUST_PATH=$1

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

cd $MUST_PATH
cd $(echo */)
# ls

OCP_VERSION=$(cat cluster-scoped-resources/config.openshift.io/clusterversions.yaml |grep "Cluster version is"| grep -Po "(\d+\.)+\d+")
echo -e "Cluster version is $OCP_VERSION"
echo -e ""

cd cluster-scoped-resources/core/nodes
NODES_NUMBER=$(ls|wc -l)
echo -e "There are $NODES_NUMBER nodes in cluster"

cd ../persistentvolumes
PV_NUMBER=$(ls|wc -l)
echo -e "There are $PV_NUMBER PVs in cluster"

cd ../nodes

NODES=()
MASTER=()
INFRA=()
WORKER=()

help_etcd_objects() {
  echo -e ""
  echo -e "- Number of objects ---"
  echo -e ""
  echo -e "List number of objects in ETCD:"
  echo -e ""
  echo -e "oc rsh -c etcd -n openshift-etcd <etcd pod>"
  echo -e "> etcdctl get / --prefix --keys-only | sed '/^$/d' | cut -d/ -f3 | sort | uniq -c | sort -rn"
  echo -e ""
  echo -e "[HINT] Any number of CRDs (secrets, deployments, etc..) above 8k could cause performance issues on storage with not enough IOPS."

  echo -e ""
  echo -e "List secrets per namespace:"
  echo -e ""
  echo -e "> oc get secrets -A --no-headers | awk '{ns[\$1]++}END{for (i in ns) print i,ns[i]}'"
  echo -e ""
  echo -e "[HINT] Any namespace with 20+ secrets should be cleaned up (unless there's specific customer need for so many secrets)."
  echo -e ""
}

help_etcd_troubleshoot() {
  echo -e ""
  echo -e "- Generic troubleshooting ---"
  echo -e ""
  echo -e "More details about troubleshooting ETCD can be found at https://access.redhat.com/articles/6271341"
}

help_etcd_metrics() {
  echo -e ""
  echo -e "- ETCD metrics ---"
  echo -e ""
  echo -e "How to collect ETCD metrics. https://access.redhat.com/solutions/5489721"
}

help_etcd_networking() {
  echo -e ""
  echo -e "- ETCD networking troubleshooting ---"
  echo -e ""
  echo -e "From masters check if there are no dropped packets or RX/TX errors on main NIC."
  echo -e "> ip -s link show"
  echo -e ""
  echo -e "but also check latency against API (expected value is 2-5ms, 0.002-0.005 in output)"
  echo -e "> curl -k https://api.<OCP URL>.com -w \"%{time_connect}\""
  echo -e "Any higher latency could mean network bottleneck."
}

# help_etcd_objects


for filename in *.yaml; do
    [ -e "$filename" ] || continue
    [ ! -z "$(cat $filename |grep node-role|grep -w 'node-role.kubernetes.io/master:')" ] && MASTER+=("$filename") && NODES+=("$filename [master]") || true
done

for filename in *.yaml; do
    [ -e "$filename" ] || continue
    [ ! -z "$(cat $filename |grep node-role|grep -w 'node-role.kubernetes.io/infra:')" ] && INFRA+=("$filename")  && NODES+=("$filename [infra]") || true
done

for filename in *.yaml; do
    [ -e "$filename" ] || continue
    [ ! -z "$(cat $filename |grep node-role|grep -w 'node-role.kubernetes.io/worker:')" ] && WORKER+=("$filename")  && NODES+=("$filename [worker]") || true
done

echo -e " --------------- "
# echo ${NODES[@]}

echo -e "${#MASTER[@]} masters"
if [ "${#MASTER[@]}" != "3" ]; then
  echo -e "[WARNING] only 3 masters are supported, you have ${#MASTER[@]}."
fi

echo -e "${#INFRA[@]} infra nodes"
echo -e "${#WORKER[@]} worker nodes"

# for i in ${NODES[@]}; do echo $i; done


cd $MUST_PATH
cd $(echo */)
cd namespaces/openshift-etcd/pods
echo -e ""
echo -e "[ETCD]"

OVRL=0
NTP=0
HR=0
TK=0
LED=0

etcd_overload() {
    OVERLOAD=$(cat $1/etcd/etcd/logs/current.log|grep 'overload'|wc -l)
    if [ "$OVERLOAD" != "0" ]; then
      echo -e "${RED}[WARNING]${NONE} we found $OVERLOAD 'server is likely overloaded' messages in $1"
      echo -e ""
      OVRL=$(($OVRL+$OVERLOAD))
    fi
}

etcd_took_too_long() {
    TOOK=$(cat $1/etcd/etcd/logs/current.log|grep 'took too long'|wc -l)
    if [ "$TOOK" != "0" ]; then
      echo -e "${RED}[WARNING]${NONE} we found $TOOK took too long messages in $1"
      TK=$(($TK+$TOOK))
      echo -e ""
    fi
}

etcd_ntp() {
    CLOCK=$(cat $1/etcd/etcd/logs/current.log|grep 'clock difference'|wc -l)
    if [ "$CLOCK" != "0" ]; then
      echo -e "${RED}[WARNING]${NONE} we found $CLOCK ntp clock difference messages in $1"
      NTP=$(($NTP+$CLOCK))
    fi
}

etcd_heart() {
    HEART=$(cat $1/etcd/etcd/logs/current.log|grep 'failed to send out heartbeat on time'|wc -l)
    if [ "$HEART" != "0" ]; then
      echo -e "${RED}[WARNING]${NONE} we found $HEART failed to send out heartbeat on time messages in $1"
      HR=$(($HR+$HEART))
    fi
}

etcd_space() {
    SPACE=$(cat $member/etcd/etcd/logs/current.log|grep 'database space exceeded'|wc -l)
    if [ "$SPACE" != "0" ]; then
      echo -e "${RED}[WARNING]${NONE} we found $SPACE 'database space exceeded' in $1"
      SP=$(($SP+$SPACE))
    fi
}

etcd_leader() {
  LEADER=$(cat $member/etcd/etcd/logs/current.log|grep 'leader changed'|wc -l)
      if [ "$LEADER" != "0" ]; then
      echo -e "${RED}[WARNING]${NONE} we found $LEADER 'leader changed' in $1"
      LED=$(($LED+$LEADER))
    fi
}


etcd_compaction() {

  echo -e "Compaction on $1"
  case "${OCP_VERSION}" in
  4.9*|4.8*|4.10*)
    echo -e "[highest seconds]"
    cat $1/etcd/etcd/logs/current.log|grep "compaction"| grep -v downgrade| grep -E "[0-9]+(.[0-9]+)s"|grep -o '[^,]*$'| cut -d":" -f2|grep -oP '"\K[^"]+'|sort| tail -6
    echo -e ""
    echo -e "[highest ms]"
    cat $1/etcd/etcd/logs/current.log|grep "compaction"| grep -v downgrade| grep -E "[0-9]+(.[0-9]+)ms"|grep -o '[^,]*$'| cut -d":" -f2|grep -oP '"\K[^"]+'|sort| tail -6
    
    # ${CLIENT} logs pod/$1 -n ${NS} -c etcd | grep "compaction"| grep -v downgrade| grep -E "[0-9]+(.[0-9]+)*"|grep -o '[^,]*$'| cut -d":" -f2|grep -oP '"\K[^"]+'|sort| tail -10
    ;;
  4.7*)
    echo -e "[highest seconds]"
    cat $1/etcd/etcd/logs/current.log | grep "compaction"| grep -E "[0-9]+(.[0-9]+)s"|cut -d " " -f13| cut -d ')' -f 1 |sort|tail -6
    echo -e ""
    echo -e "[highest ms]"
    cat $1/etcd/etcd/logs/current.log | grep "compaction"| grep -E "[0-9]+(.[0-9]+)ms"|cut -d " " -f13| cut -d ')' -f 1 |sort|tail -6
    ;;
  4.6*)
    echo -e "[highest seconds]"
    cat $1/etcd/etcd/logs/current.log | grep "compaction"| grep -E "[0-9]+(.[0-9]+)s"|cut -d " " -f13| cut -d ')' -f 1 |sort|tail -6 #was f12, but doesnt work on some gathers
    echo -e ""
    echo -e "[highest ms]"
    cat $1/etcd/etcd/logs/current.log | grep "compaction"| grep -E "[0-9]+(.[0-9]+)ms"|cut -d " " -f13| cut -d ')' -f 1 |sort|tail -6 #was f12, but doesnt work on some gathers
    ;;
  *)
    echo -e "unknown version ${OCP_VERSION} !"
    ;;
  esac
  echo -e ""
}



# MAIN FUNCS

overload_solution() {
    echo -e "SOLUTION: Review ETCD and CPU metrics as this could be caused by CPU bottleneck or slow disk."
    echo -e ""
}


overload_check() {
    # echo -e ""
    # echo -e "[ETCD - looking for 'server is likely overloaded' messages.]"
    # echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_overload $member
    done
    echo -e "Found together $OVRL 'server is likely overloaded' messages."
    echo -e ""
    if [[ $OVRL -ne "0" ]];then
        overload_solution
    fi
}

tooklong_solution() {
    echo -e ""
    echo -e "SOLUTION: Even with a slow mechanical disk or a virtualized network disk, applying a request should normally take fewer than 50 milliseconds (and around 5ms for fast SSD/NVMe disk)."
    echo -e ""
}

tooklong_check() {
    # echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_took_too_long $member
    done
    echo -e ""
    if [[ $TK -eq "0" ]];then
        echo -e "Found zero 'took too long' messages.  OK"
    else
        echo -e "Found together $TK 'took too long' messages."
    fi
    if [[ $TK -ne "0" ]];then
        tooklong_solution
    fi
}



ntp_solution() {
    echo -e ""
    echo -e "SOLUTION: When clocks are out of sync with each other they are causing I/O timeouts and the liveness probe is failing which makes the ETCD pod to restart frequently. Check if Chrony is enabled, running, and in sync with:"
    echo -e "          - chronyc sources"
    echo -e "          - chronyc tracking"
    echo -e ""
}

ntp_check() {
    # echo -e ""
    # echo -e "[ETCD - looking for 'rafthttp: the clock difference against peer XXXX is too high' messages.]"
    # echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_ntp $member
    done
    echo -e ""
    if [[ $NTP -eq "0" ]];then
        echo -e "Found zero NTP out of sync messages.  OK"
    else
        echo -e "Found together $NTP NTP out of sync messages."
    fi
    echo -e ""
    if [[ $NTP -ne "0" ]];then
        ntp_solution
    fi
}

heart_solution() {
    echo -e ""
    echo -e "SOLUTION: Usually this issue is caused by a slow disk. The disk could be experiencing contention among ETCD and other applications, or the disk is too simply slow."
    echo -e ""
}

heart_check() {
    # echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_heart $member
    done
    echo -e ""    
    if [[ $HEART -eq "0" ]];then
        echo -e "Found zero 'failed to send out heartbeat on time' messages.  OK"
    else
        echo -e "Found together $HR 'failed to send out heartbeat on time' messages."
    fi
    echo -e ""
    if [[ $HEART -ne "0" ]];then
        heart_solution
    fi
}

space_solution() {
    echo -e ""
    echo -e "SOLUTION: Defragment and clean up ETCD, remove unused secrets or deployments."
    echo -e ""
}

space_check() {
    # echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_space $member
    done
    echo -e ""
    if [[ $SP -eq "0" ]];then
        echo -e "Found zero 'database space exceeded' messages.  OK"
    else
        echo -e "Found together $SP 'database space exceeded' messages."
    fi
    echo -e ""
    if [[ $SPACE -ne "0" ]];then
        space_solution
    fi
}


leader_solution() {
    echo -e ""
    echo -e "SOLUTION: Defragment and clean up ETCD. Also consider faster storage."
    echo -e ""
}

leader_check() {
    # echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_leader $member
    done
    echo -e ""
    if [[ $LED -eq "0" ]];then
        echo -e "Found zero 'leader changed' messages.  OK"
    else
        echo -e "Found together $LED 'leader changed' messages."
    fi
    if [[ $LED -ne "0" ]];then
        leader_solution
    fi
}

compaction_check() {
  echo -e "-- ETCD COMPACTION ---"
  echo -e ""
  echo -e "should be ideally below 100ms (and below 10ms on fast SSD/NVMe)"
  echo -e ""
  for member in $(ls |grep -v "revision"|grep -v "quorum"); do
    etcd_compaction $member
  done
  echo -e ""
  # echo -e "  Found together $LED 'leader changed' messages."
  # if [[ $LED -ne "0" ]];then
  #     leader_solution
  # fi
}

compaction_check
echo -e ""
echo -e "- ERROR CHECK ---"
overload_check
tooklong_check
ntp_check
heart_check
space_check
leader_check


echo -e ""
echo -e "[NETWORKING]"
cd ../../../cluster-scoped-resources/network.openshift.io/clusternetworks/
cat default.yaml |grep CIDR
cat default.yaml | grep serviceNetwork

echo -e ""
echo -e "ADDITIONAL HELP:"
help_etcd_troubleshoot
help_etcd_metrics
help_etcd_networking
help_etcd_objects
