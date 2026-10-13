# Puppet lab infrastructure

This example uses Terraform to create a Rocky Linux 9 server and client in a dedicated VPC in AWS. Terraform provisions the infrastructure only; it does not install or configure Puppet software. This example does not use Ansible.

## Resources

- Region: `ap-south-1`
- VPC: `10.20.0.0/16`
- Public subnet: `10.20.1.0/24`, with an internet gateway and a default route
- `puppet-server`: Rocky Linux 9 x86_64, `t3.small`
- `puppet-client1`: Rocky Linux 9 x86_64, `t3.micro`
- Linux hostnames and EC2 `Name` tags are `puppet-server` and `puppet-client1` respectively.
- On first boot, each instance sets its Linux hostname, sets the timezone to `Asia/Kolkata` (IST), and runs `dnf -y update` through EC2 user data.
- Each instance receives a dedicated VPC Elastic IP and uses the `puppet-lab-key` EC2 key pair.
- Instance tags are `Environment=puppet-lab`, `role=puppet-server`, and `role=puppet-client1` respectively.

The Puppet server security group allows TCP 8140 from the client security group. SSH (TCP 22) is allowed from the `ssh_cidr` variable, whose current default is `0.0.0.0/0`. Restrict this to a trusted source before applying, for example `-var='ssh_cidr=YOUR_PUBLIC_IP/32'`.

The AMI data source looks up the latest matching Rocky Linux 9 x86_64 base image from the Rocky Linux AWS account. The image ID can therefore change between plans.

The Rocky 9 AMI selector differs from the previous Rocky 10 configuration. Applying the Rocky 9 and first-boot configuration replaces both EC2 instances. Changing the client hostname also replaces the client instance. Back up any data you need first; the root EBS volumes are deleted when their instances are terminated. Review the plan to confirm the Elastic IP allocations are retained and re-associated. Private IPs can change when instances are replaced. Package updates also make first boot take longer. Additional clients can follow the `puppet-client2` naming pattern.

## Prerequisites

- Terraform 1.5 or newer
- AWS CLI or SDK credentials with permission to create EC2, VPC, security groups, routing, and key pairs in `ap-south-1`
- A dedicated SSH key pair at `~/.ssh/puppet-lab` and `~/.ssh/puppet-lab.pub`

The public key is read from `~/.ssh/puppet-lab.pub` when Terraform runs. The private key is only for SSH access; keep it outside the repository.

## Provision and inspect

Run these commands from this directory:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -var='ssh_cidr=YOUR_PUBLIC_IP/32'
terraform apply -var='ssh_cidr=YOUR_PUBLIC_IP/32'
```

Replace `YOUR_PUBLIC_IP/32` with a CIDR that is allowed to SSH to the instances. Use the same value for plan and apply. If you intentionally want the current default of `0.0.0.0/0`, omit the `-var` option.

Show the Terraform outputs:

```bash
terraform output
```

The outputs include the server private IP and both Elastic IP addresses. The private addresses stay assigned when the instances are stopped and started. Each Elastic IP remains associated through stop/start, so the public addresses stay consistent.

## Start and stop instances

Use the helper script to find lab instances by their `Environment=puppet-lab` tag and current EC2 state. It does not depend on instance names or IDs. It waits for the requested state transition to finish.

```bash
./manage-instances.sh start
./manage-instances.sh stop
```

The script defaults to `ap-south-1`. Override the region with `--region` or the `AWS_REGION` / `AWS_DEFAULT_REGION` environment variable. AWS CLI credentials must permit `DescribeInstances`, `StartInstances`, `StopInstances`, and the relevant EC2 wait operations.

## Current addresses and states


```bash
aws ec2 describe-instances --region ap-south-1 \
  --filters 'Name=tag:Environment,Values=puppet-lab' \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}' \
  --output table
```

Stopped instances do not incur EC2 compute charges, but EBS volumes, Elastic IPs, and other retained resources can continue to incur charges. AWS currently lists public IPv4 addresses, including Elastic IPs, at $0.005 per address-hour; this charge continues while an Elastic IP is associated with a stopped instance. Check current pricing before applying this change. See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/).

## Remove this experiment

To delete the resources managed by this Terraform state, run from this directory:

```bash
terraform destroy
```

Review the plan carefully before confirming. This deletes the instances and networking resources managed by this example.

## State and GitHub

This example uses local Terraform state in this directory. State files and backups are ignored by the repository `.gitignore`; do not add them to Git. The `.terraform.lock.hcl` in this directory should be committed so provider selection is reproducible. For shared or long-lived use, configure an access-controlled remote backend with encryption, versioning, and locking.
