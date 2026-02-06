#!/bin/bash
#
# EXPRESS HADOOP SETUP SCRIPT - Run on Master Node after Terraform deployment
# This automates the manual configuration steps
#
set -e

echo "=========================================="
echo "Hadoop Express Setup Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use: sudo bash express-setup.sh)"
    exit 1
fi

# Get worker IPs from user
echo "Enter Worker 1 Private IP:"
read WORKER1_IP
echo "Enter Worker 2 Private IP:"
read WORKER2_IP

echo ""
echo "Configuration:"
echo "  Worker 1: $WORKER1_IP"
echo "  Worker 2: $WORKER2_IP"
echo ""
read -p "Is this correct? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Exiting. Please run again with correct IPs."
    exit 1
fi

MASTER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "Step 1: Updating Hadoop configuration files..."

# Update core-site.xml
cat > /opt/hadoop/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$MASTER_IP:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop/tmp</value>
    </property>
</configuration>
EOF

# Update workers file
cat > /opt/hadoop/etc/hadoop/workers << EOF
$WORKER1_IP
$WORKER2_IP
EOF

echo "✓ Configuration files updated"

echo ""
echo "Step 2: Setting up SSH keys for hadoop user..."

# Setup SSH for hadoop user
su - hadoop << 'HEREDOC'
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 0600 ~/.ssh/authorized_keys
fi
HEREDOC

echo "✓ SSH keys generated"

echo ""
echo "Step 3: Copying SSH keys to worker nodes..."
echo "You'll be prompted for the password for each worker (password: hadoop)"
echo ""

# Copy SSH key to workers
su - hadoop << HEREDOC
ssh-keyscan -H $WORKER1_IP >> ~/.ssh/known_hosts 2>/dev/null
ssh-keyscan -H $WORKER2_IP >> ~/.ssh/known_hosts 2>/dev/null

# Use sshpass if available, otherwise prompt user
if command -v sshpass &> /dev/null; then
    sshpass -p 'hadoop' ssh-copy-id -o StrictHostKeyChecking=no hadoop@$WORKER1_IP
    sshpass -p 'hadoop' ssh-copy-id -o StrictHostKeyChecking=no hadoop@$WORKER2_IP
else
    echo "Enter password 'hadoop' for Worker 1:"
    ssh-copy-id hadoop@$WORKER1_IP
    echo "Enter password 'hadoop' for Worker 2:"
    ssh-copy-id hadoop@$WORKER2_IP
fi
HEREDOC

echo "✓ SSH keys copied to workers"

echo ""
echo "Step 4: Installing sshpass for automation..."
apt-get install -y sshpass > /dev/null 2>&1 || true

echo ""
echo "Step 5: Configuring worker nodes..."

# Configure workers via SSH
for WORKER_IP in $WORKER1_IP $WORKER2_IP; do
    echo "Configuring $WORKER_IP..."
    su - hadoop << HEREDOC
ssh hadoop@$WORKER_IP "cat > /opt/hadoop/etc/hadoop/core-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$MASTER_IP:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop/tmp</value>
    </property>
</configuration>
EOF

ssh hadoop@$WORKER_IP "cat > /opt/hadoop/etc/hadoop/hdfs-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/hadoop/data/datanode</value>
    </property>
</configuration>
EOF

ssh hadoop@$WORKER_IP "cat > /opt/hadoop/etc/hadoop/yarn-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>$MASTER_IP</value>
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
</configuration>
EOF
HEREDOC
done

echo "✓ Worker nodes configured"

echo ""
echo "Step 6: Creating necessary directories..."
su - hadoop -c "mkdir -p /opt/hadoop/data/namenode /opt/hadoop/data/datanode /opt/hadoop/tmp"

echo ""
echo "Step 7: Formatting NameNode..."
su - hadoop -c "hdfs namenode -format -force" 2>&1 | tail -5

echo "✓ NameNode formatted"

echo ""
echo "Step 8: Starting Hadoop services..."
su - hadoop << 'HEREDOC'
source /etc/profile.d/hadoop.sh
$HADOOP_HOME/sbin/start-dfs.sh
sleep 5
$HADOOP_HOME/sbin/start-yarn.sh
HEREDOC

echo "✓ Hadoop services started"

echo ""
echo "Step 9: Waiting for services to initialize (30 seconds)..."
sleep 30

echo ""
echo "Step 10: Verifying cluster status..."
echo ""
echo "=== HDFS Status ==="
su - hadoop -c "hdfs dfsadmin -report" | head -20
echo ""
echo "=== YARN Nodes ==="
su - hadoop -c "yarn node -list"
echo ""

echo "=========================================="
echo "✓ SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Access your services:"
echo "  • Grafana:          http://$MASTER_IP:3000 (admin/admin)"
echo "  • NameNode UI:      http://$MASTER_IP:9870"
echo "  • ResourceManager:  http://$MASTER_IP:8088"
echo "  • Prometheus:       http://$MASTER_IP:9090"
echo ""
echo "To test the cluster, run:"
echo "  sudo su - hadoop"
echo "  hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar pi 4 100"
echo ""
echo "Next: Configure Grafana (see Quick Setup Guide)"
echo "=========================================="
