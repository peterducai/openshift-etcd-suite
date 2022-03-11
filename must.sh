#!/bin/bash

MUST_PATH=$1

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
echo -e "${#INFRA[@]} infra nodes"
echo -e "${#WORKER[@]} worker nodes"

# for i in ${NODES[@]}; do echo $i; done


cd $MUST_PATH
cd $(echo */)
cd namespaces/openshift-etcd/pods
echo -e ""
echo -e "[ETCD]"
echo -e ""
# ls |grep -v "revision"|grep -v "quorum"

for member in $(ls |grep -v "revision"|grep -v "quorum"); do
    echo -e "$member"

    OVERLOAD=$(cat $member/etcd/etcd/logs/current.log|grep 'overload'|wc -l)
    TOOK=$(cat $member/etcd/etcd/logs/current.log|grep 'took too long'|wc -l)
    CLOCK=$(cat $member/etcd/etcd/logs/current.log|grep 'clock difference'|wc -l) 
    HEART=$(cat $member/etcd/etcd/logs/current.log|grep 'failed to send out heartbeat on time'|wc -l)
    SPACE=$(cat $member/etcd/etcd/logs/current.log|grep 'database space exceeded'|wc -l)
    LEADER=$(cat $member/etcd/etcd/logs/current.log|grep 'leader changed'|wc -l)

    if [ "$OVERLOAD" = "0" ]; then
      echo -e "  - no overloaded messages. OK"
    else
      echo -e "  [WARNING] we found $OVERLOAD overloaded messages!"
    fi

    if [ "$TOOK" = "0" ]; then
      echo -e "  - no took too long messages. OK"
    else
      echo -e "  [WARNING] we found $TOOK took too long messages!"
    fi

    if [ "$CLOCK" = "0" ]; then
      echo -e "  - no ntp clock difference messages. OK"
    else
      echo -e "  [WARNING] we found $CLOCK ntp clock difference messages! Check 'chronyc sources' and 'chronyc tracking' on masters."
    fi


    echo -e "  - we found $(cat $member/etcd/etcd/logs/current.log|grep 'failed to send out heartbeat on time'|wc -l) failed to send out heartbeat on time messages."
    echo -e "  - we found $(cat $member/etcd/etcd/logs/current.log|grep 'database space exceeded'|wc -l) database space exceeded messages."
    echo -e "  - we found $(cat $member/etcd/etcd/logs/current.log|grep 'leader changed'|wc -l) leader changed messages."
    # echo -e "[$filename]"
    # cat $filename |grep node-role|grep -w "node-role.kubernetes.io/master:"
    # [ ! -z "$(cat $filename |grep node-role|grep -w 'node-role.kubernetes.io/master:')" ] && MASTER+=("$filename") && NODES+=("$filename [master]") || true
done


echo -e ""
echo -e "[NETWORKING]"
cd ../../../cluster-scoped-resources/network.openshift.io/clusternetworks/
cat default.yaml |grep CIDR
cat default.yaml | grep serviceNetwork
