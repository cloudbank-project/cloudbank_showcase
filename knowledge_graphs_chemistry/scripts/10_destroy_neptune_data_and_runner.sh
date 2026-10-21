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

# LEFTOVERS is set to 1 whenever a resource created by this tutorial is still
# present when the script finishes. The script then prints a WARNING with the
# exact command to finish, exits non-zero, and never claims "cleanup complete".
LEFTOVERS=0

warn_remaining() {
  echo "WARNING: $1" >&2
  LEFTOVERS=1
}

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

# Delete a security group with a bounded retry loop. AWS teardown is
# asynchronous: a group attached to a VPC endpoint or an Elastic Network
# Interface that is still deleting fails with DependencyViolation, so the
# delete is retried every 20 s (up to 10 attempts) before declaring failure.
delete_sg_with_retry() {
  local sg_id="$1"
  local label="$2"
  local attempt=0
  local out
  while true; do
    if out="$(aws ec2 delete-security-group --region "${AWS_REGION}" --group-id "$sg_id" 2>&1)"; then
      echo "Deleted ${label}: ${sg_id}"
      return 0
    fi
    attempt=$((attempt + 1))
    if [[ "$attempt" -ge 10 ]]; then
      warn_remaining "${label} ${sg_id} could not be deleted: ${out}. Finish with: aws ec2 delete-security-group --region ${AWS_REGION} --group-id ${sg_id}"
      return 1
    fi
    echo "Waiting for ${label} ${sg_id} to detach (attempt ${attempt}/10)..."
    sleep 20
  done
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
  echo "Deleting Neptune cluster ${NEPTUNE_CLUSTER_IDENTIFIER}..."
  aws neptune delete-db-cluster --region "$AWS_REGION" --db-cluster-identifier "$NEPTUNE_CLUSTER_IDENTIFIER" --skip-final-snapshot >/dev/null || true
  # There is no 'aws neptune wait db-cluster-deleted' waiter in AWS CLI v2
  # (only db-instance-available and db-instance-deleted exist). Poll until the
  # cluster stops being listed; teardown is asynchronous and can continue after
  # describe-db-clusters stops reporting the cluster, so the subnet group
  # deletion below retries on InvalidDBSubnetGroupStateFault.
  for i in {1..60}; do
    CLUSTER_STATUS="$(aws neptune describe-db-clusters --region "$AWS_REGION" --db-cluster-identifier "$NEPTUNE_CLUSTER_IDENTIFIER" --query 'DBClusters[0].DBClusterStatus' --output text 2>/dev/null || echo "GONE")"
    if [[ -z "$CLUSTER_STATUS" || "$CLUSTER_STATUS" == "None" || "$CLUSTER_STATUS" == "GONE" ]]; then
      break
    fi
    echo "Waiting for Neptune cluster deletion (status: $CLUSTER_STATUS)..."
    sleep 10
  done
  # Verify before saying deleted: the cluster must not be listed anymore.
  CLUSTER_CHECK="$(aws neptune describe-db-clusters --region "$AWS_REGION" --db-cluster-identifier "$NEPTUNE_CLUSTER_IDENTIFIER" --query 'DBClusters[0].DBClusterIdentifier' --output text 2>/dev/null || true)"
  if [[ -n "$CLUSTER_CHECK" && "$CLUSTER_CHECK" != "None" ]]; then
    warn_remaining "Neptune cluster ${NEPTUNE_CLUSTER_IDENTIFIER} is still present after waiting. Finish with: aws neptune delete-db-cluster --region ${AWS_REGION} --db-cluster-identifier ${NEPTUNE_CLUSTER_IDENTIFIER} --skip-final-snapshot"
  else
    echo "Neptune cluster deleted."
  fi
fi

# Delete Neptune subnet group. The cluster teardown can keep the group in use
# after describe-db-clusters stops listing the cluster, so retry on
# InvalidDBSubnetGroupStateFault (every 20 s, up to 10 attempts).
if aws neptune describe-db-subnet-groups --region "$AWS_REGION" --db-subnet-group-name "$NEPTUNE_SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  SUBGROUP_DELETED=0
  for try in {1..10}; do
    if SUBGROUP_OUT="$(aws neptune delete-db-subnet-group --region "$AWS_REGION" --db-subnet-group-name "$NEPTUNE_SUBNET_GROUP_NAME" 2>&1)"; then
      SUBGROUP_DELETED=1
      break
    fi
    if [[ "$SUBGROUP_OUT" == *"InvalidDBSubnetGroupStateFault"* ]]; then
      echo "Subnet group still in use by the cluster (attempt ${try}/10); waiting 20 s..."
      sleep 20
    else
      warn_remaining "subnet group ${NEPTUNE_SUBNET_GROUP_NAME} could not be deleted: ${SUBGROUP_OUT}"
      SUBGROUP_DELETED=2
      break
    fi
  done
  if [[ "$SUBGROUP_DELETED" -eq 0 ]]; then
    warn_remaining "subnet group ${NEPTUNE_SUBNET_GROUP_NAME} is still in use after 10 attempts (cluster teardown still running). Finish with: aws neptune delete-db-subnet-group --region ${AWS_REGION} --db-subnet-group-name ${NEPTUNE_SUBNET_GROUP_NAME}"
  elif [[ "$SUBGROUP_DELETED" -eq 1 ]]; then
    echo "Subnet group deleted."
  fi
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
    # Endpoint deletion is asynchronous (state 'deleting' before the endpoint
    # disappears). Poll until the endpoints are gone so the security group
    # delete below does not race them.
    EP_ATTEMPTS=0
    EP_LEFT="$(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" --vpc-endpoint-ids $VPCE_IDS --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null || true)"
    while [[ -n "$EP_LEFT" && "$EP_LEFT" != "None" ]]; do
      EP_ATTEMPTS=$((EP_ATTEMPTS + 1))
      if [[ "$EP_ATTEMPTS" -ge 30 ]]; then
        break
      fi
      echo "Waiting for VPC endpoints to finish deleting (still present: $EP_LEFT)..."
      sleep 10
      EP_LEFT="$(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" --vpc-endpoint-ids $VPCE_IDS --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null || true)"
    done
    if [[ -n "$EP_LEFT" && "$EP_LEFT" != "None" ]]; then
      warn_remaining "VPC endpoints are still deleting: ${EP_LEFT}. Finish with: aws ec2 delete-vpc-endpoints --region ${AWS_REGION} --vpc-endpoint-ids ${EP_LEFT}"
    else
      echo "VPC endpoints fully deleted."
    fi
  fi
fi

# Delete security group used by Neptune (only if created by this tutorial).
if [[ -n "$NEPTUNE_SG_ID" && "$NEPTUNE_SG_ID" != "None" ]]; then
  if sg_has_marker "$NEPTUNE_SG_ID"; then
    delete_sg_with_retry "$NEPTUNE_SG_ID" "Neptune security group" || true
  else
    echo "Skipping security group $NEPTUNE_SG_ID (pre-existing, not created by this tutorial)."
  fi
fi

# Delete the STS endpoint security group created by script 07 (only if marked).
STS_ENDPOINT_SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values=cloudbank-sts-endpoint-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [[ -n "$STS_ENDPOINT_SG_ID" && "$STS_ENDPOINT_SG_ID" != "None" ]]; then
  if sg_has_marker "$STS_ENDPOINT_SG_ID"; then
    delete_sg_with_retry "$STS_ENDPOINT_SG_ID" "STS endpoint security group" || true
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

# Verify every destructive step before claiming success. Everything below
# should return no output; if something created by this tutorial is still
# present, a WARNING with the exact command to finish is printed and the
# script exits non-zero. The script is safe to re-run: a re-run completes
# whatever teardown was still in progress.
echo "Verifying Neptune/data/runner cleanup..."

ALL_CLUSTERS="$(aws neptune describe-db-clusters --region "$AWS_REGION" --query 'DBClusters[].DBClusterIdentifier' --output text 2>/dev/null || true)"
if [[ "$ALL_CLUSTERS" == *"$NEPTUNE_CLUSTER_IDENTIFIER"* ]]; then
  warn_remaining "Neptune cluster ${NEPTUNE_CLUSTER_IDENTIFIER} is still present. Finish with: aws neptune delete-db-cluster --region ${AWS_REGION} --db-cluster-identifier ${NEPTUNE_CLUSTER_IDENTIFIER} --skip-final-snapshot"
fi

ALL_INSTANCES="$(aws neptune describe-db-instances --region "$AWS_REGION" --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null || true)"
if [[ "$ALL_INSTANCES" == *"$NEPTUNE_INSTANCE_IDENTIFIER"* ]]; then
  warn_remaining "Neptune instance ${NEPTUNE_INSTANCE_IDENTIFIER} is still present. Finish with: aws neptune delete-db-instance --region ${AWS_REGION} --db-instance-identifier ${NEPTUNE_INSTANCE_IDENTIFIER}"
fi

ALL_SUBGROUPS="$(aws neptune describe-db-subnet-groups --region "$AWS_REGION" --query 'DBSubnetGroups[].DBSubnetGroupName' --output text 2>/dev/null || true)"
if [[ "$ALL_SUBGROUPS" == *"$NEPTUNE_SUBNET_GROUP_NAME"* ]]; then
  warn_remaining "Neptune subnet group ${NEPTUNE_SUBNET_GROUP_NAME} is still present. Finish with: aws neptune delete-db-subnet-group --region ${AWS_REGION} --db-subnet-group-name ${NEPTUNE_SUBNET_GROUP_NAME}"
fi

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
  VPCE_LEFT="$(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=service-name,Values=com.amazonaws.${AWS_REGION}.s3,com.amazonaws.${AWS_REGION}.sts Name=tag:cloudbank-demo-created,Values=true --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null || true)"
  if [[ -n "$VPCE_LEFT" && "$VPCE_LEFT" != "None" ]]; then
    warn_remaining "tutorial VPC endpoints are still present: ${VPCE_LEFT}. Finish with: aws ec2 delete-vpc-endpoints --region ${AWS_REGION} --vpc-endpoint-ids ${VPCE_LEFT}"
  fi
fi

for sg_name in "$NEPTUNE_SG_NAME" "cloudbank-sts-endpoint-sg"; do
  SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values="$sg_name" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
  if [[ -n "$SG_ID" && "$SG_ID" != "None" ]] && sg_has_marker "$SG_ID"; then
    warn_remaining "security group ${sg_name} (${SG_ID}) is still present. Finish with: aws ec2 delete-security-group --region ${AWS_REGION} --group-id ${SG_ID}"
  fi
done

RUNNER_IDS="$(aws ec2 describe-instances --region "$AWS_REGION" --filters Name=tag:Name,Values="$RUNNER_TAG_NAME" Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)"
if [[ -n "$RUNNER_IDS" ]]; then
  warn_remaining "runner instance(s) ${RUNNER_IDS} are still present (not terminated). Finish with: aws ec2 terminate-instances --region ${AWS_REGION} --instance-ids ${RUNNER_IDS}"
fi

if aws s3api head-bucket --bucket "$S3_BUCKET" >/dev/null 2>&1; then
  warn_remaining "S3 bucket ${S3_BUCKET} is still present. Finish with: aws s3 rm s3://${S3_BUCKET} --recursive && aws s3api delete-bucket --bucket ${S3_BUCKET} --region ${AWS_REGION}"
fi

for role_name in "$ROLE_EC2" "$ROLE_NEPTUNE" "$ROLE_UI_TASK"; do
  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    if role_has_marker "$role_name"; then
      warn_remaining "IAM role ${role_name} is still present. Re-run this script (it is idempotent) to finish deleting it."
    fi
  fi
done

if aws iam get-instance-profile --instance-profile-name "$PROFILE_EC2" >/dev/null 2>&1; then
  if profile_has_marker "$PROFILE_EC2"; then
    warn_remaining "instance profile ${PROFILE_EC2} is still present. Re-run this script (it is idempotent) to finish deleting it."
  fi
fi

if [[ "$LEFTOVERS" -eq 0 ]]; then
  echo "Neptune/data/runner cleanup complete (verified)."
else
  echo "Neptune/data/runner cleanup did NOT complete: one or more resources are still terminating." >&2
  echo "Re-run this script after a few minutes; it is safe and idempotent and completes any leftover." >&2
  exit 1
fi
