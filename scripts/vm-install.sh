#!/usr/bin/env bash
# Copies build/danky.app into the Tart VM `danky` and launches it there.
set -euo pipefail
cd "$(dirname "$0")/.."

IP="$(tart ip danky)"
SSH_OPTS=(-i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/danky-known-hosts)

ssh "${SSH_OPTS[@]}" "admin@$IP" 'pkill -f danky.app; mkdir -p ~/Applications && rm -rf ~/Applications/danky.app'
scp -rq "${SSH_OPTS[@]}" build/danky.app "admin@$IP:Applications/"
ssh "${SSH_OPTS[@]}" "admin@$IP" 'open ~/Applications/danky.app'
echo "launched danky.app in the VM at $IP"
