# openshift-etcd-suite

tools to troubleshoot ETCD on Openshift 4

For easy use of container you can create alias for openshift-etcd-suite

> alias oes="podman run --volume /$(pwd):/test:Z quay.io/peterducai/openshift-etcd-suite:latest"

to build container just run

> buildah bud -t openshift-etcd-suite:latest .

## etcd.sh script

ETCD script will make collect info from ETCD pods, make little summary and search for errors/issues and explains what are expected values.

Fastest way to use it with must-gather is 

```
alias etcdcheck='podman run --privileged --volume /$(pwd):/test quay.io/peterducai/openshift-etcd-suite:latest etcd omc'
etcdcheck /test/<path to must-gather>
```

You can either do *oc login* and then run

> chmod +x etcd.sh && ./etcd.sh

or you can use it with [omc](https://github.com/gmeghnag/omc) and must-gather (omc should be either in /usr/bin or $HOME/bin directory)

> ./etcd.sh omc /some_path/must-gather.folder

or 

> podman run --privileged --volume /$(pwd):/test quay.io/peterducai/openshift-etcd-suite:latest etcd omc /test/path-to-must-gather


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

```
podman run --privileged --volume /$(pwd):/test quay.io/peterducai/openshift-etcd-suite:latest fio
FIO SUITE version 0.1
 
WARNING: this test will run for several minutes without any progress! Please wait until it finish!
 
- [MAX CONCURRENT READ] ---
This job is a read-heavy workload with lots of parallelism that is likely to show off the device's best throughput:
 
Highly concurrent reading of 1GB file 
  read: IOPS=4794, BW=300MiB/s (314MB/s)(1024MiB/3417msec)
 
Highly concurrent reading of 200MB file 
  read: IOPS=4139, BW=259MiB/s (271MB/s)(200MiB/773msec)
 
- [REQUEST OVERHEAD AND SEEK TIMES] ---
This job is a latency-sensitive workload that stresses per-request overhead and seek times. Random reads.
 
Reading randomly 1GB file 
  read: IOPS=267k, BW=1043MiB/s (1093MB/s)(1024MiB/982msec)
 
Reading randomly 200MB file 
  read: IOPS=289k, BW=1130MiB/s (1185MB/s)(200MiB/177msec)
 
 
- [SEQUENTIAL IOPS UNDER DIFFERENT READ/WRITE LOAD] ---
 
 -- SINGLE JOB -- 
-- [70% read, 30% write] --
 
Sequential read of 1GB file 
  write: IOPS=42.7k, BW=167MiB/s (175MB/s)(308MiB/1844msec); 0 zone resets
 
Sequential read of 1GB file 
  write: IOPS=42.6k, BW=166MiB/s (175MB/s)(59.9MiB/360msec); 0 zone resets
 
 -- SINGLE JOB -- 
-- [30% read, 70% write] --
 
Sequential read of 1GB file 
  write: IOPS=35.6k, BW=139MiB/s (146MB/s)(140MiB/1005msec); 0 zone resets
 
Sequential read of 1GB file 
  write: IOPS=37.8k, BW=148MiB/s (155MB/s)(715MiB/4849msec); 0 zone resets
 
 -- 16 PARALLEL JOBS -- 
-- [70% read, 30% write] --
 
Sequential read of 1GB file 
  write: IOPS=2957, BW=11.6MiB/s (12.1MB/s)(193MiB/16710msec); 0 zone resets
 
Sequential read of 1GB file 
  write: IOPS=2718, BW=10.6MiB/s (11.1MB/s)(60.0MiB/5647msec); 0 zone resets
 
 -- 16 PARALLEL JOBS -- 
-- [30% read, 70% write] --
 
Sequential read of 1GB file 
  write: IOPS=2975, BW=11.6MiB/s (12.2MB/s)(14.7MiB/1264msec); 0 zone resets
 
Sequential read of 1GB file 
  write: IOPS=3130, BW=12.2MiB/s (12.8MB/s)(598MiB/48897msec); 0 zone resets
 
 
- END -----------------------------------------

```



[![Docker Repository on Quay](https://quay.io/repository/peterducai/openshift-etcd-suite/status "Docker Repository on Quay")](https://quay.io/repository/peterducai/openshift-etcd-suite)