## What

## Why

## Tested on

- Provider:
- OS and version:
- Playbook run twice, second run summary (`changed=0`):

## Checklist

- [ ] `python3 scripts/norminette.py` prints `Norminette: OK`
- [ ] `ansible-lint` passes on the production profile
- [ ] `terraform fmt`, `terraform validate` and `tflint` pass on every changed root
- [ ] No secret, real inventory, `group_vars/*.yml`, `*.tfvars` or state file is committed
- [ ] The anti lockout chain (key validation, `sshd -t`, login smoke test, firewall last) is intact
- [ ] New ports, services and variables are closed by default and documented in `group_vars/all.example.yml`
- [ ] The Sway logos and where they are displayed are untouched
