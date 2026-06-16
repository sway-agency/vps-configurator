# Hostinger — Provisionnement manuel

Hostinger n'a **pas** de provider Terraform officiel (à date 2026-06). On provisionne donc le VPS manuellement, puis Ansible prend le relais — exactement comme pour Scaleway / OVH.

## Étapes

1. **Commander le VPS** dans hpanel.hostinger.com → VPS → choisir un plan.
2. **OS** : choisir **Debian 12** (template officiel).
3. **SSH key** : importer ta clé publique (`~/.ssh/id_ed25519.pub`) dans hpanel → SSH Keys, puis l'attacher au VPS au moment du déploiement.
4. Attendre la fin du provisioning, récupérer l'**IP publique**.
5. Tester `ssh root@<IP>` — doit marcher avec ta clé.

## Handoff vers Ansible

```bash
cd ../../ansible
cp inventory.example.yml inventory.yml
# édite inventory.yml : ansible_host = <IP Hostinger>, ansible_user = root, ansible_port = 22

ansible-playbook -i inventory.yml playbook.yml
```

À partir du 2e run : `ansible_user: deploy`, `ansible_port: 4242`.

## Notes

- Si Hostinger ouvre un provider TF un jour, il viendra ici comme `terraform/hostinger/{main,variables,outputs}.tf`.
- Alternativement, l'API Hostinger (REST) peut être pilotée via un `null_resource` + `curl`, mais ça n'apporte pas grand-chose pour 1 VPS — autant cliquer.
