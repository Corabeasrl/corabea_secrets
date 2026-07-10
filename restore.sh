#!/bin/bash
# Decrypt every secret in this repo and apply it to the cluster.
# Non-yaml files (WireGuard, k3s token, acme.json) are decrypted into
# /tmp/restore/ for manual placement.

set -euo pipefail

AGE_KEY="${AGE_KEY:-$HOME/corabea-age.key}"

if [ ! -f "$AGE_KEY" ]; then
    echo "ERROR: age key not found at $AGE_KEY"
    echo "Set AGE_KEY=/path/to/key or place the key at ~/corabea-age.key"
    exit 1
fi

if ! command -v age >/dev/null; then
    echo "ERROR: age is not installed. Run 'sudo apt install age'."
    exit 1
fi

echo "Using age key: $AGE_KEY"
echo

for ns in prod test web cert-manager; do
    kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns"
done

for f in $(find prod test web cert-manager -type f -name '*.yaml.age' 2>/dev/null); do
    echo "Applying: $f"
    age -d -i "$AGE_KEY" "$f" | kubectl apply -f -
done

mkdir -p /tmp/restore/infra
chmod 700 /tmp/restore

for f in $(find infra -type f -name '*.age' 2>/dev/null); do
    base=$(basename "$f" .age)
    out="/tmp/restore/infra/$base"
    age -d -i "$AGE_KEY" -o "$out" "$f"
    echo "Decrypted: $out"
done

echo
echo "Done. Yaml secrets applied to the cluster."
echo "Infra files are in /tmp/restore/infra/ — place them by hand:"
echo "  - wireguard-corabea.conf   -> /etc/wireguard/wg0.conf on corabea"
echo "  - wireguard-corabea-1.conf -> /etc/wireguard/wg0.conf on corabea-1"
echo "  - k3s-node-token           -> /var/lib/rancher/k3s/server/node-token on corabea"
echo "  - traefik-acme.json        -> traefik PVC (see RECOVERY.md)"
