#!/bin/bash

buildah bud -t quay.io/peterducai/openshift-etcd-suite:latest .
podman login -u peterducai -p KZkM7Z+sIC5xhL43g4tQFjbo3VA+1MuBAA93xyZqLqv7Cumh6plykV0MGjJsjX0f quay.io
podman push quay.io/peterducai/openshift-etcd-suite:latest
podman push quay.io/peterducai/openshift-etcd-suite:0.1.3

