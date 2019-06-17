FROM ubuntu

ENV PYTHON_VERSION 3.5
ENV JDK_VERSION 8
ENV MAVEN_VERSION 3.6.1

ENV HADOOP_VERSION 2.9
ENV HADOOP_VERSION_DETAIL 2.9.2
ENV SPARK_VERSION 2.4
ENV SPARK_VERSION_DETAIL 2.4.0
ENV HADOOP_FOR_SPARK_VERSION 2.7

USER root

RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y build-essential && \
  apt-get install -y software-properties-common && \
  apt-get install -y git wget curl man unzip vim-tiny bc


RUN \
  apt-get update && \
  apt-get -y install openssh-server; mkdir -p /var/run/sshd


RUN rm -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN rm -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
RUN echo "    StrictHostKeyChecking no                     " >> /etc/ssh/ssh_config
RUN echo "    UserKnownHostsFile=/dev/null                 " >> /etc/ssh/ssh_config


RUN \
  add-apt-repository -y ppa:openjdk-r/ppa && \
  apt-get update && \
  apt-get install -y openjdk-${JDK_VERSION}-jdk

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-${JDK_VERSION}-openjdk-amd64
ENV PATH $PATH:$JAVA_HOME/bin

# download maven
RUN wget http://us.mirrors.quenda.co/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
RUN tar xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz
RUN rm -f apache-maven-${MAVEN_VERSION}-bin.tar.gz
RUN mv apache-maven-* /usr/local/apache-maven

# define environment variables for maven
ENV M2_HOME /usr/local/apache-maven
ENV PATH $PATH:/usr/local/apache-maven/bin
# copy local maven repository to docker image
#RUN rm -rf /root/.m2
#ADD .m2 /root/.m2

# Set env variable for spark bench
ENV SPARK_BENCH_HOME /root/spark-bench

# Clone spark bench legacy version
RUN wget https://github.com/CODAIT/spark-bench/archive/legacy.zip
RUN unzip legacy.zip -d /root/
RUN mv /root/spark-bench-legacy  ${SPARK_BENCH_HOME}
RUN rm -f legacy.zip

# A necessary package
WORKDIR /root
RUN apt-get update
RUN git clone https://github.com/synhershko/wikixmlj.git
WORKDIR wikixmlj
RUN mvn package install

# Set up spark bench
#RUN cd ${SPARK_BENCH_HOME}/bin/build-all.sh
#COPY conf/env.sh ${SPARK_BENCH_HOME}/conf/env.sh
## Kmeans
#COPY app/kmeans/kmeans.scala ${SPARK_BENCH_HOME}/KMeans/src/main/scala/
#COPY app/kmeans/env.sh ${SPARK_BENCH_HOME}/KMeans/conf/
## Tera sort
#COPY app/terasort/terasortApp.scala ${SPARK_BENCH_HOME}/Terasort/src/main/scala/
#COPY app/terasort/env.sh ${SPARK_BENCH_HOME}/Terasort/conf/
## Page rank
#COPY app/pagerank/pagerankApp.scala ${SPARK_BENCH_HOME}/PageRank/src/main/scala/
#COPY app/pagerank/env.sh ${SPARK_BENCH_HOME}/PageRank/conf/
## Build
#RUN ${SPARK_BENCH_HOME}/bin/build-all.sh

# Hadoop
# Set env variables for hadoop
ENV HADOOP_HOME /usr/local/hadoop-${HADOOP_VERSION_DETAIL}
ENV HADOOP_PREFIX /usr/local/hadoop-${HADOOP_VERSION_DETAIL}
ENV HADOOP_CONF_DIR ${HADOOP_HOME}/etc/hadoop/

RUN export HADOOP_INSTALL=$HADOOP_HOME
RUN export PATH=$PATH:$HADOOP_INSTALL/bin
RUN export PATH=$PATH:$HADOOP_INSTALL/sbin
RUN export HADOOP_MAPRED_HOME=$HADOOP_INSTALL
RUN export HADOOP_COMMON_HOME=$HADOOP_INSTALL
RUN export HADOOP_HDFS_HOME=$HADOOP_INSTALL
RUN export YARN_HOME=$HADOOP_INSTALL
RUN export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_INSTALL/lib/native
RUN export HADOOP_OPTS="-Djava.library.path=$HADOOP_INSTALL/lib"

RUN wget http://apache.claz.org/hadoop/common/hadoop-${HADOOP_VERSION_DETAIL}/hadoop-${HADOOP_VERSION_DETAIL}.tar.gz
RUN tar xzf hadoop-*.tar.gz -C /usr/local/
RUN rm -f hadoop-*.tar.gz

# Scala
RUN curl https://downloads.lightbend.com/scala/2.11.12/scala-2.11.12.tgz > /scala-2.11.12.tgz && tar -xzf /scala-2.11.12.tgz -C /usr/local/ && ln -s /usr/local/scala-2.11.12 /usr/local/scala

# Spark
# Set env variables for spark
ENV SPARK_HOME /usr/local/spark-${SPARK_VERSION_DETAIL}
ENV SPARK_MASTER_IP localhost
ENV SPARK_CONF_DIR ${SPARK_HOME}/conf/

RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION_DETAIL}/spark-${SPARK_VERSION_DETAIL}-bin-hadoop${HADOOP_FOR_SPARK_VERSION}.tgz
RUN tar xzf spark-*.tgz -C /usr/local
RUN mv /usr/local/spark-* ${SPARK_HOME}
RUN rm -f spark-*.tgz

# Copy configuration files
COPY conf/core-site.xml ${HADOOP_CONF_DIR}/
COPY conf/hdfs-site.xml ${HADOOP_CONF_DIR}/
COPY conf/mapred-site.xml ${HADOOP_CONF_DIR}/
COPY conf/yarn-site.xml ${HADOOP_CONF_DIR}/
COPY conf/spark-env.sh ${SPARK_CONF_DIR}/
COPY scripts/hadoop-env.sh ${HADOOP_CONF_DIR}/

# For rebooting hdfs and spark
COPY scripts/restart_hadoop_spark.sh /usr/bin
RUN chmod +x /usr/bin/restart_hadoop_spark.sh

# Required for testing
RUN apt-get update
RUN apt-get -y install python
RUN apt-get -y install python-pip
RUN pip install numpy
RUN pip install pyspark
RUN apt-get update
RUN apt-get -y install nano
