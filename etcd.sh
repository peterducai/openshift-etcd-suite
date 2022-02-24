#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:$HOME/bin"

NS="openshift-etcd"
CLIENT="oc"
CURRENT_PATH=$(pwd)


# INPUT params

case "$1" in
  omc)
    CLIENT="omc"
    CURRENT_PATH=$2
    echo -e "using client omc  in folder $CURRENT_PATH"
    $($CLIENT use $CURRENT_PATH)
    echo -e "$($CLIENT version)"
    #$(${CLIENT} alert rule -s firing,pending -o wide)
    #$($CLIENT etcd status)
    ;;
  omg)
    CLIENT="$omg"
    CURRENT_PATH=$2
    echo -e "using client omg in folder $CURRENT_PATH"
    $($CLIENT use $CURRENT_PATH)
    ;;
  *)
    echo -e "using default client oc"
    ;;
esac

OCP_VERSION=$(${CLIENT} get clusterversion|tail -1|cut -d ' ' -f4|head --bytes 3)

echo -e ""
echo -e "CLUSTER VERSION IS $OCP_VERSION"
echo -e ""

etcd_compaction() {
  echo -e ""
  echo -e "- $1 ---------"

  case "${OCP_VERSION}" in
  4.9|4.8)
    ${CLIENT} logs pod/$1 -n ${NS} -c etcd | grep "compaction"| grep -v downgrade| grep -E "[0-9]+(.[0-9]+)*"|grep -o '[^,]*$'| cut -d":" -f2|grep -oP '"\K[^"]+'|sort| tail -10
    ;;
  4.7)
    #echo -e "${CLIENT} logs pod/$1 -n ${NS} -c etcd | grep \"compaction\"| grep -E \"[0-9]+(.[0-9]+)*\"|cut -d \" \" -f13| cut -d ')' -f 1 |sort|tail -10"
    ${CLIENT} logs pod/$1 -n ${NS} -c etcd | grep "compaction"| grep -E "[0-9]+(.[0-9]+)*"|cut -d " " -f13| cut -d ')' -f 1 |sort|tail -10
    ;;
  4.6)
    ${CLIENT} logs pod/$1 -n ${NS} -c etcd | grep "compaction"| grep -E "[0-9]+(.[0-9]+)*"|cut -d " " -f12| cut -d ')' -f 1 |sort|tail -10 
    ;;
  *)
    echo -e "unknown version ${CLIENT} !"
    ;;
  esac
}


etcd_overload() {
  echo -e ""
  overload_sum=$(${CLIENT} logs $1 -n ${NS} -c etcd | grep "overload"| wc -l)
  echo -e "we found $overload_sum messages in $1"
}

etcd_tooktoolong() {
  echo -e ""
  tooktoolong=$(${CLIENT} logs $1 -n ${NS} -c etcd | grep 'took too long' | wc -l)
  echo -e "we found $tooktoolong messages in $1"
}

etcd_ntp() {
  echo -e ""
  ntp=$(${CLIENT} logs $1 -n ${NS} -c etcd | grep 'clock difference' | wc -l)
  echo -e "we found $ntp messages in $1"
}

etcd_heartbeat() {
  echo -e ""
  heartbeat=$(${CLIENT} logs $1 -n ${NS} -c etcd | grep 'failed to send out heartbeat on time' | wc -l)
  echo -e "we found $heartbeat messages in $1"
}

etcd_membershealth() {
  echo -e ""
  ${CLIENT} rsh -n ${NS} -c etcd $1 etcdctl endpoint status -w table
}

etcd_objects() {
  echo -e ""
  ${CLIENT} rsh -n ${NS} -c etcd $1 etcdctl get / --prefix --keys-only | sed '/^$/d' | cut -d/ -f3 | sort | uniq -c | sort -rn
}

echo -e "-- ETCD COMPACTION ---------------------------------"
echo -e "should be ideally below 100ms (and below 10ms on fast SSD/NVMe)"
echo -e ""
for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_compaction $o;done

echo -e ""
echo -e "-- NUMBER OF ALL ETCD OBJECTS"
echo -e "any amount of objects higher than 8k can cause performance problems"
echo -e ""

if [[ $CLIENT = "oc" ]]
then
  for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_membershealth $o; break;done
  for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_objects $o; break;done
else
  echo "$CLIENT cannot use this feature."
fi




echo -e ""
echo -e "ERROR DETECTION"
echo -e ""
echo -e "-- NUMBER OF 'etcd is likely overloaded' MESSAGES ---------------------------------"
echo -e "there should be no messages like that at all"
for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_overload $o;done

echo -e ""
echo -e "-- NUMBER OF 'took too long' MESSAGES ---------------------------------"
echo -e "there should be ideally no messages like that, but it really depends also on amount of messages (hundreds vs thousands)"
for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_tooktoolong $o;done

echo -e ""
echo -e "-- NUMBER OF 'failed to send out heartbeat on time' MESSAGES ---------------------------------"
echo -e "Usually this issue is caused by a slow disk. Before the leader sends heartbeats attached with metadata, it may need to persist the metadata to disk. The disk could be experiencing contention among ETCD and other applications, or the disk is too simply slow"
for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_heartbeat $o;done

echo -e ""
echo -e "-- NUMBER OF 'rafthttp: the clock difference' MESSAGES ---------------------------------"
echo -e "when clocks are out of sync with each other they are causing I/O timeouts and the liveness probe is failing which makes the ETCD pod to restart frequently. Check if Chrony is enabled, running, and in sync with chronyc sources and chronyc tracking"
for o in $(${CLIENT} get pod -n openshift-etcd| grep -v quorum-guard | grep etcd|cut -d " " -f1); do etcd_ntp $o;done