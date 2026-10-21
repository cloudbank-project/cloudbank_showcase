#!/usr/bin/env bash
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-cloudbank-demo-admin}"
AWS_REGION="${AWS_REGION:-us-west-2}"
NEPTUNE_CLUSTER_IDENTIFIER="${NEPTUNE_CLUSTER_IDENTIFIER:-cloudbank-biobricks-neptune}"
NEPTUNE_INSTANCE_IDENTIFIER="${NEPTUNE_INSTANCE_IDENTIFIER:-cloudbank-biobricks-neptune-1}"
NEPTUNE_SUBNET_GROUP_NAME="${NEPTUNE_SUBNET_GROUP_NAME:-neptune-demo-subnet-group}"
NEPTUNE_SG_NAME="${NEPTUNE_SG_NAME:-neptune-demo-sg}"
RUNNER_TAG_NAME="${RUNNER_TAG_NAME:-cloudbank-neptune-runner}"
ROLE_NEPTUNE="${ROLE_NEPTUNE:-NeptuneLoadFromS3Role}"
ROLE_EC2="${ROLE_EC2:-CloudbankDemoEc2Role}"
PROFILE_EC2="${PROFILE_EC2:-CloudbankDemoEc2Profile}"
ROLE_UI_TASK="${ROLE_UI_TASK:-CloudbankChemistryUiTaskRole}"
ROLE_ECS_EXECUTION="${ROLE_ECS_EXECUTION:-ecsTaskExecutionRole}"

# Marker tag: resources created by this tutorial carry cloudbank-demo-created=true.
# Cleanup only deletes resources that carry this tag, so a pre-existing resource
# that happens to share a tutorial name is never touched (a note is printed instead).
MARKER_KEY="cloudbank-demo-created"

role_has_marker() {
  local tags
  tags="$(aws iam list-role-tags --role-name "$1" --query 'Tags' --output text 2>/dev/null || true)"
  [[ "${tags}" == *"${MARKER_KEY}"* ]]
}

profile_has_marker() {
  local tags
  tags="$(aws iam list-instance-profile-tags --instance-profile-name "$1" --query 'Tags' --output text 2>/dev/null || true)"
  [[ "${tags}" == *"${MARKER_KEY}"* ]]
}

sg_has_marker() {
  local tags
  tags="$(aws ec2 describe-security-groups --region "${AWS_REGION}" --group-ids "$1" --query 'SecurityGroups[0].Tags' --output text 2>/dev/null || true)"
  [[ "${tags}" == *"${MARKER_KEY}"* ]]
}

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
S3_BUCKET="${S3_BUCKET:-${BUCKET_PREFIX:-cloudbank-biobricks-kg}-${ACCOUNT_ID}-${AWS_REGION//-/}}"

echo "Destroying Neptune, runner, and data resources..."

# Terminate runner EC2 instances.
RUNNER_IDS="$(aws ec2 describe-instances --region "$AWS_REGION" --filters Name=tag:Name,Values="$RUNNER_TAG_NAME" Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)"
if [[ -n "$RUNNER_IDS" ]]; then
  aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids $RUNNER_IDS >/dev/null || true
  aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids $RUNNER_IDS >/dev/null 2>&1 || true
fi

# Delete Neptune instance first.
INSTANCE_EXISTS="$(aws neptune describe-db-instances --region "$AWS_REGION" --db-instance-identifier "$NEPTUNE_INSTANCE_IDENTIFIER" --query 'DBInstances[0].DBInstanceIdentifier' --output text 2>/dev/null || true)"
if [[ "$INSTANCE_EXISTS" == "$NEPTUNE_INSTANCE_IDENTIFIER" ]]; then
  aws neptune delete-db-instance --region "$AWS_REGION" --db-instance-identifier "$NEPTUNE_INSTANCE_IDENTIFIER" >/dev/null || true
  aws neptune wait db-instance-deleted --region "$AWS_REGION" --db-instance-identifier "$NEPTUNE_INSTANCE_IDENTIFIER" >/dev/null 2>&1 || true
fi

# Delete Neptune cluster.
CLUSTER_EXISTS="$(aws neptune describe-db-clusters --region "$AWS_REGION" --db-cluster-identifier "$NEPTUNE_CLUSTER_IDENTIFIER" --query 'DBClusters[0].DBClusterIdentifier' --output text 2>/dev/null || true)"
if [[ "$CLUSTER_EXISTS" == "$NEPTUNE_CLUSTER_IDENTIFIER" ]]; then
  aws neptune delete-db-cluster --region "$AWS_REGION" --db-cluster-identifier "$NEPTUNE_CLUSTER_IDENTIFIER" --skip-final-snapshot >/dev/null || true
  # There is no 'aws neptune wait db-cluster-deleted' waiter. Poll until the
  # cluster is gone so the subnet group can be deleted right after.
  for i in {1..60}; do
    CLUSTER_STATUS="$(aws neptune describe-db-clusters --region "$AWS_REGION" --db-cluster-identifier "$NEPTUNE_CLUSTER_IDENTIFIER" --query 'DBClusters[0].DBClusterStatus' --output text 2>/dev/null || echo "GONE")"
    if [[ -z "$CLUSTER_STATUS" || "$CLUSTER_STATUS" == "None" || "$CLUSTER_STATUS" == "GONE" ]]; then
      echo "Neptune cluster deleted."
      break
    fi
    echo "Waiting for Neptune cluster deletion (status: $CLUSTER_STATUS)..."
    sleep 10
  done
  if [[ -n "$CLUSTER_STATUS" && "$CLUSTER_STATUS" != "None" && "$CLUSTER_STATUS" != "GONE" ]]; then
    echo "WARNING: cluster ${NEPTUNE_CLUSTER_IDENTIFIER} is still present (status: ${CLUSTER_STATUS}) after waiting." >&2
  fi
fi

# Delete Neptune subnet group.
if aws neptune describe-db-subnet-groups --region "$AWS_REGION" --db-subnet-group-name "$NEPTUNE_SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  aws neptune delete-db-subnet-group --region "$AWS_REGION" --db-subnet-group-name "$NEPTUNE_SUBNET_GROUP_NAME" >/dev/null || true
fi

# Delete S3 data bucket for the demo.
if aws s3api head-bucket --bucket "$S3_BUCKET" >/dev/null 2>&1; then
  aws s3 rm "s3://$S3_BUCKET" --recursive >/dev/null || true
  aws s3api delete-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" >/dev/null || true
fi

# Delete VPC endpoints created for demo networking (S3 + STS in same VPC as neptune-demo-sg if available).
NEPTUNE_SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values="$NEPTUNE_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
VPC_ID=""
if [[ -n "$NEPTUNE_SG_ID" && "$NEPTUNE_SG_ID" != "None" ]]; then
  VPC_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --group-ids "$NEPTUNE_SG_ID" --query 'SecurityGroups[0].VpcId' --output text 2>/dev/null || true)"
fi
if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  VPC_ID="$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
fi

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
  # Only delete endpoints carrying the tutorial marker tag, so pre-existing
  # S3/STS endpoints in the same VPC are never touched.
  VPCE_IDS="$(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=service-name,Values=com.amazonaws.${AWS_REGION}.s3,com.amazonaws.${AWS_REGION}.sts Name=tag:cloudbank-demo-created,Values=true --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null || true)"
  if [[ -n "$VPCE_IDS" ]]; then
    aws ec2 delete-vpc-endpoints --region "$AWS_REGION" --vpc-endpoint-ids $VPCE_IDS >/dev/null || true
    echo "Deleted tutorial VPC endpoints: $VPCE_IDS"
  fi
fi

# Delete security group used by Neptune (only if created by this tutorial).
if [[ -n "$NEPTUNE_SG_ID" && "$NEPTUNE_SG_ID" != "None" ]]; then
  if sg_has_marker "$NEPTUNE_SG_ID"; then
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$NEPTUNE_SG_ID" >/dev/null 2>&1 || true
  else
    echo "Skipping security group $NEPTUNE_SG_ID (pre-existing, not created by this tutorial)."
  fi
fi

# Delete the STS endpoint security group created by script 07 (only if marked).
STS_ENDPOINT_SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values=cloudbank-sts-endpoint-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [[ -n "$STS_ENDPOINT_SG_ID" && "$STS_ENDPOINT_SG_ID" != "None" ]]; then
  if sg_has_marker "$STS_ENDPOINT_SG_ID"; then
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$STS_ENDPOINT_SG_ID" >/dev/null 2>&1 || true
    echo "Deleted STS endpoint security group: $STS_ENDPOINT_SG_ID"
  else
    echo "Skipping security group $STS_ENDPOINT_SG_ID (pre-existing, not created by this tutorial)."
  fi
fi

# Remove IAM instance profile/roles created for demo (leave admin user untouched).
if aws iam get-instance-profile --instance-profile-name "$PROFILE_EC2" >/dev/null 2>&1; then
  if profile_has_marker "$PROFILE_EC2"; then
    aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE_EC2" --role-name "$ROLE_EC2" >/dev/null 2>&1 || true
    aws iam delete-instance-profile --instance-profile-name "$PROFILE_EC2" >/dev/null 2>&1 || true
    echo "Deleted instance profile $PROFILE_EC2"
  else
    echo "Skipping instance profile $PROFILE_EC2 (pre-existing, not created by this tutorial)."
  fi
fi

if aws iam get-role --role-name "$ROLE_EC2" >/dev/null 2>&1; then
  if role_has_marker "$ROLE_EC2"; then
    aws iam detach-role-policy --role-name "$ROLE_EC2" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore >/dev/null 2>&1 || true
    aws iam detach-role-policy --role-name "$ROLE_EC2" --policy-arn arn:aws:iam::aws:policy/AdministratorAccess >/dev/null 2>&1 || true
    aws iam delete-role --role-name "$ROLE_EC2" >/dev/null 2>&1 || true
    echo "Deleted role $ROLE_EC2"
  else
    echo "Skipping role $ROLE_EC2 (pre-existing, not created by this tutorial)."
  fi
fi

if aws iam get-role --role-name "$ROLE_NEPTUNE" >/dev/null 2>&1; then
  if role_has_marker "$ROLE_NEPTUNE"; then
    for policy_arn in $(aws iam list-attached-role-policies --role-name "$ROLE_NEPTUNE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true); do
      aws iam detach-role-policy --role-name "$ROLE_NEPTUNE" --policy-arn "$policy_arn" >/dev/null 2>&1 || true
    done
    for policy_name in $(aws iam list-role-policies --role-name "$ROLE_NEPTUNE" --query 'PolicyNames' --output text 2>/dev/null || true); do
      aws iam delete-role-policy --role-name "$ROLE_NEPTUNE" --policy-name "$policy_name" >/dev/null 2>&1 || true
    done
    aws iam delete-role --role-name "$ROLE_NEPTUNE" >/dev/null 2>&1 || true
    echo "Deleted role $ROLE_NEPTUNE"
  else
    echo "Skipping role $ROLE_NEPTUNE (pre-existing, not created by this tutorial)."
  fi
fi

if aws iam get-role --role-name "$ROLE_UI_TASK" >/dev/null 2>&1; then
  if role_has_marker "$ROLE_UI_TASK"; then
    for policy_arn in $(aws iam list-attached-role-policies --role-name "$ROLE_UI_TASK" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true); do
      aws iam detach-role-policy --role-name "$ROLE_UI_TASK" --policy-arn "$policy_arn" >/dev/null 2>&1 || true
    done
    aws iam delete-role --role-name "$ROLE_UI_TASK" >/dev/null 2>&1 || true
    echo "Deleted role $ROLE_UI_TASK"
  else
    echo "Skipping role $ROLE_UI_TASK (pre-existing, not created by this tutorial)."
  fi
fi

if aws iam get-role --role-name "$ROLE_ECS_EXECUTION" >/dev/null 2>&1; then
  CLUSTER_ARNS="$(aws ecs list-clusters --region "$AWS_REGION" --query 'clusterArns' --output text 2>/dev/null || true)"
  if [[ -z "$CLUSTER_ARNS" || "$CLUSTER_ARNS" == "None" ]]; then
    if role_has_marker "$ROLE_ECS_EXECUTION"; then
      for policy_arn in $(aws iam list-attached-role-policies --role-name "$ROLE_ECS_EXECUTION" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true); do
        aws iam detach-role-policy --role-name "$ROLE_ECS_EXECUTION" --policy-arn "$policy_arn" >/dev/null 2>&1 || true
      done
      aws iam delete-role --role-name "$ROLE_ECS_EXECUTION" >/dev/null 2>&1 || true
      echo "Deleted role $ROLE_ECS_EXECUTION"
    else
      echo "Skipping role $ROLE_ECS_EXECUTION (pre-existing, not created by this tutorial)."
    fi
  fi
fi

echo "Neptune/data/runner cleanup complete."
