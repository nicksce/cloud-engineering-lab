# Repository instructions for coding agents

## Project scope

This repository provisions a two-instance Rocky Linux 10 Puppet lab in AWS with Terraform and configures Puppet Server and Puppet Agent with Ansible. Keep changes limited to this lab unless the user requests broader infrastructure work.

## Terraform

- Preserve the AWS region `ap-south-1`, VPC CIDR `10.20.0.0/16`, subnet CIDR `10.20.1.0/24`, instance sizes, and requested tags unless the user asks to change them.
- Keep Terraform resource definitions as the source of truth. Do not edit Terraform state files manually.
- Treat `terraform.tfstate`, backups, and plans as local sensitive artifacts. Never print or commit their contents.
- The SSH ingress default currently permits `0.0.0.0/0`. Call this out when changing network rules and prefer a user-specified trusted CIDR for new deployments.
- Do not run `terraform apply`, `terraform destroy`, or other AWS mutations unless the user explicitly asks for that operation in the current task.
- Before proposing an apply, review the plan for unexpected replacement or destruction.

## Ansible

- Use `inventory.ini` for the current public addresses. These can change after a stop and start; refresh them from AWS before remote Ansible runs.
- The client uses the server's private IP in `install_puppet.yml`. Update it if the server is replaced or its address changes.
- Use the dedicated `~/.ssh/puppet-lab` key. Never copy private key material into this repository, command output, or documentation.
- Puppet Core repository access uses `PUPPET_FORGE_API_KEY`. Keep it out of source control, logs, and task output. Ansible tasks that handle it should use `no_log: true`.
- Keep Ansible changes idempotent and use `become: true` for tasks requiring root privileges.

## Review and validation

- Run `terraform fmt -check` and `terraform validate` after Terraform changes when dependencies are available.
- Run `ansible-playbook --syntax-check install_puppet.yml` after playbook changes.
- Do not run deployments as a substitute for validation. Use AWS-changing commands only when the user explicitly asks to create, update, start, stop, or delete resources.
- Update `README.md` when setup steps, prerequisites, access rules, or operational commands change.
