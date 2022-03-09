#!/bin/bash

buildah bud -t quay.io/peterducai/openshift-etcd-suite:latest .
podman tag quay.io/peterducai/openshift-etcd-suite:latest quay.io/peterducai/openshift-etcd-suite:0.1.4

# podman push quay.io/peterducai/openshift-etcd-suite:latest
# podman push quay.io/peterducai/openshift-etcd-suite:0.1.3

