#!/bin/bash
set -e

WORKER1_IP="${worker1_private_ip}"
WORKER2_IP="${worker2_private_ip}"

# Update system
apt-get update
apt-get install -y openjdk-11-jdk wget curl apt-transport-https software-properties-common gnupg2

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
export HDFS_NAMENODE_OPTS="-Dcom.sun.management.jmxremote -javaagent:/opt/hadoop/jmx_prometheus_javaagent.jar=9101:/opt/hadoop/etc/hadoop/namenode-jmx-config.yaml $HDFS_NAMENODE_OPTS"
export YARN_RESOURCEMANAGER_OPTS="-Dcom.sun.management.jmxremote -javaagent:/opt/hadoop/jmx_prometheus_javaagent.jar=9103:/opt/hadoop/etc/hadoop/resourcemanager-jmx-config.yaml $YARN_RESOURCEMANAGER_OPTS"
EOF

# Create JMX configs
cat > /opt/hadoop/etc/hadoop/namenode-jmx-config.yaml << 'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - "Hadoop:service=NameNode,name=*"
  - "Hadoop:service=NameNode,name=FSNamesystem*"
  - "java.lang:type=Memory"
  - "java.lang:type=Threading"
  - "java.lang:type=Runtime"
EOF

cat > /opt/hadoop/etc/hadoop/resourcemanager-jmx-config.yaml << 'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - "Hadoop:service=ResourceManager,name=*"
  - "Hadoop:service=ResourceManager,name=QueueMetrics*"
  - "java.lang:type=Memory"
  - "java.lang:type=Threading"
  - "java.lang:type=Runtime"
EOF

# Configure core-site.xml
cat > /opt/hadoop/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$(hostname):9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop/tmp</value>
    </property>
</configuration>
EOF

# Configure hdfs-site.xml
cat > /opt/hadoop/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/opt/hadoop/data/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/hadoop/data/datanode</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>0.0.0.0:9870</value>
    </property>
</configuration>
EOF

# Configure yarn-site.xml
cat > /opt/hadoop/etc/hadoop/yarn-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>$(hostname)</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>4096</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>2</value>
    </property>
    <property>
        <name>yarn.resourcemanager.webapp.address</name>
        <value>0.0.0.0:8088</value>
    </property>
</configuration>
EOF

# Configure mapred-site.xml
cat > /opt/hadoop/etc/hadoop/mapred-site.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
EOF

# Configure workers file
cat > /opt/hadoop/etc/hadoop/workers << EOF
$WORKER1_IP
$WORKER2_IP
EOF

# Create necessary directories
mkdir -p /opt/hadoop/data/namenode /opt/hadoop/data/datanode /opt/hadoop/tmp
chown -R hadoop:hadoop /opt/hadoop

# Install Prometheus
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar -xzf prometheus-2.48.0.linux-amd64.tar.gz
mv prometheus-2.48.0.linux-amd64 /opt/prometheus

# Configure Prometheus
cat > /opt/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'hadoop-namenode'
    static_configs:
      - targets: ['localhost:9101']
        labels:
          cluster: 'hadoop-poc'
          service: 'namenode'

  - job_name: 'hadoop-resourcemanager'
    static_configs:
      - targets: ['localhost:9103']
        labels:
          cluster: 'hadoop-poc'
          service: 'resourcemanager'

  - job_name: 'hadoop-datanodes'
    static_configs:
      - targets: ['$WORKER1_IP:9102', '$WORKER2_IP:9102']
        labels:
          cluster: 'hadoop-poc'
          service: 'datanode'

  - job_name: 'hadoop-nodemanagers'
    static_configs:
      - targets: ['$WORKER1_IP:9104', '$WORKER2_IP:9104']
        labels:
          cluster: 'hadoop-poc'
          service: 'nodemanager'
EOF

# Create Prometheus systemd service
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Install Grafana
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
apt-get update
apt-get install -y grafana

# Start services
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
systemctl enable grafana-server
systemctl start grafana-server

echo "Master node setup complete!"
echo "Next steps: SSH to workers and start DataNode/NodeManager services"
