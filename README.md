# AWS Terraform experiments

This repository is a collection of independent Terraform examples and experiments for AWS. Each example lives in its own directory, with its own configuration, state, and README. Run Terraform from the example directory you intend to work with; the root directory is for project guidance and navigation.

## Current examples

| Directory | Description |
| --- | --- |
| [`puppet/`](puppet/README.md) | Creates a Rocky Linux 9 Puppet lab with one server and one client. Terraform installs Puppet Server and Puppet Agent through EC2 user data and updates packages on first boot; it does not use Ansible. Read the [Puppet lab article](https://nikunjmaster.org/technology/aws-terraform-puppet-lab). |

Each example README describes its prerequisites, resources, variables, and commands. Add future experiments in new directories and document them in both the directory's README and the table above.

## Website

More from the author: [website](https://nikunjmaster.org) · [technology page](https://nikunjmaster.org/technology).

## Pair programming

This project is maintained through pair programming with OpenAI Codex. To learn
how to set up OpenAI Codex with Visual Studio Code, follow the
[Codex pair programming guide](https://nikunjmaster.org/technology/codex-pair-programming).

## Working with an example

For the Puppet lab, for example:

```bash
cd puppet
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the plan before applying. AWS credentials and permissions are supplied through your AWS CLI or SDK configuration. See [`puppet/README.md`](puppet/README.md) for the lab's network rules, costs, and start/stop commands.

## GitHub and state files

Commit Terraform source, documentation, and each example's `.terraform.lock.hcl`. Do not commit Terraform state, plans, credentials, SSH private keys, or other secrets. The root `.gitignore` excludes common local state and secret files. Terraform state can contain sensitive infrastructure information; use a secured remote backend before collaborating or applying from multiple machines.
