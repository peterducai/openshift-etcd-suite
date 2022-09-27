#!/bin/bash

podman login -u peterducai -p 7+xYl7py8Cbd/iPLUXeCFvZmpZ34H0yxG+SC3ds+t1eBlBzCKvzkMJV/dQ/lJdvd quay.io
podman push quay.io/peterducai/openshift-etcd-suite:latest
podman push quay.io/peterducai/openshift-etcd-suite:0.1.28
