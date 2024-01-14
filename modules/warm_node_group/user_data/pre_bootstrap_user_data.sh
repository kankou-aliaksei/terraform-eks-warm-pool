# Redirect stdout and stderr to both a log file and the console
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Enable debug mode for detailed script execution trace
set -x

# Log the date and time when the script starts
DATETIME=$(date -u '+%Y_%m_%d_T%H:%M:%SZ')
echo "Script running at $DATETIME"

execute_warmup_tasks() {
  echo "Executing warm-up tasks at $current_date_time"
  # Perform tasks required during the warm-up stage
  # For instance: downloading files, configuring settings, etc.
  sleep 2m # Simulating a time-consuming task. Remove this line in production.
}

# Function to complete the lifecycle action
complete_lifecycle_action() {
  while true; do
    if [[ "$LIFECYCLE_STATE" == *Pending:Wait* ]]; then
      aws autoscaling complete-lifecycle-action \
        --lifecycle-hook-name "finish_user_data" \
        --auto-scaling-group-name "$ASG_NAME" \
        --lifecycle-action-result CONTINUE \
        --instance-id "$INSTANCE_ID" \
        --region "$REGION"
      DATETIME_END=$(date -u '+%Y_%m_%d_T%H:%M:%SZ')
      echo "User data complete at $DATETIME_END"
      break
    fi
    echo "Waiting for lifecycle hook to trigger..."
    sleep 1
  done
}

# Fetch AWS metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600")
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Query Auto Scaling Group details
ASG_DETAILS=$(aws autoscaling describe-auto-scaling-instances --instance-ids "$INSTANCE_ID" --region "$REGION")
LIFECYCLE_STATE=$(echo "$ASG_DETAILS" | jq -r '.AutoScalingInstances[].LifecycleState')
ASG_NAME=$(echo "$ASG_DETAILS" | jq -r '.AutoScalingInstances[].AutoScalingGroupName')

# Main logic for handling lifecycle states
if [[ "$LIFECYCLE_STATE" == *Warmed:Pending* || "$LIFECYCLE_STATE" == *Warmed:Pending:Wait* ]]; then
  echo "Warming stage"
  execute_warmup_tasks
  # During the warming stage, remove the semaphore file to ensure user data is executed again
  # This is necessary because instances from the warm pool need to run user data scripts upon activation
  rm /var/lib/cloud/instances/"$INSTANCE_ID"/sem/config_scripts_user
  complete_lifecycle_action
  cp "/var/log/user-data.log" "/var/log/user-data-$DATETIME".log
  # Exit to avoid running the full bootstrap process during the warm stage
  exit 0
fi

echo "Get/Run instance from warm pool"
