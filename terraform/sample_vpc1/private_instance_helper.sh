#!/bin/bash

# Quick Access Script for Private Security Testing Instances
# This script helps you connect to and test the private EC2 instances

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Private Instance Security Testing Helper ===${NC}"
echo ""

# Function to get instance IDs
get_instance_ids() {
    echo -e "${YELLOW}Getting private instance information...${NC}"
    aws ec2 describe-instances \
        --filters "Name=tag:Category,Values=security-testing" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,AvailabilityZone]' \
        --output table
}

# Function to start Session Manager session
connect_instance() {
    local instance_id=$1
    echo -e "${GREEN}Starting Session Manager session to $instance_id...${NC}"
    aws ssm start-session --target "$instance_id"
}

# Function to run security tests
run_security_tests() {
    local instance_id=$1
    echo -e "${GREEN}Running security tests on $instance_id...${NC}"
    
    # Send commands via Session Manager
    aws ssm send-command \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["cd /home/ubuntu && ./test_internet.sh"]' \
        --output text --query 'Command.CommandId'
}

# Function to get command output
get_command_output() {
    local command_id=$1
    local instance_id=$2
    echo -e "${YELLOW}Getting command output...${NC}"
    sleep 5  # Wait for command to complete
    aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$instance_id" \
        --query 'StandardOutputContent' \
        --output text
}

# Main menu
show_menu() {
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1. List private instances"
    echo "2. Connect to private instance (Session Manager)"
    echo "3. Run basic security tests"
    echo "4. Run malicious URL tests"
    echo "5. Show connection instructions"
    echo "6. Exit"
    echo ""
}

# Connection instructions
show_instructions() {
    echo -e "${YELLOW}=== Connection Instructions ===${NC}"
    echo ""
    echo -e "${GREEN}Method 1: AWS Session Manager (Recommended)${NC}"
    echo "Prerequisites:"
    echo "- AWS CLI configured"
    echo "- Session Manager plugin installed"
    echo "- Appropriate IAM permissions"
    echo ""
    echo "Commands:"
    echo "aws ssm start-session --target INSTANCE_ID"
    echo ""
    echo -e "${GREEN}Method 2: SSH via Bastion Host${NC}"
    echo "1. SSH to public instance first:"
    echo "   ssh -i your-key.pem ubuntu@PUBLIC_INSTANCE_IP"
    echo "2. Then SSH to private instance:"
    echo "   ssh ubuntu@PRIVATE_INSTANCE_IP"
    echo ""
    echo -e "${GREEN}Pre-installed Test Scripts:${NC}"
    echo "- ./test_internet.sh     # Basic connectivity tests"
    echo "- ./test_malicious.sh    # Malicious URL/IP tests"
    echo "- ./comprehensive_test.sh # Full security test suite"
    echo ""
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice (1-6): " choice
    echo ""
    
    case $choice in
        1)
            get_instance_ids
            ;;
        2)
            get_instance_ids
            echo ""
            read -p "Enter Instance ID to connect: " instance_id
            if [[ -n "$instance_id" ]]; then
                connect_instance "$instance_id"
            else
                echo -e "${RED}Invalid instance ID${NC}"
            fi
            ;;
        3)
            get_instance_ids
            echo ""
            read -p "Enter Instance ID for testing: " instance_id
            if [[ -n "$instance_id" ]]; then
                command_id=$(run_security_tests "$instance_id")
                echo "Command ID: $command_id"
                echo "Use: aws ssm get-command-invocation --command-id $command_id --instance-id $instance_id"
            else
                echo -e "${RED}Invalid instance ID${NC}"
            fi
            ;;
        4)
            get_instance_ids
            echo ""
            read -p "Enter Instance ID for malicious testing: " instance_id
            if [[ -n "$instance_id" ]]; then
                echo -e "${GREEN}Running malicious URL tests on $instance_id...${NC}"
                command_id=$(aws ssm send-command \
                    --instance-ids "$instance_id" \
                    --document-name "AWS-RunShellScript" \
                    --parameters 'commands=["cd /home/ubuntu && ./test_malicious.sh"]' \
                    --output text --query 'Command.CommandId')
                echo "Command ID: $command_id"
                echo "Use: aws ssm get-command-invocation --command-id $command_id --instance-id $instance_id"
            else
                echo -e "${RED}Invalid instance ID${NC}"
            fi
            ;;
        5)
            show_instructions
            ;;
        6)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1-6.${NC}"
            ;;
    esac
    echo ""
    read -p "Press Enter to continue..."
    echo ""
done
