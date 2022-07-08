etcd.sh failed to find a NTP issue in the cluster.
[NTP MESSAGES]
Found zero NTP out of sync messages.  OK
-bash-4.2$ grep 'clock difference' namespaces/openshift-etcd/pods/etcd-pdhppr-xc55z-master-0/etcd/etcd/logs/current.log 
-bash-4.2$ 
But there is a huge clock-drift and the cluster is not working:
$ tail -1 namespaces/openshift-etcd/pods/etcd-pdhppr-xc55z-master-0/etcd/etcd/logs/current.log 
2022-07-04T06:35:26.512448489Z {"level":"warn","ts":"2022-07-04T06:35:26.512Z","caller":"rafthttp/probing_status.go:86","msg":"prober found high clock drift","round-tripper-name":"ROUND_TRIPPER_SNAPSHOT","remote-peer-id":"d66e878e1cd03cfc","clock-drift":"8m0.640985013s","rtt":"502.906µs"}





4:01
maybe we can add this check to the script.