#!/bin/bash

echo -e "FIO SUITE version 0.1"
echo -e " "
echo -e "WARNING: this test will run for several minutes without any progress! Please wait until it finish!"
echo -e " "


# if [ -z "$(rpm -qa | grep fio)" ]
# then
#       echo "sudo dnf install fio -y"
# else
#       echo "fio is installed.. OK"
# fi

echo -e "- [MAX CONCURRENT READ] ---"
echo -e "This job is a read-heavy workload with lots of parallelism that is likely to show off the device's best throughput:"
echo -e " "

fio --name=global1 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read1 --iodepth=4 --readwrite=randread --numjobs=16 --blocksize=64k --offset_increment=128m --size=1G > best_1G_d4.log
best_large=$(cat best_1G_d4.log |grep IOPS|tail -1)
echo -e "Highly concurrent reading of 1GB file \n$best_large"
echo -e " "
rm fiotest
rm best_1G_d4.log


fio --name=global1 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read1 --iodepth=4 --readwrite=randread --numjobs=16 --blocksize=64k --offset_increment=128m --size=200M > best_200M_d4.log
best_small=$(cat best_200M_d4.log |grep IOPS|tail -1)
echo -e "Highly concurrent reading of 200MB file \n$best_small"
echo -e " "
rm best_200M_d4.log



echo -e "- [REQUEST OVERHEAD AND SEEK TIMES] ---"
echo -e "This job is a latency-sensitive workload that stresses per-request overhead and seek times. Random reads."
echo -e " "



fio  --name=global2 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read2 --iodepth=4 --readwrite=randread --blocksize=4k --size=1G > rand_1G_d1.log
overhead_big=$(cat rand_1G_d1.log |grep IOPS|tail -1)
echo -e "Reading randomly 1GB file \n$overhead_big"
echo -e " "
rm rand_1G_d1.log

fio  --name=global2 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read2 --iodepth=4 --readwrite=randread --blocksize=4k --size=200M > rand_200M_d1.log
overhead_small=$(cat rand_200M_d1.log |grep IOPS|tail -1)
echo -e "Reading randomly 200MB file \n$overhead_small"
echo -e " "
rm rand_200M_d1.log

# echo -e "- [MIXED CONCURRENT IO] ---"
# echo -e "This job simulates a more real-life workload with an concurrent I/O pattern that contains boths reads and writes:"

# echo -e " "
echo -e " "
echo -e "- [SEQUENTIAL IOPS UNDER DIFFERENT READ/WRITE LOAD] ---"
echo -e " "

echo -e " -- SINGLE JOB -- "
echo -e "-- [70% read, 30% write] --"
echo -e " "

fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=4 --blocksize=4k --size=1G --percentage_random=0 > r70_w30_1G_d4.log
s7030big=$(cat r70_w30_1G_d4.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$s7030big"
echo -e " "
rm r70_w30_1G_d4.log

fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=4 --blocksize=4k --size=200M > r70_w30_200M_d4.log
s7030small=$(cat r70_w30_200M_d4.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$s7030small"
echo -e " "
rm r70_w30_200M_d4.log

# fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3 --readwrite=randrw --rwmixread=70 --rwmixwrite=30 --iodepth=4 --blocksize=4k --size=1G > r70_w30_1G_d4.log

# fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3 --readwrite=randrw --rwmixread=70 --rwmixwrite=30 --iodepth=4 --blocksize=4k --size=200M > r70_w30_200M_d4.log


# ## This job simulates a more real-life workload with an sequential I/O pattern that contains boths reads and writes:


# fio --name=global4 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read4 --readwrite=randrw --rwmixread=70 --rwmixwrite=30 --iodepth=1 --blocksize=4k --size=200M > r70_w30_200M_d1.log

# fio --name=global4 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read4 --readwrite=randrw --rwmixread=70 --rwmixwrite=30 --iodepth=1 --blocksize=4k --size=1G > r70_w30_1G_d1.log

echo -e " -- SINGLE JOB -- "
echo -e "-- [30% read, 70% write] --"
echo -e " "

fio --name=global5 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read5 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=200M  > r30_w70_200M_d1.log
so7030big=$(cat r30_w70_200M_d1.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$so7030big"
echo -e " "
rm r30_w70_200M_d1.log

fio --name=global5 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read5 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=1G > r30_w70_1G_d1.log
so7030small=$(cat r30_w70_1G_d1.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$so7030small"
echo -e " "
rm r30_w70_1G_d1.log
rm fiotest


echo -e " -- 16 PARALLEL JOBS -- "
echo -e "-- [70% read, 30% write] --"
echo -e " "

fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3  --numjobs=16 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=4 --blocksize=4k --size=1G --percentage_random=0 > r70_w30_1G_d4.log
s7030big=$(cat r70_w30_1G_d4.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$s7030big"
echo -e " "
rm r70_w30_1G_d4.log

fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3  --numjobs=16 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=4 --blocksize=4k --size=200M > r70_w30_200M_d4.log
s7030small=$(cat r70_w30_200M_d4.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$s7030small"
echo -e " "
rm r70_w30_200M_d4.log

echo -e " -- 16 PARALLEL JOBS -- "
echo -e "-- [30% read, 70% write] --"
echo -e " "

fio --name=global5 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read5  --numjobs=16 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=200M  > r30_w70_200M_d1.log
so7030big=$(cat r30_w70_200M_d1.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$so7030big"
echo -e " "
rm r30_w70_200M_d1.log

fio --name=global5 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read5  --numjobs=16 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=1G > r30_w70_1G_d1.log
so7030small=$(cat r30_w70_1G_d1.log |grep IOPS|tail -1)
echo -e "Sequential read of 1GB file \n$so7030small"
echo -e " "
rm r30_w70_1G_d1.log
rm fiotest

echo -e " "
echo -e "- END -----------------------------------------"