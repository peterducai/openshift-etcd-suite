#!/usr/bin/env python3

import os.path
import sys
import re
import json

import numpy as np
import matplotlib.pyplot as plt


etcd_logfile = sys.argv[1]
if not os.path.isfile(etcd_logfile):
    print('File does not exist')

lines_skipped = 0
times_list = []
with open(etcd_logfile, 'r') as logfile:
    for line in logfile:
        if "request took too long" in line:

            # Remove timestamp at beginning of line
            # 2021-08-26T06:20:50.210590693Z {"level":"warn","ts":"20...
            line = line[31:]

            # Print lines for https://bugzilla.redhat.com/show_bug.cgi?id=2017004
            # etcd log sometimes contains invalid JSON
            #print(line)

            # Parse line
            try:
                line_json = json.loads(line)
            except:
                lines_skipped = lines_skipped + 1
                continue
            time_took = line_json["took"]

            # Process "ms" and "s"
            if(re.match('[0-9]*\.[0-9]*ms', time_took)):
                time = time_took[0:-2]

            elif(re.match('[0-9]*\.[0-9]*s', time_took)):
                # Time is in seconds, convert it to ms
                time = 1000 * float(time_took[0:-1])

            times_list.append(time)

#for item in times_list:
#    print(item)

a = np.asarray(times_list).astype(np.float64)

if lines_skipped > 0:
    print("")
    print("WARNING: LINES SKIPPED: {0}".format(lines_skipped))
    print("")

print("# Statistics")
print("Count: {0}".format(len(times_list)))
print("Min: {0}".format(np.min(a)))
print("Max: {0}".format(np.max(a)))
print("Average: {0}".format(np.average(a)))
print("Median: {0}".format(np.median(a)))
print("Std Dev: {0}".format(np.std(a)))