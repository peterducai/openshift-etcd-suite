# openshift-etcd-suite

tools to troubleshoot ETCD on Openshift 4

For easy use of container you can create alias for openshift-etcd-suite

> alias oes="podman run --volume /$(pwd):/test:Z quay.io/peterducai/openshift-etcd-suite:latest"

to build container just run

> buildah bud -t openshift-etcd-suite:latest .

## etcd.sh script

ETCD script will make collect info from ETCD pods, make little summary and search for errors/issues and explains what are expected values

You can either do *oc login* and then run

> chmod +x etcd.sh && ./etcd.sh

or you can use it with [omc](https://github.com/gmeghnag/omc) and must-gather (omc should be either in /usr/bin or $HOME/bin directory)

> ./etcd.sh omc /some_path/must-gather.folder

or 

> podman run --volume /$(pwd):/test:Z quay.io/peterducai/openshift-etcd-suite:latest etcd omc path_to_must-gather

## fio_suite

fio_suite is benchmark tool which runs several fio tests to see how IOPS change under different load.

Run

> ./fio_suite.sh

or thru podman/docker

> podman run --volume /$(pwd):/test:Z quay.io/peterducai/openshift-etcd-suite:latest fio

but on RHCOS run

> podman run --privileged --volume /$(pwd):/test quay.io/peterducai/openshift-etcd-suite:latest fio

or to benchmark disk where ETCD resides

> podman run --privileged --volume /var/lib/etcd:/test quay.io/peterducai/openshift-etcd-suite:latest fio

**NOTE:** don't run it in / or /home/user as its top folder and you get Selinux error



[![Docker Repository on Quay](https://quay.io/repository/peterducai/openshift-etcd-suite/status "Docker Repository on Quay")](https://quay.io/repository/peterducai/openshift-etcd-suite)