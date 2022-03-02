#!/usr/bin/env python3

import os.path
import sys
import re

import numpy as np
import matplotlib.pyplot as plt


etcd_logfile = sys.argv[1]
if not os.path.isfile(etcd_logfile):
    print('File does not exist')

times_list = []
with open(etcd_logfile, 'r') as logfile:
    for line in logfile:
        if "took too long" in line:

            # Get time from line
            time_string = re.search('\(.+\)', line).group()

            # Get rid of parentheses
            time_string = time_string[1:-1]

            if(re.match('[0-9]*\.[0-9]*ms', time_string)):
                time = time_string[0:-2]

            elif(re.match('[0-9]*\.[0-9]*s', time_string)):
                # Time is in seconds, convert it to ms
                time = time_string[0:-1]
                time = 1000 * float(time)

            times_list.append(time)

#for item in times_list:
#    print(item)

a = np.asarray(times_list).astype(np.float64)

print("")
print("Count: {0}".format(len(times_list)))
print("Min: {0}".format(np.min(a)))
print("Max: {0}".format(np.max(a)))
print("Average: {0}".format(np.average(a)))
print("Median: {0}".format(np.median(a)))
print("Std Dev: {0}".format(np.std(a)))