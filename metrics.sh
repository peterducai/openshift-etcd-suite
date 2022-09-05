#!/bin/bash

function promqlQuery() {
    END_TIME=$(date -u +%s) 
    START_TIME=$(date -u --date="60 minutes ago" +%s)

    oc exec -c prometheus -n openshift-monitoring prometheus-k8s-0 -- curl --data-urlencode "query=$1" --data-urlencode "step=10" --data-urlencode "start=$START_TIME" --data-urlencode "end=$END_TIME" http://localhost:9090/api/v1/query_range 
}
promqlQuery "rate(node_disk_read_time_seconds_total[1m])" > ./out/node_disk_read_time_seconds_total
promqlQuery "rate(node_disk_write_time_seconds_total[1m])" > ./out/node_disk_write_time_seconds_total
promqlQuery "rate(node_schedstat_running_seconds_total[1m])" > ./out/node_schedstat_running_seconds_total
promqlQuery "rate(node_schedstat_waiting_seconds_total[1m])" > ./out/node_schedstat_waiting_seconds_total
promqlQuery "rate(node_cpu_seconds_total[1m])" > ./out/node_cpu_seconds_total
promqlQuery "rate(node_network_receive_errs_total[1m])" > ./out/node_network_receive_errs_total 
promqlQuery "rate(node_network_receive_drop_total[1m])" > ./out/node_network_receive_drop_total 
promqlQuery "rate(node_network_receive_bytes_total[1m])" > ./out/node_network_receive_bytes_total
promqlQuery "rate(node_network_transmit_errs_total[1m])" > ./out/node_network_transmit_errs_total 
promqlQuery "rate(node_network_transmit_drop_total[1m])" > ./out/node_network_transmit_drop_total 
promqlQuery "rate(node_network_transmit_bytes_total[1m])" > ./out/node_network_transmit_bytes_total
promqlQuery "instance:node_cpu_utilisation:rate1m" > ./out/node_cpu_utilisation
promqlQuery "instance_device:node_disk_io_time_seconds:rate1m" > ./out/node_disk_io_time_seconds
promqlQuery "rate(node_disk_io_time_seconds_total[1m])" > ./out/node_disk_io_time_seconds_total
promqlQuery "histogram_quantile(0.99, sum(rate(etcd_disk_backend_commit_duration_seconds_bucket{job=\"etcd\"}[1m])) by (instance, le))" > ./out/etcd_disk_backend_commit_duration_seconds_bucket_.99
promqlQuery "histogram_quantile(0.999, sum(rate(etcd_disk_backend_commit_duration_seconds_bucket{job=\"etcd\"}[1m])) by (instance, le))" > ./out/etcd_disk_backend_commit_duration_seconds_bucket_.999
promqlQuery "histogram_quantile(0.9999, sum(rate(etcd_disk_backend_commit_duration_seconds_bucket{job=\"etcd\"}[1m])) by (instance, le))" > ./out/etcd_disk_backend_commit_duration_seconds_bucket_.9999

tar cfz metrics.tar.gz ./out