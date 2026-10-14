# Puppet lab infrastructure

This example uses Terraform to create a Rocky Linux 9 server and client in a dedicated VPC in AWS. EC2 user data updates packages with `dnf -y update` and installs Puppet Server on the server and Puppet Agent on the client during first boot. The Puppet Server service is enabled and started by the script. Ansible is not used.

## Resources

- Region: `aws_region` variable, default `ap-south-1`
- VPC: `10.20.0.0/16`
- Public subnet: `10.20.1.0/24`, with an internet gateway and a default route
- `puppet-server`: Rocky Linux 9 x86_64, `t3.small`
- `puppet-client1`: Rocky Linux 9 x86_64, `t3.micro`
- Linux hostnames and EC2 `Name` tags are `puppet-server` and `puppet-client1` respectively.
- The instances use private IPs `10.20.1.10` (`puppet-server`) and `10.20.1.11` (`puppet-client1`). Each instance adds both IP-to-hostname mappings to `/etc/hosts` on first boot.
- On first boot, each instance sets its Linux hostname, sets the timezone to `Asia/Kolkata` (IST), adds the `/etc/hosts` entries, updates packages with `dnf -y update`, and installs the Puppet software through EC2 user data.
- The server installs and starts `puppetserver`; the client installs `puppet-agent`, configures the server and its certname, waits for the server, then runs `puppet agent --test` on first boot.
- The server CA autosigns only `puppet-client1.<aws_region>.compute.internal`. This is convenient for the lab but is not strong identity verification: any host allowed to reach the Puppet CA could request that certname. Keep TCP 8140 restricted to trusted client security groups.
- The Puppet server sets `JAVA_ARGS="-Xms512m -Xmx512m"` in `/etc/sysconfig/puppetserver` before starting the service.
- The Puppet server installs r10k and writes its configuration to `/etc/puppetlabs/r10k/r10k.yaml`. The repository owner is the `github_username` variable, which defaults to `nicksce`; add `/root/.ssh/puppet_github_deploy.pub` as a deploy key or account SSH key with access to that repository.
- Each instance receives a dedicated VPC Elastic IP and uses the `puppet-lab-key` EC2 key pair.
- Instance tags are `Environment=puppet-lab`, `role=puppet-server`, and `role=puppet-client1` respectively.

The Puppet server security group allows TCP 8140 from the client security group. SSH (TCP 22) is allowed from the `ssh_cidr` variable, whose current default is `0.0.0.0/0`. Restrict this to a trusted source before applying, for example `-var='ssh_cidr=YOUR_PUBLIC_IP/32'`.

The AMI data source looks up the latest matching Rocky Linux 9 x86_64 base image from the Rocky Linux AWS account. The image ID can therefore change between plans.

The Rocky 9 AMI selector differs from the previous Rocky 10 configuration. Applying the Rocky 9 and first-boot configuration replaces both EC2 instances. Changes to either instance's user data also replace that instance; this includes the automatic Puppet registration setup. Changing the client hostname also replaces the client instance. Back up any data you need first; the root EBS volumes are deleted when their instances are terminated. Review the plan to confirm the Elastic IP allocations are retained and re-associated. Private IPs can change when instances are replaced. Package updates also make first boot take longer. Additional clients can follow the `puppet-client2` naming pattern.

## Prerequisites

- Terraform 1.5 or newer
- AWS CLI or SDK credentials with permission to create EC2, VPC, security groups, routing, and key pairs in the configured region
- A dedicated SSH key pair at `~/.ssh/puppet-lab` and `~/.ssh/puppet-lab.pub`

The public key is read from `~/.ssh/puppet-lab.pub` when Terraform runs. The private key is only for SSH access; keep it outside the repository.

Set `aws_region` to choose another AWS region. The server's private DNS hostname in `/etc/hosts` uses this value, for example `puppet-server.ap-south-1.compute.internal`.

## Provision and inspect

Run these commands from this directory:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -var='ssh_cidr=YOUR_PUBLIC_IP/32' -var='aws_region=ap-south-1'
terraform apply -var='ssh_cidr=YOUR_PUBLIC_IP/32' -var='aws_region=ap-south-1'
```

Replace `YOUR_PUBLIC_IP/32` with a CIDR that is allowed to SSH to the instances. Use the same values for plan and apply. `ssh_cidr`, `aws_region`, and `github_username` default to `0.0.0.0/0`, `ap-south-1`, and `nicksce`, respectively. Omit their `-var` options to use these defaults, or pass `-var='github_username=YOUR_GITHUB_USERNAME'` to use another repository owner.

Show the Terraform outputs:

```bash
terraform output
```

The outputs include both private IPs and both Elastic IP addresses. The private addresses stay assigned when the instances are stopped and started. Each Elastic IP remains associated through stop/start, so the public addresses stay consistent.

## Monitor first-boot setup

After an instance is reachable over SSH, connect with the Rocky Linux account and follow cloud-init's output log to watch package updates and Puppet installation:

```bash
ssh -i ~/.ssh/puppet-lab rocky@SERVER_PUBLIC_IP
sudo tail -f /var/log/cloud-init-output.log
```

Replace `SERVER_PUBLIC_IP` with the instance's Elastic IP. The detailed cloud-init log is available at `/var/log/cloud-init.log`. Cloud-init writes user-data script output to `cloud-init-output.log` by default. See the [cloud-init logging documentation](https://cloudinit.readthedocs.io/en/latest/topics/logging.html).

## Connect r10k to GitHub and deploy

After cloud-init finishes, connect to `puppet-server`. The r10k configuration uses the SSH URL for the `puppet-control-repo` repository. Override `github_username` if the repository is owned by a different GitHub user, for example `-var='github_username=YOUR_GITHUB_USERNAME'`.

Print the generated public key and copy its output:

```bash
sudo cat /root/.ssh/puppet_github_deploy.pub
```

In GitHub, open the `puppet-control-repo` repository and go to **Settings → Deploy keys → Add deploy key**. Add a title such as `Puppet Server`, paste the public key, and leave **Allow write access** unchecked. Then open a root shell on the server and test the SSH connection:

```bash
sudo -i
ssh -T git@github.com
```

GitHub may respond that authentication succeeded but it does not provide shell access; that response confirms the key was accepted. Deploy the production environment:

```bash
r10k deploy environment production -v info
```

To inspect Puppet's active environment and code directory:

```bash
/opt/puppetlabs/bin/puppet config print environment
/opt/puppetlabs/bin/puppet config print codedir
```

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
