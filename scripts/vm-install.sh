#!/usr/bin/env bash
# Copies build/scuttle.app into the Tart VM `scuttle` and launches it there.
set -euo pipefail
cd "$(dirname "$0")/.."

IP="$(tart ip scuttle)"
SSH_OPTS=(-i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/scuttle-known-hosts)

ssh "${SSH_OPTS[@]}" "admin@$IP" 'pkill -f scuttle.app; mkdir -p ~/Applications && rm -rf ~/Applications/scuttle.app'
scp -rq "${SSH_OPTS[@]}" build/scuttle.app "admin@$IP:Applications/"
ssh "${SSH_OPTS[@]}" "admin@$IP" 'open ~/Applications/scuttle.app'
echo "launched scuttle.app in the VM at $IP"
