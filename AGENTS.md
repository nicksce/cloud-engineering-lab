# Instructions for coding agents

## Repository organization

- The repository root catalogs independent AWS Terraform examples; each example has its own configuration, state, provider lock file, and README.
- Read the selected example's documentation and configuration before editing. Keep changes isolated to that example unless the user asks otherwise.
- Update the root README when examples are added or renamed.
- The current `puppet/` example provisions only AWS infrastructure for a Rocky Linux 9 Puppet lab. Do not add Puppet installation automation or Ansible unless requested.

## Terraform and AWS changes

- Run Terraform from the selected example directory so it uses the correct state and lock file.
- Never edit state files manually or include their contents in output, documentation, or commits.
- Format and validate Terraform changes when the provider is available, and review plans for unintended replacement or destruction.
- Do not run `terraform apply`, `terraform destroy`, or other AWS mutations unless the user explicitly asks for that operation in the current task.
- Preserve an example's stated region, sizes, tags, and network design unless the user requests changes. Call out broad network access such as SSH from `0.0.0.0/0` when relevant.

## Secrets and documentation

- Do not commit Terraform state, plans, credentials, SSH private keys, API keys, or secret variable files.
- Keep `.terraform.lock.hcl` inside its Terraform example directory and commit it.
- Update the relevant README when setup, resources, costs, or operations change.
