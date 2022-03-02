# building container 
FROM registry.fedoraproject.org/fedora
RUN dnf install fio python-pip -y && dnf clean all -y
RUN /usr/bin/python3 -m pip install --upgrade pip
RUN pip install matplotlib
RUN wget https://github.com/gmeghnag/omc/releases/download/v1.4.0/omc-v1.4.0_Linux_x86_64.tar.gz
RUN tar -xvf omc-v1.4.0_Linux_x86_64.tar.gz
WORKDIR /
COPY omc /usr/local/bin/
COPY fio_suite.sh /usr/local/bin/
COPY etcd_tooktoolong.py /usr/local/bin/
COPY runner.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/fio_suite.sh
RUN chmod +x /usr/local/bin/etcd_tooktoolong.py
RUN chmod +x /usr/local/bin/runner.sh
CMD ["runner.sh"]