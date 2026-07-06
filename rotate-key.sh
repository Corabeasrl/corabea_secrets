#!/bin/bash
# Re-encrypt every .age file with a new public key.
# Old key must still be able to decrypt.

set -euo pipefail

OLD_KEY="${OLD_KEY:?set OLD_KEY=/path/to/old-age.key}"
NEW_PUBKEY="${NEW_PUBKEY:?set NEW_PUBKEY=age1...}"

for f in $(find . -type f -name '*.age'); do
    echo "Rotating: $f"
    tmp=$(mktemp)
    age -d -i "$OLD_KEY" -o "$tmp" "$f"
    age -r "$NEW_PUBKEY" -o "$f" "$tmp"
    shred -u "$tmp"
done

echo "Done. Commit and push, then update 1Password with the new key."
