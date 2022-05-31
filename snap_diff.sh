#!/bin/bash

# dump_keys <snapshot file> <output file>
function dump_keys() {
   rm -rf default.etcd
   etcdctl snapshot restore "$1"

   etcd --enable-pprof &
   etcdPid=$!

   # wait for it to come up
   etcdctl member list      
   etcdctl get / --prefix --keys-only | awk NF | sort -n > "$2"

   kill -9 $etcdPid
}

if [ "$#" -ne 3 ]; then
    echo "./snap_diff.sh <snapshot file> <snapshot file> <output diff>"
    exit 1
fi

first=$(mktemp)
dump_keys $1 $first
second=$(mktemp)
dump_keys $2 $second

diff $first $second > $3
echo "diff $first $second -> $3"
