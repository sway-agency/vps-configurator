#!/usr/bin/env python3
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWAY_LOGOS = {
    ".github/assets/sway-logo-black.svg": "9aea2f5c3d7a3490b31e9340419e17083ce2f1ed23d8edf0088533d77e837851",
    ".github/assets/sway-logo-white.svg": "3963583ee0b5f077985b9a872f372aa3efcfdb81dc427e7269ca3b1edd7c3bf4",
}
SWAY_LOGO_REFERENCES = [
    ("README.md", 'srcset=".github/assets/sway-logo-white.svg"'),
    ("README.md", 'src=".github/assets/sway-logo-black.svg"'),
]
FORBIDDEN_TRACKED_FILES = [
    (re.compile(r"^ansible/inventories/(?!.*\.example\.yml$).*\.ya?ml$"), "real inventory"),
    (re.compile(r"^ansible/group_vars/(?!.*\.example\.yml$).*\.ya?ml$"), "real group_vars"),
    (re.compile(r"(^|/)[^/]*\.tfvars(\.json)?$"), "terraform variables"),
    (re.compile(r"(^|/)[^/]*\.tfstate(\..*)?$"), "terraform state"),
    (re.compile(r"(^|/)\.terraform/"), "terraform working directory"),
    (re.compile(r"(^|/)(id_rsa|id_ed25519|id_ecdsa)[^/]*$|\.(pem|key|p12|pfx)$"), "private key"),
    (re.compile(r"(^|/)\.env(\..*)?$|(^|/)\.vault_pass$|\.vault$"), "secret file"),
    (re.compile(r"(^|/)\.claude/settings\.local\.json$"), "local agent settings"),
]
TEXT_SUFFIXES = {".md", ".yml", ".yaml", ".tf", ".hcl", ".j2", ".sh", ".py", ".cfg", ".example", ""}
BINARY_SUFFIXES = {".svg", ".png", ".jpg"}

errors = []

def report(relative, line, code, message):
    errors.append(f"{relative}:{line}: [{code}] {message}")

def tracked_files():
    output = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT, check=True, capture_output=True, text=True).stdout
    return [name for name in output.split("\0") if name]

def check_forbidden(relative):
    for pattern, label in FORBIDDEN_TRACKED_FILES:
        if pattern.search(relative):
            report(relative, 0, "N-SEC-01", f"{label} must never be committed")

def is_text(relative):
    path = ROOT / relative
    return path.is_file() and not path.is_symlink() and path.suffix not in BINARY_SUFFIXES and path.suffix in TEXT_SUFFIXES

def check_text(relative):
    text = (ROOT / relative).read_text()
    for number, line in enumerate(text.split("\n"), 1):
        if line != line.rstrip():
            report(relative, number, "N-ALL-01", "trailing whitespace")
    if text and (not text.endswith("\n") or text.endswith("\n\n")):
        report(relative, text.count("\n"), "N-ALL-02", "file must end with exactly one newline")

def check_sway_logos():
    for relative, expected in SWAY_LOGOS.items():
        logo = ROOT / relative
        if not logo.exists():
            report(relative, 0, "N-SWAY-01", "Sway logo was removed")
        elif hashlib.sha256(logo.read_bytes()).hexdigest() != expected:
            report(relative, 0, "N-SWAY-01", "Sway logo was modified")
    for source, reference in SWAY_LOGO_REFERENCES:
        if reference not in (ROOT / source).read_text():
            report(source, 0, "N-SWAY-02", "Sway logo is no longer displayed")

def main():
    for relative in tracked_files():
        check_forbidden(relative)
        if is_text(relative):
            check_text(relative)
    check_sway_logos()
    print("\n".join(errors) if errors else "Norminette: OK")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
