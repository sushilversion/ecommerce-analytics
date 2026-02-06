#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y openjdk-11-jdk wget curl

# Create hadoop user
useradd -m -s /bin/bash hadoop
echo "hadoop:hadoop" | chpasswd

# Download Hadoop
cd /tmp
wget -q https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 /opt/hadoop
chown -R hadoop:hadoop /opt/hadoop

# Set environment variables
cat >> /etc/profile.d/hadoop.sh << 'EOF'
export HADOOP_HOME=/opt/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
EOF

source /etc/profile.d/hadoop.sh

# Download JMX Exporter
wget -q https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar -O /opt/hadoop/jmx_prometheus_javaagent.jar

# Configure hadoop-env.sh
cat >> /opt/hadoop/etc/hadoop/hadoop-env.sh << 'EOF'

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HDFS_DATANODE_OPTS="-Dcom.sun.management.jmxremote -javaagent:/opt/hadoop/jmx_prometheus_javaagent.jar=9102:/opt/hadoop/etc/hadoop/datanode-jmx-config.yaml $HDFS_DATANODE_OPTS"
export YARN_NODEMANAGER_OPTS="-Dcom.sun.management.jmxremote -javaagent:/opt/hadoop/jmx_prometheus_javaagent.jar=9104:/opt/hadoop/etc/hadoop/nodemanager-jmx-config.yaml $YARN_NODEMANAGER_OPTS"
EOF

# Create JMX config for DataNode
cat > /opt/hadoop/etc/hadoop/datanode-jmx-config.yaml << 'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - "Hadoop:service=DataNode,name=*"
  - "java.lang:type=Memory"
  - "java.lang:type=Threading"
  - "java.lang:type=Runtime"
EOF

# Create JMX config for NodeManager
cat > /opt/hadoop/etc/hadoop/nodemanager-jmx-config.yaml << 'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - "Hadoop:service=NodeManager,name=*"
  - "java.lang:type=Memory"
  - "java.lang:type=Threading"
  - "java.lang:type=Runtime"
EOF

chown -R hadoop:hadoop /opt/hadoop

echo "Worker node setup complete. Waiting for master configuration..."
