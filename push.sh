#!/bin/bash

podman login -u peterducai -p key quay.io
podman push quay.io/peterducai/openshift-etcd-suite:latest
podman push quay.io/peterducai/openshift-etcd-suite:0.1.20