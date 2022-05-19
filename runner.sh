#!/bin/bash

case "$1" in
  etcd)
    ./etcd.sh $2 $3
    ;;
  toolong)
    etcd_tooktoolong.py $2
    ;;
  fio)
    ./fio_suite.sh
    ;;
  fio2)
    ./fio_suite2.sh
    ;;
  *)
    echo -e "NO PARAMS. Choose 'etcd' or 'fio' or 'toolong'"
    ;;
esac