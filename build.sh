#!/bin/bash

buildah bud -t quay.io/peterducai/openshift-etcd-suite:latest .
podman login -u USER -p PASSWORD quay.io
podman push quay.io/peterducai/openshift-etcd-suite:latest
podman push quay.io/peterducai/openshift-etcd-suite:0.1.3

