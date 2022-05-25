# building container 
FROM registry.fedoraproject.org/fedora
RUN dnf install fio python-pip wget -y && dnf clean all -y
# RUN /usr/bin/python3 -m pip install --upgrade pip
# RUN pip install numpy
# RUN pip install matplotlib

WORKDIR /
COPY etcd.sh /
COPY fio_suite.sh /
COPY fio_suite2.sh /
COPY runner.sh /usr/local/bin/
RUN chmod +x /fio_suite.sh
RUN chmod +x /fio_suite2.sh
RUN chmod +x /etcd.sh
RUN chmod +x /usr/local/bin/runner.sh
CMD ["/usr/local/bin/runner.sh"]
ENTRYPOINT ["/usr/local/bin/runner.sh"]