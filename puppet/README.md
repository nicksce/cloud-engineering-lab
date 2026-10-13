# Puppet lab infrastructure

This example uses Terraform to create a Rocky Linux 10 server and client in a dedicated VPC in AWS. Terraform provisions the infrastructure only; it does not install or configure Puppet software. This example does not use Ansible.

## Resources

- Region: `ap-south-1`
- VPC: `10.20.0.0/16`
- Public subnet: `10.20.1.0/24`, with an internet gateway and a default route
- `puppet-server`: Rocky Linux 10 x86_64, `t3.small`
- `puppet-client`: Rocky Linux 10 x86_64, `t3.micro`
- Both instances receive public IPv4 addresses and use the `puppet-lab-key` EC2 key pair.
- Instance tags are `Environment=puppet-lab`, `role=puppet-server`, and `role=puppet-client` respectively.

The Puppet server security group allows TCP 8140 from the client security group. SSH (TCP 22) is allowed from the `ssh_cidr` variable, whose current default is `0.0.0.0/0`. Restrict this to a trusted source before applying, for example `-var='ssh_cidr=YOUR_PUBLIC_IP/32'`.

The AMI data source looks up the latest matching Rocky Linux 10 x86_64 base image from the Rocky Linux AWS account. The image ID can therefore change between plans.

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

The outputs include the server private IP and both public IPs. The server and client private IPv4 addresses stay assigned when the instances are stopped and started. AWS releases auto-assigned public IPv4 addresses on stop and assigns new ones on the next start, so retrieve the current addresses from EC2 when needed.

## Start and stop instances

These commands find the current instance IDs by tags and state, so they do not depend on fixed IDs:

```bash
INSTANCE_IDS=$(aws ec2 describe-instances --region ap-south-1 \
  --filters 'Name=tag:Environment,Values=puppet-lab' \
            'Name=instance-state-name,Values=stopped' \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 start-instances --region ap-south-1 --instance-ids $INSTANCE_IDS
```

```bash
INSTANCE_IDS=$(aws ec2 describe-instances --region ap-south-1 \
  --filters 'Name=tag:Environment,Values=puppet-lab' \
            'Name=instance-state-name,Values=running' \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 stop-instances --region ap-south-1 --instance-ids $INSTANCE_IDS
```

Get current addresses and states:

```bash
aws ec2 describe-instances --region ap-south-1 \
  --filters 'Name=tag:Environment,Values=puppet-lab' \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}' \
  --output table
```

Stopped instances do not incur EC2 compute charges, but EBS volumes and other retained AWS resources may continue to incur charges. Public IPv4 addresses change after stop and start.

## Remove this experiment

To delete the resources managed by this Terraform state, run from this directory:

```bash
terraform destroy
```

Review the plan carefully before confirming. This deletes the instances and networking resources managed by this example.

## State and GitHub

This example uses local Terraform state in this directory. State files and backups are ignored by the repository `.gitignore`; do not add them to Git. The `.terraform.lock.hcl` in this directory should be committed so provider selection is reproducible. For shared or long-lived use, configure an access-controlled remote backend with encryption, versioning, and locking.
