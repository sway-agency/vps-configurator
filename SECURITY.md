# Security policy

VPS Configurator hardens servers, so a weakness in it can expose every server it configured. Thank you for reporting responsibly.

## Reporting a vulnerability

Please **do not open a public issue or pull request**. Report it privately with [GitHub private vulnerability reporting](https://github.com/sway-agency/vps-configurator/security/advisories/new).

Include the affected file and task, the impact (lockout, open port, privilege escalation, secret leak...) and steps to reproduce. You get an answer within 7 days, and a fix or mitigation is published as soon as possible, with credit if you wish.

## Supported versions

Only the latest commit on `main` is supported. Run the playbook again after updating to apply fixes.

## Scope

- Ansible tasks and templates (`ansible/`)
- Terraform modules (`terraform/`)
- GitHub Actions workflows (`.github/workflows/`)

Vulnerabilities in Debian, Ubuntu, Docker, endlessh or a cloud provider are reported upstream.
