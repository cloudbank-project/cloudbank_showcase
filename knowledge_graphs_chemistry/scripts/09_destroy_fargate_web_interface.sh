#!/usr/bin/env bash
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-cloudbank-demo-admin}"
AWS_REGION="${AWS_REGION:-us-west-2}"
APP_NAME="${APP_NAME:-cloudbank-chemistry-ui}"
ECR_REPO="${ECR_REPO:-cloudbank-chemistry-ui}"
ECS_CLUSTER="${ECS_CLUSTER:-cloudbank-chemistry-ui-cluster}"
ECS_SERVICE="${ECS_SERVICE:-cloudbank-chemistry-ui-service}"
TASK_FAMILY="${TASK_FAMILY:-cloudbank-chemistry-ui-task}"
ALB_NAME="${ALB_NAME:-cloudbank-chemistry-ui-alb}"
TG_NAME="${TG_NAME:-cloudbank-chemistry-ui-tg}"
UI_SG_NAME="${UI_SG_NAME:-cloudbank-chemistry-ui-sg}"
ALB_SG_NAME="${ALB_SG_NAME:-cloudbank-chemistry-ui-alb-sg}"

# Marker tag: security groups created by this tutorial carry
# cloudbank-demo-created=true. Cleanup only deletes tagged groups, so a
# pre-existing group with the same name is never touched (a note is printed).
MARKER_KEY="cloudbank-demo-created"

# LEFTOVERS is set to 1 whenever a resource created by this tutorial is still
# present when the script finishes. The script then prints a WARNING with the
# exact command to finish, exits non-zero, and never claims "cleanup complete".
LEFTOVERS=0

warn_remaining() {
  echo "WARNING: $1" >&2
  LEFTOVERS=1
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

echo "Destroying Fargate web interface resources..."

# Scale the service to zero, wait for its tasks to drain, then delete it.
# ECS teardown is asynchronous: DeleteCluster fails with
# ClusterContainsTasksException while any task is still running, so the task
# list is polled (AWS CLI v2 also ships 'aws ecs wait services-inactive', but
# a service scaled to zero stays ACTIVE, so polling the task list is the
# reliable signal that the tasks are gone).
SERVICE_NAME="$(aws ecs describe-services --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].serviceName' --output text 2>/dev/null || true)"
if [[ "$SERVICE_NAME" == "$ECS_SERVICE" ]]; then
  echo "Scaling service ${ECS_SERVICE} to zero tasks..."
  aws ecs update-service --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --desired-count 0 >/dev/null || true
  TASK_ATTEMPTS=0
  ACTIVE_TASKS="$(aws ecs list-tasks --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --service-name "$ECS_SERVICE" --desired-status RUNNING --query 'taskArns' --output text 2>/dev/null || true)"
  while [[ -n "$ACTIVE_TASKS" && "$ACTIVE_TASKS" != "None" ]]; do
    TASK_ATTEMPTS=$((TASK_ATTEMPTS + 1))
    if [[ "$TASK_ATTEMPTS" -ge 30 ]]; then
      break
    fi
    echo "Waiting for ECS tasks to stop (still running: ${ACTIVE_TASKS})..."
    sleep 10
    ACTIVE_TASKS="$(aws ecs list-tasks --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --service-name "$ECS_SERVICE" --desired-status RUNNING --query 'taskArns' --output text 2>/dev/null || true)"
  done
  if [[ -n "$ACTIVE_TASKS" && "$ACTIVE_TASKS" != "None" ]]; then
    warn_remaining "service ${ECS_SERVICE} still has running tasks after 5 minutes: ${ACTIVE_TASKS}. The tasks may still be stopping; re-run this script after a few minutes."
  else
    echo "ECS tasks stopped."
  fi
  aws ecs delete-service --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --force >/dev/null || true
  # Wait for the service record to become INACTIVE or to disappear.
  SVC_ATTEMPTS=0
  SVC_STATUS="$(aws ecs describe-services --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].status' --output text 2>/dev/null || true)"
  while [[ -n "$SVC_STATUS" && "$SVC_STATUS" != "None" && "$SVC_STATUS" != "INACTIVE" ]]; do
    SVC_ATTEMPTS=$((SVC_ATTEMPTS + 1))
    if [[ "$SVC_ATTEMPTS" -ge 30 ]]; then
      break
    fi
    sleep 10
    SVC_STATUS="$(aws ecs describe-services --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].status' --output text 2>/dev/null || true)"
  done
  if [[ -n "$SVC_STATUS" && "$SVC_STATUS" != "None" && "$SVC_STATUS" != "INACTIVE" ]]; then
    warn_remaining "service ${ECS_SERVICE} is still ${SVC_STATUS} after 5 minutes. Finish with: aws ecs delete-service --region ${AWS_REGION} --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force"
  else
    echo "Service ${ECS_SERVICE} deleted."
  fi
fi

# Delete ALB listeners/load balancer first.
ALB_ARN="$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
  LISTENER_ARNS="$(aws elbv2 describe-listeners --region "$AWS_REGION" --load-balancer-arn "$ALB_ARN" --query 'Listeners[].ListenerArn' --output text 2>/dev/null || true)"
  for listener_arn in $LISTENER_ARNS; do
    aws elbv2 delete-listener --region "$AWS_REGION" --listener-arn "$listener_arn" >/dev/null || true
  done
  aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$ALB_ARN" >/dev/null || true
  aws elbv2 wait load-balancers-deleted --region "$AWS_REGION" --load-balancer-arns "$ALB_ARN" >/dev/null 2>&1 || true
fi

# Delete target group.
TG_ARN="$(aws elbv2 describe-target-groups --region "$AWS_REGION" --names "$TG_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
if [[ -n "$TG_ARN" && "$TG_ARN" != "None" ]]; then
  aws elbv2 delete-target-group --region "$AWS_REGION" --target-group-arn "$TG_ARN" >/dev/null || true
fi

# Delete ECS cluster. Retry in a bounded loop: DeleteCluster can fail with
# ClusterContainsTasksException or ClusterContainsServicesException while the
# async teardown of the service/tasks is still in progress.
CLUSTER_STATUS="$(aws ecs describe-clusters --region "$AWS_REGION" --clusters "$ECS_CLUSTER" --query 'clusters[0].status' --output text 2>/dev/null || true)"
if [[ "$CLUSTER_STATUS" == "ACTIVE" ]]; then
  echo "Deleting ECS cluster ${ECS_CLUSTER}..."
  CLUSTER_DELETED=0
  for try in {1..10}; do
    if aws ecs delete-cluster --region "$AWS_REGION" --cluster "$ECS_CLUSTER" >/dev/null 2>&1; then
      CLUSTER_DELETED=1
      break
    fi
    echo "DeleteCluster attempt ${try}/10 failed (teardown still in progress); waiting 20 s..."
    sleep 20
  done
  if [[ "$CLUSTER_DELETED" -eq 0 ]]; then
    echo "DeleteCluster could not complete within 10 attempts; the cluster teardown is still in progress." >&2
  else
    # After DeleteCluster succeeds, poll briefly so a shortly-after ACTIVE
    # reading does not get reported as a leftover by the verification below.
    for i in {1..10}; do
      sleep 10
      CLUSTER_STATUS="$(aws ecs describe-clusters --region "$AWS_REGION" --clusters "$ECS_CLUSTER" --query 'clusters[0].status' --output text 2>/dev/null || true)"
      if [[ -z "$CLUSTER_STATUS" || "$CLUSTER_STATUS" == "None" || "$CLUSTER_STATUS" == "INACTIVE" ]]; then
        break
      fi
    done
  fi
fi

# Deregister all task definition revisions in family.
TASK_DEFS="$(aws ecs list-task-definitions --region "$AWS_REGION" --family-prefix "$TASK_FAMILY" --status ACTIVE --query 'taskDefinitionArns' --output text 2>/dev/null || true)"
for task_def in $TASK_DEFS; do
  aws ecs deregister-task-definition --region "$AWS_REGION" --task-definition "$task_def" >/dev/null || true
done

# Delete ECR repository and images.
if aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$ECR_REPO" >/dev/null 2>&1; then
  aws ecr delete-repository --region "$AWS_REGION" --repository-name "$ECR_REPO" --force >/dev/null || true
fi

# Delete log group.
aws logs delete-log-group --region "$AWS_REGION" --log-group-name "/ecs/${APP_NAME}" >/dev/null 2>&1 || true

# Delete UI security groups.
UI_SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values="$UI_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
ALB_SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values="$ALB_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"

# Revoke potential reference from Neptune SG before deletion.
if [[ -n "$UI_SG_ID" && "$UI_SG_ID" != "None" ]]; then
  NEPTUNE_SG_ID="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values=neptune-demo-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
  if [[ -n "$NEPTUNE_SG_ID" && "$NEPTUNE_SG_ID" != "None" ]]; then
    aws ec2 revoke-security-group-ingress --region "$AWS_REGION" --group-id "$NEPTUNE_SG_ID" --protocol tcp --port 8182 --source-group "$UI_SG_ID" >/dev/null 2>&1 || true
  fi
fi

if [[ -n "$ALB_SG_ID" && "$ALB_SG_ID" != "None" ]]; then
  if sg_has_marker "$ALB_SG_ID"; then
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$ALB_SG_ID" >/dev/null 2>&1 || true
  else
    echo "Skipping security group $ALB_SG_ID ($ALB_SG_NAME, pre-existing, not created by this tutorial)."
  fi
fi
if [[ -n "$UI_SG_ID" && "$UI_SG_ID" != "None" ]]; then
  if sg_has_marker "$UI_SG_ID"; then
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$UI_SG_ID" >/dev/null 2>&1 || true
  else
    echo "Skipping security group $UI_SG_ID ($UI_SG_NAME, pre-existing, not created by this tutorial)."
  fi
fi

# Verify every destructive step before claiming success. Everything below
# should return no output; if something created by this tutorial is still
# present, a WARNING with the exact command to finish is printed and the
# script exits non-zero. The script is safe to re-run: a re-run completes
# whatever teardown was still in progress.
echo "Verifying Fargate web interface cleanup..."

CLUSTER_STATUS="$(aws ecs describe-clusters --region "$AWS_REGION" --clusters "$ECS_CLUSTER" --query 'clusters[0].status' --output text 2>/dev/null || true)"
if [[ -n "$CLUSTER_STATUS" && "$CLUSTER_STATUS" != "None" && "$CLUSTER_STATUS" != "INACTIVE" ]]; then
  warn_remaining "ECS cluster ${ECS_CLUSTER} is still ${CLUSTER_STATUS}. Finish with: aws ecs delete-cluster --region ${AWS_REGION} --cluster ${ECS_CLUSTER}"
else
  if [[ "$CLUSTER_STATUS" == "INACTIVE" ]]; then
    echo "ECS cluster ${ECS_CLUSTER} is INACTIVE and will be removed by AWS."
  else
    echo "ECS cluster ${ECS_CLUSTER} is gone."
  fi
fi

SERVICE_STATUS="$(aws ecs describe-services --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].status' --output text 2>/dev/null || true)"
if [[ -n "$SERVICE_STATUS" && "$SERVICE_STATUS" != "None" && "$SERVICE_STATUS" != "INACTIVE" ]]; then
  warn_remaining "ECS service ${ECS_SERVICE} is still ${SERVICE_STATUS}. Finish with: aws ecs delete-service --region ${AWS_REGION} --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force"
fi

ALB_ARN="$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
  warn_remaining "load balancer ${ALB_NAME} is still present (${ALB_ARN}). Finish with: aws elbv2 delete-load-balancer --region ${AWS_REGION} --load-balancer-arn ${ALB_ARN}"
fi

TG_ARN="$(aws elbv2 describe-target-groups --region "$AWS_REGION" --names "$TG_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
if [[ -n "$TG_ARN" && "$TG_ARN" != "None" ]]; then
  warn_remaining "target group ${TG_NAME} is still present (${TG_ARN}). Finish with: aws elbv2 delete-target-group --region ${AWS_REGION} --target-group-arn ${TG_ARN}"
fi

TASK_DEFS="$(aws ecs list-task-definitions --region "$AWS_REGION" --family-prefix "$TASK_FAMILY" --status ACTIVE --query 'taskDefinitionArns' --output text 2>/dev/null || true)"
if [[ -n "$TASK_DEFS" && "$TASK_DEFS" != "None" ]]; then
  warn_remaining "task definitions in family ${TASK_FAMILY} are still ACTIVE: ${TASK_DEFS}. Finish with: aws ecs deregister-task-definition --region ${AWS_REGION} --task-definition <task-definition-arn>"
fi

if aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$ECR_REPO" >/dev/null 2>&1; then
  warn_remaining "ECR repository ${ECR_REPO} is still present. Finish with: aws ecr delete-repository --region ${AWS_REGION} --repository-name ${ECR_REPO} --force"
fi

LOG_GROUPS="$(aws logs describe-log-groups --region "$AWS_REGION" --log-group-name-prefix "/ecs/${APP_NAME}" --query 'logGroups[].logGroupName' --output text 2>/dev/null || true)"
if [[ -n "$LOG_GROUPS" && "$LOG_GROUPS" != "None" ]]; then
  warn_remaining "log group ${LOG_GROUPS} is still present. Finish with: aws logs delete-log-group --region ${AWS_REGION} --log-group-name ${LOG_GROUPS}"
fi

for sg_entry in "$UI_SG_NAME:$UI_SG_ID" "$ALB_SG_NAME:$ALB_SG_ID"; do
  sg_name="${sg_entry%%:*}"
  sg_id="${sg_entry#*:}"
  if [[ -n "$sg_id" && "$sg_id" != "None" ]] && sg_has_marker "$sg_id"; then
    warn_remaining "security group ${sg_name} (${sg_id}) is still present. Finish with: aws ec2 delete-security-group --region ${AWS_REGION} --group-id ${sg_id}"
  fi
done

if [[ "$LEFTOVERS" -eq 0 ]]; then
  echo "Fargate web interface cleanup complete (verified)."
else
  echo "Fargate web interface cleanup did NOT complete: one or more resources are still terminating." >&2
  echo "Re-run this script after a few minutes; it is safe and idempotent and completes any leftover." >&2
  exit 1
fi
