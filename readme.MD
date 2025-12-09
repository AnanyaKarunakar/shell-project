# AWS DevOps Shell Concepts & Interview Notes 

  

## **Core Shell Scripting Concepts for DevOps** 

  

### **1. Shell Types & Environment** 

```bash 

# Check current shell 

echo $SHELL 

ps -p $$ 

  

# Common shells: bash, zsh, sh, ksh 

# /bin/sh is usually symlinked to bash or dash 

``` 

  

### **2. Important Environment Variables** 

```bash 

$PATH      # Command search path 

$HOME      # Home directory 

$USER      # Current user 

$PWD       # Present working directory 

$SHELL     # Current shell 

$TERM      # Terminal type 

$PS1       # Primary prompt string 

$?         # Exit status of last command 

``` 

  

### **3. File Permissions & Ownership** 

```bash 

# Numeric permissions 

chmod 755 file.sh    # rwxr-xr-x 

chmod 644 file.sh    # rw-r--r-- 

chmod 777 file.sh    # rwxrwxrwx (Avoid in production!) 

  

# Symbolic permissions 

chmod u+x file.sh    # Add execute for user 

chmod g-w file.sh    # Remove write for group 

chmod o=r file.sh    # Set others to read-only 

  

# Ownership 

chown user:group file.sh 

chown -R ec2-user:ec2-user /opt/app  # Recursive 

``` 

  

### **4. Redirection & Pipes** 

```bash 

# Redirection 

command > file      # Overwrite output to file 

command >> file     # Append output to file 

command 2> file     # Redirect stderr 

command &> file     # Redirect both stdout & stderr 

command < file      # Use file as stdin 

  

# Pipes 

cat file.txt | grep "error" | sort | uniq 

ps aux | grep nginx | awk '{print $2}' 

``` 

  

### **5. Process Management** 

```bash 

# Job control 

command &          # Run in background 

jobs              # List background jobs 

fg %1             # Bring job 1 to foreground 

bg %1             # Continue job 1 in background 

  

# Process signals 

kill -9 PID       # Force kill (SIGKILL) 

kill -15 PID      # Terminate gracefully (SIGTERM) 

kill -HUP PID     # Hangup (reload config) 

  

# Process info 

ps aux | grep process 

top/htop 

pstree 

``` 

  

### **6. Shell Script Essentials** 

```bash 

#!/bin/bash        # Shebang 

set -e             # Exit on error 

set -u             # Treat unset variables as error 

set -o pipefail    # Exit if any command in pipe fails 

``` 

  

## **AWS DevOps Shell Interview Q&A** 

  

### **Q1: How would you write a script to backup EBS volumes?** 

```bash 

#!/bin/bash 

# EBS Backup Script 

set -euo pipefail 

  

REGION="us-east-1" 

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) 

VOLUMES=$(aws ec2 describe-volumes \ 

    --region $REGION \ 

    --filters Name=attachment.instance-id,Values=$INSTANCE_ID \ 

    --query 'Volumes[*].VolumeId' \ 

    --output text) 

  

for VOLUME_ID in $VOLUMES; do 

    SNAPSHOT_ID=$(aws ec2 create-snapshot \ 

        --region $REGION \ 

        --volume-id $VOLUME_ID \ 

        --description "Backup $(date +%Y-%m-%d)" \ 

        --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=AutoBackup}]' \ 

        --query 'SnapshotId' \ 

        --output text) 

     

    echo "Created snapshot $SNAPSHOT_ID for volume $VOLUME_ID" 

     

    # Add retention policy (delete snapshots older than 30 days) 

    aws ec2 describe-snapshots \ 

        --region $REGION \ 

        --filters Name=tag:Name,Values=AutoBackup \ 

                  Name=volume-id,Values=$VOLUME_ID \ 

        --query 'Snapshots[?StartTime<`'"$(date --date='30 days ago' +%Y-%m-%d)"'`].SnapshotId' \ 

        --output text | xargs -r -I {} aws ec2 delete-snapshot --snapshot-id {} --region $REGION 

done 

``` 

  

### **Q2: Script to monitor disk space and send SNS alert** 

```bash 

#!/bin/bash 

THRESHOLD=80 

TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:DiskAlerts" 

  

USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//') 

  

if [ $USAGE -gt $THRESHOLD ]; then 

    MESSAGE="Disk usage on $(hostname) is ${USAGE}% exceeding ${THRESHOLD}% threshold" 

    aws sns publish \ 

        --topic-arn $TOPIC_ARN \ 

        --subject "Disk Alert: $(hostname)" \ 

        --message "$MESSAGE" \ 

        --region us-east-1 

fi 

``` 

  

### **Q3: Write a script to deploy to Auto Scaling Group** 

```bash 

#!/bin/bash 

# Blue-Green Deployment Script 

set -euo pipefail 

  

APP_NAME="myapp" 

BLUE_ASG="${APP_NAME}-blue-asg" 

GREEN_ASG="${APP_NAME}-green-asg" 

LATEST_AMI="ami-12345678" 

  

# Detect current active ASG 

ACTIVE_ASG=$(aws autoscaling describe-tags \ 

    --filters Name=key,Values=Environment \ 

              Name=value,Values=Active \ 

    --query 'Tags[?ResourceType==`auto-scaling-group`].ResourceId' \ 

    --output text) 

  

if [ "$ACTIVE_ASG" == "$BLUE_ASG" ]; then 

    INACTIVE_ASG=$GREEN_ASG 

else 

    INACTIVE_ASG=$BLUE_ASG 

fi 

  

# Update inactive ASG with new AMI 

aws autoscaling update-auto-scaling-group \ 

    --auto-scaling-group-name $INACTIVE_ASG \ 

    --launch-template "LaunchTemplateName=${APP_NAME},Version=\$Latest" \ 

    --min-size 2 \ 

    --desired-capacity 2 

  

# Wait for instances to be healthy 

echo "Waiting for instances to be healthy..." 

aws autoscaling wait group-in-service \ 

    --auto-scaling-group-name $INACTIVE_ASG \ 

    --group-options MinSize=2,MaxSize=4 

  

# Update ELB target group 

ELB_ARN=$(aws elbv2 describe-target-groups \ 

    --names "${APP_NAME}-tg" \ 

    --query 'TargetGroups[0].TargetGroupArn' \ 

    --output text) 

  

# Switch traffic to new ASG 

aws autoscaling attach-load-balancer-target-groups \ 

    --auto-scaling-group-name $INACTIVE_ASG \ 

    --target-group-arns $ELB_ARN 

  

# Detach old ASG from ELB 

aws autoscaling detach-load-balancer-target-groups \ 

    --auto-scaling-group-name $ACTIVE_ASG \ 

    --target-group-arns $ELB_ARN 

  

# Update tags 

aws autoscaling create-or-update-tags \ 

    --tags ResourceId=$INACTIVE_ASG,ResourceType=auto-scaling-group,Key=Environment,Value=Active,PropagateAtLaunch=false 

  

aws autoscaling create-or-update-tags \ 

    --tags ResourceId=$ACTIVE_ASG,ResourceType=auto-scaling-group,Key=Environment,Value=Standby,PropagateAtLaunch=false 

``` 

  

### **Q4: Script to rotate IAM access keys** 

```bash 

#!/bin/bash 

# IAM Key Rotation Script 

set -euo pipefail 

  

USER_NAME="deploy-user" 

DAYS_OLD=45 

  

# List access keys older than specified days 

OLD_KEYS=$(aws iam list-access-keys --user-name $USER_NAME \ 

    --query "AccessKeyMetadata[?CreateDate<='$(date --date="${DAYS_OLD} days ago" +%Y-%m-%d)'].AccessKeyId" \ 

    --output text) 

  

# Create new access key 

NEW_KEY=$(aws iam create-access-key --user-name $USER_NAME) 

NEW_ACCESS_KEY_ID=$(echo $NEW_KEY | jq -r '.AccessKey.AccessKeyId') 

NEW_SECRET_KEY=$(echo $NEW_KEY | jq -r '.AccessKey.SecretAccessKey') 

  

# Store new key in AWS Secrets Manager 

aws secretsmanager update-secret \ 

    --secret-id /deploy/credentials \ 

    --secret-string "{\"ACCESS_KEY\":\"$NEW_ACCESS_KEY_ID\",\"SECRET_KEY\":\"$NEW_SECRET_KEY\"}" 

  

# Deactivate old keys 

for OLD_KEY in $OLD_KEYS; do 

    aws iam update-access-key \ 

        --user-name $USER_NAME \ 

        --access-key-id $OLD_KEY \ 

        --status Inactive 

    echo "Deactivated key: $OLD_KEY" 

done 

  

# Delete keys older than 90 days 

VERY_OLD_KEYS=$(aws iam list-access-keys --user-name $USER_NAME \ 

    --query "AccessKeyMetadata[?CreateDate<='$(date --date="90 days ago" +%Y-%m-%d)'].AccessKeyId" \ 

    --output text) 

  

for KEY in $VERY_OLD_KEYS; do 

    aws iam delete-access-key \ 

        --user-name $USER_NAME \ 

        --access-key-id $KEY 

    echo "Deleted key: $KEY" 

done 

``` 

  

### **Q5: Script to clean up orphaned resources** 

```bash 

#!/bin/bash 

# Cleanup orphaned AWS resources 

set -euo pipefail 

  

REGION="us-east-1" 

RETENTION_DAYS=7 

  

# Find unattached EBS volumes 

UNATTACHED_VOLUMES=$(aws ec2 describe-volumes \ 

    --region $REGION \ 

    --filters Name=status,Values=available \ 

    --query "Volumes[?CreateTime<='$(date --date="${RETENTION_DAYS} days ago" +%Y-%m-%d)'].VolumeId" \ 

    --output text) 

  

for VOLUME in $UNATTACHED_VOLUMES; do 

    echo "Deleting unattached volume: $VOLUME" 

    aws ec2 delete-volume --volume-id $VOLUME --region $REGION 

done 

  

# Find old AMIs 

OLD_AMIS=$(aws ec2 describe-images \ 

    --region $REGION \ 

    --owners self \ 

    --query "Images[?CreationDate<='$(date --date="30 days ago" +%Y-%m-%d)'].ImageId" \ 

    --output text) 

  

for AMI in $OLD_AMIS; do 

    # Check if AMI is being used 

    INSTANCES=$(aws ec2 describe-instances \ 

        --region $REGION \ 

        --filters Name=image-id,Values=$AMI \ 

        --query 'Reservations[].Instances[].InstanceId' \ 

        --output text) 

     

    if [ -z "$INSTANCES" ]; then 

        echo "Deregistering unused AMI: $AMI" 

        # Get associated snapshots first 

        SNAPSHOTS=$(aws ec2 describe-images \ 

            --image-ids $AMI \ 

            --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' \ 

            --output text) 

         

        aws ec2 deregister-image --image-id $AMI --region $REGION 

         

        # Delete associated snapshots 

        for SNAP in $SNAPSHOTS; do 

            aws ec2 delete-snapshot --snapshot-id $SNAP --region $REGION 

        done 

    fi 

done 

``` 

  

## **Advanced Shell Scripting Patterns** 

  

### **1. Error Handling & Logging** 

```bash 

#!/bin/bash 

# Script with proper error handling 

set -euo pipefail 

  

LOG_FILE="/var/log/aws-deploy.log" 

exec > >(tee -a "$LOG_FILE") 2>&1 

  

trap 'error_exit "Line $LINENO"' ERR 

  

error_exit() { 

    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE" 

    # Send to CloudWatch Logs 

    aws logs put-log-events \ 

        --log-group-name "/aws/scripts" \ 

        --log-stream-name "$(hostname)" \ 

        --log-events "[$(date +%s%3N), \"$1\"]" \ 

        --region us-east-1 || true 

    exit 1 

} 

``` 

  

### **2. Parallel Processing** 

```bash 

#!/bin/bash 

# Process S3 files in parallel 

BUCKET="my-bucket" 

MAX_JOBS=5 

  

process_file() { 

    local file=$1 

    # Process file... 

    echo "Processing $file" 

} 

  

export -f process_file 

  

# List files and process in parallel 

aws s3 ls "s3://$BUCKET/" --recursive | awk '{print $4}' | \ 

    xargs -P $MAX_JOBS -I {} bash -c 'process_file "$@"' _ {} 

``` 

  

### **3. Configuration Management** 

```bash 

#!/bin/bash 

# Load configuration from SSM Parameter Store 

load_config() { 

    local prefix="/app/${ENVIRONMENT}" 

     

    # Get all parameters under prefix 

    params=$(aws ssm get-parameters-by-path \ 

        --path "$prefix" \ 

        --with-decryption \ 

        --recursive \ 

        --query 'Parameters[*].[Name,Value]' \ 

        --output text) 

     

    while IFS=$'\t' read -r name value; do 

        # Convert parameter name to environment variable 

        var_name=$(echo "$name" | sed "s|$prefix/||" | tr '/-' '_' | tr '[:lower:]' '[:upper:]') 

        export "$var_name=$value" 

    done <<< "$params" 

} 

  

# Usage 

ENVIRONMENT=${1:-production} 

load_config 

echo "DB_HOST: $DATABASE_HOST" 

``` 

  

## **Common Interview Questions** 

  

### **Q: What does `set -euo pipefail` do?** 

**A:** 

- `set -e`: Exit immediately if any command exits with non-zero status 

- `set -u`: Treat unset variables as errors 

- `set -o pipefail`: Return value of pipeline is status of last command to exit with non-zero, or zero if all succeed 

  

### **Q: How to pass parameters to a shell script?** 

**A:** 

```bash 

#!/bin/bash 

# $0 = script name 

# $1, $2, $3... = positional parameters 

# $# = number of parameters 

# $@ = all parameters as separate words 

# $* = all parameters as single word 

  

echo "Script: $0" 

echo "First arg: $1" 

echo "All args: $@" 

echo "Total args: $#" 

``` 

  

### **Q: Difference between `$@` and `$*`?** 

**A:** 

- `$@` expands to separate words: `"$1" "$2" ...` 

- `$*` expands to single word: `"$1 $2 ..."` 

- Use `"$@"` for preserving arguments with spaces 

  

### **Q: How to check if a command exists?** 

**A:** 

```bash 

if command -v aws &> /dev/null; then 

    echo "AWS CLI is installed" 

else 

    echo "Installing AWS CLI..." 

fi 

``` 

  

### **Q: Best practices for AWS DevOps shell scripts?** 

**A:** 

1. Always use `set -euo pipefail` at the beginning 

2. Use IAM roles instead of hardcoding credentials 

3. Implement proper error handling and logging 

4. Use tags for resource identification 

5. Implement idempotency where possible 

6. Use AWS CLI `--query` and JMESPath for parsing output 

7. Store sensitive data in Parameter Store or Secrets Manager 

8. Use CloudWatch Logs for centralized logging 

9. Implement retry logic for AWS API calls 

10. Clean up temporary resources 

  

## **Useful One-Liners for AWS DevOps** 

  

```bash 

# Get instance metadata 

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) 

AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) 

  

# List all EC2 instances with tags 

aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table 

  

# Monitor CloudWatch metrics 

aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --period 300 --statistics Average --dimensions Name=InstanceId,Value=i-12345678 

  

# Find security groups with unrestricted SSH 

aws ec2 describe-security-groups --query 'SecurityGroups[?IpPermissions[?ToPort==`22` && contains(IpRanges[].CidrIp, `0.0.0.0/0`)]].GroupId' --output text 

  

# Get latest AMI for Ubuntu 

aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" "Name=state,Values=available" --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text 

``` 

  

## **Debugging Tips** 

  

```bash 

# Debug mode 

bash -x script.sh 

set -x  # Enable debugging in script 

set +x  # Disable debugging 

  

# Check script syntax 

bash -n script.sh 

  

# Trace variable assignments 

bash -v script.sh 

  

# Use trap for debugging 

trap 'echo "Line $LINENO: $BASH_COMMAND"' DEBUG 

``` 

  

## **Performance Optimization** 

  

```bash 

# Use aws-cli pagination for large results 

aws ec2 describe-instances --max-items 1000 

  

# Parallelize AWS operations 

parallel -j 10 aws s3 cp {} s3://bucket/ ::: *.log 

  

# Use jq for JSON processing (faster than Python) 

aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | .InstanceId + " " + .State.Name' 

``` 

  
