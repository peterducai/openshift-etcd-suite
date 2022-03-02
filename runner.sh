#!/bin/bash

case "$1" in
  etcd)
    ./etcd.sh
    ;;
  toolong)
    ./etcd_tooktoolong.py
    ;;
  fio)
    ./fio_suite.sh
    ;;
  *)
    echo -e "NO PARAMS. Choose 'etcd' or 'fio' or 'toolong'"
    ;;
esac