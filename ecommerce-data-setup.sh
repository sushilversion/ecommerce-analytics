#!/bin/bash
#
# E-COMMERCE HADOOP POC - DATA SETUP SCRIPT
# Creates realistic e-commerce datasets and runs sample analytics jobs
#
set -e

echo "=========================================="
echo "E-Commerce Analytics Platform Setup"
echo "=========================================="
echo ""

# Check if running as hadoop user
if [ "$USER" != "hadoop" ]; then
    echo "Please run as hadoop user (use: sudo su - hadoop)"
    exit 1
fi

echo "Creating e-commerce sample datasets..."
echo ""

# Create directory structure
echo "Step 1: Creating HDFS directory structure..."
hdfs dfs -mkdir -p /ecommerce/raw/orders
hdfs dfs -mkdir -p /ecommerce/raw/customers
hdfs dfs -mkdir -p /ecommerce/raw/products
hdfs dfs -mkdir -p /ecommerce/raw/clickstream
hdfs dfs -mkdir -p /ecommerce/processed
hdfs dfs -mkdir -p /ecommerce/analytics

echo "✓ Directory structure created"
echo ""

# Generate sample orders data
echo "Step 2: Generating sample orders data..."
cat > /tmp/generate_orders.py << 'EOF'
import random
import datetime
import sys

# Product catalog
products = [
    ("LAPTOP001", "Gaming Laptop", 1299.99),
    ("PHONE001", "Smartphone Pro", 899.99),
    ("TABLET001", "Tablet 10-inch", 399.99),
    ("HEADPH001", "Wireless Headphones", 199.99),
    ("WATCH001", "Smart Watch", 299.99),
    ("CAMERA001", "Digital Camera", 599.99),
    ("SPEAKER001", "Bluetooth Speaker", 79.99),
    ("KEYBOARD001", "Mechanical Keyboard", 129.99),
    ("MOUSE001", "Gaming Mouse", 59.99),
    ("MONITOR001", "4K Monitor", 449.99),
    ("CHARGER001", "Fast Charger", 29.99),
    ("CASE001", "Phone Case", 19.99),
    ("CABLE001", "USB-C Cable", 14.99),
    ("ADAPTER001", "Power Adapter", 24.99),
    ("STAND001", "Laptop Stand", 39.99),
]

regions = ["US-EAST", "US-WEST", "EU-WEST", "ASIA-PACIFIC", "LATAM"]
statuses = ["COMPLETED", "COMPLETED", "COMPLETED", "COMPLETED", "PENDING", "CANCELLED"]

# Generate orders for last 30 days
start_date = datetime.datetime.now() - datetime.timedelta(days=30)
num_orders = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

print("order_id,customer_id,product_id,product_name,quantity,price,total_amount,order_date,status,region")

for i in range(1, num_orders + 1):
    order_date = start_date + datetime.timedelta(
        days=random.randint(0, 30),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59)
    )
    
    customer_id = f"CUST{random.randint(1, 5000):05d}"
    product = random.choice(products)
    quantity = random.randint(1, 5)
    total = round(product[2] * quantity, 2)
    status = random.choice(statuses)
    region = random.choice(regions)
    
    print(f"ORD{i:08d},{customer_id},{product[0]},{product[1]},{quantity},{product[2]},{total},{order_date.strftime('%Y-%m-%d %H:%M:%S')},{status},{region}")
EOF

python3 /tmp/generate_orders.py 50000 > /tmp/orders.csv
hdfs dfs -put /tmp/orders.csv /ecommerce/raw/orders/orders.csv
echo "✓ Generated 50,000 orders"
echo ""

# Generate sample customers data
echo "Step 3: Generating customer data..."
cat > /tmp/generate_customers.py << 'EOF'
import random

first_names = ["John", "Jane", "Michael", "Emily", "David", "Sarah", "James", "Emma", "Robert", "Olivia"]
last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]
cities = {
    "US-EAST": ["New York", "Boston", "Philadelphia", "Atlanta", "Miami"],
    "US-WEST": ["Los Angeles", "San Francisco", "Seattle", "Portland", "San Diego"],
    "EU-WEST": ["London", "Paris", "Berlin", "Madrid", "Rome"],
    "ASIA-PACIFIC": ["Tokyo", "Singapore", "Sydney", "Mumbai", "Seoul"],
    "LATAM": ["Mexico City", "Sao Paulo", "Buenos Aires", "Lima", "Bogota"]
}

print("customer_id,first_name,last_name,email,city,region,signup_date,lifetime_value,tier")

for i in range(1, 5001):
    first = random.choice(first_names)
    last = random.choice(last_names)
    region = random.choice(list(cities.keys()))
    city = random.choice(cities[region])
    email = f"{first.lower()}.{last.lower()}{i}@example.com"
    signup_year = random.randint(2020, 2024)
    signup_month = random.randint(1, 12)
    signup_day = random.randint(1, 28)
    ltv = round(random.uniform(100, 10000), 2)
    tier = "PLATINUM" if ltv > 5000 else "GOLD" if ltv > 2000 else "SILVER" if ltv > 500 else "BRONZE"
    
    print(f"CUST{i:05d},{first},{last},{email},{city},{region},{signup_year}-{signup_month:02d}-{signup_day:02d},{ltv},{tier}")
EOF

python3 /tmp/generate_customers.py > /tmp/customers.csv
hdfs dfs -put /tmp/customers.csv /ecommerce/raw/customers/customers.csv
echo "✓ Generated 5,000 customers"
echo ""

# Generate clickstream data
echo "Step 4: Generating clickstream data..."
cat > /tmp/generate_clickstream.py << 'EOF'
import random
import datetime
import sys

actions = ["VIEW", "VIEW", "VIEW", "ADD_TO_CART", "ADD_TO_CART", "REMOVE_FROM_CART", "CHECKOUT", "PURCHASE"]
pages = ["home", "category", "product", "cart", "checkout", "account", "search"]
devices = ["mobile", "desktop", "tablet"]

start_date = datetime.datetime.now() - datetime.timedelta(days=7)
num_events = int(sys.argv[1]) if len(sys.argv) > 1 else 100000

print("timestamp,session_id,customer_id,action,page,product_id,device,duration_seconds")

for i in range(num_events):
    timestamp = start_date + datetime.timedelta(
        days=random.randint(0, 7),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59),
        seconds=random.randint(0, 59)
    )
    
    session_id = f"SESSION{random.randint(1, 20000):08d}"
    customer_id = f"CUST{random.randint(1, 5000):05d}" if random.random() > 0.3 else "GUEST"
    action = random.choice(actions)
    page = random.choice(pages)
    product_id = f"PROD{random.randint(1, 15):03d}" if page in ["product", "cart"] else ""
    device = random.choice(devices)
    duration = random.randint(5, 300)
    
    print(f"{timestamp.strftime('%Y-%m-%d %H:%M:%S')},{session_id},{customer_id},{action},{page},{product_id},{device},{duration}")
EOF

python3 /tmp/generate_clickstream.py 200000 > /tmp/clickstream.csv
hdfs dfs -put /tmp/clickstream.csv /ecommerce/raw/clickstream/clickstream.csv
echo "✓ Generated 200,000 clickstream events"
echo ""

# Create Hive tables (if Hive is available)
echo "Step 5: Creating analysis scripts..."

# Sales analysis MapReduce job
cat > /tmp/SalesAnalysis.java << 'EOF'
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.DoubleWritable;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import java.io.IOException;

public class SalesAnalysis {
    
    public static class SalesMapper extends Mapper<Object, Text, Text, DoubleWritable> {
        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String[] fields = value.toString().split(",");
            if (fields.length >= 10 && !fields[0].equals("order_id")) {
                String region = fields[9];
                double amount = Double.parseDouble(fields[6]);
                context.write(new Text(region), new DoubleWritable(amount));
            }
        }
    }
    
    public static class SalesReducer extends Reducer<Text, DoubleWritable, Text, DoubleWritable> {
        public void reduce(Text key, Iterable<DoubleWritable> values, Context context) 
                throws IOException, InterruptedException {
            double sum = 0;
            for (DoubleWritable val : values) {
                sum += val.get();
            }
            context.write(key, new DoubleWritable(sum));
        }
    }
    
    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "sales by region");
        job.setJarByClass(SalesAnalysis.class);
        job.setMapperClass(SalesMapper.class);
        job.setReducerClass(SalesReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(DoubleWritable.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
EOF

echo "✓ Created sales analysis job"
echo ""

# Create simple analysis script using Hadoop streaming
cat > /tmp/analyze_orders.sh << 'EOF'
#!/bin/bash
echo "Running E-Commerce Analytics..."
echo ""
echo "1. Sales by Region:"
hdfs dfs -cat /ecommerce/raw/orders/orders.csv | \
  awk -F',' 'NR>1 {region=$10; sales[region]+=$7} END {for (r in sales) printf "%s: $%.2f\n", r, sales[r]}' | \
  sort -t':' -k2 -nr
echo ""
echo "2. Top 5 Products by Revenue:"
hdfs dfs -cat /ecommerce/raw/orders/orders.csv | \
  awk -F',' 'NR>1 {product=$4; revenue[product]+=$7} END {for (p in revenue) printf "%s: $%.2f\n", p, revenue[p]}' | \
  sort -t':' -k2 -nr | head -5
echo ""
echo "3. Order Status Distribution:"
hdfs dfs -cat /ecommerce/raw/orders/orders.csv | \
  awk -F',' 'NR>1 {status[$9]++} END {for (s in status) printf "%s: %d orders\n", s, status[s]}' | \
  sort -t':' -k2 -nr
echo ""
echo "4. Daily Order Count (Last 7 days):"
hdfs dfs -cat /ecommerce/raw/orders/orders.csv | \
  awk -F',' 'NR>1 {date=substr($8,1,10); count[date]++} END {for (d in count) printf "%s: %d orders\n", d, count[d]}' | \
  sort | tail -7
EOF

chmod +x /tmp/analyze_orders.sh
echo "✓ Created analysis script"
echo ""

echo "Step 6: Running sample analytics..."
bash /tmp/analyze_orders.sh
echo ""

echo "=========================================="
echo "✓ E-COMMERCE DATA SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "📊 Generated Datasets:"
echo "  • 50,000 orders (/ecommerce/raw/orders/)"
echo "  • 5,000 customers (/ecommerce/raw/customers/)"
echo "  • 200,000 clickstream events (/ecommerce/raw/clickstream/)"
echo ""
echo "🔍 Quick Analysis:"
echo "  bash /tmp/analyze_orders.sh"
echo ""
echo "📁 HDFS Structure:"
hdfs dfs -du -h /ecommerce
echo ""
echo "💡 Use these datasets for your demo to show:"
echo "  • Sales analytics by region"
echo "  • Customer segmentation"
echo "  • Product performance analysis"
echo "  • Clickstream analytics"
echo "  • Real-time data processing"
echo ""
