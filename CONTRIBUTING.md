# Contributing

Thanks for helping. Humans and AI agents follow the same rules.

## Before you start

- AI agents read `CLAUDE.md` (or `AGENTS.md`, the same file).
- Security issues are never reported in a public issue or pull request: see `SECURITY.md`.
- The Sway logos and where they are displayed are not open to changes (N-SWAY-01, N-SWAY-02).

## Golden rules

1. **Never commit a secret or a real environment.** Inventories, `group_vars/*.yml`, `*.tfvars`, Terraform state, private keys and `.env` files stay local. Only `*.example*` files are committed, with fake values.
2. **Never lock the operator out.** Any change to `ssh.yml`, `user.yml` or `firewall.yml` keeps the anti lockout chain: key validation, `sshd -t`, smoke test of the new login, firewall last.
3. **Secure by default.** A new port, egress rule or service is closed unless a variable opens it, and the variable is documented in `group_vars/all.example.yml`.
4. **Idempotent.** Running the playbook twice in a row reports no change the second time.
5. **Pinned.** New Terraform providers, Ansible collections, downloaded binaries and GitHub Actions are pinned to a version (actions to a full commit SHA).

## Development setup

```sh
python3 -m pip install ansible-core ansible-lint checkov
brew install terraform tflint shellcheck actionlint gitleaks zizmor
cd ansible && ansible-galaxy collection install -r requirements.yml
```

## Checks to run before a pull request

```sh
python3 scripts/norminette.py
(cd ansible && ansible-lint)
terraform fmt -check -recursive terraform
tflint --recursive --config "$PWD/.tflint.hcl"
checkov --config-file .checkov.yaml
git ls-files '*.sh' | xargs shellcheck
actionlint && zizmor .github/workflows
gitleaks git --redact .
```

For Terraform validation, run `terraform -chdir=<root> init -backend=false && terraform -chdir=<root> validate` in each changed root (`terraform/ovh`, `terraform/scaleway/envs/*`).

If you have a disposable Debian 12 or Ubuntu VPS, run the playbook twice on it and attach the summary of the second run to the pull request.

## Workflow

1. Fork the repository, or branch from `main` if you have write access: `feature/<topic>` or `fix/<topic>`.
2. Keep the change small and focused.
3. Run the checks above.
4. Commit following the rules below and open a pull request with the template filled in.

## Commits

Commits follow [Conventional Commits](https://www.conventionalcommits.org) on **one line only** (`git log --oneline` must tell the whole story):

```text
type(scope): imperative description in English
```

- Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`, `build`, `ci`, `chore`.
- Scopes: `ansible`, `ssh`, `firewall`, `docker`, `terraform`, `scaleway`, `ovh`, `ci`, `docs`.
- No body, no trailing full stop.
- No `Co-Authored-By` trailer and no mention of a tool or an AI, in commits or pull requests.

```text
feat(firewall): allow extra outbound udp ports
fix(scaleway): attach routed ipv6 to the instance
docs(ovh): document openstack credentials
```

## Pull requests

`main` is protected: every change lands through a squashed pull request with all checks green and the approval of a code owner listed in `.github/CODEOWNERS`.

Fill in `.github/pull_request_template.md`. CI runs the norminette, ansible-lint (production profile), a playbook syntax check, Terraform fmt, validate and TFLint, ShellCheck, actionlint, zizmor, Checkov, Gitleaks, dependency review and CodeQL on every pull request.
