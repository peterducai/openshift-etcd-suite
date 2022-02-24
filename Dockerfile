# building container 
FROM registry.fedoraproject.org/fedora
RUN dnf install fio -y && dnf clean all -y
WORKDIR /
COPY fio_suite.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/fio_suite.sh
CMD ["fio_suite.sh"] 