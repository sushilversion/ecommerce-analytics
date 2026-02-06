# 🚀 EXPRESS DEPLOYMENT GUIDE - Hadoop & Grafana Demo
## ⏱️ Total Time: 20-25 Minutes

---

## BEFORE YOU START - Prerequisites Checklist

- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform installed (`terraform version`)
- [ ] EC2 Key Pair created in your AWS region
- [ ] Your public IP address (run: `curl ifconfig.me`)

---

## PHASE 1: INFRASTRUCTURE DEPLOYMENT (10 minutes)

### Step 1: Get Your Public IP
```bash
curl ifconfig.me
# Note this down - you'll need it
```

### Step 2: Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region     = "us-east-1"              # Your preferred region
ami_id         = "ami-0866a3c8686eaeeba"  # Ubuntu 22.04 (us-east-1)
key_pair_name  = "YOUR-KEY-PAIR-NAME"     # Your EC2 key pair name
your_ip_cidr   = "YOUR.IP.HERE/32"        # Your IP from Step 1
```

**AMI IDs by Region (Ubuntu 22.04 LTS):**
- us-east-1: `ami-0866a3c8686eaeeba`
- us-west-2: `ami-05134c8ef96964280`
- ap-south-1: `ami-0dee22c13ea7a9a67`
- eu-west-1: `ami-0932440befd74cdba`

### Step 3: Deploy Infrastructure
```bash
terraform init
terraform apply -auto-approve
```

**⏱️ Wait 5-7 minutes for deployment**

### Step 4: Note the Outputs
Save these IPs and URLs displayed at the end:
- Master Public IP
- Worker Private IPs (you'll need these)
- Grafana URL
- NameNode URL

---

## PHASE 2: HADOOP CONFIGURATION (5-8 minutes)

### Step 5: SSH to Master Node
```bash
ssh -i your-key.pem ubuntu@<MASTER-PUBLIC-IP>
```

### Step 6: Download and Run Express Setup Script
```bash
# Download the setup script
wget https://raw.githubusercontent.com/YOUR-REPO/express-setup.sh
# Or copy from the provided files

# Make it executable
chmod +x express-setup.sh

# Run it
sudo bash express-setup.sh
```

**When prompted, enter:**
- Worker 1 Private IP: (from Terraform output)
- Worker 2 Private IP: (from Terraform output)
- Password for workers: `hadoop` (when asked)

The script will:
- ✓ Configure Hadoop files
- ✓ Setup SSH keys
- ✓ Format NameNode
- ✓ Start all services
- ✓ Verify cluster health

**⏱️ Wait 3-5 minutes for script completion**

---

## PHASE 3: GRAFANA SETUP (2-3 minutes)

### Step 7: Access Grafana
Open browser: `http://<MASTER-PUBLIC-IP>:3000`

**Login:**
- Username: `admin`
- Password: `admin`
- (Change password when prompted)

### Step 8: Add Prometheus Data Source
1. Click **⚙️ Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Set URL: `http://localhost:9090`
5. Click **Save & Test** (should show green checkmark)

### Step 9: Import Dashboards
1. Click **+** → **Import**
2. Click **Upload JSON file**
3. Import `dashboards/hdfs-dashboard.json`
4. Select **Prometheus** as data source
5. Click **Import**
6. Repeat for `dashboards/yarn-dashboard.json`

---

## PHASE 4: DEMO TESTING (2-3 minutes)

### Step 10: Run Sample Job
```bash
# On master node
sudo su - hadoop
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar pi 4 100
```

**While job runs, show in your demo:**
1. ✓ ResourceManager UI: `http://<MASTER-IP>:8088`
   - Shows running application
2. ✓ Grafana YARN Dashboard
   - Shows resource allocation in real-time
3. ✓ NameNode UI: `http://<MASTER-IP>:9870`
   - Shows cluster capacity and datanodes

---

## 📊 YOUR DEMO IS READY!

### Quick Health Check Before Demo:
```bash
# On master node as hadoop user
hdfs dfsadmin -report    # Should show 2 live datanodes
yarn node -list          # Should show 2 active nodes
jps                      # Should show NameNode, ResourceManager
```

### Demo Flow Suggestion:

**1. Show Architecture (1 min)**
   - Explain: 1 master + 2 workers
   - Hadoop (HDFS + YARN) + Monitoring stack

**2. Show Cluster Status (1 min)**
   - NameNode UI → Datanodes tab (2 live nodes)
   - ResourceManager UI → Nodes (2 active)

**3. Show Monitoring Setup (1 min)**
   - Prometheus → Targets (all UP)
   - Grafana → HDFS Dashboard

**4. Run Live Job (2-3 min)**
   - Execute Pi calculation
   - Switch between ResourceManager UI and Grafana
   - Show real-time metrics updating

**5. Show Metrics (1 min)**
   - HDFS: Capacity, blocks, nodes
   - YARN: Memory, vCores, applications

---

## 🆘 QUICK TROUBLESHOOTING

### If DataNodes don't connect:
```bash
sudo su - hadoop
$HADOOP_HOME/sbin/stop-dfs.sh
$HADOOP_HOME/sbin/start-dfs.sh
sleep 10
hdfs dfsadmin -report
```

### If Prometheus shows DOWN targets:
```bash
# On master
curl localhost:9101/metrics  # Should show metrics
sudo systemctl restart prometheus
```

### If Grafana doesn't show data:
- Check data source is Prometheus with URL `http://localhost:9090`
- Check time range (last 1 hour)
- Refresh dashboard

---

## 💰 AFTER DEMO - CLEANUP

**IMPORTANT:** Destroy infrastructure to avoid charges
```bash
cd terraform
terraform destroy -auto-approve
```

---

## 🎯 DEMO TALKING POINTS

**What you built:**
- Production-like Hadoop cluster on AWS
- Real-time monitoring with Prometheus + Grafana
- Automated deployment with Terraform
- JMX exporters for metrics collection

**Key metrics demonstrated:**
- HDFS: Storage capacity, replication, node health
- YARN: Resource allocation, job scheduling
- System: Memory, CPU, throughput

**Scalability:**
- Can add more workers by updating Terraform
- Monitoring scales automatically
- Production-ready architecture

**Use cases:**
- Big data processing
- Log analytics
- Data warehousing
- Machine learning pipelines

---

## 📱 BACKUP PLAN

If something breaks during demo:
1. Have screenshots ready of working cluster
2. Use the presentation slides (we can create these)
3. Show the architecture and code instead

---

## ⏰ TIMELINE SUMMARY

| Phase | Time | What Happens |
|-------|------|--------------|
| 1. Infrastructure | 10 min | Terraform deploys EC2, VPC, etc. |
| 2. Hadoop Config | 5-8 min | Script configures cluster |
| 3. Grafana Setup | 2-3 min | Manual dashboard import |
| 4. Testing | 2-3 min | Run sample job |
| **TOTAL** | **20-25 min** | **Ready to demo** |

---

## 📋 PRE-DEMO CHECKLIST

- [ ] All services running (check with `jps`)
- [ ] 2 datanodes live (check NameNode UI)
- [ ] 2 nodemanagers active (check ResourceManager UI)
- [ ] Grafana dashboards showing data
- [ ] Prometheus targets all UP
- [ ] Test job runs successfully
- [ ] URLs bookmarked in browser
- [ ] Screenshots taken as backup

---

**🎬 YOU'RE READY! Good luck with your demo!**
