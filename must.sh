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

cat cluster-scoped-resources/config.openshift.io/clusterversions.yaml |grep "Cluster version is"
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
  echo -e "List number of objects in ETCD:"
  echo -e ""
  echo -e "oc rsh <etcd pod> -n openshift-etcd -c etcd"
  echo -e "> etcdctl get / --prefix --keys-only | sed '/^$/d' | cut -d/ -f3 | sort | uniq -c | sort -rn"
  echo -e ""
  echo -e "[HINT] Any number of CRDs (secrets, deployments, etc..) above 8k could cause performance issues on storage with not enough IOPS."

  echo -e ""
  echo -e "List secrets per namespace:"
  echo -e ""
  echo -e "> oc get secrets -A --no-headers | awk '{ns[$1]++}END{for (i in ns) print i,ns[i]}'"
  echo -e ""
  echo -e "[HINT] Any namespace with 20+ secrets should be cleaned up (unless there's specific customer need for so many secrets)."
  echo -e ""
}

# help_etcd_objects


for filename in *.yaml; do
    [ -e "$filename" ] || continue
    # echo -e "[$filename]"
    # cat $filename |grep node-role|grep -w "node-role.kubernetes.io/master:"
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

etcd_overload() {
    OVERLOAD=$(cat $1/etcd/etcd/logs/current.log|grep 'overload'|wc -l)
    if [ "$OVERLOAD" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $OVERLOAD 'server is likely overloaded' messages in $1"
      echo -e ""
      OVRL=$(($OVRL+$OVERLOAD))
    fi
}

etcd_took_too_long() {
    TOOK=$(cat $1/etcd/etcd/logs/current.log|grep 'took too long'|wc -l)
    if [ "$TOOK" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $TOOK took too long messages in $1"
      TK=$(($TK+$TOOK))
      echo -e ""
    fi
}

etcd_ntp() {
    CLOCK=$(cat $1/etcd/etcd/logs/current.log|grep 'clock difference'|wc -l)
    if [ "$CLOCK" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $CLOCK ntp clock difference messages in $1"
      NTP=$(($NTP+$CLOCK))
    fi
}

etcd_heart() {
    HEART=$(cat $1/etcd/etcd/logs/current.log|grep 'failed to send out heartbeat on time'|wc -l)
    if [ "$HEART" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $HEART failed to send out heartbeat on time messages in $1"
      HR=$(($HR+$HEART))
    fi
}


# MAIN FUNCS

overload_solution() {
    echo -e "  SOLUTION: Review ETCD and CPU metrics as this could be caused by CPU bottleneck or slow disk."
    echo -e ""
}


overload_check() {
    echo -e ""
    echo -e "[ETCD - looking for 'server is likely overloaded' messages.]"
    echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_overload $member
    done
    echo -e "  Found together $OVRL overloaded messages."
    echo -e ""
    if [[ $OVRL -ne "0" ]];then
        overload_solution
    fi
}

tooklong_solution() {
    echo -e ""
    echo -e "  SOLUTION: Even with a slow mechanical disk or a virtualized network disk, applying a request should normally take fewer than 50 milliseconds (and around 5ms for fast SSD/NVMe disk)."
    echo -e ""
}

tooklong_check() {
    echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_took_too_long $member
    done
    echo -e ""
    echo -e "  Found together $TK 'took too long' messages."
    if [[ $TK -ne "0" ]];then
        tooklong_solution
    fi
}



ntp_solution() {
    echo -e ""
    echo -e "  SOLUTION: When clocks are out of sync with each other they are causing I/O timeouts and the liveness probe is failing which makes the ETCD pod to restart frequently. Check if Chrony is enabled, running, and in sync with:"
    echo -e "            - chronyc sources"
    echo -e "            - chronyc tracking"
    echo -e ""
}

ntp_check() {
    echo -e ""
    echo -e "[ETCD - looking for 'rafthttp: the clock difference against peer XXXX is too high' messages.]"
    echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_ntp $member
    done
    echo -e ""
    if [[ $NTP -eq "0" ]];then
        echo -e "  Found together $NTP NTP out of sync messages.  OK"
    else
        echo -e "  Found together $NTP NTP out of sync messages."
    fi
    
    if [[ $NTP -ne "0" ]];then
        overload_solution
    fi
}

heart_solution() {
    echo -e ""
    echo -e "  SOLUTION: Usually this issue is caused by a slow disk. The disk could be experiencing contention among ETCD and other applications, or the disk is too simply slow."
    echo -e ""
}

heart_check() {
    echo -e ""
    for member in $(ls |grep -v "revision"|grep -v "quorum"); do
      etcd_heart $member
    done
    echo -e ""
    echo -e "  Found together $HEART messages."
    if [[ $HEART -ne "0" ]];then
        heart_solution
    fi
    # if [ "$HEART" != "0" ]; then
    #   echo -e "  ${RED}[WARNING]${NONE} we found $HEART failed to send out heartbeat on time messages!"
    #   echo -e ""
    # fi
}


overload_check
ntp_check
heart_check






for member in $(ls |grep -v "revision"|grep -v "quorum"); do
    echo -e "- $member ----------------"
    echo -e ""



    
    HEART=$(cat $member/etcd/etcd/logs/current.log|grep 'failed to send out heartbeat on time'|wc -l)
    SPACE=$(cat $member/etcd/etcd/logs/current.log|grep 'database space exceeded'|wc -l)
    LEADER=$(cat $member/etcd/etcd/logs/current.log|grep 'leader changed'|wc -l)


    



    if [ "$HEART" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $HEART failed to send out heartbeat on time messages!"
      echo -e "  SOLUTION: Usually this issue is caused by a slow disk. The disk could be experiencing contention among ETCD and other applications, or the disk is too simply slow."
      echo -e ""
    fi

    if [ "$SPACE" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $SPACE database space exceeded messages!"
    fi

    if [ "$LEADER" != "0" ]; then
      echo -e "  ${RED}[WARNING]${NONE} we found $LEADER leader changed messages!"
    fi

    echo -e ""

    # echo -e "[$filename]"
    # cat $filename |grep node-role|grep -w "node-role.kubernetes.io/master:"
    # [ ! -z "$(cat $filename |grep node-role|grep -w 'node-role.kubernetes.io/master:')" ] && MASTER+=("$filename") && NODES+=("$filename [master]") || true
done


echo -e ""
echo -e "[NETWORKING]"
cd ../../../cluster-scoped-resources/network.openshift.io/clusternetworks/
cat default.yaml |grep CIDR
cat default.yaml | grep serviceNetwork
