# openshift-etcd-suite

tools to troubleshoot ETCD on Openshift 4

## fio_suite

> podman run --volume /$(pwd):/test:Z quay.io/peterducai/openshift-etcd-suite:latest

but on RHCOS run

> podman run --privileged --volume /$(pwd):/test quay.io/peterducai/openshift-etcd-suite:latest

or to benchmark disk where ETCD resides

> podman run --privileged --volume /var/lib/etcd:/test quay.io/peterducai/openshift-etcd-suite:latest

**NOTE:** don't run it in / or /home/user as its top folder and you get Selinux error

## etcd.sh script

ETCD script will make collect info from ETCD pods, make little summary and search for errors/issues and explains what are expected values

You can either do *oc login* and then run

> chmod +x etcd.sh && ./etcd.sh

or you can use it with [omc](https://github.com/gmeghnag/omc)/omg and must-gather (omc should be either in /usr/bin or $HOME/bin directory)

> ./etcd.sh omc /some_path/must-gather.folder