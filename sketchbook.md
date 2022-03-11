# other stuff

```
ip -s link show
curl -k http://api.<OCP URL>.com -w "%{time_connect},%{time_total},%{speed_download},%{http_code},%{size_download},%{url_effective}\n"
journalctl -xe
dmesg
```




To modify an Amazon EBS volume using the AWS Management Console:
1. Open the Amazon EC2 console [1].
2. Choose Volumes, select the volume to modify, and then choose Actions, Modify Volume.
3. The Modify Volume window displays the volume ID and the volume’s current configuration, including type, size, IOPS, and throughput. Set new configuration values as follows:
   - To modify the type, choose io1 for Volume Type.
   - To modify the IOPS, enter a new value for IOPS.
   - After you have finished changing the volume settings, choose Modify. When prompted for confirmation, choose Yes.


https://aws.amazon.com/it/blogs/storage/migrate-your-amazon-ebs-volumes-from-gp2-to-gp3-and-save-up-to-20-on-costs/