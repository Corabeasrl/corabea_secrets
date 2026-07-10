# corabea-secrets

Encrypted backups of every secret and external config needed to rebuild the Corabea cluster from scratch. Every file is age-encrypted; the private key lives in 1Password (`Corabea DR — age master key`).

If you can read this repo but you don't have the key, you cannot decrypt anything. That is by design.

## Layout

```
prod/            Secrets from the `prod` namespace
test/            Secrets from the `test` namespace
web/             Secrets from the `web` namespace
cert-manager/    ACME account key (avoids Let's Encrypt rate limits on restore)
infra/           Config that lives outside k8s:
                 - wireguard-<host>.conf  per-node WG configuration
                 - k3s-node-token          needed to join new workers
                 - traefik-acme.json       current TLS certs (regenerable)
```

## Decrypt a single file

```
age -d -i ~/corabea-age.key prod/postgres-prod-creds.yaml.age | kubectl apply -f -
```

## Restore everything in one go

`restore.sh` reads a key from `$AGE_KEY` (default `~/corabea-age.key`), decrypts every `*.yaml.age` file, and applies it with `kubectl apply`. Non-yaml files (WireGuard config, node token, acme.json) are decrypted into `/tmp/restore/` for manual placement — see the DR playbook in `corabea-infra/RECOVERY.md`.

```
AGE_KEY=/path/to/corabea-age.key ./restore.sh
```

## Adding a new secret to the backup

```
# 1. Get the plaintext
kubectl get secret -n <ns> <name> -o yaml > /tmp/<name>.yaml

# 2. Encrypt it
age -r $(cat ~/corabea-age.pub) -o <ns>/<name>.yaml.age /tmp/<name>.yaml

# 3. Wipe the plaintext
rm /tmp/<name>.yaml

# 4. Commit and push
git add <ns>/<name>.yaml.age
git commit -m "Add <name> to backup"
git push
```

## When a secret value changes

Repeat the four steps above. The existing `.age` file gets overwritten.

## Rotating the age key

If the key is ever compromised or lost:

1. Generate a new key (`age-keygen -o new.key`).
2. Decrypt every `.age` file with the old key.
3. Re-encrypt every file with the new public key.
4. Update 1Password.
5. Never commit the old key or the intermediate plaintext.

A helper script for this rotation lives at `rotate-key.sh`.
