# building container 
FROM registry.fedoraproject.org/fedora
RUN dnf install fio python-pip wget -y && dnf clean all -y
RUN /usr/bin/python3 -m pip install --upgrade pip
RUN pip install numpy
RUN pip install matplotlib
RUN wget https://github.com/gmeghnag/omc/releases/download/v1.4.0/omc-v1.4.0_Linux_x86_64.tar.gz
RUN tar -xvf omc-v1.4.0_Linux_x86_64.tar.gz
RUN rm -rf omc-v1.4.0_Linux_x86_64.tar.gz
WORKDIR /
COPY /omc /usr/local/bin/
COPY /omc /
COPY etcd.sh /
COPY fio_suite.sh /
COPY etcd_tooktoolong311.py /
COPY etcd_tooktoolong311.py /usr/local/bin/
COPY runner.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/omc
RUN chmod +x /fio_suite.sh
RUN chmod +x /etcd.sh
RUN chmod +x /etcd_tooktoolong311.py
RUN chmod +x /usr/local/bin/etcd_tooktoolong311.py
RUN chmod +x /usr/local/bin/runner.sh
CMD ["runner.sh"]