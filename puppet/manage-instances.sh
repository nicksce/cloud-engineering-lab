#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: manage-instances.sh start|stop [--region REGION]

Finds EC2 instances tagged Environment=puppet-lab and starts stopped instances
or stops running instances. The default region is ap-south-1.
USAGE
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage >&2
  exit 2
fi

action=$1
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-south-1}}"
if [[ $# -eq 3 ]]; then
  if [[ $2 != "--region" || -z $3 ]]; then
    usage >&2
    exit 2
  fi
  region=$3
elif [[ $# -eq 2 ]]; then
  usage >&2
  exit 2
fi

case "$action" in
  start)
    target_state=stopped
    operation=start-instances
    waiter=instance-running
    ;;
  stop)
    target_state=running
    operation=stop-instances
    waiter=instance-stopped
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

id_text=$(aws ec2 describe-instances \
  --region "$region" \
  --filters \
    'Name=tag:Environment,Values=puppet-lab' \
    "Name=instance-state-name,Values=$target_state" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [[ -z $id_text || $id_text == None ]]; then
  printf 'No puppet-lab instances found in state %s in %s.\n' "$target_state" "$region"
  exit 0
fi

id_text=${id_text//$'\t'/$'\n'}
mapfile -t instance_ids <<< "$id_text"

printf '%s %s puppet-lab instance(s) in %s...\n' "$action" "${#instance_ids[@]}" "$region"
aws ec2 "$operation" --region "$region" --instance-ids "${instance_ids[@]}"
aws ec2 wait "$waiter" --region "$region" --instance-ids "${instance_ids[@]}"
printf 'All matching instances are %s.\n' "$([[ $action == start ]] && printf running || printf stopped)"
