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



# echo -e " "
echo -e " "
echo -e "- [SEQUENTIAL IOPS UNDER DIFFERENT READ/WRITE LOAD] ---"
echo -e " "

echo -e "-- [ SINGLE JOB, 70% read, 30% write] --"
echo -e " "

/usr/bin/fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=1 --blocksize=4k --size=1G --percentage_random=0 > r70_w30_1G_d4.log
s7030big=$(cat r70_w30_1G_d4.log |grep IOPS|tail -1)
echo -e "$s7030big"
cat r70_w30_1G_d4.log
rm r70_w30_1G_d4.log
echo -e " "
/usr/bin/fio --name=global3 --filename=fiotest --runtime=120 --ioengine=libaio --direct=1 --ramp_time=10 --name=read3 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=1 --blocksize=4k --size=200M > r70_w30_200M_d4.log
s7030small=$(cat r70_w30_200M_d4.log |grep IOPS|tail -1)
echo -e "$s7030small"
cat r70_w30_200M_d4.log
rm r70_w30_200M_d4.log
echo -e " "
echo -e "-- [ SINGLE JOB, 30% read, 70% write] --"
echo -e " "

/usr/bin/fio --name=global5 --filename=fiotest --runtime=120 --bs=2k --ioengine=libaio --direct=1 --ramp_time=10 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=200M  > r30_w70_200M_d1.log
so7030big=$(cat r30_w70_200M_d1.log |grep IOPS|tail -1)
echo -e "$so7030big"
cat r30_w70_200M_d1.log
rm r30_w70_200M_d1.log
echo -e " "
/usr/bin/fio --name=global5 --filename=fiotest --runtime=120 --bs=2k --ioengine=libaio --direct=1 --ramp_time=10 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=1G > r30_w70_1G_d1.log
so7030small=$(cat r30_w70_1G_d1.log |grep IOPS|tail -1)
echo -e "$so7030small"
cat r30_w70_1G_d1.log
rm r30_w70_1G_d1.log
rm fiotest

echo -e " "
echo -e "-- [ 8 PARALLEL JOBS, 70% read, 30% write] ----"
echo -e " "

/usr/bin/fio --name=global3 --filename=fiotest --runtime=120 --bs=2k --ioengine=libaio --direct=1 --ramp_time=10 --numjobs=8 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=1 --blocksize=4k --size=1G --percentage_random=0 > r70_w30_1G_d4.log
s7030big=$(cat r70_w30_1G_d4.log |grep IOPS|tail -1)
echo -e "$s7030big"
rm r70_w30_1G_d4.log
echo -e " "
/usr/bin/fio --name=global3 --filename=fiotest --runtime=120 --bs=2k --ioengine=libaio --direct=1 --ramp_time=10 --numjobs=8 --readwrite=rw --rwmixread=70 --rwmixwrite=30 --iodepth=1 --blocksize=4k --size=200M > r70_w30_200M_d4.log
s7030small=$(cat r70_w30_200M_d4.log |grep IOPS|tail -1)
echo -e "$s7030small"
rm r70_w30_200M_d4.log

echo -e " "
echo -e "-- [ 8 PARALLEL JOBS, 30% read, 70% write] ----"
echo -e " "

/usr/bin/fio --name=global5 --filename=fiotest --runtime=120 --bs=2k --ioengine=libaio --direct=1 --ramp_time=10 --numjobs=8 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=200M  > r30_w70_200M_d1.log
so7030big=$(cat r30_w70_200M_d1.log |grep IOPS|tail -1)
echo -e "$so7030big"
rm r30_w70_200M_d1.log
echo -e " "
/usr/bin/fio --name=global5 --filename=fiotest --runtime=120 --bs=2k --ioengine=libaio --direct=1 --ramp_time=10 --numjobs=8 --readwrite=rw --rwmixread=30 --rwmixwrite=70 --iodepth=1 --blocksize=4k --size=1G > r30_w70_1G_d1.log
so7030small=$(cat r30_w70_1G_d1.log |grep IOPS|tail -1)
echo -e "$so7030small"
rm r30_w70_1G_d1.log
rm fiotest

echo -e " "
echo -e "- END -----------------------------------------"